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
    @Test fun completionLinesRetainLogicalWidthAcrossDensityAndFontScale() {
        for (density in listOf(1f, 2f, 3f)) {
            for (fontScale in listOf(1f, 1.5f, 2f)) {
                for (size in listOf(8f, 9f, 13f, 24f)) {
                    val font = size * density * fontScale
                    assertTrue(DailyCompletionContrast.strokeWidth(font, density) / density >= 1.25f)
                }
            }
        }
    }

    @Test fun nativePalettesExactlyMatchDartFixtures() {
        val roots = generateSequence(java.io.File(checkNotNull(System.getProperty("user.dir")))) { it.parentFile }
        val file = roots.map { java.io.File(it, "tool/tests/fixtures/event_palette.json") }
            .first { it.isFile }
        val cases = JSONObject(file.readText()).getJSONArray("cases")
        assertEquals(512, cases.length())
        for (index in 0 until cases.length()) {
            val row = cases.getJSONArray(index)
            val colors = DailyCompletionContrast.resolve(row.getLong(0).toInt(), row.getLong(1).toInt())
            assertEquals("foreground at $index", row.getLong(2).toInt(), colors.foreground)
            assertEquals("strike at $index", row.getLong(3).toInt(), colors.strike)
            assertEquals("background at $index", row.getLong(4).toInt(), colors.background)
        }
    }

    @Test fun everyRgbTenStepValueHasReadableTitleAndLineOnActualWidgetSurfaces() {
        // This independent evaluator checks final 8-bit rendered colours.
        val linear = DoubleArray(256) { c ->
            val v = c / 255.0
            if (v <= .04045) v / 12.92 else Math.pow((v + .055) / 1.055, 2.4)
        }
        fun luminance(color: Int): Double =
            linear[android.graphics.Color.red(color)] * .2126 +
                linear[android.graphics.Color.green(color)] * .7152 +
                linear[android.graphics.Color.blue(color)] * .0722 + .05
        fun contrast(a: Int, b: Int): Double =
            maxOf(luminance(a), luminance(b)) / minOf(luminance(a), luminance(b))
        val values = (0..250 step 10).toList() + 255
        var count = 0
        for (r in values) for (g in values) for (b in values) {
            val category = android.graphics.Color.rgb(r, g, b)
            for (surface in listOf(0xff000000.toInt(), 0xfffdfdfe.toInt())) {
                for (alpha in listOf(0.0, 38 / 255.0)) {
                    val background = DailyCompletionContrast.blend(category, surface, alpha)
                    val colors = DailyCompletionContrast.resolve(category, background)
                    check(contrast(colors.foreground, colors.background) >= 4.5 &&
                        contrast(colors.strike, colors.foreground) >= 3 &&
                        contrast(colors.strike, colors.background) >= 3) {
                        "Inaccessible palette for $r/$g/$b on $surface at $alpha"
                    }
                    count++
                }
            }
        }
        assertEquals(78732, count)
    }

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

    @Test fun todayWidgetPreservesStoredCategoryAndPaintsReadableTitleInBothThemes() {
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
            val surface = if (mode == Configuration.UI_MODE_NIGHT_YES) 0xff000000.toInt() else 0xfffdfdfe.toInt()
            val colors = DailyCompletionContrast.resolve(categoryColor, surface)
            val title = view.findViewById<TextView>(R.id.widget_event_title)
            assertEquals(colors.foreground, title.currentTextColor)
            assertEquals(colors.background, (title.background as android.graphics.drawable.ColorDrawable).color)
            assertEquals(categoryColor, DailyAndroidWidgetStore.snapshot(context)!!
                .getJSONArray("todayEvents").getJSONObject(0).getInt("color"))
            assertEquals(android.view.View.VISIBLE,
                view.findViewById<android.view.View>(R.id.widget_event_strike).visibility)
            assertNotNull(view.findViewById<android.widget.ImageView>(R.id.widget_event_strike).drawable)
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
