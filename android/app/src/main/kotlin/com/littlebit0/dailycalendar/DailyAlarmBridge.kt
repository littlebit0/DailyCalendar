package com.littlebit0.dailycalendar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal enum class AlarmPermissionStep { RUNTIME_NOTIFICATION, NOTIFICATION_SETTINGS, EXACT_ALARM, FULL_SCREEN, AUTHORIZED, DENIED }

/**
 * Next step of one alarm authorization request. [attempted] remembers what this request already
 * launched, so each screen opens at most once. Above API 32 the notification settings screen opens
 * only when [openSettings] is set (the user turned an alarm on) and a runtime request cannot help:
 * the permission is granted but the app or channel is muted, or the dialog is no longer shown.
 */
internal fun nextAlarmPermissionStep(
    sdk: Int,
    notificationsAllowed: Boolean,
    permissionGranted: Boolean,
    permissionBlocked: Boolean,
    exactAllowed: Boolean,
    fullScreenAllowed: Boolean,
    openSettings: Boolean,
    attempted: MutableSet<String>,
): AlarmPermissionStep = when {
    !notificationsAllowed && sdk >= 33 && !permissionGranted && attempted.add("notifications") -> AlarmPermissionStep.RUNTIME_NOTIFICATION
    !notificationsAllowed && (sdk < 33 || (openSettings && (permissionGranted || permissionBlocked))) &&
        attempted.add("notificationSettings") -> AlarmPermissionStep.NOTIFICATION_SETTINGS
    !notificationsAllowed -> AlarmPermissionStep.DENIED
    !exactAllowed && attempted.add("exact") -> AlarmPermissionStep.EXACT_ALARM
    !exactAllowed -> AlarmPermissionStep.DENIED
    !fullScreenAllowed && attempted.add("fullScreen") -> AlarmPermissionStep.FULL_SCREEN
    else -> if (notificationsAllowed && exactAllowed && fullScreenAllowed) AlarmPermissionStep.AUTHORIZED else AlarmPermissionStep.DENIED
}

internal class DailyAlarmBridge(private val activity: FragmentActivity) {
    private var pending: MethodChannel.Result? = null
    private val attempted = mutableSetOf<String>()
    private var openSettings = false
    private var rationaleBeforeRequest = false
    private var permissionBlocked = false
    private val permission = activity.registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        // No rationale before and after a refused request: the system did not ask (refused for good) or the dialog was dismissed.
        permissionBlocked = !granted && !rationaleBeforeRequest && !showsNotificationRationale()
        nextPermission()
    }
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
                        openSettings = call.argument<Boolean>("openSettings") == true
                        permissionBlocked = false
                        nextPermission()
                    }
                    "schedule", "reconcile" -> {
                        val eventId = requireNotNull(call.argument<String>("eventId"))
                        val title = requireNotNull(call.argument<String>("title"))
                        require(eventId.isNotBlank() && title.isNotBlank())
                        val memo = call.argument<String>("memo").orEmpty()
                        val fireTimes = requireNotNull(call.argument<List<Number>>("fireAtMillisecondsList")).map { it.toLong() }
                        val snooze = (call.argument<Number>("snoozeMinutes")?.toInt() ?: 10).coerceIn(1, 60)
                        result.success(
                            if (call.method == "reconcile") DailyAlarmScheduler.reconcile(activity, eventId, title, memo, snooze, fireTimes)
                            else DailyAlarmScheduler.scheduleAll(activity, eventId, title, memo, snooze, fireTimes),
                        )
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
            val step = nextAlarmPermissionStep(
                Build.VERSION.SDK_INT,
                DailyAlarmScheduler.notificationsAllowed(activity),
                notificationPermissionGranted(),
                permissionBlocked,
                DailyAlarmScheduler.exactAllowed(activity),
                DailyAlarmScheduler.fullScreenAllowed(activity),
                openSettings,
                attempted,
            )
            when (step) {
                AlarmPermissionStep.RUNTIME_NOTIFICATION -> {
                    rationaleBeforeRequest = showsNotificationRationale()
                    permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
                AlarmPermissionStep.NOTIFICATION_SETTINGS -> settings.launch(notificationSettingsIntent())
                AlarmPermissionStep.EXACT_ALARM -> settings.launch(
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}")),
                )
                AlarmPermissionStep.FULL_SCREEN -> settings.launch(
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${activity.packageName}")),
                )
                AlarmPermissionStep.AUTHORIZED -> complete("authorized")
                AlarmPermissionStep.DENIED -> complete("denied")
            }
        } catch (error: Exception) {
            pending = null
            result.error("alarm_permission_failed", error.message, null)
        }
    }

    private fun notificationPermissionGranted() = Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun showsNotificationRationale() = Build.VERSION.SDK_INT >= 33 &&
        ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.POST_NOTIFICATIONS)

    /** The alarm channel screen when only that channel is muted, otherwise the app notification screen. */
    private fun notificationSettingsIntent(): Intent {
        val onlyChannelMuted = Build.VERSION.SDK_INT >= 26 && notificationPermissionGranted() &&
            activity.getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled()
        return if (onlyChannelMuted) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, DailyAlarmScheduler.CHANNEL)
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
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
