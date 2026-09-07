package com.littlebit0.dailycalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.text.DateFormat
import java.text.DateFormatSymbols
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.absoluteValue

enum class DailyWidgetKind {
    MONTH,
    TODAY,
    DDAY,
}

abstract class DailyBaseWidgetProvider : AppWidgetProvider() {
    internal abstract val widgetKind: DailyWidgetKind

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        DailyWidgetUpdater.updateWidgets(
            context,
            appWidgetManager,
            appWidgetIds,
            widgetKind,
        )
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        DailyWidgetUpdater.updateWidgets(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            widgetKind,
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in DATE_CHANGE_ACTIONS) {
            DailyWidgetUpdater.refreshAll(context)
        }
    }

    private companion object {
        val DATE_CHANGE_ACTIONS = setOf(
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
        )
    }
}

class DailyMonthWidgetProvider : DailyBaseWidgetProvider() {
    override val widgetKind = DailyWidgetKind.MONTH
}

class DailyTodayWidgetProvider : DailyBaseWidgetProvider() {
    override val widgetKind = DailyWidgetKind.TODAY
}

class DailyDdayWidgetProvider : DailyBaseWidgetProvider() {
    override val widgetKind = DailyWidgetKind.DDAY
}

object DailyWidgetUpdater {
    private val providers = listOf(
        DailyWidgetKind.MONTH to DailyMonthWidgetProvider::class.java,
        DailyWidgetKind.TODAY to DailyTodayWidgetProvider::class.java,
        DailyWidgetKind.DDAY to DailyDdayWidgetProvider::class.java,
    )

    fun refreshAll(context: Context) {
        val applicationContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(applicationContext)
        providers.forEach { (kind, providerClass) ->
            val ids = manager.getAppWidgetIds(ComponentName(applicationContext, providerClass))
            updateWidgets(applicationContext, manager, ids, kind)
        }
    }

    internal fun updateWidgets(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
        kind: DailyWidgetKind,
    ) {
        if (widgetIds.isEmpty()) return
        val snapshot = DailyAndroidWidgetStore.snapshot(context)
        val palette = DailyWidgetPalette.resolve(context, snapshot?.optString("themeMode"))
        widgetIds.forEach { widgetId ->
            val views = when (kind) {
                DailyWidgetKind.MONTH -> monthViews(context, widgetId, snapshot, palette)
                DailyWidgetKind.TODAY -> todayViews(context, widgetId, snapshot, palette)
                DailyWidgetKind.DDAY -> ddayViews(context, widgetId, snapshot, palette)
            }
            manager.updateAppWidget(widgetId, views)
        }
        manager.notifyAppWidgetViewDataChanged(widgetIds, R.id.widget_collection)
    }

