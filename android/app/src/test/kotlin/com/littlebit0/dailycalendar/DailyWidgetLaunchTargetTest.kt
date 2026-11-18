package com.littlebit0.dailycalendar

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyWidgetLaunchTargetTest {
    private fun tap(vararg extras: Pair<String, String>) = Intent().apply {
        putExtra(DailyAndroidWidgetBridge.EXTRA_WIDGET_OPEN, true)
        extras.forEach { (key, value) -> putExtra(key, value) }
    }

    @Before fun clear() {
        DailyAndroidWidgetBridge.takeLaunchTarget()
    }

    @Test fun widgetTapIsTakenOnceAndConsumedFromTheIntent() {
        val intent = tap("eventId" to "weekly", "date" to "2026-09-15")
        DailyAndroidWidgetBridge.offerLaunchTarget(intent)
        assertEquals(mapOf("eventId" to "weekly", "date" to "2026-09-15"), DailyAndroidWidgetBridge.takeLaunchTarget())
        assertNull(DailyAndroidWidgetBridge.takeLaunchTarget())
        // Offering the same intent again (activity recreation) is a no-op.
        assertFalse(intent.hasExtra(DailyAndroidWidgetBridge.EXTRA_WIDGET_OPEN))
        DailyAndroidWidgetBridge.offerLaunchTarget(intent)
        assertNull(DailyAndroidWidgetBridge.takeLaunchTarget())
    }

    @Test fun ordinaryAndRecentsLaunchesCarryNoTarget() {
        DailyAndroidWidgetBridge.offerLaunchTarget(Intent().putExtra("eventId", "weekly"))
        assertNull(DailyAndroidWidgetBridge.takeLaunchTarget())
        DailyAndroidWidgetBridge.offerLaunchTarget(tap("date" to "2026-09-15").addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY))
        assertNull(DailyAndroidWidgetBridge.takeLaunchTarget())
        DailyAndroidWidgetBridge.offerLaunchTarget(null)
        assertNull(DailyAndroidWidgetBridge.takeLaunchTarget())
    }

    @Test fun widgetRowsOpenTheirOccurrenceDay() {
        val intent = DailyWidgetActionReceiver.openFillInIntent(date = "2026-09-15", eventId = "weekly")
        assertEquals("2026-09-15", intent.getStringExtra("date"))
        assertEquals("weekly", intent.getStringExtra("eventId"))
    }
}
