package com.daymaster.daymaster

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.Year
import java.time.temporal.ChronoUnit
import kotlin.math.abs

/** A portable snapshot shared by the Flutter app and the system widget. */
object DayMasterStore {
    fun preferences(context: Context) = context.getSharedPreferences("daymaster_native", Context.MODE_PRIVATE)

    fun snapshot(context: Context): JSONObject = runCatching {
        JSONObject(preferences(context).getString("snapshot", "{}") ?: "{}")
    }.getOrDefault(JSONObject())

    fun save(context: Context, json: String): JSONObject {
        require(json.toByteArray(Charsets.UTF_8).size <= 20 * 1024 * 1024) { "Snapshot exceeds 20 MiB" }
        val snapshot = JSONObject(json)
        require(snapshot.optInt("version") == 1) { "Unsupported snapshot version" }
        require(snapshot.optJSONArray("events") != null && snapshot.optJSONArray("widgets") != null) {
            "A snapshot must include events and widgets"
        }
        check(preferences(context).edit().putString("snapshot", snapshot.toString()).commit()) {
            "Could not save the widget snapshot"
        }
        return snapshot
    }

    fun objects(array: JSONArray?): List<JSONObject> = (0 until (array?.length() ?: 0))
        .mapNotNull { array?.optJSONObject(it) }
    fun widgets(context: Context): List<JSONObject> = objects(snapshot(context).optJSONArray("widgets"))
    fun binding(context: Context, widgetId: Int): String? = preferences(context).getString("widget_$widgetId", null)
    fun bind(context: Context, widgetId: Int, configId: String) {
        check(preferences(context).edit().putString("widget_$widgetId", configId).commit())
    }
    fun unbind(context: Context, widgetId: Int) {
        preferences(context).edit().remove("widget_$widgetId").apply()
    }

    fun date(event: JSONObject): LocalDate? = runCatching { LocalDate.parse(event.getString("date")) }.getOrNull()

    // Calendar days are independent of daylight-saving hours.
    fun nextAnniversary(original: LocalDate, today: LocalDate): LocalDate {
        if (today < original) return original
        fun inYear(year: Int): LocalDate = LocalDate.of(year, original.monthValue,
            original.dayOfMonth.coerceAtMost(original.month.length(Year.isLeap(year.toLong()))))
        val current = inYear(today.year)
        return if (current < today) inYear(today.year + 1) else current
    }

    data class Count(val value: Long, val label: String, val target: LocalDate)
    fun count(event: JSONObject, today: LocalDate = LocalDate.now()): Count? {
        val original = date(event) ?: return null
        val target = if (event.optBoolean("repeatYearly")) nextAnniversary(original, today) else original
        val difference = ChronoUnit.DAYS.between(today, target)
        val inclusive = difference < 0 && event.optBoolean("inclusive")
        return Count(abs(difference) + if (inclusive) 1L else 0L,
            when { difference > 0 -> "还有"; difference < 0 -> if (inclusive) "第" else "已经"; else -> "就是今天" },
            target)
    }

    fun elapsed(event: JSONObject, today: LocalDate = LocalDate.now()): Long =
        date(event)?.let {
            (ChronoUnit.DAYS.between(it, today) + if (event.optBoolean("inclusive")) 1L else 0L).coerceAtLeast(0)
        } ?: 0
}
