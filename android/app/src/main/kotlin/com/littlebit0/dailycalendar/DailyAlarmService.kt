package com.littlebit0.dailycalendar

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class DailyAlarmService : Service() {
    private val alarms = linkedMapOf<String, DailyAlarm>()
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val vibrator get() = getSystemService(Vibrator::class.java)

    override fun onCreate() {
        super.onCreate()
        active = this
        DailyAlarmScheduler.createChannel(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra(DailyAlarmScheduler.EVENT_ID)
        if (id == null) { stopSelf(); return START_NOT_STICKY }
        when (intent.action) {
            DailyAlarmScheduler.STOP -> remove(id, false)
            DailyAlarmScheduler.SNOOZE -> remove(id, true)
            else -> {
                val alarm = DailyAlarmScheduler.read(this, id)
                if (alarm == null) {
                    if (alarms.isEmpty()) stopSelf()
                    return START_NOT_STICKY
                }
                alarms[id] = alarm
                startForeground(NOTIFICATION_ID, notification(alarms.values.first()))
                if (player == null) startSound()
            }
        }
        return START_NOT_STICKY
    }

    private fun notification(alarm: DailyAlarm): Notification = NotificationCompat.Builder(this, DailyAlarmScheduler.CHANNEL)
        .setSmallIcon(R.drawable.ic_alarm_notification)
        .setContentTitle(alarm.title)
        .setContentText(alarm.memo)
        .setStyle(NotificationCompat.BigTextStyle().bigText(alarm.memo))
        .setCategory(NotificationCompat.CATEGORY_ALARM)
        .setPriority(NotificationCompat.PRIORITY_MAX)
        .setOngoing(true)
        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
        .setContentIntent(DailyAlarmScheduler.showIntent(this, alarm.eventId))
        .setFullScreenIntent(DailyAlarmScheduler.showIntent(this, alarm.eventId), true)
        .addAction(0, getString(R.string.alarm_stop), actionIntent(alarm.eventId, DailyAlarmScheduler.STOP))
        .addAction(0, getString(R.string.alarm_snooze, alarm.snoozeMinutes), actionIntent(alarm.eventId, DailyAlarmScheduler.SNOOZE))
        .build()

    private fun actionIntent(id: String, action: String) = PendingIntent.getService(
        this, 0, Intent(this, DailyAlarmService::class.java).apply {
            this.action = action
            data = Uri.parse("dailycalendar://alarm/action/${Uri.encode(id)}/$action")
            putExtra(DailyAlarmScheduler.EVENT_ID, id)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun startSound() {
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:EventAlarm")
            .apply { acquire(10 * 60 * 1000L) }
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val media = MediaPlayer()
        try {
            media.setAudioAttributes(attributes)
            media.setDataSource(this, uri)
            media.isLooping = true
            media.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            media.prepare()
            media.start()
            player = media
        } catch (error: Exception) {
            media.release()
            android.util.Log.e("DailyAlarm", "Alarm audio could not start", error)
        }
        if (Build.VERSION.SDK_INT >= 26) {
            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 500), 0), attributes)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0, 500, 500), 0, attributes)
        }
    }

    internal fun remove(id: String, snooze: Boolean) {
        val alarm = alarms[id] ?: DailyAlarmScheduler.read(this, id)
        if (snooze && alarm != null) {
            try {
                DailyAlarmScheduler.schedule(this, alarm.copy(fireAt = System.currentTimeMillis() + alarm.snoozeMinutes * 60_000L))
            } catch (error: Exception) {
                // Keep ringing if rescheduling fails rather than losing the alarm.
                android.util.Log.e("DailyAlarm", "Unable to snooze alarm", error)
                return
            }
        } else DailyAlarmScheduler.finish(this, id)
        alarms.remove(id)
        sendBroadcast(Intent(DailyAlarmScheduler.CLOSED).setPackage(packageName).putExtra(DailyAlarmScheduler.EVENT_ID, id))
        if (alarms.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } else {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(alarms.values.first()))
        }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        vibrator.cancel()
        wakeLock?.let { if (it.isHeld) it.release() }
        if (active === this) active = null
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_ID = 0xDA11
        private var active: DailyAlarmService? = null
        internal fun stopEvent(context: android.content.Context, id: String) {
            active?.remove(id, false)
            context.sendBroadcast(Intent(DailyAlarmScheduler.CLOSED).setPackage(context.packageName).putExtra(DailyAlarmScheduler.EVENT_ID, id))
        }
    }
}
