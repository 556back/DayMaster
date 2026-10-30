package com.daymaster.daymaster

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** The system configuration screen binds each placed widget to a saved Flutter configuration. */
class DayMasterWidgetConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setResult(RESULT_CANCELED)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        title = getString(R.string.widget_config_title)
        val dp = resources.displayMetrics.density
        fun padding(value: Int) = (value * dp).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding(24), padding(24), padding(24), padding(24))
            setBackgroundColor(Color.parseColor("#F8FAFD"))
        }
        layout.addView(TextView(this).apply {
            text = getString(R.string.widget_config_title)
            textSize = 26f
            setTextColor(Color.parseColor("#15233D"))
            setPadding(0, 0, 0, padding(12))
        })
        layout.addView(TextView(this).apply {
            text = getString(R.string.widget_config_help)
            textSize = 15f
            setTextColor(Color.parseColor("#66748B"))
            setPadding(0, 0, 0, padding(20))
        })
        val snapshot = DayMasterStore.snapshot(this)
        val eventMap = DayMasterStore.objects(snapshot.optJSONArray("events")).associateBy { it.optString("id") }
        val widgets = DayMasterStore.objects(snapshot.optJSONArray("widgets"))
        widgets.forEach { config ->
            val eventIds = config.optJSONArray("eventIds")
            val titles = (0 until (eventIds?.length() ?: 0)).mapNotNull {
                eventMap[eventIds?.optString(it).orEmpty()]?.optString("title")
            }
            val style = when (config.optString("style")) {
                "photo" -> getString(R.string.widget_style_photo)
                "dual" -> getString(R.string.widget_style_dual)
                "list" -> getString(R.string.widget_style_list)
                "ring" -> getString(R.string.widget_style_ring)
                "calendar" -> getString(R.string.widget_style_calendar)
                "ticket" -> getString(R.string.widget_style_ticket)
                "bloom" -> getString(R.string.widget_style_bloom)
                else -> getString(R.string.widget_style_number)
            }
            layout.addView(Button(this).apply {
                text = style + " · " + titles.joinToString("、").ifEmpty { getString(R.string.widget_empty_title) }
                isAllCaps = false
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                minHeight = padding(64)
                setTextColor(Color.parseColor("#15233D"))
                setOnClickListener {
                    DayMasterStore.bind(this@DayMasterWidgetConfigureActivity, widgetId, config.getString("id"))
                    DayMasterWidgetProvider.update(this@DayMasterWidgetConfigureActivity,
                        AppWidgetManager.getInstance(this@DayMasterWidgetConfigureActivity), widgetId, snapshot)
                    DayMasterAlarms.schedule(this@DayMasterWidgetConfigureActivity, snapshot)
                    setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                    finish()
                }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        }
        if (widgets.isEmpty()) layout.addView(TextView(this).apply {
            text = getString(R.string.widget_no_configs)
            textSize = 17f
            setTextColor(Color.parseColor("#15233D"))
            setPadding(0, padding(12), 0, padding(20))
        })
        layout.addView(Button(this).apply {
            text = getString(R.string.widget_open_app)
            isAllCaps = false
            setOnClickListener {
                startActivity(Intent(this@DayMasterWidgetConfigureActivity, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                finish()
            }
        })
        setContentView(ScrollView(this).apply { addView(layout) })
    }
}

class DayMasterWidgetPinReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val configId = intent.getStringExtra("config_id") ?: return
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        if (DayMasterStore.widgets(context).none { it.optString("id") == configId }) return
        DayMasterStore.bind(context, widgetId, configId)
        DayMasterWidgetProvider.update(context, AppWidgetManager.getInstance(context), widgetId)
        DayMasterAlarms.schedule(context)
    }
}
