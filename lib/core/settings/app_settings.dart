import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';

enum AppLanguage {
  system,
  korean,
  english,
  japanese,
  traditionalChinese;

  static AppLanguage fromName(String? name) {
    return AppLanguage.values.firstWhere(
      (language) => language.name == name,
      orElse: () => AppLanguage.system,
    );
  }
}

enum AppThemeMode {
  system('자동'),
  light('화이트'),
  dark('다크');

  const AppThemeMode(this.label);

  final String label;

  static AppThemeMode fromName(String? name) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => AppThemeMode.system,
    );
  }
}

enum MonthNavigationMode {
  horizontal('좌우 슬라이드'),
  vertical('상하 스크롤');

  const MonthNavigationMode(this.label);

  final String label;

  static MonthNavigationMode fromName(String? name) {
    return MonthNavigationMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => MonthNavigationMode.horizontal,
    );
  }
}

enum AppTextSize {
  basic('기본', 0.8),
  large('크게', 1.0),
  extraLarge('더 크게', 1.15);

  const AppTextSize(this.label, this.scale);

  final String label;
  final double scale;

  static AppTextSize fromName(String? name) {
    return AppTextSize.values.firstWhere(
      (size) => size.name == name,
      orElse: () => AppTextSize.basic,
    );
  }
}

enum CalendarViewMode {
  week('주간'),
  month('월간'),
  day('일간');

  const CalendarViewMode(this.label);

  final String label;

  static CalendarViewMode fromName(String? name) {
    return CalendarViewMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => CalendarViewMode.week,
    );
  }
}

enum AppStartView {
  calendar,
  quickView;

  static AppStartView fromName(String? name) {
    return AppStartView.values.firstWhere(
      (view) => view.name == name,
      orElse: () => AppStartView.calendar,
    );
  }
}

enum WeekDayLayoutMode {
  list,
  schedule;

  static WeekDayLayoutMode fromName(String? name) {
    return WeekDayLayoutMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => WeekDayLayoutMode.list,
    );
  }
}

enum CalendarEventTitleAlignment {
  leading,
  center;

  static CalendarEventTitleAlignment fromName(String? name) {
    return CalendarEventTitleAlignment.values.firstWhere(
      (alignment) => alignment.name == name,
      orElse: () => CalendarEventTitleAlignment.leading,
    );
  }
}

enum CalendarEventSortPriority {
  category,
  time;

  static CalendarEventSortPriority fromName(String? name) {
    return CalendarEventSortPriority.values.firstWhere(
      (priority) => priority.name == name,
      orElse: () => CalendarEventSortPriority.time,
    );
  }
}

class CalendarManualEventOrder {
  const CalendarManualEventOrder({
    required this.eventKeys,
    required this.updatedAt,
    required this.deviceId,
  });

  final List<String> eventKeys;
  final DateTime updatedAt;
  final String deviceId;

  Map<String, Object?> toJson() => {
    'eventKeys': eventKeys,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
  };

  static CalendarManualEventOrder? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, Object?>.from(value);
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (updatedAt == null) {
      return null;
    }
    return CalendarManualEventOrder(
      eventKeys: (json['eventKeys'] as List? ?? const <Object?>[])
          .whereType<String>()
          .where((key) => key.trim().isNotEmpty)
          .toSet()
          .toList(growable: false),
      updatedAt: updatedAt.toLocal(),
      deviceId: json['deviceId'] as String? ?? '',
    );
  }
}

