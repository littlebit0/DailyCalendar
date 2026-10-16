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
class DailyWidgetOccurrenceTest {
    @Test fun actionPersistsSelectedOccurrenceAndOptimismDoesNotTouchAnotherDay() {
        val context: Context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("daily_android_widgets", Context.MODE_PRIVATE).edit().clear().commit()
        val first = "series@2026-10-15T09:00:00.000"
        val second = "series@2026-10-16T09:00:00.000"
        val events = listOf(first, second).map { mapOf("id" to it, "eventId" to "series", "completed" to false) }
        val snapshot = mapOf("generatedAt" to 1, "themeMode" to "light", "monthDays" to emptyList<Any>(),
            "todayEvents" to events, "ddays" to emptyList<Any>())
        assertTrue(DailyAndroidWidgetStore.updateSnapshot(context, snapshot))
        val token = DailyAndroidWidgetStore.enqueueTodoAction(context, "series", true, first)
        val action = DailyAndroidWidgetStore.pendingTodoActions(context).single()
        assertEquals(first, action["occurrenceId"])
        assertEquals("series", action["eventId"])
        // A fresh Flutter snapshot must replay only the selected occurrence.
        DailyAndroidWidgetStore.updateSnapshot(context, snapshot)
        val rows = DailyAndroidWidgetStore.snapshot(context)!!.getJSONArray("todayEvents")
        assertTrue(rows.getJSONObject(0).getBoolean("completed"))
        assertFalse(rows.getJSONObject(1).getBoolean("completed"))
        assertTrue(DailyAndroidWidgetStore.acknowledgeTodoActions(context, setOf(token)))
        assertTrue(DailyAndroidWidgetStore.pendingTodoActions(context).isEmpty())
    }
}
