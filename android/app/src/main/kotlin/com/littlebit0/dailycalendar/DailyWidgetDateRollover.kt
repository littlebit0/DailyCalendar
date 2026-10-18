package com.littlebit0.dailycalendar

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/**
 * Re-derives the "today" values of a stored widget snapshot for the device date.
 *
 * Flutter computes `todayTitle`, `todayEvents`, `weekTitle`, `isToday` and the
 * D-days for `snapshotDate` and, for every day of the cached month grid, a
 * `dailyViews` entry with the same values for that day. When the date has moved
 * on this picks the matching entry, so no date arithmetic or ranking happens
 * here. It returns null when the snapshot cannot represent the situation (the
 * date is outside the cached grid, or the time zone changed since the day
 * buckets were built), so widgets ask the user to open the app instead of
 * showing stale values as current (#103).
 */
internal object DailyWidgetDateRollover {
    /** `yyyy-MM-dd` in the Gregorian calendar and [zone], whatever calendar the user's locale prefers. */
    fun todayKey(
        zone: TimeZone = TimeZone.getDefault(),
        nowMs: Long = System.currentTimeMillis(),
    ): String {
        val calendar = GregorianCalendar(zone)
        calendar.timeInMillis = nowMs
        return "%04d-%02d-%02d".format(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }

    fun rollForward(
        stored: JSONObject,
        today: String,
        zone: TimeZone = TimeZone.getDefault(),
    ): JSONObject? {
        val snapshotDate = stored.optString("snapshotDate")
        // Snapshots written before this contract carry no base date to compare.
        if (snapshotDate.isBlank()) return stored

        // The day buckets were built with one UTC offset. If the device now has a
        // different offset at that same instant, the zone changed and a timed
        // event may belong to another day than the one it was filed under.
        if (stored.has("utcOffsetMinutes") && stored.has("utcOffsetAtMs")) {
            val built = stored.optInt("utcOffsetMinutes")
            val now = zone.getOffset(stored.optLong("utcOffsetAtMs")) / 60_000
            if (built != now) return null
        }
        if (snapshotDate == today) return stored

        val views = stored.optJSONArray("dailyViews") ?: return null
        val view = (0 until views.length())
            .mapNotNull { views.optJSONObject(it) }
            .firstOrNull { it.optString("date") == today }
            ?: return null

        val rolled = JSONObject(stored.toString())
        rolled.put("todayTitle", view.optString("todayTitle"))
        rolled.put("weekTitle", view.optString("weekTitle"))
        rolled.put("todayEvents", view.optJSONArray("todayEvents") ?: JSONArray())
        rolled.put("todayRemainingCount", view.optInt("todayRemainingCount"))
        rolled.put("ddays", view.optJSONArray("ddays") ?: JSONArray())
        rolled.put("snapshotDate", today)

        rolled.optJSONArray("monthDays")?.let { days ->
            for (index in 0 until days.length()) {
                val day = days.optJSONObject(index) ?: continue
                day.put("isToday", day.optString("date") == today)
            }
        }
        return rolled
    }
}
