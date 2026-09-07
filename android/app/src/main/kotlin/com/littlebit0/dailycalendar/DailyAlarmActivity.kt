package com.littlebit0.dailycalendar

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.text.DateFormat
import java.util.Date

class DailyAlarmActivity : Activity() {
    private var eventId = ""
    private val closed = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.getStringExtra(DailyAlarmScheduler.EVENT_ID) == eventId) finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        ContextCompat.registerReceiver(this, closed, IntentFilter(DailyAlarmScheduler.CLOSED), ContextCompat.RECEIVER_NOT_EXPORTED)
        showAlarm()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showAlarm()
    }

    private fun showAlarm() {
        eventId = intent.getStringExtra(DailyAlarmScheduler.EVENT_ID).orEmpty()
        val alarm = DailyAlarmScheduler.read(this, eventId)
        if (alarm == null) { finish(); return }
        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(padding, padding * 2, padding, padding)
        }
        fun label(text: String, size: Float) = TextView(this).apply {
            this.text = text
            textSize = size
            gravity = Gravity.CENTER
            setPadding(0, padding / 2, 0, padding / 2)
            column.addView(this, LinearLayout.LayoutParams(-1, -2))
        }
        label(getString(R.string.event_alarm), 18f)
        label(DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(alarm.fireAt)), 40f)
        label(alarm.title, 28f)
        if (alarm.memo.isNotBlank()) label(alarm.memo, 18f)
        column.addView(Button(this).apply {
            text = getString(R.string.alarm_stop)
            setOnClickListener { DailyAlarmScheduler.cancel(this@DailyAlarmActivity, eventId); finish() }
        }, LinearLayout.LayoutParams(-1, -2))
        if (alarm.fireAt <= System.currentTimeMillis()) {
            column.addView(Button(this).apply {
                text = getString(R.string.alarm_snooze, alarm.snoozeMinutes)
                setOnClickListener {
                    startService(Intent(this@DailyAlarmActivity, DailyAlarmService::class.java)
                        .setAction(DailyAlarmScheduler.SNOOZE).putExtra(DailyAlarmScheduler.EVENT_ID, eventId))
                }
            }, LinearLayout.LayoutParams(-1, -2))
        }
        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onDestroy() {
        unregisterReceiver(closed)
        super.onDestroy()
    }
}
