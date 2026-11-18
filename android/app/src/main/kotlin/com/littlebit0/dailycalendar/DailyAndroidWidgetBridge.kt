package com.littlebit0.dailycalendar

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object DailyAndroidWidgetBridge {
    const val CHANNEL_NAME = "daily/android_widgets"
    const val EXTRA_WIDGET_OPEN = "daily.widgetOpen"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    // The latest widget tap, kept until Dart takes it so a cold start and a
    // tap that arrives before the calendar is ready are not lost.
    @Volatile
    private var launchTarget: Map<String, String>? = null

    /** Remembers the date/event of a widget tap that opened [intent]. */
    fun offerLaunchTarget(intent: Intent?) {
        if (intent == null || !intent.getBooleanExtra(EXTRA_WIDGET_OPEN, false)) return
        // Reopening the task from Recents replays the original intent.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val target = buildMap {
            intent.getStringExtra("eventId")?.takeIf(String::isNotBlank)?.let { put("eventId", it) }
            intent.getStringExtra("date")?.takeIf(String::isNotBlank)?.let { put("date", it) }
        }
        // Consumed once: a recreated activity sees the intent without it.
        intent.removeExtra(EXTRA_WIDGET_OPEN)
        if (target.isEmpty()) return
        launchTarget = target
        mainHandler.post { channel?.invokeMethod("launchTargetOpened", null) }
    }

    internal fun takeLaunchTarget(): Map<String, String>? = launchTarget.also { launchTarget = null }

    fun register(context: Context, messenger: BinaryMessenger) {
        channel?.setMethodCallHandler(null)
        val applicationContext = context.applicationContext
        val registeredChannel = MethodChannel(messenger, CHANNEL_NAME)
        channel = registeredChannel
        registeredChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "updateSnapshot" -> {
                        val snapshot = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("A widget snapshot map is required")
                        if (!DailyAndroidWidgetStore.updateSnapshot(applicationContext, snapshot)) {
                            error("Unable to persist widget snapshot")
                        }
                        DailyWidgetUpdater.refreshAll(applicationContext)
                        result.success(null)
                    }
                    "takeLaunchTarget" -> result.success(takeLaunchTarget())
                    "pendingTodoActions" -> result.success(
                        DailyAndroidWidgetStore.pendingTodoActions(applicationContext),
                    )
                    "acknowledgeTodoActions" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val tokens = ((arguments?.get("tokens") as? Iterable<*>)
                            ?: emptyList<Any?>())
                            .filterIsInstance<String>()
                            .filter(String::isNotBlank)
                            .toSet()
                        if (!DailyAndroidWidgetStore.acknowledgeTodoActions(
                                applicationContext,
                                tokens,
                            )
                        ) {
                            error("Unable to acknowledge widget Todo actions")
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_widget_arguments", error.message, null)
            } catch (error: Throwable) {
                result.error("android_widget_failed", error.message, null)
            }
        }
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun notifyTodoActionsChanged() {
        mainHandler.post {
            channel?.invokeMethod("todoActionsChanged", null)
        }
    }

    fun notifyPendingTodoActions(context: Context) {
        if (DailyAndroidWidgetStore.pendingTodoActions(context).isNotEmpty()) {
            notifyTodoActionsChanged()
        }
    }
}
