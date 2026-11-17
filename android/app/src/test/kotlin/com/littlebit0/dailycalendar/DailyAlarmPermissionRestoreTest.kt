package com.littlebit0.dailycalendar

import android.Manifest
import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ServiceController
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowNotificationManager

/** Robolectric has no shadow for the Android 14 full-screen-intent permission. */
@Implements(NotificationManager::class)
class FullScreenIntentShadow : ShadowNotificationManager() {
    @Implementation fun canUseFullScreenIntent(): Boolean = allowed
    companion object { @JvmStatic var allowed = true }
}

internal abstract class DailyAlarmServiceTestBase {
    protected val context: Application get() = RuntimeEnvironment.getApplication()
    protected val store get() = context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE)
    protected val notifications get() = shadowOf(context.getSystemService(NotificationManager::class.java))
    protected val scheduled get() = shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms
    private val services = mutableListOf<ServiceController<DailyAlarmService>>()

    protected fun put(alarm: DailyAlarm) = store.edit().putString(alarm.id, alarm.json()).commit()
    protected fun missed(alarm: DailyAlarm) = notifications.getNotification(alarm.id, DailyAlarmScheduler.MISSED_NOTIFICATION_ID)
    protected fun fire(alarm: DailyAlarm) = DailyAlarmReceiver().onReceive(
        context, Intent().putExtra(DailyAlarmScheduler.EVENT_ID, alarm.id).putExtra(DailyAlarmScheduler.FIRE_AT, alarm.fireAt))

    /** Starts the alarm service so that [alarm] is ringing. */
    protected fun ring(alarm: DailyAlarm): DailyAlarmService {
        val controller = Robolectric.buildService(DailyAlarmService::class.java,
            Intent(context, DailyAlarmService::class.java).putExtra(DailyAlarmScheduler.EVENT_ID, alarm.id)).create()
        services += controller
        controller.startCommand(0, 1)
        return controller.get()
    }

    @Before fun clear() {
        store.edit().clear().commit()
        DailyAlarmScheduler.createChannel(context)
    }

    // The service keeps its running instance in a static field.
    @After fun stopServices() = services.forEach { it.destroy() }
}

