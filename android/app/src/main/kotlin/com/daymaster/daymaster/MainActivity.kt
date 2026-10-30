package com.daymaster.daymaster

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launchEventId: String? = null
    private var notificationResult: MethodChannel.Result? = null
    private val nativeWork = Executors.newSingleThreadExecutor()
    private val notificationRequest = 9104

    override fun onCreate(savedInstanceState: Bundle?) {
        launchEventId = intent.getStringExtra("event_id")
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daymaster/native").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSnapshot" -> {
                        val json = call.argument<String>("json")
                        if (json == null) result.error("SNAPSHOT_INVALID", "Snapshot JSON is required", null)
                        else nativeWork.execute {
                            try {
                                val snapshot = DayMasterStore.save(this@MainActivity, json)
                                DayMasterWidgetProvider.updateAll(this@MainActivity, snapshot)
                                DayMasterAlarms.schedule(this@MainActivity, snapshot, clearNotifications = true)
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("SNAPSHOT_INVALID", error.message, null) }
                            }
                        }
                    }
                    "requestPinWidget" -> {
                        val configId = call.argument<String>("configId")
                        if (configId == null) result.error("CONFIG_INVALID", "Widget configuration is required", null)
                        else try { result.success(requestWidget(configId)) }
                        catch (error: Exception) { result.error("WIDGET_PIN_FAILED", error.message, null) }
                    }
                    "requestNotifications" -> requestNotifications(result)
                    "getLaunchEventId" -> {
                        result.success(launchEventId)
                        launchEventId = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = intent.getStringExtra("event_id") ?: return
        if (channel != null) channel?.invokeMethod("openEvent", mapOf("id" to id))
        else launchEventId = id
    }

    override fun onResume() {
        super.onResume()
        refreshNativeWidgets()
    }

    override fun onConfigurationChanged(configuration: Configuration) {
        super.onConfigurationChanged(configuration)
        refreshNativeWidgets()
    }

    private fun refreshNativeWidgets() {
        if (nativeWork.isShutdown) return
        nativeWork.execute {
            val snapshot = DayMasterStore.snapshot(this)
            DayMasterWidgetProvider.updateAll(this, snapshot)
            DayMasterAlarms.schedule(this, snapshot)
        }
    }

    private fun requestWidget(configId: String): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val snapshot = DayMasterStore.snapshot(this)
        if (DayMasterStore.objects(snapshot.optJSONArray("widgets")).none { it.optString("id") == configId }) return false
        // The launcher supplies appWidgetId via this explicit callback.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        val callback = PendingIntent.getBroadcast(this, configId.hashCode(),
            Intent(this, DayMasterWidgetPinReceiver::class.java)
                .setData(android.net.Uri.parse("daymaster://pin/" + android.net.Uri.encode(configId)))
                .putExtra("config_id", configId), flags)
        val extras = Bundle().apply {
            putParcelable(AppWidgetManager.EXTRA_APPWIDGET_PREVIEW, DayMasterWidgetProvider.render(this@MainActivity,
                AppWidgetManager.INVALID_APPWIDGET_ID, Bundle(), snapshot, configId))
        }
        return manager.requestPinAppWidget(ComponentName(this, DayMasterWidgetProvider::class.java), extras, callback)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (notificationResult != null) {
            result.error("PERMISSION_PENDING", "A notification permission request is already open", null)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            notificationResult = result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest)
        } else {
            val enabled = getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled()
            completeAuthorization(result, enabled)
        }
    }

    private fun completeAuthorization(result: MethodChannel.Result, granted: Boolean) {
        nativeWork.execute {
            try {
                DayMasterAlarms.setAuthorization(this, granted)
                runOnUiThread { result.success(granted) }
            } catch (error: Exception) {
                runOnUiThread { result.error("PERMISSION_FAILED", error.message, null) }
            }
        }
    }

    override fun onDestroy() {
        nativeWork.shutdown()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grants)
        if (requestCode != notificationRequest) return
        val result = notificationResult ?: return
        notificationResult = null
        completeAuthorization(result, grants.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }
}
