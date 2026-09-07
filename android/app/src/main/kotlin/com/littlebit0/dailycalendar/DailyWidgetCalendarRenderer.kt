package com.littlebit0.dailycalendar

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.TextPaint
import android.text.TextUtils
import org.json.JSONObject
import java.time.LocalDate

internal object DailyWidgetCalendarRenderer {
    data class Bar(val event: JSONObject, val first: Int, val last: Int, val lane: Int)

    fun bars(days: List<JSONObject>): List<Bar> {
        val spans = linkedMapOf<String, Triple<JSONObject, Int, Int>>()
        days.forEachIndexed { dayIndex, day ->
            val events = day.optJSONArray("events") ?: return@forEachIndexed
            for (index in 0 until events.length()) {
                val event = events.optJSONObject(index) ?: continue
                val id = event.optString("id", event.optString("eventId"))
                if (id.isBlank()) continue
                // Occurrence IDs keep separate recurrences distinct.
                val old = spans[id]
                if (old == null) spans[id] = Triple(event, dayIndex, dayIndex)
                else spans[id] = Triple(old.first, old.second, dayIndex)
            }
        }
        val laneEnds = mutableListOf<Int>()
        return spans.values.sortedWith(compareBy({ it.second }, { -(it.third - it.second) }))
            .map { (event, first, last) ->
                val available = laneEnds.indexOfFirst { it < first }
                val lane = if (available < 0) laneEnds.size else available
                if (lane == laneEnds.size) laneEnds.add(last) else laneEnds[lane] = last
                Bar(event, first, last, lane)
            }
    }

    fun render(
        context: Context, days: List<JSONObject>, width: Int, height: Int,
        primary: Int, muted: Int, accent: Int, sunday: Int, saturday: Int,
    ): Bitmap {
        val scale = context.resources.displayMetrics.density.coerceAtMost(2f)
        val bitmap = Bitmap.createBitmap((width * scale).toInt(), (height * scale).toInt(), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(scale, scale)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        val cell = width / 7f
        days.forEachIndexed { index, day ->
            val center = cell * (index + 0.5f)
            if (day.optBoolean("isToday")) {
                paint.color = accent
                canvas.drawCircle(center, 12f, 10f, paint)
            }
            val weekday = runCatching { LocalDate.parse(day.optString("date")).dayOfWeek.value }.getOrNull()
            paint.color = when {
                day.optBoolean("isToday") -> Color.WHITE
                !day.optBoolean("inMonth", true) -> muted
                weekday == 7 -> sunday
                weekday == 6 -> saturday
                else -> primary
            }
            paint.textSize = 11f
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(day.optInt("day").toString(), center, 16f, paint)
        }
        paint.textAlign = Paint.Align.LEFT
        val lanes = ((height - 25) / 16).coerceAtLeast(0)
        val bars = bars(days)
        bars.filter { it.lane < lanes }.forEach { bar ->
            val raw = bar.event.optLong("color", accent.toLong()).toInt() or -0x1000000
            val rect = RectF(bar.first * cell + 1, 25f + bar.lane * 16, (bar.last + 1) * cell - 1, 39f + bar.lane * 16)
            paint.color = (raw and 0x00ffffff) or 0x26000000
            canvas.drawRoundRect(rect, 3f, 3f, paint)
            paint.color = raw
            paint.textSize = 9f
            val label = TextUtils.ellipsize(bar.event.optString("title"), paint, (rect.width() - 4).coerceAtLeast(0f), TextUtils.TruncateAt.END).toString()
            canvas.drawText(label, rect.left + 2, rect.top + 10, paint)
            if (bar.event.optBoolean("completed")) {
                paint.color = primary
                paint.strokeWidth = 0.8f
                canvas.drawLine(rect.left + 2, rect.top + 6, rect.left + 2 + paint.measureText(label), rect.top + 6, paint)
            }
        }
        return bitmap
    }
}
