package com.littlebit0.dailycalendar

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Credential-protected storage shared by the Flutter activity and AppWidget
 * providers. The snapshot shape intentionally matches AppleWidgetSnapshotBuilder.
 */
object DailyAndroidWidgetStore {
    private const val PREFERENCES_NAME = "daily_android_widgets"
    private const val SNAPSHOT_KEY = "snapshot_json"
    private const val TODO_ACTIONS_KEY = "todo_actions_json"

    @Synchronized
    fun updateSnapshot(context: Context, rawSnapshot: Map<*, *>): Boolean {
        val snapshot = mapToJson(rawSnapshot)
        requireValidSnapshot(snapshot)
        // Flutter may publish a snapshot before acknowledging an in-flight tap.
        val pending = loadTodoActions(context)
        for (index in 0 until pending.length()) {
            val action = pending.optJSONObject(index) ?: continue
            updateCompletion(snapshot, action.optString("eventId"), action.optBoolean("completed"))
        }
        return preferences(context)
            .edit()
            .putString(SNAPSHOT_KEY, snapshot.toString())
            .commit()
    }

    fun snapshot(context: Context): JSONObject? {
        val raw = preferences(context).getString(SNAPSHOT_KEY, null) ?: return null
        return runCatching { JSONObject(raw) }.getOrNull()
    }

    @Synchronized
    fun enqueueTodoAction(
        context: Context,
        eventId: String,
        completed: Boolean,
    ): String {
        require(eventId.isNotBlank()) { "eventId must not be blank" }
        val token = UUID.randomUUID().toString()
        val actions = loadTodoActions(context)
        actions.put(
            JSONObject()
                .put("token", token)
                .put("eventId", eventId)
                .put("completed", completed),
        )

        val snapshot = snapshot(context)
        if (snapshot != null) {
            updateCompletion(snapshot, eventId, completed)
        }

        val editor = preferences(context)
            .edit()
            .putString(TODO_ACTIONS_KEY, actions.toString())
        if (snapshot != null) {
            editor.putString(SNAPSHOT_KEY, snapshot.toString())
        }
        check(editor.commit()) { "Unable to persist widget Todo action" }
        return token
    }

    @Synchronized
    fun pendingTodoActions(context: Context): List<Map<String, Any>> {
        val actions = loadTodoActions(context)
        val result = mutableListOf<Map<String, Any>>()
        for (index in 0 until actions.length()) {
            val action = actions.optJSONObject(index) ?: continue
            val token = action.optString("token")
            val eventId = action.optString("eventId")
            if (token.isBlank() || eventId.isBlank() || !action.has("completed")) continue
            result += mapOf(
                "token" to token,
                "eventId" to eventId,
                "completed" to action.optBoolean("completed"),
            )
        }
        return result
    }

    @Synchronized
    fun acknowledgeTodoActions(context: Context, tokens: Set<String>): Boolean {
        if (tokens.isEmpty()) return true
        val current = loadTodoActions(context)
        val remaining = JSONArray()
        for (index in 0 until current.length()) {
            val action = current.optJSONObject(index) ?: continue
            if (action.optString("token") !in tokens) {
                remaining.put(action)
            }
        }
        return preferences(context)
            .edit()
            .putString(TODO_ACTIONS_KEY, remaining.toString())
            .commit()
    }

    private fun requireValidSnapshot(snapshot: JSONObject) {
        require(snapshot.has("generatedAt")) { "generatedAt is required" }
        require(snapshot.optString("themeMode").isNotBlank()) { "themeMode is required" }
        require(snapshot.optJSONArray("monthDays") != null) { "monthDays is required" }
        require(snapshot.optJSONArray("todayEvents") != null) { "todayEvents is required" }
        require(snapshot.optJSONArray("ddays") != null) { "ddays is required" }
    }

    private fun loadTodoActions(context: Context): JSONArray {
        val raw = preferences(context).getString(TODO_ACTIONS_KEY, null) ?: return JSONArray()
        return runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
    }

    private fun preferences(context: Context) = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    private fun mapToJson(map: Map<*, *>): JSONObject {
        val result = JSONObject()
        map.forEach { (key, value) ->
            require(key is String) { "Snapshot keys must be strings" }
            result.put(key, jsonValue(value))
        }
        return result
    }

    private fun jsonValue(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> mapToJson(value)
        is Iterable<*> -> JSONArray().also { array ->
            value.forEach { array.put(jsonValue(it)) }
        }
        is Array<*> -> JSONArray().also { array ->
            value.forEach { array.put(jsonValue(it)) }
        }
        is String, is Number, is Boolean -> value
        else -> throw IllegalArgumentException(
            "Unsupported widget snapshot value: ${value::class.java.simpleName}",
        )
    }

    private fun updateCompletion(snapshot: JSONObject, eventId: String, completed: Boolean) {
        updateCompletionInEvents(snapshot.optJSONArray("todayEvents"), eventId, completed)
        updateCompletionInEvents(snapshot.optJSONArray("scheduleEvents"), eventId, completed)
        updateCompletionInEvents(snapshot.optJSONArray("ddays"), eventId, completed)

        val monthDays = snapshot.optJSONArray("monthDays") ?: return
        for (dayIndex in 0 until monthDays.length()) {
            updateCompletionInEvents(
                monthDays.optJSONObject(dayIndex)?.optJSONArray("events"),
                eventId,
                completed,
            )
        }
    }

    private fun updateCompletionInEvents(
        events: JSONArray?,
        eventId: String,
        completed: Boolean,
    ) {
        if (events == null) return
        for (index in 0 until events.length()) {
            val event = events.optJSONObject(index) ?: continue
            if (event.optString("eventId", event.optString("id")) == eventId) {
                event.put("completed", completed)
            }
        }
    }
}
