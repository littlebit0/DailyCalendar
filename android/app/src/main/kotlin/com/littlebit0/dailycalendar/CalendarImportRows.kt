package com.littlebit0.dailycalendar

import android.database.Cursor
import android.os.CancellationSignal
import android.provider.CalendarContract
import java.util.Calendar
import java.util.TimeZone

/** Turns Calendar Provider event rows into the maps sent to Dart. */
internal object CalendarImportRows {
    const val HOUR_MILLIS = 60L * 60L * 1000L
    const val DAY_MILLIS = 24L * HOUR_MILLIS

    val projection = arrayOf(
        CalendarContract.Events._ID,
        CalendarContract.Events.CALENDAR_ID,
        CalendarContract.Events.TITLE,
        CalendarContract.Events.DESCRIPTION,
        CalendarContract.Events.EVENT_LOCATION,
        CalendarContract.Events.DTSTART,
        CalendarContract.Events.DTEND,
        CalendarContract.Events.DURATION,
        CalendarContract.Events.ALL_DAY,
        CalendarContract.Events.RRULE,
        CalendarContract.Events.CUSTOM_APP_URI,
        CalendarContract.Events.DELETED,
        CalendarContract.Events.STATUS,
        CalendarContract.Events.EXDATE,
        CalendarContract.Events.EVENT_TIMEZONE,
        CalendarContract.Events.ORIGINAL_ID,
        CalendarContract.Events.ORIGINAL_INSTANCE_TIME,
        CalendarContract.Events.ORIGINAL_ALL_DAY,
    )