    private fun monthViews(
        context: Context,
        widgetId: Int,
        snapshot: JSONObject?,
        palette: DailyWidgetPalette,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_month)
        val weekly = isWeeklyWidget(context, widgetId)
        applyRoot(views, palette)
        views.setTextViewText(R.id.widget_title, context.getString(R.string.app_name))
        views.setTextViewText(
            R.id.widget_subtitle,
            snapshot?.optString(if (weekly) "weekTitle" else "monthTitle")?.takeIf(String::isNotBlank)
                ?: localizedString(context, snapshot, R.string.widget_open_app),
        )
        views.setTextColor(R.id.widget_subtitle, palette.primaryText)
        applyWeekdayLabels(context, views, snapshot, palette)
        bindCollection(context, views, widgetId, DailyWidgetKind.MONTH)
        return views
    }

    private fun todayViews(
        context: Context,
        widgetId: Int,
        snapshot: JSONObject?,
        palette: DailyWidgetPalette,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        applyRoot(views, palette)
        views.setTextViewText(
            R.id.widget_title,
            localizedString(context, snapshot, R.string.widget_today_title),
        )
        val todayTitle = snapshot?.optString("todayTitle")?.takeIf(String::isNotBlank)
            ?: DateFormat.getDateInstance(
                DateFormat.MEDIUM,
                snapshotLocale(context, snapshot),
            ).format(Date())
        val remainingCount = snapshot?.optInt("todayRemainingCount") ?: 0
        views.setTextViewText(
            R.id.widget_subtitle,
            if (remainingCount > 0) {
                "$todayTitle · ${localizedString(context, snapshot, R.string.widget_more_count, remainingCount)}"
            } else {
                todayTitle
            },
        )
        views.setTextColor(R.id.widget_subtitle, palette.accent)
        views.setTextViewText(
            R.id.widget_empty,
            if (snapshot == null) {
                localizedString(context, snapshot, R.string.widget_open_app)
            } else {
                localizedString(context, snapshot, R.string.widget_no_today_events)
            },
        )
        views.setTextColor(R.id.widget_empty, palette.secondaryText)
        views.setEmptyView(R.id.widget_collection, R.id.widget_empty)
        bindCollection(context, views, widgetId, DailyWidgetKind.TODAY)
        return views
    }

    private fun ddayViews(
        context: Context,
        widgetId: Int,
        snapshot: JSONObject?,
        palette: DailyWidgetPalette,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_dday)
        applyRoot(views, palette)
        views.setTextViewText(
            R.id.widget_title,
            localizedString(context, snapshot, R.string.widget_dday_title),
        )
        val ddayCount = snapshot?.optJSONArray("ddays")?.length() ?: 0
        views.setTextViewText(
            R.id.widget_subtitle,
            if (ddayCount > 0) "$ddayCount · ${context.getString(R.string.app_name)}"
            else context.getString(R.string.app_name),
        )
        views.setTextColor(R.id.widget_subtitle, palette.ddayAccent)
        views.setTextViewText(
            R.id.widget_empty,
            if (snapshot == null) {
                localizedString(context, snapshot, R.string.widget_open_app)
            } else {
                localizedString(context, snapshot, R.string.widget_no_ddays)
            },
        )
        views.setTextColor(R.id.widget_empty, palette.secondaryText)
        views.setEmptyView(R.id.widget_collection, R.id.widget_empty)
        bindCollection(context, views, widgetId, DailyWidgetKind.DDAY)
        return views
    }

    private fun applyRoot(views: RemoteViews, palette: DailyWidgetPalette) {
        views.setInt(R.id.widget_root, "setBackgroundResource", palette.backgroundResource)
        views.setTextColor(R.id.widget_title, palette.primaryText)
    }

    private fun applyWeekdayLabels(
        context: Context,
        views: RemoteViews,
        snapshot: JSONObject?,
        palette: DailyWidgetPalette,
    ) {
        val startsOnMonday = snapshot?.optBoolean("weekStartsOnMonday") == true
        val firstDay = if (startsOnMonday) Calendar.MONDAY else Calendar.SUNDAY
        val names = DateFormatSymbols(snapshotLocale(context, snapshot)).shortWeekdays
        val ids = intArrayOf(
            R.id.widget_weekday_1,
            R.id.widget_weekday_2,
            R.id.widget_weekday_3,
            R.id.widget_weekday_4,
            R.id.widget_weekday_5,
            R.id.widget_weekday_6,
            R.id.widget_weekday_7,
        )
        ids.forEachIndexed { index, id ->
            val dayOfWeek = ((firstDay - 1 + index) % 7) + 1
            val label = names[dayOfWeek].trim().removeSuffix(".").take(2)
            views.setTextViewText(id, label)
            views.setTextColor(
                id,
                when (dayOfWeek) {
                    Calendar.SUNDAY -> palette.sundayText
                    Calendar.SATURDAY -> palette.saturdayText
                    else -> palette.secondaryText
                },
            )
        }
    }

    private fun bindCollection(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        kind: DailyWidgetKind,
    ) {
        val serviceClass = when (kind) {
            DailyWidgetKind.MONTH -> DailyMonthWidgetService::class.java
            DailyWidgetKind.TODAY -> DailyTodayWidgetService::class.java
            DailyWidgetKind.DDAY -> DailyDdayWidgetService::class.java
        }
        val adapterIntent = Intent(context, serviceClass).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("dailycalendar://widget/${kind.name.lowercase(Locale.ROOT)}/$widgetId")
        }
        views.setRemoteAdapter(R.id.widget_collection, adapterIntent)
        views.setPendingIntentTemplate(
            R.id.widget_collection,
            DailyWidgetActionReceiver.pendingIntentTemplate(context, widgetId, kind),
        )
        views.setOnClickPendingIntent(R.id.widget_header, launchAppIntent(context, widgetId))
    }

    private fun launchAppIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

