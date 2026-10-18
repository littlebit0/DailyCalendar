package com.littlebit0.dailycalendar

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Re-derives the "today" values of a stored widget snapshot for the device date.
 *
 * Flutter computes `todayTitle`, `todayEvents`, `weekTitle`, `isToday` and
 * `daysRemaining` for `snapshotDate` only. When the date has moved on, this picks
 * the matching precomputed `dailyViews` entry and recomputes the rest without any
 * network access. It returns null when the snapshot cannot represent the new date
 * (outside the cached grid), so widgets ask the user to open the app instead of
 * showing stale values as current (#103).
 */
internal object DailyWidgetDateRollover {
    fun todayKey(calendar: Calendar = Calendar.getInstance()): String =
        "%04d-%02d-%02d".format(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )

    fun rollForward(stored: JSONObject, today: String): JSONObject? {
        val snapshotDate = stored.optString("snapshotDate")
        // Snapshots written before this contract carry no base date to compare.
        if (snapshotDate.isBlank() || snapshotDate == today) return stored

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
        rolled.put("snapshotDate", today)

        rolled.optJSONArray("monthDays")?.let { days ->
            for (index in 0 until days.length()) {
                val day = days.optJSONObject(index) ?: continue
                day.put("isToday", day.optString("date") == today)
            }
        }
        rolled.optJSONArray("ddays")?.let { ddays ->
            for (index in 0 until ddays.length()) {
                val dday = ddays.optJSONObject(index) ?: continue
                val target = dday.optString("targetDate")
                if (target.isNotBlank()) {
                    dday.put("daysRemaining", daysBetween(today, target))
                }
            }
        }
        return rolled
    }

    /** Whole calendar days from [from] to [to] (`yyyy-MM-dd`), independent of time zone and DST. */
    fun daysBetween(from: String, to: String): Int = epochDay(to) - epochDay(from)

    private fun epochDay(date: String): Int {
        val (year, month, day) = date.split("-").map { it.toInt() }
        val y = if (month <= 2) year - 1 else year
        val era = Math.floorDiv(y, 400)
        val yoe = y - era * 400
        val doy = (153 * (month + (if (month > 2) -3 else 9)) + 2) / 5 + day - 1
        val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }
}