    /**
     * Events by source id, in cursor order. A row with ORIGINAL_ID replaces one occurrence of that
     * series: its original start is excluded from the series, a cancelled one is not imported and
     * a moved one stays as a single event.
     */
    fun read(cursor: Cursor, signal: CancellationSignal? = null): LinkedHashMap<String, MutableMap<String, Any?>> {
        val events = LinkedHashMap<String, MutableMap<String, Any?>>()
        val excluded = mutableMapOf<String, MutableSet<Long>>()
        val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events._ID)
        val calendarIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.CALENDAR_ID)
        val titleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.TITLE)
        val descriptionIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DESCRIPTION)
        val locationIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.EVENT_LOCATION)
        val startIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTSTART)
        val endIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTEND)
        val durationIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DURATION)
        val allDayIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ALL_DAY)
        val ruleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.RRULE)
        val urlIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.CUSTOM_APP_URI)
        val statusIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.STATUS)
        val exdateIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.EXDATE)
        val zoneIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.EVENT_TIMEZONE)
        val originalIdIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ORIGINAL_ID)
        val originalTimeIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ORIGINAL_INSTANCE_TIME)
        val originalAllDayIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ORIGINAL_ALL_DAY)
        while (cursor.moveToNext()) {
            signal?.throwIfCanceled()
            val allDay = cursor.getInt(allDayIndex) == 1
            val sourceId = cursor.getLong(idIndex).toString()
            val originalId = cursor.getString(originalIdIndex)?.takeIf { it.isNotBlank() }
            if (originalId != null) {
                if (!cursor.isNull(originalTimeIndex)) {
                    val original = cursor.getLong(originalTimeIndex)
                    excluded.getOrPut(originalId) { mutableSetOf() } +=
                        if (cursor.getInt(originalAllDayIndex) == 1) utcMidnightToLocalMidnight(original) else original
                }
                if (!cursor.isNull(statusIndex) && cursor.getInt(statusIndex) == CalendarContract.Events.STATUS_CANCELED) continue
            }
            var start = cursor.getLong(startIndex)
            if (allDay) start = utcMidnightToLocalMidnight(start)
            var end = if (cursor.isNull(endIndex)) {
                start + durationMillis(cursor.getString(durationIndex), allDay)
            } else {
                cursor.getLong(endIndex).let { if (allDay) utcMidnightToLocalMidnight(it) else it }
            }
            if (end <= start) end = start + if (allDay) DAY_MILLIS else HOUR_MILLIS
            val event = mutableMapOf<String, Any?>(
                "sourceId" to sourceId,
                "calendarId" to cursor.getLong(calendarIndex).toString(),
                "title" to cursor.getString(titleIndex).orEmpty().ifBlank { "제목 없음" },
                "startMilliseconds" to start,
                "endMilliseconds" to end,
                "allDay" to allDay,
            )
            cursor.getString(descriptionIndex)?.takeIf { it.isNotBlank() }?.let { event["memo"] = it }
            cursor.getString(locationIndex)?.takeIf { it.isNotBlank() }?.let { event["location"] = it }
            cursor.getString(ruleIndex)?.takeIf { it.isNotBlank() }?.let {
                event["recurrenceRule"] = "RRULE:$it"
                val dates = exdateMillis(cursor.getString(exdateIndex), allDay, cursor.getString(zoneIndex))
                if (dates.isNotEmpty()) excluded.getOrPut(sourceId) { mutableSetOf() } += dates
            }
            cursor.getString(urlIndex)?.takeIf { it.isNotBlank() }?.let { event["url"] = it }
            events[sourceId] = event
        }
        excluded.forEach { (id, starts) ->
            events[id]?.takeIf { it.containsKey("recurrenceRule") }?.set("excludedMilliseconds", starts.sorted())
        }
        return events
    }

    private val duration = Regex("([+-])?P(?:(\\d+)W)?(?:(\\d+)D)?T?(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?")

    /**
     * RFC 5545 durations plus what the platform's own parser takes: seconds without "T"
     * (AOSP Calendar stores "P7200S") and a leading sign. Anything else is one hour (all-day: one day).
     */
    fun durationMillis(value: String?, allDay: Boolean): Long {
        val fallback = if (allDay) DAY_MILLIS else HOUR_MILLIS
        val match = value?.trim()?.let(duration::matchEntire) ?: return fallback
        if (match.groupValues[1] == "-") return fallback
        val (weeks, days, hours, minutes, seconds) = (2..6).map { match.groupValues[it].toLongOrNull() ?: 0L }
        val millis = (((weeks * 7 + days) * 24 + hours) * 60 * 60 + minutes * 60 + seconds) * 1000
        return if (millis > 0) millis else fallback
    }

    private val exdateValue = Regex("(\\d{4})(\\d{2})(\\d{2})(?:T(\\d{2})(\\d{2})(\\d{2})(Z)?)?")

    /** Occurrence starts of an EXDATE column, e.g. "20260105T010000Z,..." or "TZID=Asia/Seoul:20260105T100000". */
    fun exdateMillis(value: String?, allDay: Boolean, eventZone: String?): List<Long> {
        if (value.isNullOrBlank()) return emptyList()
        return value.lines().flatMap { line ->
            val parameters = line.substringBeforeLast(':', "")
            val zoneId = Regex("TZID=([^;:]+)").find(parameters)?.groupValues?.get(1) ?: eventZone
            line.substringAfterLast(':').split(',').mapNotNull { raw ->
                val match = exdateValue.matchEntire(raw.trim()) ?: return@mapNotNull null
                val (year, month, day) = (1..3).map { match.groupValues[it].toInt() }
                val dateOnly = match.groupValues[4].isEmpty()
                val zone = when {
                    allDay || dateOnly -> TimeZone.getDefault()
                    match.groupValues[7] == "Z" -> TimeZone.getTimeZone("UTC")
                    zoneId.isNullOrBlank() -> TimeZone.getDefault()
                    else -> TimeZone.getTimeZone(zoneId)
                }
                Calendar.getInstance(zone).apply {
                    clear()
                    if (allDay || dateOnly) set(year, month - 1, day)
                    else set(year, month - 1, day, match.groupValues[4].toInt(), match.groupValues[5].toInt(), match.groupValues[6].toInt())
                }.timeInMillis
            }
        }
    }

    fun utcMidnightToLocalMidnight(value: Long): Long {
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = value }
        return Calendar.getInstance().apply {
            clear()
            set(utc.get(Calendar.YEAR), utc.get(Calendar.MONTH), utc.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
    }
}