private data class DailyWidgetPalette(
    val backgroundResource: Int,
    val primaryText: Int,
    val secondaryText: Int,
    val mutedText: Int,
    val accent: Int,
    val ddayAccent: Int,
    val sundayText: Int,
    val saturdayText: Int,
) {
    companion object {
        fun resolve(context: Context, requestedMode: String?): DailyWidgetPalette {
            val systemDark = context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            val dark = requestedMode == "dark" || (requestedMode != "light" && systemDark)
            return if (dark) {
                DailyWidgetPalette(
                    backgroundResource = R.drawable.widget_background_dark,
                    primaryText = Color.parseColor("#FFF8FAFC"),
                    secondaryText = Color.parseColor("#FFCBD5E1"),
                    mutedText = Color.parseColor("#FF64748B"),
                    accent = Color.parseColor("#FF60A5FA"),
                    ddayAccent = Color.parseColor("#FFF472B6"),
                    sundayText = Color.parseColor("#FFF87171"),
                    saturdayText = Color.parseColor("#FF60A5FA"),
                )
            } else {
                DailyWidgetPalette(
                    backgroundResource = R.drawable.widget_background_light,
                    primaryText = Color.parseColor("#FF111827"),
                    secondaryText = Color.parseColor("#FF64748B"),
                    mutedText = Color.parseColor("#FFCBD5E1"),
                    accent = Color.parseColor("#FF2563EB"),
                    ddayAccent = Color.parseColor("#FFDB2777"),
                    sundayText = Color.parseColor("#FFDC2626"),
                    saturdayText = Color.parseColor("#FF2563EB"),
                )
            }
        }
    }
}

abstract class DailyWidgetRemoteViewsService : RemoteViewsService() {
    protected abstract val kind: DailyWidgetKind

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = when (kind) {
        DailyWidgetKind.MONTH -> DailyMonthWidgetFactory(
            applicationContext,
            intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID),
        )
        DailyWidgetKind.TODAY -> DailyEventWidgetFactory(
            applicationContext,
            "todayEvents",
            DailyWidgetKind.TODAY,
        )
        DailyWidgetKind.DDAY -> DailyEventWidgetFactory(
            applicationContext,
            "ddays",
            DailyWidgetKind.DDAY,
        )
    }
}

class DailyMonthWidgetService : DailyWidgetRemoteViewsService() {
    override val kind = DailyWidgetKind.MONTH
}

class DailyTodayWidgetService : DailyWidgetRemoteViewsService() {
    override val kind = DailyWidgetKind.TODAY
}

class DailyDdayWidgetService : DailyWidgetRemoteViewsService() {
    override val kind = DailyWidgetKind.DDAY
}

private class DailyMonthWidgetFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private var days = JSONArray()
    private var palette = DailyWidgetPalette.resolve(context, null)
    private var snapshot: JSONObject? = null

    override fun onCreate() = reload()

    override fun onDataSetChanged() = reload()

    override fun onDestroy() = Unit

    override fun getCount(): Int = (days.length() + 6) / 7

    override fun getViewAt(position: Int): RemoteViews? {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_week)
        val week = (0..6).mapNotNull { days.optJSONObject(position * 7 + it) }
        if (week.isEmpty()) return null
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val width = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300) - 24).coerceIn(140, 700)
        val height = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 300) - 70)
            .div(getCount().coerceAtLeast(1)).coerceIn(32, 260)
        views.setImageViewBitmap(R.id.widget_week_image, DailyWidgetCalendarRenderer.render(
            context, week, width, height, palette.primaryText, palette.mutedText,
            palette.accent, palette.sundayText, palette.saturdayText,
        ))
        week.forEachIndexed { index, day ->
            val id = WEEK_DAY_IDS[index]
            views.setOnClickFillInIntent(id, DailyWidgetActionReceiver.openFillInIntent(day.optString("date")))
            views.setContentDescription(id, day.optString("date") + " " +
                (day.optJSONArray("events") ?: JSONArray()).let { events ->
                    (0 until events.length()).joinToString(", ") { events.optJSONObject(it)?.optString("title").orEmpty() }
                })
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        days.optJSONObject(position * 7)?.optString("date")?.hashCode()?.toLong()
            ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun reload() {
        snapshot = DailyAndroidWidgetStore.snapshot(context)
        days = snapshot?.optJSONArray("monthDays") ?: JSONArray()
        if (isWeeklyWidget(context, widgetId)) {
            val todayIndex = (0 until days.length()).firstOrNull {
                days.optJSONObject(it)?.optBoolean("isToday") == true
            } ?: 0
            val start = todayIndex / 7 * 7
            days = JSONArray().also { week ->
                for (index in start until minOf(start + 7, days.length())) week.put(days.get(index))
            }
        }
        palette = DailyWidgetPalette.resolve(context, snapshot?.optString("themeMode"))
    }
}

