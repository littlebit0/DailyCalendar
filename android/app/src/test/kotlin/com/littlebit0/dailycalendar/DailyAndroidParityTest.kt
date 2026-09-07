package com.littlebit0.dailycalendar

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DailyAndroidParityTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Before fun reset() {
        context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences("daily_android_widgets", Context.MODE_PRIVATE).edit().clear().commit()
        DailyAlarmScheduler.createChannel(context)
    }

    @Test fun scheduleUpdateAndCancelUseTheSameAlarmIdentity() {
        val alarm = DailyAlarm("id", "Event", "Memo", System.currentTimeMillis() + 60_000, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        val updated = alarm.copy(fireAt = alarm.fireAt + 60_000)
        DailyAlarmScheduler.schedule(context, updated)
        val manager = shadowOf(context.getSystemService(AlarmManager::class.java))
        assertEquals(1, manager.scheduledAlarms.size)
        assertEquals(updated, DailyAlarmScheduler.read(context, "id"))
        DailyAlarmScheduler.cancel(context, "id")
        assertTrue(manager.scheduledAlarms.isEmpty())
        assertNull(DailyAlarmScheduler.read(context, "id"))
    }

    @Test fun cancelAllKeepsOtherPreferencesUntouched() {
        val alarm = DailyAlarm("one", "Event", "", System.currentTimeMillis() + 60_000, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        DailyAlarmScheduler.schedule(context, alarm.copy(eventId = "two"))
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("data", "keep").commit()
        DailyAlarmScheduler.cancelAll(context)
        assertNull(DailyAlarmScheduler.read(context, "one"))
        assertNull(DailyAlarmScheduler.read(context, "two"))
        assertEquals("keep", prefs.getString("data", null))
    }

    @Test fun deniedNotificationsDoNotPersistOrScheduleAnAlarm() {
        shadowOf(context.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        val alarm = DailyAlarm("denied", "Event", "", System.currentTimeMillis() + 60_000, 10)
        assertFalse(DailyAlarmScheduler.authorized(context))
        assertThrows(IllegalStateException::class.java) { DailyAlarmScheduler.schedule(context, alarm) }
        assertNull(DailyAlarmScheduler.read(context, alarm.eventId))
        assertTrue(shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.isEmpty())
    }

    @Test fun staleBroadcastCannotStartAReplacedAlarm() {
        val alarm = DailyAlarm("updated", "Event", "", System.currentTimeMillis() + 60_000, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        DailyAlarmReceiver().onReceive(context, Intent().putExtra(DailyAlarmScheduler.EVENT_ID, alarm.eventId)
            .putExtra(DailyAlarmScheduler.FIRE_AT, alarm.fireAt - 60_000))
        assertNull(shadowOf(RuntimeEnvironment.getApplication()).nextStartedService)
    }

    @Test fun restoringAfterBootKeepsFutureAlarmsAndRemovesExpiredOnes() {
        val alarm = DailyAlarm("future", "Event", "", System.currentTimeMillis() + 60_000, 10)
        DailyAlarmScheduler.schedule(context, alarm)
        context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE).edit()
            .putString("expired", alarm.copy(eventId = "expired", fireAt = 1L).json()).commit()
        DailyAlarmScheduler.restore(context)
        assertEquals(alarm, DailyAlarmScheduler.read(context, "future"))
        assertNull(DailyAlarmScheduler.read(context, "expired"))
        assertEquals(1, shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }

    @Test fun todayWidgetRetainsCategoryColorAndRendersBothSystemThemes() {
        val categoryColor = 0xff2563eb.toInt()
        DailyAndroidWidgetStore.updateSnapshot(context, mapOf(
            "generatedAt" to 1L, "themeMode" to "system", "monthDays" to emptyList<Any>(),
            "todayEvents" to listOf(mapOf("id" to "id", "eventId" to "id", "title" to "Title",
                "completed" to true, "color" to categoryColor)), "ddays" to emptyList<Any>(),
        ))
        val service = org.robolectric.Robolectric.buildService(DailyTodayWidgetService::class.java).create()
        val factory = service.get().onGetViewFactory(Intent())
        for (mode in listOf(Configuration.UI_MODE_NIGHT_NO, Configuration.UI_MODE_NIGHT_YES)) {
            val configuration = Configuration(context.resources.configuration).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
            }
            @Suppress("DEPRECATION")
            context.resources.updateConfiguration(configuration, context.resources.displayMetrics)
            factory.onDataSetChanged()
            val view = factory.getViewAt(0)!!.apply(context, LinearLayout(context))
            assertEquals(categoryColor, view.findViewById<TextView>(R.id.widget_event_title).currentTextColor)
            assertEquals(context.getString(R.string.widget_toggle_todo),
                view.findViewById<android.view.View>(R.id.widget_todo_button).contentDescription)
        }
        service.destroy()
    }

    @Test fun widgetCheckboxDispatchPersistsOnlyTheTargetEvent() {
        DailyAndroidWidgetStore.updateSnapshot(context, mapOf(
            "generatedAt" to 1L, "themeMode" to "system", "monthDays" to emptyList<Any>(),
            "todayEvents" to listOf("one", "two").map { mapOf("id" to it, "title" to "Same", "completed" to false) },
            "ddays" to emptyList<Any>(),
        ))
        DailyWidgetActionReceiver().onReceive(context, DailyWidgetActionReceiver.toggleFillInIntent("one", true))
        val events = DailyAndroidWidgetStore.snapshot(context)!!.getJSONArray("todayEvents")
        assertTrue(events.getJSONObject(0).getBoolean("completed"))
        assertFalse(events.getJSONObject(1).getBoolean("completed"))
        assertEquals(1, DailyAndroidWidgetStore.pendingTodoActions(context).size)
    }

    @Test fun continuousEventsUseOneBarAndDistinctOccurrencesStaySeparate() {
        fun event(id: String) = JSONObject().put("id", id).put("eventId", "recurrence").put("title", "Same title")
        val continuous = event("span")
        val days = (0..6).map { day -> JSONObject().put("events", JSONArray().apply {
            if (day in 1..4) put(continuous)
            if (day in 2..3) put(event("occurrence-$day"))
        }) }
        val bars = DailyWidgetCalendarRenderer.bars(days)
        assertEquals(3, bars.size)
        val span = bars.first { it.event.getString("id") == "span" }
        assertEquals(1, span.first)
        assertEquals(4, span.last)
        assertTrue(bars.filter { it !== span }.all { it.lane > span.lane })
    }

    @Test fun pendingWidgetCompletionSurvivesStaleSnapshotUntilAcknowledged() {
        fun snapshot(completed: Boolean) = mapOf(
            "generatedAt" to 1L, "themeMode" to "system", "monthDays" to emptyList<Any>(),
            "todayEvents" to listOf(mapOf("id" to "id", "eventId" to "id", "completed" to completed)),
            "ddays" to emptyList<Any>(),
        )
        DailyAndroidWidgetStore.updateSnapshot(context, snapshot(false))
        val token = DailyAndroidWidgetStore.enqueueTodoAction(context, "id", true)
        DailyAndroidWidgetStore.updateSnapshot(context, snapshot(false))
        assertTrue(DailyAndroidWidgetStore.snapshot(context)!!.getJSONArray("todayEvents").getJSONObject(0).getBoolean("completed"))
        DailyAndroidWidgetStore.acknowledgeTodoActions(context, setOf(token))
        assertTrue(DailyAndroidWidgetStore.pendingTodoActions(context).isEmpty())
        DailyAndroidWidgetStore.updateSnapshot(context, snapshot(false))
        assertFalse(DailyAndroidWidgetStore.snapshot(context)!!.getJSONArray("todayEvents").getJSONObject(0).getBoolean("completed"))
    }
}
