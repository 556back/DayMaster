package com.daymaster.daymaster

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** Inexact alarms need no special alarm access and survive ordinary process death. */
object DayMasterAlarms {
    private const val CHANNEL = "daymaster_dates"
    private const val UPDATE = "com.daymaster.daymaster.UPDATE_DAY"
    private const val REMIND = "com.daymaster.daymaster.REMIND"

    fun notificationsAuthorized(context: Context): Boolean {
        if (!DayMasterStore.preferences(context).getBoolean("reminders_authorized", false)) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    fun setAuthorization(context: Context, enabled: Boolean) {
        DayMasterStore.preferences(context).edit().putBoolean("reminders_authorized", enabled).commit()
        schedule(context, clearNotifications = !enabled)
    }

    @Synchronized
    fun schedule(context: Context, snapshot: JSONObject = DayMasterStore.snapshot(context), clearNotifications: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val preferences = DayMasterStore.preferences(context)
        val oldIds = preferences.getStringSet("scheduled_reminders", emptySet())?.toSet() ?: emptySet()
        oldIds.forEach { id ->
            alarms.cancel(reminderPending(context, id))

        }
        if (clearNotifications) {
            val manager = context.getSystemService(NotificationManager::class.java)
            preferences.getStringSet("posted_notifications", emptySet())?.forEach { manager.cancel(it, 0) }
            preferences.edit().remove("posted_notifications").commit()
        }
        val today = LocalDate.now()
        val zone = ZoneId.systemDefault()
        val widgetIds = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, DayMasterWidgetProvider::class.java))
        val midnight = PendingIntent.getBroadcast(context, 1,
            Intent(context, DayMasterSystemReceiver::class.java).setAction(UPDATE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (widgetIds.isEmpty()) alarms.cancel(midnight)
        else alarms.set(AlarmManager.RTC, today.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli(), midnight)
        val scheduled = mutableSetOf<String>()
        if (notificationsAuthorized(context)) {
            DayMasterStore.objects(snapshot.optJSONArray("events")).forEach { event ->
                val original = DayMasterStore.date(event) ?: return@forEach
                if (event.isNull("reminderDays")) return@forEach
                val offset = event.optInt("reminderDays", -1)
                if (offset !in listOf(0, 1, 3, 7)) return@forEach
                var occurrence = if (event.optBoolean("repeatYearly")) DayMasterStore.nextAnniversary(original, today) else original
                var trigger = occurrence.minusDays(offset.toLong()).atTime(9, 0).atZone(zone).toInstant().toEpochMilli()
                if (trigger <= System.currentTimeMillis() && event.optBoolean("repeatYearly")) {
                    occurrence = DayMasterStore.nextAnniversary(original, occurrence.plusDays(1))
                    trigger = occurrence.minusDays(offset.toLong()).atTime(9, 0).atZone(zone).toInstant().toEpochMilli()
                }
                if (trigger <= System.currentTimeMillis()) return@forEach
                val id = event.optString("id")
                if (id.isEmpty()) return@forEach
                val intent = reminderIntent(context, id)
                    .putExtra("event_id", id)
                    .putExtra("source_date", event.optString("date"))
                    .putExtra("occurrence_date", occurrence.toString())
                    .putExtra("repeat_yearly", event.optBoolean("repeatYearly"))
                    .putExtra("offset", offset)
                val pending = PendingIntent.getBroadcast(context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending)
                scheduled.add(id)
            }
        }
        preferences.edit().putStringSet("scheduled_reminders", scheduled).commit()
    }

    private fun reminderIntent(context: Context, id: String) =
        Intent(context, DayMasterReminderReceiver::class.java).setAction(REMIND)
            .setData(Uri.parse("daymaster://reminder/" + Uri.encode(id)))

    private fun reminderPending(context: Context, id: String) =
        PendingIntent.getBroadcast(context, 0, reminderIntent(context, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    @Synchronized
    fun notify(context: Context, intent: Intent) {
        if (!notificationsAuthorized(context)) return
        val id = intent.getStringExtra("event_id") ?: return
        val event = DayMasterStore.objects(DayMasterStore.snapshot(context).optJSONArray("events"))
            .firstOrNull { it.optString("id") == id } ?: return
        if (event.isNull("reminderDays") || event.optInt("reminderDays") != intent.getIntExtra("offset", -1) ||
            event.optString("date") != intent.getStringExtra("source_date") ||
            event.optBoolean("repeatYearly") != intent.getBooleanExtra("repeat_yearly", false)) return
        val occurrence = runCatching { LocalDate.parse(intent.getStringExtra("occurrence_date")) }.getOrNull() ?: return
        val dueDate = occurrence.minusDays(event.optInt("reminderDays").toLong())
        if (dueDate != LocalDate.now()) return
        val remaining = ChronoUnit.DAYS.between(LocalDate.now(), occurrence)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, context.getString(R.string.reminder_channel), NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = context.getString(R.string.reminder_channel_description) })
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        manager.notify(id, 0, builder
            .setSmallIcon(R.drawable.ic_daymaster_notification)
            .setContentTitle(event.optString("emoji") + " " + event.optString("title"))
            .setContentText(if (remaining == 0L) context.getString(R.string.reminder_today)
                else context.getString(R.string.reminder_remaining, remaining))
            .setContentIntent(DayMasterWidgetProvider.launch(context, id, id.hashCode()))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build())
        val preferences = DayMasterStore.preferences(context)
        val posted = preferences.getStringSet("posted_notifications", emptySet())?.toMutableSet() ?: mutableSetOf()
        posted.add(id)
        preferences.edit().putStringSet("posted_notifications", posted).commit()
    }
}

class DayMasterSystemReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                val snapshot = DayMasterStore.snapshot(context)
                DayMasterWidgetProvider.updateAll(context, snapshot)
                DayMasterAlarms.schedule(context, snapshot)
            } finally { pending.finish() }
        }.start()
    }
}

class DayMasterReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                DayMasterAlarms.notify(context, intent)
                DayMasterAlarms.schedule(context)
            } finally { pending.finish() }
        }.start()
    }
}
