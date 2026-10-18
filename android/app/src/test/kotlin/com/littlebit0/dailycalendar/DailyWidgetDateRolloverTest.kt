package com.littlebit0.dailycalendar

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyWidgetDateRolloverTest {
    private val seoul = TimeZone.getTimeZone("Asia/Seoul")
    private val utc = TimeZone.getTimeZone("UTC")

    private fun event(id: String) = JSONObject().put("id", id).put("title", id)

    private fun dday(id: String, remaining: Int) =
        JSONObject().put("id", id).put("daysRemaining", remaining)

    private fun view(date: String, title: String, vararg events: String, ddays: JSONArray = JSONArray()) =
        JSONObject()
            .put("date", date)
            .put("todayTitle", title)
            .put("weekTitle", "week $date")
            .put("todayEvents", JSONArray(events.map { event(it) }))
            .put("todayRemainingCount", 0)
            .put("ddays", ddays)

    /** A snapshot built on Oct 31, 2026 (Seoul) whose grid ends on Nov 7. */
    private fun snapshot(): JSONObject {
        val generatedAt = 1_793_000_000_000L
        return JSONObject()
            .put("snapshotDate", "2026-10-31")
            .put("generatedAt", generatedAt)
            .put("utcOffsetMinutes", 540)
            .put("utcOffsetAtMs", generatedAt)
            .put("todayTitle", "Oct 31")
            .put("weekTitle", "week 2026-10-31")
            .put("todayEvents", JSONArray().put(event("old")))
            .put("todayRemainingCount", 0)
            .put("ddays", JSONArray().put(dday("exam", 10)))
            .put(
                "monthDays",
                JSONArray()
                    .put(JSONObject().put("date", "2026-10-31").put("isToday", true))
                    .put(JSONObject().put("date", "2026-11-01").put("isToday", false)),
            )
            .put(
                "dailyViews",
                JSONArray()
                    .put(view("2026-10-31", "Oct 31", "old", ddays = JSONArray().put(dday("exam", 10))))
                    .put(
                        view(
                            "2026-11-01", "Nov 1", "new",
                            ddays = JSONArray().put(dday("exam", 9)).put(dday("fresh", 3)),
                        ),
                    ),
            )
    }

    @Test fun sameDayAndLegacySnapshotsAreReturnedUntouched() {
        val stored = snapshot()
        assertSame(stored, DailyWidgetDateRollover.rollForward(stored, "2026-10-31", seoul))
        val legacy = snapshot().apply { remove("snapshotDate") }
        assertSame(legacy, DailyWidgetDateRollover.rollForward(legacy, "2026-11-01", seoul))
    }

    @Test fun nextDayAcrossAMonthBoundaryUsesThatDaysView() {
        val rolled = DailyWidgetDateRollover.rollForward(snapshot(), "2026-11-01", seoul)!!
        assertEquals("Nov 1", rolled.getString("todayTitle"))
        assertEquals("week 2026-11-01", rolled.getString("weekTitle"))
        assertEquals("new", rolled.getJSONArray("todayEvents").getJSONObject(0).getString("id"))
        val days = rolled.getJSONArray("monthDays")
        assertFalse(days.getJSONObject(0).getBoolean("isToday"))
        assertTrue(days.getJSONObject(1).getBoolean("isToday"))
        assertEquals("2026-11-01", rolled.getString("snapshotDate"))
    }

    @Test fun ddaysComeFromTheDaysOwnRankedList() {
        val rolled = DailyWidgetDateRollover.rollForward(snapshot(), "2026-11-01", seoul)!!
        val ddays = rolled.getJSONArray("ddays")
        assertEquals(2, ddays.length())
        assertEquals(9, ddays.getJSONObject(0).getInt("daysRemaining"))
        assertEquals("fresh", ddays.getJSONObject(1).getString("id"))
    }

    @Test fun aDateOutsideTheCachedGridAsksForARefresh() {
        assertNull(DailyWidgetDateRollover.rollForward(snapshot(), "2026-12-25", seoul))
        val noViews = snapshot().apply { remove("dailyViews") }
        assertNull(DailyWidgetDateRollover.rollForward(noViews, "2026-11-01", seoul))
    }

    @Test fun aTimeZoneChangeInvalidatesEvenOnTheSameDate() {
        assertNotNull(DailyWidgetDateRollover.rollForward(snapshot(), "2026-10-31", seoul))
        assertNull(DailyWidgetDateRollover.rollForward(snapshot(), "2026-10-31", utc))
        assertNull(DailyWidgetDateRollover.rollForward(snapshot(), "2026-11-01", utc))
    }

    @Test fun aDaylightSavingShiftInTheSameZoneIsNotATimeZoneChange() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        // Built on Oct 26 (EDT, UTC-4). The check looks the offset up for the
        // build instant in the zone's own rules, so the later switch to EST in
        // the same zone is not mistaken for a time-zone change.
        val built = 1_793_000_000_000L // 2026-10-26 07:33 UTC
        val stored = snapshot()
            .put("utcOffsetMinutes", newYork.getOffset(built) / 60_000)
            .put("utcOffsetAtMs", built)
        assertNotNull(DailyWidgetDateRollover.rollForward(stored, "2026-10-31", newYork))
    }

    @Test fun todayKeyIsGregorianInTheDeviceZone() {
        // 2026-10-31T16:30:00Z is already Nov 1 in Seoul.
        val instant = 1_793_464_200_000L
        assertEquals("2026-11-01", DailyWidgetDateRollover.todayKey(seoul, instant))
        assertEquals("2026-10-31", DailyWidgetDateRollover.todayKey(utc, instant))
        // A Buddhist-calendar locale must not change the Gregorian key.
        val previous = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale.forLanguageTag("th-TH-u-ca-buddhist"))
            assertEquals("2026-11-01", DailyWidgetDateRollover.todayKey(seoul, instant))
        } finally {
            java.util.Locale.setDefault(previous)
        }
    }
}
