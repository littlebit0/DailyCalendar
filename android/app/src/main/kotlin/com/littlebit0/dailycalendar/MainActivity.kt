package com.littlebit0.dailycalendar

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.app.AlertDialog
import android.os.Build
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
    private val alarmBridge = DailyAlarmBridge(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestSupportedRefreshRate()
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
                        result.success(listSamsungCalendars())
                    }
                    "loadEvents" -> {
                        val calendarIds = call.argument<List<String>>("calendarIds").orEmpty()
                        withCalendarPermission(result) {
                            result.success(loadSamsungEvents(calendarIds.toSet()))
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

    private fun listSamsungCalendars(): List<Map<String, Any?>> {
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
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val titleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
            val accountIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_NAME)
            val typeIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_TYPE)
            val colorIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_COLOR)
            val visibleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.VISIBLE)
            while (cursor.moveToNext()) {
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

    private fun loadSamsungEvents(calendarIds: Set<String>): List<Map<String, Any?>> {
        if (calendarIds.isEmpty()) return emptyList()
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.CALENDAR_ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DESCRIPTION,
            CalendarContract.Events.EVENT_LOCATION,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.DURATION,
            CalendarContract.Events.ALL_DAY,
            CalendarContract.Events.RRULE,
            CalendarContract.Events.CUSTOM_APP_URI,
            CalendarContract.Events.DELETED,
        )
        val placeholders = calendarIds.joinToString(",") { "?" }
        val values = mutableListOf<Map<String, Any?>>()
        val mutableEvents = mutableMapOf<String, MutableMap<String, Any?>>()
        contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            "${CalendarContract.Events.CALENDAR_ID} IN ($placeholders) AND ${CalendarContract.Events.DELETED}=0",
            calendarIds.toTypedArray(),
            CalendarContract.Events.DTSTART + " ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events._ID)
            val calendarIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.CALENDAR_ID)
            val titleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.TITLE)
            val descriptionIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DESCRIPTION)
            val locationIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.EVENT_LOCATION)
            val startIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTSTART)
            val endIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTEND)
            val durationIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.DURATION)
            val allDayIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.ALL_DAY)
            val ruleIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.RRULE)
            val urlIndex = cursor.getColumnIndexOrThrow(CalendarContract.Events.CUSTOM_APP_URI)
            while (cursor.moveToNext()) {
                val allDay = cursor.getInt(allDayIndex) == 1
                var start = cursor.getLong(startIndex)
                if (allDay) start = utcMidnightToLocalMidnight(start)
                var end = if (cursor.isNull(endIndex)) {
                    start + parseDurationMillis(cursor.getString(durationIndex), allDay)
                } else {
                    cursor.getLong(endIndex).let { if (allDay) utcMidnightToLocalMidnight(it) else it }
                }
                if (end <= start) end = start + if (allDay) DAY_MILLIS else HOUR_MILLIS
                val sourceId = cursor.getLong(idIndex).toString()
                val event = mutableMapOf<String, Any?>(
                    "sourceId" to sourceId,
                    "calendarId" to cursor.getLong(calendarIndex).toString(),
                    "title" to cursor.getString(titleIndex).orEmpty().ifBlank { "제목 없음" },
                    "startMilliseconds" to start,
                    "endMilliseconds" to end,
                    "allDay" to allDay,
                )
                cursor.getString(descriptionIndex)?.takeIf { it.isNotBlank() }?.let { event["memo"] = it }
                cursor.getString(locationIndex)?.takeIf { it.isNotBlank() }?.let { event["location"] = it }
                cursor.getString(ruleIndex)?.takeIf { it.isNotBlank() }?.let { event["recurrenceRule"] = "RRULE:$it" }
                cursor.getString(urlIndex)?.takeIf { it.isNotBlank() }?.let { event["url"] = it }
                values += event
                mutableEvents[sourceId] = event
            }
        }
        attachReminderMinutes(mutableEvents)
        return values
    }

    private fun attachReminderMinutes(events: Map<String, MutableMap<String, Any?>>) {
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
            )?.use { cursor ->
                val eventIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.EVENT_ID)
                val minutesIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.MINUTES)
                val methodIndex = cursor.getColumnIndexOrThrow(CalendarContract.Reminders.METHOD)
                while (cursor.moveToNext()) {
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

    private fun utcMidnightToLocalMidnight(value: Long): Long {
        val utc = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
            timeInMillis = value
        }
        return java.util.Calendar.getInstance().apply {
            clear()
            set(utc.get(java.util.Calendar.YEAR), utc.get(java.util.Calendar.MONTH), utc.get(java.util.Calendar.DAY_OF_MONTH))
        }.timeInMillis
    }

    private fun parseDurationMillis(value: String?, allDay: Boolean): Long {
        if (value.isNullOrBlank()) return if (allDay) DAY_MILLIS else HOUR_MILLIS
        val match = Regex("P(?:(\\d+)D)?(?:T(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?)?").matchEntire(value)
            ?: return if (allDay) DAY_MILLIS else HOUR_MILLIS
        val days = match.groupValues[1].toLongOrNull() ?: 0
        val hours = match.groupValues[2].toLongOrNull() ?: 0
        val minutes = match.groupValues[3].toLongOrNull() ?: 0
        val seconds = match.groupValues[4].toLongOrNull() ?: 0
        return ((days * 24 + hours) * 60 * 60 + minutes * 60 + seconds) * 1000
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
            0 -> {
                startActivity(Intent(Intent.ACTION_VIEW, kakaoWebUrl(location)))
                result.success("handled")
            }
            1 -> {
                startActivity(candidates.first().intent)
                result.success("handled")
            }
            else -> AlertDialog.Builder(this)
                .setTitle("지도에서 열기")
                .setMessage(location)
                .setItems(candidates.map { it.title }.toTypedArray()) { _, index ->
                    startActivity(candidates[index].intent)
                    result.success("handled")
                }
                .setOnCancelListener { result.success("handled") }
                .show()
        }
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
        private const val HOUR_MILLIS = 60L * 60L * 1000L
        private const val DAY_MILLIS = 24L * HOUR_MILLIS
    }
}