Map<String, CalendarManualEventOrder> mergeCalendarManualEventOrders(
  Map<String, CalendarManualEventOrder> local,
  Map<String, CalendarManualEventOrder> remote,
) {
  final merged = <String, CalendarManualEventOrder>{...local};
  for (final entry in remote.entries) {
    final current = merged[entry.key];
    if (current == null || _isNewerManualEventOrder(entry.value, current)) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

bool _isNewerManualEventOrder(
  CalendarManualEventOrder candidate,
  CalendarManualEventOrder current,
) {
  final timeComparison = candidate.updatedAt.compareTo(current.updatedAt);
  if (timeComparison != 0) {
    return timeComparison > 0;
  }
  return candidate.deviceId.compareTo(current.deviceId) > 0;
}

enum AppLockMethod {
  noPin('PIN 없이 잠금'),
  appPin('PIN 잠금'),
  system('시스템 잠금 비밀번호');

  const AppLockMethod(this.label);

  final String label;

  static AppLockMethod fromName(
    String? name, {
    bool legacyBiometricsEnabled = false,
  }) {
    return AppLockMethod.values.firstWhere(
      (method) => method.name == name,
      orElse: () =>
          legacyBiometricsEnabled ? AppLockMethod.system : AppLockMethod.appPin,
    );
  }
}

class AppSettings {
  AppSettings({
    int? defaultReminderMinutes = 60,
    List<int>? defaultReminderMinutesList,
    this.allDayReminderHour = 9,
    this.allDayReminderMinute = 0,
    this.morningBriefingHour = 8,
    this.morningBriefingMinute = 0,
    this.morningBriefingEnabled = true,
    this.weekStartsOnMonday = false,
    this.showLunarDates = true,
    this.showAdjacentMonthDates = true,
    this.onboardingCompleted = false,
    this.aiEnabled = false,
    this.aiOnlyForComplexInput = true,
    this.blockSensitiveAi = true,
    this.categories = _defaultCategories,
    this.dDayReminderOffsets = const [-7, -3, -1, 0],
    this.appTextSize = AppTextSize.basic,
    this.appStartView = AppStartView.calendar,
    this.defaultCalendarView = CalendarViewMode.week,
    this.weekDayLayoutMode = WeekDayLayoutMode.list,
    this.calendarEventTitleAlignment = CalendarEventTitleAlignment.leading,
    this.calendarEventSortPriority = CalendarEventSortPriority.time,
    this.calendarManualEventOrders = const <String, CalendarManualEventOrder>{},
    this.hiddenCategoryIds = const <String>[],
    this.calendarShowHolidays = true,
    this.calendarHolidayBackgroundEnabled = true,
    this.calendarDdayOnly = false,
    this.appLockEnabled = false,
    this.appLockBiometricsEnabled = false,
    this.appLockMethod = AppLockMethod.noPin,
    this.use24HourTime = true,
    this.themeMode = AppThemeMode.system,
    this.monthNavigationMode = MonthNavigationMode.horizontal,
    this.language = AppLanguage.system,
  }) : defaultReminderMinutesList = normalizeReminderMinutes(
         defaultReminderMinutesList ??
             (defaultReminderMinutes == null
                 ? const <int>[]
                 : <int>[defaultReminderMinutes]),
       );

  static const _defaultCategories = <EventCategory>[
    EventCategory.basic,
    EventCategory.holiday,
  ];

  final List<int> defaultReminderMinutesList;
  int get defaultReminderMinutes => defaultReminderMinutesList.isEmpty
      ? 60
      : defaultReminderMinutesList.first;
  final int allDayReminderHour;
  final int allDayReminderMinute;
  final int morningBriefingHour;
  final int morningBriefingMinute;
  final bool morningBriefingEnabled;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool showAdjacentMonthDates;
  final bool onboardingCompleted;
  final bool aiEnabled;
  final bool aiOnlyForComplexInput;
  final bool blockSensitiveAi;
  final List<EventCategory> categories;
  final List<int> dDayReminderOffsets;
  final AppTextSize appTextSize;
  final AppStartView appStartView;
  final CalendarViewMode defaultCalendarView;
  final WeekDayLayoutMode weekDayLayoutMode;
  final CalendarEventTitleAlignment calendarEventTitleAlignment;
  final CalendarEventSortPriority calendarEventSortPriority;
  final Map<String, CalendarManualEventOrder> calendarManualEventOrders;
  final List<String> hiddenCategoryIds;
  final bool calendarShowHolidays;
  final bool calendarHolidayBackgroundEnabled;
  final bool calendarDdayOnly;
  final bool appLockEnabled;
  final bool appLockBiometricsEnabled;
  final AppLockMethod appLockMethod;
  final bool use24HourTime;
  final AppThemeMode themeMode;
  final MonthNavigationMode monthNavigationMode;
  final AppLanguage language;

  AppSettings copyWith({
    int? defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
    int? allDayReminderHour,
    int? allDayReminderMinute,
    int? morningBriefingHour,
    int? morningBriefingMinute,
    bool? morningBriefingEnabled,
    bool? weekStartsOnMonday,
    bool? showLunarDates,
    bool? showAdjacentMonthDates,
    bool? onboardingCompleted,
    bool? aiEnabled,
    bool? aiOnlyForComplexInput,
    bool? blockSensitiveAi,
    List<EventCategory>? categories,
    List<int>? dDayReminderOffsets,
    AppTextSize? appTextSize,
    AppStartView? appStartView,
    CalendarViewMode? defaultCalendarView,
    WeekDayLayoutMode? weekDayLayoutMode,
    CalendarEventTitleAlignment? calendarEventTitleAlignment,
    CalendarEventSortPriority? calendarEventSortPriority,
    Map<String, CalendarManualEventOrder>? calendarManualEventOrders,
    List<String>? hiddenCategoryIds,
    bool? calendarShowHolidays,
    bool? calendarHolidayBackgroundEnabled,
    bool? calendarDdayOnly,
    bool? appLockEnabled,
    bool? appLockBiometricsEnabled,
    AppLockMethod? appLockMethod,
    bool? use24HourTime,
    AppThemeMode? themeMode,
    MonthNavigationMode? monthNavigationMode,
    AppLanguage? language,
  }) {
    return AppSettings(
      defaultReminderMinutesList:
          defaultReminderMinutesList ??
          (defaultReminderMinutes == null
              ? this.defaultReminderMinutesList
              : <int>[defaultReminderMinutes]),
      allDayReminderHour: allDayReminderHour ?? this.allDayReminderHour,
      allDayReminderMinute: allDayReminderMinute ?? this.allDayReminderMinute,
      morningBriefingHour: morningBriefingHour ?? this.morningBriefingHour,
      morningBriefingMinute:
          morningBriefingMinute ?? this.morningBriefingMinute,
      morningBriefingEnabled:
          morningBriefingEnabled ?? this.morningBriefingEnabled,
      weekStartsOnMonday: weekStartsOnMonday ?? this.weekStartsOnMonday,
      showLunarDates: showLunarDates ?? this.showLunarDates,
      showAdjacentMonthDates:
          showAdjacentMonthDates ?? this.showAdjacentMonthDates,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiOnlyForComplexInput:
          aiOnlyForComplexInput ?? this.aiOnlyForComplexInput,
      blockSensitiveAi: blockSensitiveAi ?? this.blockSensitiveAi,
      categories: categories ?? this.categories,
      dDayReminderOffsets: dDayReminderOffsets ?? this.dDayReminderOffsets,
      appTextSize: appTextSize ?? this.appTextSize,
      appStartView: appStartView ?? this.appStartView,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      weekDayLayoutMode: weekDayLayoutMode ?? this.weekDayLayoutMode,
      calendarEventTitleAlignment:
          calendarEventTitleAlignment ?? this.calendarEventTitleAlignment,
      calendarEventSortPriority:
          calendarEventSortPriority ?? this.calendarEventSortPriority,
      calendarManualEventOrders:
          calendarManualEventOrders ?? this.calendarManualEventOrders,
      hiddenCategoryIds: hiddenCategoryIds ?? this.hiddenCategoryIds,
      calendarShowHolidays: calendarShowHolidays ?? this.calendarShowHolidays,
      calendarHolidayBackgroundEnabled:
          calendarHolidayBackgroundEnabled ??
          this.calendarHolidayBackgroundEnabled,
      calendarDdayOnly: calendarDdayOnly ?? this.calendarDdayOnly,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockBiometricsEnabled:
          appLockBiometricsEnabled ?? this.appLockBiometricsEnabled,
      appLockMethod: appLockMethod ?? this.appLockMethod,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      themeMode: themeMode ?? this.themeMode,
      monthNavigationMode: monthNavigationMode ?? this.monthNavigationMode,
      language: language ?? this.language,
    );
  }

  EventCategory get holidayCategory => categories.firstWhere(
    (category) => category.id == EventCategory.holiday.id,
    orElse: () => EventCategory.holiday,
  );
}