private class DailyEventWidgetFactory(
    private val context: Context,
    private val snapshotKey: String,
    private val kind: DailyWidgetKind,
) : RemoteViewsService.RemoteViewsFactory {
    private var events = JSONArray()
    private var palette = DailyWidgetPalette.resolve(context, null)
    private var snapshot: JSONObject? = null

    override fun onCreate() = reload()

    override fun onDataSetChanged() = reload()

    override fun onDestroy() = Unit

    override fun getCount(): Int = events.length()

    override fun getViewAt(position: Int): RemoteViews? {
        val event = events.optJSONObject(position) ?: return null
        val eventId = event.optString("eventId", event.optString("id"))
        if (eventId.isBlank()) return null
        val completed = event.optBoolean("completed")
        val views = RemoteViews(context.packageName, R.layout.widget_event_item)
        views.setTextViewText(
            R.id.widget_event_title,
            completedTitle(event.optString("title"), completed),
        )
        views.setTextColor(
            R.id.widget_event_title,
            eventColor(event, palette.accent),
        )
        views.setTextViewText(
            R.id.widget_event_detail,
            if (kind == DailyWidgetKind.DDAY) ddayDetail(event)
            else event.optString("timeLabel"),
        )
        views.setTextColor(R.id.widget_event_detail, palette.secondaryText)
        val eventColor = eventColor(event, palette.accent)
        views.setInt(R.id.widget_event_color, "setColorFilter", eventColor)
        views.setImageViewResource(
            R.id.widget_todo_button,
            if (completed) R.drawable.ic_widget_todo_checked
            else R.drawable.ic_widget_todo_unchecked,
        )
        views.setContentDescription(
            R.id.widget_todo_button,
            localizedString(context, snapshot, R.string.widget_toggle_todo),
        )
        views.setOnClickFillInIntent(
            R.id.widget_todo_button,
            DailyWidgetActionReceiver.toggleFillInIntent(eventId, !completed),
        )
        views.setOnClickFillInIntent(
            R.id.widget_item_root,
            DailyWidgetActionReceiver.openFillInIntent(eventId = eventId),
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        events.optJSONObject(position)?.optString("id")?.hashCode()?.toLong()
            ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun reload() {
        snapshot = DailyAndroidWidgetStore.snapshot(context)
        events = snapshot?.optJSONArray(snapshotKey) ?: JSONArray()
        palette = DailyWidgetPalette.resolve(context, snapshot?.optString("themeMode"))
    }

    private fun ddayDetail(event: JSONObject): String {
        val daysRemaining = event.optInt("daysRemaining")
        val dday = when {
            daysRemaining == 0 -> "D-day"
            daysRemaining > 0 -> "D-$daysRemaining"
            else -> "D+${daysRemaining.absoluteValue}"
        }
        val dateLabel = event.optString("dateLabel")
        return if (dateLabel.isBlank()) dday else "$dday · $dateLabel"
    }
}

class DailyWidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getStringExtra(EXTRA_COMMAND)) {
            COMMAND_TOGGLE -> {
                val eventId = intent.getStringExtra(EXTRA_EVENT_ID).orEmpty()
                if (eventId.isBlank() || !intent.hasExtra(EXTRA_COMPLETED)) return
                val completed = intent.getBooleanExtra(EXTRA_COMPLETED, false)
                runCatching {
                    DailyAndroidWidgetStore.enqueueTodoAction(context, eventId, completed)
                }.onSuccess {
                    DailyWidgetUpdater.refreshAll(context)
                    DailyAndroidWidgetBridge.notifyTodoActionsChanged()
                }
            }
            COMMAND_OPEN -> openApp(context, intent)
        }
    }

    private fun openApp(context: Context, source: Intent) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        source.getStringExtra(EXTRA_EVENT_ID)?.let {
            intent.putExtra(EXTRA_EVENT_ID, it)
        }
        source.getStringExtra(EXTRA_DATE)?.let {
            intent.putExtra(EXTRA_DATE, it)
        }
        context.startActivity(intent)
    }

    companion object {
        private const val ACTION_WIDGET_ITEM =
            "com.littlebit0.dailycalendar.action.WIDGET_ITEM"
        private const val EXTRA_COMMAND = "widgetCommand"
        private const val EXTRA_EVENT_ID = "eventId"
        private const val EXTRA_DATE = "date"
        private const val EXTRA_COMPLETED = "completed"
        private const val COMMAND_OPEN = "open"
        private const val COMMAND_TOGGLE = "toggleTodo"

        internal fun pendingIntentTemplate(
            context: Context,
            widgetId: Int,
            kind: DailyWidgetKind,
        ): PendingIntent {
            val intent = Intent(context, DailyWidgetActionReceiver::class.java).apply {
                action = ACTION_WIDGET_ITEM
                data = Uri.parse(
                    "dailycalendar://widget/action/${kind.name.lowercase(Locale.ROOT)}/$widgetId",
                )
            }
            val mutabilityFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            return PendingIntent.getBroadcast(
                context,
                widgetId + kind.ordinal * 10_000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or mutabilityFlag,
            )
        }

        internal fun toggleFillInIntent(eventId: String, completed: Boolean) = Intent().apply {
            putExtra(EXTRA_COMMAND, COMMAND_TOGGLE)
            putExtra(EXTRA_EVENT_ID, eventId)
            putExtra(EXTRA_COMPLETED, completed)
        }

        internal fun openFillInIntent(date: String? = null, eventId: String? = null) =
            Intent().apply {
                putExtra(EXTRA_COMMAND, COMMAND_OPEN)
                date?.takeIf(String::isNotBlank)?.let { putExtra(EXTRA_DATE, it) }
                eventId?.takeIf(String::isNotBlank)?.let { putExtra(EXTRA_EVENT_ID, it) }
            }
    }
}

