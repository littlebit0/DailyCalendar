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
    val fireAt: Long, val snoozeMinutes: Int,
) {
    fun json() = JSONObject().put("eventId", eventId).put("title", title)
        .put("memo", memo).put("fireAt", fireAt).put("snoozeMinutes", snoozeMinutes).toString()

    companion object {
        fun parse(raw: String): DailyAlarm {
            val json = JSONObject(raw)
            return DailyAlarm(json.getString("eventId"), json.getString("title"),
                json.optString("memo"), json.getLong("fireAt"), json.optInt("snoozeMinutes", 10))
        }
    }
}

internal object DailyAlarmScheduler {
    const val CHANNEL = "daily_event_alarms"
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
    fun read(context: Context, eventId: String): DailyAlarm? = store(context).getString(eventId, null)?.let {
        runCatching { DailyAlarm.parse(it) }.getOrNull()
    }

    @Synchronized
    fun schedule(context: Context, alarm: DailyAlarm) {
        require(alarm.eventId.isNotBlank() && alarm.title.isNotBlank())
        require(alarm.fireAt > System.currentTimeMillis())
        check(authorized(context)) { "System alarm permissions are required" }
        val previous = store(context).getString(alarm.eventId, null)
        check(store(context).edit().putString(alarm.eventId, alarm.json()).commit())
        try {
            manager(context).setAlarmClock(AlarmManager.AlarmClockInfo(alarm.fireAt, showIntent(context, alarm.eventId)), fireIntent(context, alarm))
        } catch (error: Exception) {
            store(context).edit().putString(alarm.eventId, previous).commit()
            throw error
        }
    }

    @Synchronized
    fun cancel(context: Context, eventId: String) {
        read(context, eventId)?.let { manager(context).cancel(fireIntent(context, it)) }
        check(store(context).edit().remove(eventId).commit())
        DailyAlarmService.stopEvent(context, eventId)
    }

    fun cancelAll(context: Context) = store(context).all.keys.toList().forEach { cancel(context, it) }

    fun restore(context: Context) {
        if (!authorized(context)) return
        store(context).all.keys.toList().forEach { id ->
            val alarm = read(context, id) ?: return@forEach
            if (alarm.fireAt > System.currentTimeMillis()) schedule(context, alarm)
            else cancel(context, id)
        }
    }

    @Synchronized
    fun finish(context: Context, eventId: String) {
        store(context).edit().remove(eventId).commit()
    }

    fun showIntent(context: Context, eventId: String): PendingIntent = PendingIntent.getActivity(
        context, 0, Intent(context, DailyAlarmActivity::class.java).apply {
            data = Uri.parse("dailycalendar://alarm/${Uri.encode(eventId)}")
            putExtra(EVENT_ID, eventId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun fireIntent(context: Context, alarm: DailyAlarm) = PendingIntent.getBroadcast(
        context, 0, Intent(context, DailyAlarmReceiver::class.java).apply {
            data = Uri.parse("dailycalendar://alarm/fire/${Uri.encode(alarm.eventId)}")
            putExtra(EVENT_ID, alarm.eventId)
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
