package com.littlebit0.dailycalendar

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class DailyAlarmBridge(private val activity: FragmentActivity) {
    private var pending: MethodChannel.Result? = null
    private val attempted = mutableSetOf<String>()
    private val permission = activity.registerForActivityResult(ActivityResultContracts.RequestPermission()) { nextPermission() }
    private val settings = activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { nextPermission() }

    fun register(messenger: BinaryMessenger) {
        DailyAlarmScheduler.createChannel(activity)
        MethodChannel(messenger, "daily/android_alarms").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "authorizationState" -> result.success(if (DailyAlarmScheduler.authorized(activity)) "authorized" else "notDetermined")
                    "requestAuthorization" -> {
                        check(pending == null) { "Alarm authorization is already in progress" }
                        pending = result
                        attempted.clear()
                        nextPermission()
                    }
                    "schedule" -> {
                        DailyAlarmScheduler.schedule(activity, DailyAlarm(
                            requireNotNull(call.argument<String>("eventId")),
                            requireNotNull(call.argument<String>("title")), call.argument<String>("memo").orEmpty(),
                            requireNotNull(call.argument<Number>("fireAtMilliseconds")).toLong(),
                            (call.argument<Number>("snoozeMinutes")?.toInt() ?: 10).coerceIn(1, 60),
                        ))
                        result.success(null)
                    }
                    "cancel" -> {
                        DailyAlarmScheduler.cancel(activity, requireNotNull(call.argument<String>("eventId")))
                        result.success(null)
                    }
                    "cancelAll" -> { DailyAlarmScheduler.cancelAll(activity); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                if (pending === result) pending = null
                result.error("android_alarm_failed", error.message, null)
            }
        }
    }

    private fun nextPermission() {
        val result = pending ?: return
        try {
            when {
                !DailyAlarmScheduler.notificationsAllowed(activity) && attempted.add("notifications") -> {
                    if (Build.VERSION.SDK_INT >= 33) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else settings.launch(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
                }
                !DailyAlarmScheduler.notificationsAllowed(activity) -> complete("denied")
                !DailyAlarmScheduler.exactAllowed(activity) && attempted.add("exact") -> settings.launch(
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}")),
                )
                !DailyAlarmScheduler.exactAllowed(activity) -> complete("denied")
                !DailyAlarmScheduler.fullScreenAllowed(activity) && attempted.add("fullScreen") -> settings.launch(
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${activity.packageName}")),
                )
                else -> complete(if (DailyAlarmScheduler.authorized(activity)) "authorized" else "denied")
            }
        } catch (error: Exception) {
            pending = null
            result.error("alarm_permission_failed", error.message, null)
        }
    }

    private fun complete(state: String) {
        val result = pending
        pending = null
        result?.success(state)
    }

    fun dispose() {
        pending?.error("alarm_permission_interrupted", "Activity closed during authorization", null)
        pending = null
    }
}
