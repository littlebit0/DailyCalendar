package com.littlebit0.dailycalendar

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.app.AlertDialog
import android.os.Build
import android.os.CancellationSignal
import android.os.Bundle
import android.provider.CalendarContract
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingCalendarOperation: (() -> Unit)? = null
    private var pendingCalendarResult: MethodChannel.Result? = null
    private val calendarImportWorker = CalendarImportWorker()
    private val alarmBridge = DailyAlarmBridge(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestSupportedRefreshRate()
        // A recreated activity (rotation, process restore) keeps the old intent.
        if (savedInstanceState == null) DailyAndroidWidgetBridge.offerLaunchTarget(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        DailyAndroidWidgetBridge.offerLaunchTarget(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        alarmBridge.register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily/map_launcher")
            .setMethodCallHandler { call, result ->
                if (call.method != "openLocation") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val location = call.argument<String>("location")?.trim().orEmpty()
                if (location.isEmpty()) {
                    result.error("bad_arguments", "A location is required.", null)
                    return@setMethodCallHandler
                }
                openLocation(location, result)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily/app_lock_privacy")
            .setMethodCallHandler { call, result ->
                if (call.method != "setEnabled") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled) {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE,
                    )
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily/calendar_import")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listCalendars" -> withCalendarPermission(result) {
                        calendarImportWorker.submit(result) { signal -> listSamsungCalendars(signal) }
                    }
                    "loadEvents" -> {
                        val calendarIds = call.argument<List<String>>("calendarIds").orEmpty()
                        withCalendarPermission(result) {
                            calendarImportWorker.submit(result) { signal -> loadSamsungEvents(calendarIds.toSet(), signal) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        DailyAndroidWidgetBridge.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onResume() {
        super.onResume()
        requestHighestSupportedRefreshRate()
        DailyWidgetUpdater.refreshAll(applicationContext)
        DailyAndroidWidgetBridge.notifyPendingTodoActions(applicationContext)
    }

    override fun onDestroy() {
        pendingCalendarOperation = null
        pendingCalendarResult?.error("calendar_import_cancelled", "캘린더 가져오기가 취소됐습니다.", null)
        pendingCalendarResult = null
        calendarImportWorker.close()
        alarmBridge.dispose()
        DailyAndroidWidgetBridge.unregister()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST) return
        val operation = pendingCalendarOperation
        val result = pendingCalendarResult
        pendingCalendarOperation = null
        pendingCalendarResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            operation?.invoke()
        } else {
            result?.error(
                "calendar_permission_denied",
                "설정에서 Daily의 캘린더 권한을 허용해 주세요.",
                null,
            )
        }
    }

    private fun withCalendarPermission(result: MethodChannel.Result, operation: () -> Unit) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            operation()
            return
        }
        if (pendingCalendarOperation != null) {
            result.error("calendar_permission_busy", "캘린더 권한 요청이 진행 중입니다.", null)
            return
        }
        pendingCalendarOperation = operation
        pendingCalendarResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CALENDAR),
            CALENDAR_PERMISSION_REQUEST,
        )
    }

    private fun requestHighestSupportedRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = windowManager.defaultDisplay
        val preferredMode = display.supportedModes.maxByOrNull { it.refreshRate } ?: return
        if (preferredMode.modeId == display.mode.modeId) return

        window.attributes = window.attributes.apply {
            preferredDisplayModeId = preferredMode.modeId
        }
    }

    private fun listSamsungCalendars(signal: CancellationSignal): List<Map<String, Any?>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
            CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.VISIBLE,
        )
        val values = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            null,
            null,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME + " COLLATE NOCASE ASC",
            signal,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val titleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
            val accountIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_NAME)
            val typeIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_TYPE)
            val colorIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_COLOR)
            val visibleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.VISIBLE)
            while (cursor.moveToNext()) {
                signal.throwIfCanceled()
                val accountType = cursor.getString(typeIndex).orEmpty()
                if (!isSamsungCalendar(accountType) || cursor.getInt(visibleIndex) == 0) continue
                values += mapOf(
                    "id" to cursor.getLong(idIndex).toString(),
                    "title" to cursor.getString(titleIndex).orEmpty().ifBlank { "내 캘린더" },
                    "accountName" to cursor.getString(accountIndex),
                    "colorValue" to cursor.getInt(colorIndex),
                )
            }
        }
        return values
    }

    private fun loadSamsungEvents(calendarIds: Set<String>, signal: CancellationSignal): List<Map<String, Any?>> {
        if (calendarIds.isEmpty()) return emptyList()
        val placeholders = calendarIds.joinToString(",") { "?" }
        val mutableEvents = contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            CalendarImportRows.projection,
            "${CalendarContract.Events.CALENDAR_ID} IN ($placeholders) AND ${CalendarContract.Events.DELETED}=0",
            calendarIds.toTypedArray(),
            CalendarContract.Events.DTSTART + " ASC",
            signal,
        )?.use { cursor -> CalendarImportRows.read(cursor, signal) } ?: LinkedHashMap()
        attachReminderMinutes(mutableEvents, signal)
        return mutableEvents.values.toList()
    }

    private fun attachReminderMinutes(events: Map<String, MutableMap<String, Any?>>, signal: CancellationSignal) {
        if (events.isEmpty()) return
        val reminders = mutableMapOf<String, MutableSet<Int>>()
        events.keys.chunked(800).forEach { eventIds ->
            val placeholders = eventIds.joinToString(",") { "?" }
            contentResolver.query(
                CalendarContract.Reminders.CONTENT_URI,
                arrayOf(
                    CalendarContract.Reminders.EVENT_ID,
                    CalendarContract.Reminders.MINUTES,
                    CalendarContract.Reminders.METHOD,
                ),
                "${CalendarContract.Reminders.EVENT_ID} IN ($placeholders)",
                eventIds.toTypedArray(),
                null,
                signal,
            )?.use { cursor ->
                val eventIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.EVENT_ID)
                val minutesIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.MINUTES)
                val methodIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.METHOD)
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    val method = cursor.getInt(methodIndex)
                    if (method != CalendarContract.Reminders.METHOD_DEFAULT &&
                        method != CalendarContract.Reminders.METHOD_ALERT &&
                        method != CalendarContract.Reminders.METHOD_ALARM
                    ) continue
                    val minutes = cursor.getInt(minutesIndex)
                    if (minutes < 0) continue
                    reminders.getOrPut(cursor.getLong(eventIndex).toString()) { mutableSetOf() }
                        .add(minutes)
                }
            }
        }
        reminders.forEach { (eventId, minutes) ->
            events[eventId]?.set("reminderMinutesBeforeList", minutes.sorted())
        }
    }

    private fun isSamsungCalendar(accountType: String): Boolean {
        val normalized = accountType.lowercase()
        if (normalized.contains("google")) return false
        if (normalized.contains("samsung") || normalized.contains("com.osp")) return true
        return Build.MANUFACTURER.equals("samsung", ignoreCase = true) &&
            (normalized == CalendarContract.ACCOUNT_TYPE_LOCAL.lowercase() || normalized == "local")
    }

    private fun openLocation(location: String, result: MethodChannel.Result) {
        val candidates = listOfNotNull(
            mapCandidate("카카오맵", "kakaomap://search?q=${Uri.encode(location)}"),
            mapCandidate(
                "네이버지도",
                "nmap://search?query=${Uri.encode(location)}&appname=com.littlebit0.daily",
            ),
        )
        when (candidates.size) {
            0 -> result.success(startMap(Intent(Intent.ACTION_VIEW, kakaoWebUrl(location))))
            1 -> result.success(startMap(candidates.first().intent))
            else -> AlertDialog.Builder(this)
                .setTitle("지도에서 열기")
                .setMessage(location)
                .setItems(candidates.map { it.title }.toTypedArray()) { _, index ->
                    result.success(startMap(candidates[index].intent))
                }
                .setOnCancelListener { result.success("handled") }
                .show()
        }
    }

    /** "failed" lets Dart tell the user no map could be opened. */
    private fun startMap(intent: Intent): String = try {
        startActivity(intent)
        "handled"
    } catch (error: ActivityNotFoundException) {
        "failed"
    } catch (error: SecurityException) {
        "failed"
    }

    private fun mapCandidate(title: String, rawUrl: String): MapCandidate? {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(rawUrl))
        return if (intent.resolveActivity(packageManager) == null) null else MapCandidate(title, intent)
    }

    private fun kakaoWebUrl(location: String): Uri =
        Uri.parse("https://map.kakao.com/link/search/${Uri.encode(location)}")

    private data class MapCandidate(val title: String, val intent: Intent)

    companion object {
        private const val CALENDAR_PERMISSION_REQUEST = 7301
    }
}
