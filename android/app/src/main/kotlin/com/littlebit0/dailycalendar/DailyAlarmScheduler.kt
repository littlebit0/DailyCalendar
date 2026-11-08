package com.littlebit0.dailycalendar

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.ContextCompat
import org.json.JSONObject

internal data class DailyAlarm(
    val eventId: String, val title: String, val memo: String,
    val fireAt: Long, val snoozeMinutes: Int, val sourceFireAt: Long = fireAt,
    // Store key and intent identity. An event has one alarm per source fire
    // time (#784); alarms saved before 4.1.1 keep their event-id key.
    val id: String = "$eventId#$sourceFireAt",
) {
    fun json() = JSONObject().put("eventId", eventId).put("title", title)
        .put("memo", memo).put("fireAt", fireAt).put("sourceFireAt", sourceFireAt).put("snoozeMinutes", snoozeMinutes).toString()

    companion object {
        fun parse(id: String, raw: String): DailyAlarm {
            val json = JSONObject(raw)
            return DailyAlarm(json.getString("eventId"), json.getString("title"),
                json.optString("memo"), json.getLong("fireAt"), json.optInt("snoozeMinutes", 10), json.optLong("sourceFireAt", 0), id)
        }
    }
}

internal object DailyAlarmScheduler {
    const val CHANNEL = "daily_event_alarms"
    // Intent extra holding the alarm's store key ([DailyAlarm.id]).
    const val EVENT_ID = "eventId"
    const val FIRE_AT = "fireAt"
    const val STOP = "daily.alarm.STOP"
    const val SNOOZE = "daily.alarm.SNOOZE"
    const val CLOSED = "daily.alarm.CLOSED"
    private fun store(context: Context) = context.getSharedPreferences("daily_event_alarms", Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(AlarmManager::class.java)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, context.getString(R.string.event_alarm), NotificationManager.IMPORTANCE_HIGH).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
    }

    fun exactAllowed(context: Context) = Build.VERSION.SDK_INT < 31 || manager(context).canScheduleExactAlarms()
    fun notificationsAllowed(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun fullScreenAllowed(context: Context) = Build.VERSION.SDK_INT < 34 ||
        context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    fun authorized(context: Context) = exactAllowed(context) && notificationsAllowed(context) && fullScreenAllowed(context)

    @Synchronized
    fun read(context: Context, id: String): DailyAlarm? = store(context).getString(id, null)?.let {
        runCatching { DailyAlarm.parse(id, it) }.getOrNull()
    }

    /** Every stored alarm of [eventId], including a pre-4.1.1 event-id entry. */
    @Synchronized
    fun alarms(context: Context, eventId: String): List<DailyAlarm> =
        store(context).all.keys.mapNotNull { read(context, it) }.filter { it.eventId == eventId }

    @Synchronized
    fun schedule(context: Context, alarm: DailyAlarm) {
        require(alarm.eventId.isNotBlank() && alarm.title.isNotBlank())
        require(alarm.fireAt > System.currentTimeMillis())
        check(authorized(context)) { "System alarm permissions are required" }
        val previous = store(context).getString(alarm.id, null)
        check(store(context).edit().putString(alarm.id, alarm.json()).commit())
        try {
            manager(context).setAlarmClock(AlarmManager.AlarmClockInfo(alarm.fireAt, showIntent(context, alarm.id)), fireIntent(context, alarm))
        } catch (error: Exception) {
            store(context).edit().putString(alarm.id, previous).commit()
            throw error
        }
    }

    /** Replaces the event's alarms with one per future time in [fireTimes]. */
    @Synchronized
    fun scheduleAll(context: Context, eventId: String, title: String, memo: String, snoozeMinutes: Int, fireTimes: List<Long>): Boolean {
        check(authorized(context)) { "System alarm permissions are required" }
        cancel(context, eventId)
        val now = System.currentTimeMillis()
        val future = fireTimes.distinct().filter { it > now }
        future.forEach { schedule(context, DailyAlarm(eventId, title, memo, it, snoozeMinutes)) }
        return future.isNotEmpty()
    }

    /**
     * Keeps each stored alarm whose source time and text are unchanged
     * (including a ringing or snoozed one, #104), cancels the rest and
     * schedules the missing future times.
     */
    @Synchronized
    fun reconcile(context: Context, eventId: String, title: String, memo: String, snoozeMinutes: Int, fireTimes: List<Long>): Boolean {
        val now = System.currentTimeMillis()
        val remaining = fireTimes.distinct().toMutableList()
        var active = false
        for (existing in alarms(context, eventId)) {
            val sameText = existing.title == title && existing.memo == memo && existing.snoozeMinutes == snoozeMinutes
            val matched = when {
                !sameText -> null
                existing.sourceFireAt in remaining -> existing.sourceFireAt
                // Pre-sourceFireAt entries: an exact time, or a passed one that may be snoozed.
                existing.sourceFireAt == 0L -> remaining.firstOrNull { it == existing.fireAt } ?: remaining.firstOrNull { it <= now }
                else -> null
            }
            if (matched == null) {
                cancelAlarm(context, existing.id)
                continue
            }
            remaining.remove(matched)
            active = true
            // Rearm a future native request (including snooze) after OS restart,
            // but never stop a currently ringing service just to open the app.
            if (existing.fireAt > now) schedule(context, existing)
        }
        for (fireAt in remaining) {
            if (fireAt <= now) continue
            schedule(context, DailyAlarm(eventId, title, memo, fireAt, snoozeMinutes))
            active = true
        }
        return active
    }

    /** Cancels every alarm of [eventId]. */
    @Synchronized
    fun cancel(context: Context, eventId: String) = alarms(context, eventId).forEach { cancelAlarm(context, it.id) }

    /** Cancels the single alarm stored under [id]. */
    @Synchronized
    fun cancelAlarm(context: Context, id: String) {
        read(context, id)?.let { manager(context).cancel(fireIntent(context, it)) }
        check(store(context).edit().remove(id).commit())
        DailyAlarmService.stopEvent(context, id)
    }

    fun cancelAll(context: Context) = store(context).all.keys.toList().forEach { cancelAlarm(context, it) }

    fun restore(context: Context) {
        if (!authorized(context)) return
        store(context).all.keys.toList().forEach { id ->
            val alarm = read(context, id) ?: return@forEach
            if (alarm.fireAt > System.currentTimeMillis()) schedule(context, alarm)
            else cancelAlarm(context, id)
        }
    }

    @Synchronized
    fun finish(context: Context, id: String) {
        store(context).edit().remove(id).commit()
    }

    fun showIntent(context: Context, id: String): PendingIntent = PendingIntent.getActivity(
        context, 0, Intent(context, DailyAlarmActivity::class.java).apply {
            data = Uri.parse("dailycalendar://alarm/${Uri.encode(id)}")
            putExtra(EVENT_ID, id)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun fireIntent(context: Context, alarm: DailyAlarm) = PendingIntent.getBroadcast(
        context, 0, Intent(context, DailyAlarmReceiver::class.java).apply {
            data = Uri.parse("dailycalendar://alarm/fire/${Uri.encode(alarm.id)}")
            putExtra(EVENT_ID, alarm.id)
            putExtra(FIRE_AT, alarm.fireAt)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

class DailyAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) {
            DailyAlarmScheduler.restore(context)
            return
        }
        val id = intent.getStringExtra(DailyAlarmScheduler.EVENT_ID) ?: return
        val alarm = DailyAlarmScheduler.read(context, id) ?: return
        if (alarm.fireAt != intent.getLongExtra(DailyAlarmScheduler.FIRE_AT, -1)) return
        if (!DailyAlarmScheduler.authorized(context)) return
        ContextCompat.startForegroundService(context, Intent(context, DailyAlarmService::class.java).putExtra(DailyAlarmScheduler.EVENT_ID, id))
    }
}
