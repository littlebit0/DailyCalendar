package com.littlebit0.dailycalendar

import android.app.AlarmManager
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyWidgetMidnightRefreshTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun at(zone: String, year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) =
        Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
            clear()
            set(year, month - 1, day, hour, minute)
        }.timeInMillis

    private fun next(zone: String, now: Long) =
        DailyWidgetUpdater.nextLocalMidnight(now, TimeZone.getTimeZone(zone))

    @Test fun nextMidnightIsTheStartOfTheFollowingLocalDay() {
        assertEquals(at("Asia/Seoul", 2026, 11, 19, 0), next("Asia/Seoul", at("Asia/Seoul", 2026, 11, 18, 15, 30)))
        assertEquals(at("Asia/Seoul", 2026, 11, 19, 0), next("Asia/Seoul", at("Asia/Seoul", 2026, 11, 18, 23, 59)))
        // Exactly at midnight the next refresh is a full day away.
        assertEquals(at("Asia/Seoul", 2026, 11, 20, 0), next("Asia/Seoul", at("Asia/Seoul", 2026, 11, 19, 0)))
    }

    @Test fun daylightSavingDaysEndAtTheirOwnMidnight() {
        // 2026-03-08 has 23 hours and 2026-11-01 has 25 hours in New York.
        val spring = at("America/New_York", 2026, 3, 8, 0, 30)
        assertEquals(at("America/New_York", 2026, 3, 9, 0), next("America/New_York", spring))
        // 00:30 to the next midnight on a 23-hour day is 22.5 hours.
        assertEquals(22 * 3_600_000L + 30 * 60_000L, next("America/New_York", spring) - spring)
        val autumn = at("America/New_York", 2026, 11, 1, 0, 30)
        assertEquals(at("America/New_York", 2026, 11, 2, 0), next("America/New_York", autumn))
        // and 24.5 hours on a 25-hour day.
        assertEquals(24 * 3_600_000L + 30 * 60_000L, next("America/New_York", autumn) - autumn)
        // Havana skips 00:00 on 2026-03-08; the day then starts at 01:00.
        assertEquals(at("America/Havana", 2026, 3, 8, 1), next("America/Havana", at("America/Havana", 2026, 3, 7, 12)))
    }

    @Test fun alarmIsSetWhileWidgetsExistAndCancelledWithoutThem() {
        val alarms = shadowOf(context.getSystemService(AlarmManager::class.java))
        DailyWidgetUpdater.scheduleMidnightRefresh(context, hasWidgets = true)
        val scheduled = alarms.scheduledAlarms.single()
        assertEquals(AlarmManager.RTC, scheduled.type)
        assertEquals(DailyWidgetUpdater.nextLocalMidnight(System.currentTimeMillis()), scheduled.triggerAtTime)
        // Rescheduling replaces the alarm instead of adding one.
        DailyWidgetUpdater.scheduleMidnightRefresh(context, hasWidgets = true)
        assertEquals(1, alarms.scheduledAlarms.size)
        DailyWidgetUpdater.scheduleMidnightRefresh(context, hasWidgets = false)
        assertNull(alarms.nextScheduledAlarm)
        // No widget is placed in this test, so the default lookup cancels too.
        DailyWidgetUpdater.scheduleMidnightRefresh(context, hasWidgets = true)
        DailyWidgetUpdater.refreshAll(context)
        assertNull(alarms.nextScheduledAlarm)
    }
}
