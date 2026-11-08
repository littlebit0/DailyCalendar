package com.littlebit0.dailycalendar

import android.content.Context
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyAlarmReconcileTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val store get() = context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE)

    @Before fun clear() {
        store.edit().clear().commit()
        DailyAlarmScheduler.createChannel(context)
    }

    private fun times(eventId: String) = DailyAlarmScheduler.alarms(context, eventId).map { it.sourceFireAt }.sorted()

    @Test fun unchangedSourceRetainsSnoozeAndSourceIdentityAcrossReload() {
        val now = System.currentTimeMillis()
        val source = DailyAlarm("snooze", "event", "memo", now - 60_000, 10)
        val snoozed = source.copy(fireAt = now + 600_000)
        DailyAlarmScheduler.schedule(context, snoozed)
        assertTrue(DailyAlarmScheduler.reconcile(context, "snooze", "event", "memo", 10, listOf(source.fireAt)))
        val saved = DailyAlarmScheduler.read(context, source.id)!!
        assertEquals(snoozed.fireAt, saved.fireAt)
        assertEquals(source.fireAt, saved.sourceFireAt)
        val changed = now + 1_200_000
        assertTrue(DailyAlarmScheduler.reconcile(context, "snooze", "event", "memo", 10, listOf(changed)))
        assertEquals(listOf(changed), DailyAlarmScheduler.alarms(context, "snooze").map { it.fireAt })
        DailyAlarmScheduler.cancel(context, "snooze")
        assertTrue(DailyAlarmScheduler.alarms(context, "snooze").isEmpty())
    }

    @Test fun ringingSourceIsNotRemovedOrRescheduledToPast() {
        val source = DailyAlarm("ringing", "event", "memo", System.currentTimeMillis() - 60_000, 10)
        store.edit().putString(source.id, source.json()).commit()
        assertTrue(DailyAlarmScheduler.reconcile(context, "ringing", "event", "memo", 10, listOf(source.fireAt)))
        assertEquals(source, DailyAlarmScheduler.read(context, source.id))
    }

    @Test fun legacyEventKeyedSnoozeIsKeptBesideNewTimes() {
        val now = System.currentTimeMillis()
        // A 4.1.0 entry: stored under the event id, without sourceFireAt.
        val legacy = DailyAlarm("legacy", "event", "memo", now + 300_000, 10, 0L, "legacy")
        store.edit().putString("legacy", legacy.json()).commit()
        val passed = now - 60_000
        val later = now + 3_600_000
        assertTrue(DailyAlarmScheduler.reconcile(context, "legacy", "event", "memo", 10, listOf(passed, later)))
        assertNotNull(DailyAlarmScheduler.read(context, "legacy"))
        assertEquals(listOf(0L, later), times("legacy"))
    }

    @Test fun eachFireTimeGetsItsOwnAlarmAndRemovedTimesAreCancelled() {
        val now = System.currentTimeMillis()
        val first = now + 600_000
        val second = now + 1_200_000
        val third = now + 1_800_000
        assertTrue(DailyAlarmScheduler.scheduleAll(context, "multi", "event", "", 10, listOf(first, second, third, now - 1)))
        assertEquals(listOf(first, second, third), times("multi"))
        assertTrue(DailyAlarmScheduler.reconcile(context, "multi", "event", "", 10, listOf(first, third)))
        assertEquals(listOf(first, third), times("multi"))
        // Changed text replaces every alarm of the event.
        assertTrue(DailyAlarmScheduler.reconcile(context, "multi", "renamed", "", 10, listOf(first)))
        assertEquals(listOf("renamed"), DailyAlarmScheduler.alarms(context, "multi").map { it.title })
        DailyAlarmScheduler.scheduleAll(context, "other", "event", "", 10, listOf(second))
        DailyAlarmScheduler.cancel(context, "multi")
        assertTrue(DailyAlarmScheduler.alarms(context, "multi").isEmpty())
        assertEquals(listOf(second), times("other"))
        assertFalse(DailyAlarmScheduler.scheduleAll(context, "past", "event", "", 10, listOf(now - 1)))
    }
}
