package com.daymaster.daymaster

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Base64
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.LocalDate
import kotlin.math.roundToInt

class DayMasterWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        Thread {
            try {
                val snapshot = DayMasterStore.snapshot(context)
                ids.forEach { update(context, manager, it, snapshot) }
                DayMasterAlarms.schedule(context, snapshot)
            } finally { pending.finish() }
        }.start()
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        ids.forEach { DayMasterStore.unbind(context, it) }
    }

    companion object {
        fun updateAll(context: Context, snapshot: JSONObject = DayMasterStore.snapshot(context)) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, DayMasterWidgetProvider::class.java))
                .forEach { update(context, manager, it, snapshot) }
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int,
                   snapshot: JSONObject = DayMasterStore.snapshot(context)) {
            manager.updateAppWidget(id, render(context, id, manager.getAppWidgetOptions(id), snapshot))
        }

        fun render(context: Context, widgetId: Int, options: Bundle, snapshot: JSONObject,
                   explicitConfigId: String? = null): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.daymaster_widget)
            val configId = explicitConfigId ?: DayMasterStore.binding(context, widgetId)
            val config = DayMasterStore.objects(snapshot.optJSONArray("widgets"))
                .firstOrNull { it.optString("id") == configId }
            val eventMap = DayMasterStore.objects(snapshot.optJSONArray("events")).associateBy { it.optString("id") }
            val references = config?.optJSONArray("eventIds")
            val events = (0 until (references?.length() ?: 0)).mapNotNull { index ->
                eventMap[references?.optString(index).orEmpty()]?.takeIf { DayMasterStore.date(it) != null }
            }
            val style = config?.optString("style", "number") ?: "number"
            val theme = config?.optString("theme", "blue") ?: "blue"
            val mode = snapshot.optJSONObject("settings")?.optString("themeMode", "system") ?: "system"
            val dark = mode == "dark" || (mode != "light" &&
                (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES)
            val photoStyle = style == "photo"
            val textTone = config?.optString("textTone", "auto")?.takeIf { it in listOf("auto", "light", "dark") } ?: "auto"
            val surfaceDark = when (textTone) { "light" -> true; "dark" -> false; else -> dark }
            val opacity = option(config, "backgroundOpacity", 1f, 0f, 1f)
            val accent = Color.parseColor(when (theme) {
                "rose" -> "#BC486F"
                "green" -> "#177B66"
                "ink" -> "#253449"
                else -> "#2864DC"
            })
            val background = when {
                photoStyle && textTone == "auto" && theme == "rose" -> R.drawable.widget_rose_photo
                photoStyle && textTone == "auto" && theme == "green" -> R.drawable.widget_green_photo
                photoStyle && textTone == "auto" && theme == "ink" -> R.drawable.widget_ink_photo
                photoStyle && textTone == "auto" -> R.drawable.widget_blue_photo
                surfaceDark && theme == "rose" -> R.drawable.widget_rose_dark
                surfaceDark && theme == "green" -> R.drawable.widget_green_dark
                surfaceDark && theme == "ink" -> R.drawable.widget_ink_dark
                surfaceDark -> R.drawable.widget_blue_dark
                theme == "rose" -> R.drawable.widget_rose
                theme == "green" -> R.drawable.widget_green
                theme == "ink" -> R.drawable.widget_ink
                else -> R.drawable.widget_blue
            }
            val foreground = when (textTone) {
                "light" -> Color.WHITE
                "dark" -> Color.parseColor("#18243A")
                else -> if (photoStyle) Color.WHITE else if (dark) Color.rgb(
                    (Color.red(accent) * 0.45f + 255 * 0.55f).toInt(),
                    (Color.green(accent) * 0.45f + 255 * 0.55f).toInt(),
                    (Color.blue(accent) * 0.45f + 255 * 0.55f).toInt()) else accent
            }
            val secondary = Color.parseColor(when (textTone) {
                "light" -> "#E7EBF4"
                "dark" -> "#43516B"
                else -> if (photoStyle) "#E7EBF4" else if (dark) "#A8B6CB" else "#5F7088"
            })
            views.setViewVisibility(R.id.widget_art, View.GONE)
            views.setViewVisibility(R.id.widget_content, View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, View.GONE)
            views.setViewVisibility(R.id.widget_counter, View.VISIBLE)
            views.setViewVisibility(R.id.widget_title, View.VISIBLE)
            val optionsWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            val optionsHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 120)
            val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
            val width = if (landscape) options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, optionsWidth) else optionsWidth
            val height = if (landscape) optionsHeight else options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, optionsHeight)
            val photoBitmap = if (photoStyle) photo(events.firstOrNull()?.optString("photoBase64", "").orEmpty()) else null
            views.setImageViewBitmap(R.id.widget_surface, surface(context, background, width, height, config, photoBitmap, textTone))
            val compact = optionsWidth < 180 || optionsHeight < 125
            val spacing = if (optionsHeight < 100) 8 else if (compact) 12 else 18
            val padding = (spacing * context.resources.displayMetrics.density).toInt()
            views.setViewPadding(R.id.widget_content, padding, padding, padding, padding)
            views.setViewVisibility(R.id.widget_brand, if (optionsHeight < 125) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_label, if (optionsHeight < 100) View.GONE else View.VISIBLE)
            views.setTextViewTextSize(R.id.widget_number, TypedValue.COMPLEX_UNIT_SP, if (compact) 34f else 64f)
            views.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, if (compact) 15f else 18f)
            views.setTextViewText(R.id.widget_brand, context.getString(R.string.widget_brand))
            val rootClick = launch(context, events.firstOrNull()?.optString("id"), widgetId)
            views.setOnClickPendingIntent(R.id.widget_root, rootClick)

            if (config != null && events.isNotEmpty() && style in listOf("ring", "calendar", "ticket", "bloom")) {
                val event = events.first()
                val today = LocalDate.now()
                val count = DayMasterStore.count(event, today)!!
                views.setImageViewBitmap(R.id.widget_art, DayMasterWidgetArt.render(
                    context, style, event, count, width, height, accent, foreground, secondary, surfaceDark, today, opacity))
                views.setViewVisibility(R.id.widget_art, View.VISIBLE)
                views.setViewVisibility(R.id.widget_content, View.GONE)
                val extra = when (style) {
                    "ring" -> "，${today.year} 年进度，已过 ${today.dayOfYear}/${today.lengthOfYear()} 天"
                    "calendar" -> "，今天是 $today，月历中实心标记今天，圈线标记本月的日子"
                    else -> ""
                }
                views.setContentDescription(R.id.widget_root,
                    event.optString("title") + "，" + count.label + " " + count.value + " 天，" + count.target + extra)
                return views
            }

            if (config == null || events.isEmpty()) {
                views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_empty_title))
                views.setTextViewText(R.id.widget_label, context.getString(R.string.widget_empty_label))
                views.setTextViewText(R.id.widget_number, "—")
                views.setTextViewText(R.id.widget_unit, "")
                views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_empty_detail))
                views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, widgetId,
                    Intent(context, DayMasterWidgetConfigureActivity::class.java)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            } else if (style == "list") {
                views.setViewVisibility(R.id.widget_title, View.GONE)
                views.setViewVisibility(R.id.widget_counter, View.GONE)
                views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                views.setTextViewText(R.id.widget_brand, context.getString(R.string.widget_list_title))
                views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_today, LocalDate.now().toString().replace("-", ".")))
                val rows = listOf(R.id.widget_row_one, R.id.widget_row_two, R.id.widget_row_three)
                val titles = listOf(R.id.widget_row_title_one, R.id.widget_row_title_two, R.id.widget_row_title_three)
                val counts = listOf(R.id.widget_row_count_one, R.id.widget_row_count_two, R.id.widget_row_count_three)
                val rowLimit = if (optionsHeight < 125) 1 else if (optionsHeight < 170) 2 else 3
                rows.forEachIndexed { index, row ->
                    val event = events.getOrNull(index)
                    if (event == null || index >= rowLimit) {
                        views.setViewVisibility(row, View.GONE)
                    } else {
                        val count = DayMasterStore.count(event)!!
                        views.setViewVisibility(row, View.VISIBLE)
                        views.setTextViewText(titles[index], event.optString("emoji") + " " + event.optString("title"))
                        views.setTextViewText(counts[index], if (count.value == 0L) count.label else count.label + " " + count.value + " 天")
                        views.setTextColor(titles[index], foreground)
                        views.setTextColor(counts[index], foreground)
                        views.setOnClickPendingIntent(row, launch(context, event.optString("id"), widgetId * 10 + index + 1))
                    }
                }
            } else {
                val event = events.first()
                val count = DayMasterStore.count(event)!!
                views.setTextViewText(R.id.widget_title, event.optString("emoji") + " " + event.optString("title"))
                views.setTextViewText(R.id.widget_label, count.label)
                val number = count.value.toString()
                views.setTextViewText(R.id.widget_number, number)
                val available = (optionsWidth - spacing * 2 - 22).coerceAtLeast(40)
                val fittedSize = available / (number.length * 0.62f * context.resources.configuration.fontScale)
                views.setTextViewTextSize(R.id.widget_number, TypedValue.COMPLEX_UNIT_SP,
                    minOf(if (compact) 34f else 64f, fittedSize).coerceAtLeast(10f))
                views.setTextViewText(R.id.widget_unit, "天")
                val original = DayMasterStore.date(event)!!
                val subtitle = when {
                    style == "dual" && original <= LocalDate.now() ->
                        context.getString(R.string.widget_elapsed, DayMasterStore.elapsed(event), count.target.toString().replace("-", "."))
                    style == "photo" && photoBitmap == null -> context.getString(R.string.widget_photo_missing)
                    else -> count.target.toString().replace("-", ".") +
                        if (event.optBoolean("repeatYearly")) context.getString(R.string.widget_annual) else ""
                }
                views.setTextViewText(R.id.widget_subtitle, subtitle)
            }
            listOf(R.id.widget_title, R.id.widget_label, R.id.widget_number, R.id.widget_unit).forEach {
                views.setTextColor(it, foreground)
            }
            listOf(R.id.widget_brand, R.id.widget_subtitle).forEach { views.setTextColor(it, secondary) }
            views.setViewVisibility(R.id.widget_subtitle, if (optionsHeight < 100) View.GONE else View.VISIBLE)
            return views
        }

        fun launch(context: Context, eventId: String?, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (!eventId.isNullOrEmpty()) {
                intent.putExtra("event_id", eventId)
                intent.data = android.net.Uri.parse("daymaster://event/" + android.net.Uri.encode(eventId))
            }
            return PendingIntent.getActivity(context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        private fun option(config: JSONObject?, key: String, fallback: Float, min: Float, max: Float): Float =
            (config?.optDouble(key, fallback.toDouble())?.takeIf { it.isFinite() }?.toFloat() ?: fallback).coerceIn(min, max)

        /** Fade the composited surface once, so photos and shading never make a transparent widget opaque. */
        private fun surface(context: Context, background: Int, requestedWidth: Int, requestedHeight: Int,
                            config: JSONObject?, photo: Bitmap?, textTone: String): Bitmap {
            val width = requestedWidth.coerceAtLeast(1).toFloat()
            val height = requestedHeight.coerceAtLeast(1).toFloat()
            val resolution = minOf(context.resources.displayMetrics.density, 600f / maxOf(width, height))
            val pixelWidth = (width * resolution).roundToInt().coerceAtLeast(1)
            val pixelHeight = (height * resolution).roundToInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(pixelWidth, pixelHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val bounds = RectF(0f, 0f, pixelWidth.toFloat(), pixelHeight.toFloat())
            val rounded = Path().apply { addRoundRect(bounds, 28f * resolution, 28f * resolution, Path.Direction.CW) }
            canvas.clipPath(rounded)
            val layer = canvas.saveLayerAlpha(bounds, (option(config, "backgroundOpacity", 1f, 0f, 1f) * 255).roundToInt())
            context.getDrawable(background)?.mutate()?.let { drawable ->
                (drawable as? GradientDrawable)?.cornerRadius = 28f * resolution
                drawable.setBounds(0, 0, pixelWidth, pixelHeight)
                drawable.draw(canvas)
            }
            if (photo != null) {
                val scale = maxOf(pixelWidth.toFloat() / photo.width, pixelHeight.toFloat() / photo.height) *
                    option(config, "photoScale", 1f, 1f, 3f)
                val renderedWidth = photo.width * scale
                val renderedHeight = photo.height * scale
                val left = (pixelWidth - renderedWidth) * (option(config, "photoX", 0f, -1f, 1f) + 1f) / 2f
                val top = (pixelHeight - renderedHeight) * (option(config, "photoY", 0f, -1f, 1f) + 1f) / 2f
                val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                canvas.drawBitmap(photo, null, RectF(left, top, left + renderedWidth, top + renderedHeight), paint)
                val dim = option(config, "photoDim", .6f, 0f, .85f)
                val shade = if (textTone == "dark") 255 else 0
                paint.shader = LinearGradient(0f, 0f, 0f, pixelHeight.toFloat(),
                    Color.argb((dim * 255).roundToInt(), shade, shade, shade),
                    Color.argb((minOf(.9f, dim + .15f) * 255).roundToInt(), shade, shade, shade), Shader.TileMode.CLAMP)
                canvas.drawRect(bounds, paint)
            }
            canvas.restoreToCount(layer)
            return bitmap
        }

        private fun photo(encoded: String): Bitmap? = runCatching {
            if (encoded.isEmpty() || encoded.length > 1_400_000) return@runCatching null
            val bytes = Base64.decode(encoded, Base64.DEFAULT)
            if (bytes.size > 1024 * 1024) return@runCatching null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
            val options = BitmapFactory.Options().apply {
                inSampleSize = 1
                // Retain the app's 1200 px source for crop/zoom; only the composed widget is capped at 600 px.
                while (bounds.outWidth / inSampleSize > 1200 || bounds.outHeight / inSampleSize > 1200) inSampleSize *= 2
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        }.getOrNull()
    }
}

