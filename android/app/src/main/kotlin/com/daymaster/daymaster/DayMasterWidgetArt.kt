package com.daymaster.daymaster

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import org.json.JSONObject
import java.time.LocalDate
import java.time.YearMonth
import kotlin.math.min
import kotlin.math.roundToInt

/** Canvas keeps the four illustrated AppWidget styles consistent at launcher resize sizes. */
object DayMasterWidgetArt {
    fun render(context: Context, style: String, event: JSONObject, count: DayMasterStore.Count,
               requestedWidth: Int, requestedHeight: Int, accent: Int, foreground: Int,
               secondary: Int, dark: Boolean, today: LocalDate = LocalDate.now(), backgroundOpacity: Float = 1f): Bitmap {
        val width = requestedWidth.coerceAtLeast(1).toFloat()
        val height = requestedHeight.coerceAtLeast(1).toFloat()
        // A single bitmap stays below 600 × 600 pixels, including on high-density phones.
        val resolution = min(context.resources.displayMetrics.density, 600f / maxOf(width, height))
        val bitmap = Bitmap.createBitmap((width * resolution).roundToInt().coerceAtLeast(1),
            (height * resolution).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap).apply { scale(resolution, resolution) }
        canvas.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, width, height), 28f, 28f, Path.Direction.CW) })
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        val fontScale = context.resources.configuration.fontScale.coerceIn(1f, 1.4f)
        val padding = min(16f, min(width, height) * .1f)
        val right = width - padding
        val innerWidth = width - padding * 2
        val title = (event.optString("emoji") + " " + event.optString("title")).trim()
        val date = count.target.toString().replace("-", ".")
        val dateLabel = if (event.optBoolean("repeatYearly")) "下一次" else "日期"
        val wide = width >= 240 && width / height >= 1.35f
        val soft = Color.argb(if (dark) 35 else 22, Color.red(foreground), Color.green(foreground), Color.blue(foreground))
        val strongSoft = Color.argb(if (dark) 65 else 40, Color.red(foreground), Color.green(foreground), Color.blue(foreground))
        fun artColor(color: Int) = Color.argb((Color.alpha(color) * backgroundOpacity).roundToInt(),
            Color.red(color), Color.green(color), Color.blue(color))

        fun text(value: String, x: Float, centerY: Float, size: Float, maxWidth: Float,
                 color: Int = foreground, bold: Boolean = false, centered: Boolean = false,
                 maxHeight: Float = Float.POSITIVE_INFINITY, fitWidth: Boolean = false) {
            textPaint.color = color
            textPaint.typeface = Typeface.create("sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
            textPaint.textSize = size * fontScale
            val lineHeight = textPaint.descent() - textPaint.ascent()
            if (lineHeight > maxHeight) textPaint.textSize *= maxHeight / lineHeight
            val measuredWidth = textPaint.measureText(value)
            if (fitWidth && measuredWidth > maxWidth) textPaint.textSize *= maxWidth / measuredWidth
            textPaint.textAlign = if (centered) Paint.Align.CENTER else Paint.Align.LEFT
            val display = TextUtils.ellipsize(value, textPaint, maxWidth.coerceAtLeast(1f), TextUtils.TruncateAt.END).toString()
            val baseline = centerY - (textPaint.ascent() + textPaint.descent()) / 2
            canvas.drawText(display, x, baseline, textPaint)
        }

        fun number(x: Float, y: Float, size: Float, available: Float, centered: Boolean = false) {
            val value = count.value.toString()
            textPaint.typeface = Typeface.create("sans-serif", Typeface.BOLD)
            textPaint.textSize = size
            val fitted = min(size, size * available / textPaint.measureText(value).coerceAtLeast(1f))
            // Numbers fit their fixed canvas region independently of the system's body-text scale.
            text(value, x, y, fitted / fontScale, available, bold = true, centered = centered)
        }

        fun circle(x: Float, y: Float, radius: Float, color: Int, stroke: Float = 0f) {
            paint.color = artColor(color)
            paint.style = if (stroke > 0) Paint.Style.STROKE else Paint.Style.FILL
            paint.strokeWidth = stroke
            canvas.drawCircle(x, y, radius.coerceAtLeast(0f), paint)
            paint.style = Paint.Style.FILL
        }

        when (style) {
            "ring" -> {
                val progress = today.dayOfYear.toFloat() / today.lengthOfYear()
                val diameter = if (wide) min(height - padding * 2, width * .42f)
                    else min(innerWidth * .66f, (height - 56f).coerceAtLeast(30f))
                val cx = if (wide) padding + diameter / 2 else width / 2
                val cy = if (wide) height / 2 else 26f + diameter / 2
                val stroke = (diameter * .055f).coerceAtLeast(2f)
                circle(cx, cy, diameter / 2, strongSoft, stroke)
                paint.color = artColor(foreground)
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = stroke
                paint.strokeCap = Paint.Cap.ROUND
                val ring = RectF(cx - diameter / 2, cy - diameter / 2, cx + diameter / 2, cy + diameter / 2)
                canvas.drawArc(ring, -90f, progress * 360f, false, paint)
                paint.style = Paint.Style.FILL
                paint.strokeCap = Paint.Cap.BUTT
                if (!wide) text(count.label, cx, cy - diameter * .25f, min(10f, diameter * .12f),
                    diameter * .8f, centered = true, maxHeight = diameter * .19f)
                number(cx, cy + (if (wide) -diameter * .06f else diameter * .035f),
                    diameter * (if (wide) .31f else .27f), diameter * .74f, centered = true)
                text("天", cx, cy + diameter * .31f, min(11f, diameter * .13f), diameter * .7f,
                    centered = true, maxHeight = diameter * .17f)
                val percent = (progress * 100).toInt()
                if (wide) {
                    val left = padding + diameter + 16f
                    val space = right - left
                    text(title, left, height * .23f, 15f, space, bold = true)
                    text(count.label, left, height * .46f, 13f, space)
                    text(date, left, height * .65f, 11f, space, secondary)
                    text("${today.year} 年进度 · $percent%", left, height * .84f, 10f, space, secondary, fitWidth = true)
                } else {
                    text(title, padding, 14f, 12f, innerWidth, bold = true)
                    text("${today.year} 年进度 · $percent%", width / 2, height - 10f, 9f,
                        innerWidth, secondary, centered = true, fitWidth = true)
                }
            }
            "calendar" -> {
                val month = YearMonth.from(today)
                val rows = (month.atDay(1).dayOfWeek.value - 1 + month.lengthOfMonth() + 6) / 7
                val gridLeft = if (wide) width * .45f else padding
                val gridWidth = right - gridLeft
                val gridTop = if (wide) padding else 26f
                val gridBottom = if (wide) height - padding else height - 34f
                val rowHeight = ((gridBottom - gridTop) / (rows + 1)).coerceAtLeast(5f)
                val cellWidth = gridWidth / 7
                val cellSize = min(cellWidth, rowHeight)
                val targetThisMonth = YearMonth.from(count.target) == month
                "一二三四五六日".forEachIndexed { index, day ->
                    text(day.toString(), gridLeft + (index + .5f) * cellWidth, gridTop + rowHeight * .5f,
                        min(9f, cellSize * .75f), cellWidth, secondary, centered = true, maxHeight = rowHeight * .88f)
                }
                val offset = month.atDay(1).dayOfWeek.value - 1
                for (day in 1..month.lengthOfMonth()) {
                    val index = offset + day - 1
                    val x = gridLeft + (index % 7 + .5f) * cellWidth
                    val y = gridTop + (index / 7 + 1.5f) * rowHeight
                    val isToday = day == today.dayOfMonth
                    val isTarget = targetThisMonth && day == count.target.dayOfMonth
                    if (isToday) circle(x, y, cellSize * .43f, accent)
                    if (isTarget) circle(x, y, cellSize * .46f, foreground, 1.1f)
                    text(day.toString(), x, y, min(10f, cellSize * .83f), cellWidth,
                        if (isToday && backgroundOpacity >= .5f) Color.WHITE else foreground, bold = isToday || isTarget, centered = true,
                        maxHeight = rowHeight * .88f)
                }
                if (wide) {
                    val space = gridLeft - padding - 15f
                    text("${today.year} 年 ${today.monthValue} 月", padding, height * .17f, 11f, space, secondary)
                    text(title, padding, height * .36f, 13f, space, bold = true)
                    number(padding, height * .57f, min(40f, height * .25f), space * .7f)
                    text("天 · ${count.label}", padding, height * .76f, 10f, space)
                    text(date, padding, height - padding, 10f, space, secondary)
                } else {
                    text("${today.year} 年 ${today.monthValue} 月", padding, 13f, 11f, innerWidth, bold = true)
                    text(title, padding, height - 24f, 10f, innerWidth, bold = true, maxHeight = 13f)
                    text("${count.label} ${count.value} 天 · $date", padding, height - 9f, 8f,
                        innerWidth, secondary, maxHeight = 11f, fitWidth = true)
                }
            }
            "ticket" -> {
                val lineX = width * .70f
                val lineY = height * .70f
                val small = height < 120
                text("日子车票", padding, padding + 3f, if (small) 8f else 10f, innerWidth, secondary)
                text(title, padding, height * .28f, if (small) 11f else 14f,
                    if (wide) lineX - padding - 14f else innerWidth, bold = true, maxHeight = height * .14f)
                if (wide) {
                    text(count.label, padding, height * .54f, 11f, lineX - padding - 14f, secondary)
                    text("$dateLabel $date", padding, height * .78f, 11f, lineX - padding - 14f, secondary)
                    number((lineX + width) / 2, height * .40f, min(54f, height * .40f), width - lineX - 16f, centered = true)
                    text("天", (lineX + width) / 2, height * .68f, 11f, width - lineX - 12f, centered = true)
                } else {
                    text(count.label, padding, height * .40f, 9f, innerWidth, secondary, maxHeight = height * .10f)
                    number(padding, height * .58f, min(42f, height * .22f), innerWidth - 18f)
                    text("天", right - 12f, height * .60f, 10f, 15f)
                    text("$dateLabel $date", padding, height * .86f, if (small) 8f else 10f,
                        innerWidth, secondary, maxHeight = height * .15f, fitWidth = true)
                }
                paint.color = artColor(strongSoft)
                paint.strokeWidth = 1.4f
                paint.pathEffect = DashPathEffect(floatArrayOf(2f, 4f), 0f)
                if (wide) canvas.drawLine(lineX, padding, lineX, height - padding, paint)
                else canvas.drawLine(padding, lineY + 4f, right, lineY + 4f, paint)
                paint.pathEffect = null
                // Circular punches mark the perforation without assuming a launcher wallpaper color.
                if (wide) {
                    circle(lineX, 0f, 7f, strongSoft)
                    circle(lineX, height, 7f, strongSoft)
                } else {
                    circle(0f, lineY + 4f, 7f, strongSoft)
                    circle(width, lineY + 4f, 7f, strongSoft)
                }
            }
            "bloom" -> {
                val diameter = if (wide) min(height - padding * 2, width * .42f)
                    else min(innerWidth, (height - 45f).coerceAtLeast(30f))
                val cx = if (wide) width - padding - diameter / 2 else width / 2
                val cy = if (wide) height / 2 else 26f + diameter / 2
                paint.color = artColor(soft)
                // Eight petals decorate the event; they never imply a goal or countdown progress.
                repeat(8) { index ->
                    canvas.save()
                    canvas.rotate(index * 45f, cx, cy)
                    canvas.drawOval(RectF(cx - diameter * .15f, cy - diameter * .48f,
                        cx + diameter * .15f, cy - diameter * .02f), paint)
                    canvas.restore()
                }
                number(cx, cy - diameter * .03f, diameter * .28f, diameter * .68f, centered = true)
                text("天", cx, cy + diameter * .30f, min(11f, diameter * .12f), diameter * .7f,
                    centered = true, maxHeight = diameter * .18f)
                if (wide) {
                    val space = cx - diameter / 2 - padding - 12f
                    text("花开日子", padding, height * .20f, 10f, space, secondary)
                    text(title, padding, height * .40f, 15f, space, bold = true)
                    text(count.label, padding, height * .63f, 13f, space)
                    text(date, padding, height * .83f, 11f, space, secondary)
                } else {
                    text(title, padding, 14f, 12f, innerWidth, bold = true)
                    text("${count.label} · $date", width / 2, height - 10f, 9f,
                        innerWidth, secondary, centered = true, fitWidth = true)
                }
            }
        }
        return bitmap
    }
}