private fun completedTitle(title: String, completed: Boolean): CharSequence {
    if (!completed) return title
    return SpannableString(title).apply {
        setSpan(
            StrikethroughSpan(),
            0,
            length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }
}

private val WEEK_DAY_IDS = intArrayOf(
    R.id.widget_hit_1, R.id.widget_hit_2, R.id.widget_hit_3, R.id.widget_hit_4,
    R.id.widget_hit_5, R.id.widget_hit_6, R.id.widget_hit_7,
)

private fun isWeeklyWidget(context: Context, widgetId: Int): Boolean {
    val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
    return options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 350) < 320
}

private fun eventColor(event: JSONObject, fallback: Int): Int {
    if (!event.has("color")) return fallback
    val value = event.optLong("color").toInt()
    return if (Color.alpha(value) == 0) value or -0x1000000 else value
}

@Suppress("DEPRECATION")
private fun currentLocale(context: Context): Locale =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        context.resources.configuration.locales[0]
    } else {
        context.resources.configuration.locale
    }

private fun snapshotLocale(context: Context, snapshot: JSONObject?): Locale {
    val languageTag = snapshot?.optString("localeTag").orEmpty().trim()
    if (languageTag.isNotEmpty()) {
        val locale = Locale.forLanguageTag(languageTag.replace('_', '-'))
        if (locale.language.isNotBlank()) return locale
    }
    return currentLocale(context)
}

private fun localizedString(
    context: Context,
    snapshot: JSONObject?,
    resourceId: Int,
    vararg arguments: Any,
): String {
    val configuration = Configuration(context.resources.configuration).apply {
        setLocale(snapshotLocale(context, snapshot))
    }
    return context.createConfigurationContext(configuration)
        .resources
        .getString(resourceId, *arguments)
}
