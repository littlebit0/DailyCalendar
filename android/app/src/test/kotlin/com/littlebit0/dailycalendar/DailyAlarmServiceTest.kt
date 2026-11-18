package com.littlebit0.dailycalendar

import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowPowerManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyAlarmServiceTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val store get() = context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE)

    @Before fun clear() {
        store.edit().clear().commit()
        ShadowPowerManager.reset()
    }

    private fun fire(id: String) = Intent(context, DailyAlarmService::class.java).putExtra(DailyAlarmScheduler.EVENT_ID, id)

    @Test fun cancelledAlarmStillEntersForegroundBeforeStopping() {
        val controller = Robolectric.buildService(DailyAlarmService::class.java, fire("gone#1")).create().startCommand(0, 1)
        val shadow = shadowOf(controller.get())
        // stopForeground(REMOVE) clears the notification; the id proves startForeground() ran.
        assertEquals(0xDA11, shadow.lastForegroundNotificationId)
        assertTrue(shadow.isForegroundStopped)
        assertTrue(shadow.notificationShouldRemoved)
        assertTrue(shadow.isStoppedBySelf)
        controller.destroy()
    }

    @Test fun failedPlaybackKeepsOneWakeLockAndReleasesItOnDestroy() {
        val first = DailyAlarm("a", "event", "", System.currentTimeMillis() - 1_000, 10)
        val second = DailyAlarm("b", "event", "", System.currentTimeMillis() - 1_000, 10)
        store.edit().putString(first.id, first.json()).putString(second.id, second.json()).commit()
        // Robolectric has no alarm data source, so playback fails and the
        // second alarm retries startSound().
        val controller = Robolectric.buildService(DailyAlarmService::class.java, fire(first.id)).create().startCommand(0, 1)
        val lock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(lock.isHeld)
        controller.get().onStartCommand(fire(second.id), 0, 2)
        assertSame(lock, ShadowPowerManager.getLatestWakeLock())
        controller.destroy()
        assertFalse(lock.isHeld)
    }
}