/** #840: Android 14+ with the full-screen-intent permission switched off. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], shadows = [FullScreenIntentShadow::class])
internal class DailyAlarmWithoutFullScreenPermissionTest : DailyAlarmServiceTestBase() {
    private val future get() = System.currentTimeMillis() + 60_000

    @Before fun permissions() {
        shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        FullScreenIntentShadow.allowed = true
    }

    @After fun allowFullScreen() { FullScreenIntentShadow.allowed = true }

    @Test fun alarmScheduledBeforeThePermissionWasRevokedStillRingsAsANotification() {
        val alarm = DailyAlarm("fsi", "Event", "memo", future, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        FullScreenIntentShadow.allowed = false
        assertFalse(DailyAlarmScheduler.authorized(context))
        fire(alarm)
        assertEquals(DailyAlarmService::class.java.name, shadowOf(context).nextStartedService?.component?.className)
        val posted = shadowOf(ring(alarm)).lastForegroundNotification
        assertEquals("Event", posted.extras.getString(android.app.Notification.EXTRA_TITLE))
        assertNull(posted.fullScreenIntent)
        assertEquals(2, posted.actions.size)
    }

    @Test fun allPermissionsKeepTheFullScreenAlarm() {
        val alarm = DailyAlarm("full", "Event", "memo", future, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        assertTrue(DailyAlarmScheduler.authorized(context))
        fire(alarm)
        assertNotNull(shadowOf(context).nextStartedService)
        assertNotNull(shadowOf(ring(alarm)).lastForegroundNotification.fullScreenIntent)
    }

    @Test fun revokedNotificationPermissionStillDropsTheAlarm() {
        val alarm = DailyAlarm("silent", "Event", "", future, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        notifications.setNotificationsEnabled(false)
        fire(alarm)
        assertNull(shadowOf(context).nextStartedService)
        // Nothing can be shown; the stored entry is left as before.
        assertEquals(alarm, DailyAlarmScheduler.read(context, alarm.id))
    }

    @Test fun snoozeReschedulesAndStopsRinging() {
        val alarm = DailyAlarm("snooze", "Event", "", future, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        val service = ring(alarm)
        FullScreenIntentShadow.allowed = false
        val before = System.currentTimeMillis()
        service.remove(alarm.id, true)
        assertTrue(shadowOf(service).isStoppedBySelf)
        val saved = DailyAlarmScheduler.read(context, alarm.id)!!
        assertTrue(saved.fireAt >= before + 10 * 60_000L)
        assertEquals(alarm.sourceFireAt, saved.sourceFireAt)
        assertEquals(1, scheduled.size)
    }

    @Test fun restoreRearmsFutureAlarmsAndShowsMissedOnes() {
        val now = System.currentTimeMillis()
        val upcoming = DailyAlarm("upcoming", "Event", "", now + 60_000, 10)
        val recent = DailyAlarm("recent", "Event", "", now - 60_000, 10)
        put(upcoming); put(recent)
        FullScreenIntentShadow.allowed = false
        DailyAlarmReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(1, scheduled.size)
        assertEquals(upcoming, DailyAlarmScheduler.read(context, upcoming.id))
        assertNull(DailyAlarmScheduler.read(context, recent.id))
        assertNotNull(missed(recent))
    }

    @Test fun newAlarmsStillNeedEveryPermission() {
        FullScreenIntentShadow.allowed = false
        assertThrows(IllegalStateException::class.java) {
            DailyAlarmScheduler.scheduleAll(context, "new", "Event", "", 10, listOf(future))
        }
        assertTrue(DailyAlarmScheduler.alarms(context, "new").isEmpty())
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        FullScreenIntentShadow.allowed = true
        assertThrows(IllegalStateException::class.java) {
            DailyAlarmScheduler.schedule(context, DailyAlarm("exact", "Event", "", future, 10))
        }
    }
}

/** #844: restoring after boot, an app update or a time or time-zone change. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
internal class DailyAlarmRestoreTest : DailyAlarmServiceTestBase() {
    @Test fun alarmThatPassedWithinTheWindowIsShownAsMissedWithoutRinging() {
        val now = System.currentTimeMillis()
        val recent = DailyAlarm("recent", "Morning", "", now - DailyAlarmScheduler.MISSED_WINDOW + 60_000, 10)
        put(recent)
        DailyAlarmReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        val posted = missed(recent)
        assertEquals("Morning", posted.extras.getString(android.app.Notification.EXTRA_TITLE))
        assertTrue(posted.extras.getString(android.app.Notification.EXTRA_TEXT)!!.startsWith("Missed alarm"))
        assertNull(shadowOf(context).nextStartedService)
        assertNull(DailyAlarmScheduler.read(context, recent.id))
        // A second broadcast finds nothing left to announce again.
        context.getSystemService(NotificationManager::class.java).cancelAll()
        DailyAlarmReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))
        assertNull(missed(recent))
    }

    @Test fun alarmOlderThanTheWindowIsRemovedSilently() {
        val old = DailyAlarm("old", "Event", "", System.currentTimeMillis() - DailyAlarmScheduler.MISSED_WINDOW - 60_000, 10)
        put(old)
        DailyAlarmScheduler.restore(context)
        assertNull(DailyAlarmScheduler.read(context, old.id))
        assertNull(missed(old))
        assertNull(shadowOf(context).nextStartedService)
        assertTrue(scheduled.isEmpty())
    }

    @Test fun snoozedAlarmKeepsItsSnoozeTimeAndSource() {
        val now = System.currentTimeMillis()
        val snoozed = DailyAlarm("snoozed", "Event", "", now + 5 * 60_000, 10, now - 5 * 60_000)
        put(snoozed)
        DailyAlarmScheduler.restore(context)
        assertEquals(snoozed, DailyAlarmScheduler.read(context, snoozed.id))
        assertEquals(1, scheduled.size)
        assertNull(missed(snoozed))
    }

    @Test fun ringingAlarmSurvivesTimeZoneAndUpdateBroadcasts() {
        val ringing = DailyAlarm("ringing", "Event", "", System.currentTimeMillis() - 30_000, 10)
        put(ringing)
        val service = ring(ringing)
        for (action in listOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_BOOT_COMPLETED)) {
            DailyAlarmReceiver().onReceive(context, Intent(action))
            assertEquals(action, ringing, DailyAlarmScheduler.read(context, ringing.id))
            assertFalse(action, shadowOf(service).isStoppedBySelf)
            assertNull(action, missed(ringing))
        }
        // Stopping it afterwards still clears the entry.
        service.remove(ringing.id, false)
        assertNull(DailyAlarmScheduler.read(context, ringing.id))
        assertTrue(shadowOf(service).isStoppedBySelf)
    }

    @Test fun ringingAlarmIsNotRearmedWhenTheClockMovesBack() {
        val ringing = DailyAlarm("back", "Event", "", System.currentTimeMillis() + 60_000, 10)
        put(ringing)
        ring(ringing)
        DailyAlarmReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))
        assertTrue(scheduled.isEmpty())
        assertEquals(ringing, DailyAlarmScheduler.read(context, ringing.id))
    }

    @Test fun deniedNotificationsLeaveStoredAlarmsUntouched() {
        val recent = DailyAlarm("recent", "Event", "", System.currentTimeMillis() - 60_000, 10)
        put(recent)
        notifications.setNotificationsEnabled(false)
        DailyAlarmScheduler.restore(context)
        assertEquals(recent, DailyAlarmScheduler.read(context, recent.id))
        assertNull(missed(recent))
    }
}
