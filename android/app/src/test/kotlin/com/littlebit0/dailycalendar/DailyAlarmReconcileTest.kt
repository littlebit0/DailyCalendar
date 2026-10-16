package com.littlebit0.dailycalendar

import android.content.Context
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyAlarmReconcileTest {
    @Test fun unchangedSourceRetainsSnoozeAndSourceIdentityAcrossReload() {
        val context: Context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE).edit().clear().commit()
        DailyAlarmScheduler.createChannel(context)
        val now = System.currentTimeMillis()
        val source = DailyAlarm("snooze", "event", "memo", now - 60_000, 10)
        val snoozed = source.copy(fireAt = now + 600_000)
        DailyAlarmScheduler.schedule(context, snoozed)
        assertTrue(DailyAlarmScheduler.reconcile(context, source))
        val saved = DailyAlarmScheduler.read(context, source.eventId)!!
        assertEquals(snoozed.fireAt, saved.fireAt)
        assertEquals(source.fireAt, saved.sourceFireAt)
        val changed = source.copy(fireAt = now + 1_200_000, sourceFireAt = now + 1_200_000)
        assertTrue(DailyAlarmScheduler.reconcile(context, changed))
        assertEquals(changed.fireAt, DailyAlarmScheduler.read(context, source.eventId)!!.fireAt)
        DailyAlarmScheduler.cancel(context, source.eventId)
        assertNull(DailyAlarmScheduler.read(context, source.eventId))
    }

    @Test fun ringingSourceIsNotRemovedOrRescheduledToPast() {
        val context: Context = RuntimeEnvironment.getApplication()
        val source = DailyAlarm("ringing", "event", "memo", System.currentTimeMillis() - 60_000, 10)
        val store = context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE)
        store.edit().clear().putString(source.eventId, source.json()).commit()
        assertTrue(DailyAlarmScheduler.reconcile(context, source))
        assertEquals(source, DailyAlarmScheduler.read(context, source.eventId))
    }
}
