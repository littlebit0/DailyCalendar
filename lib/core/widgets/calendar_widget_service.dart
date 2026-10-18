import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../calendar/calendar_event_movement.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../localization/app_localizations.dart';

abstract final class CalendarWidgetChannelContract {
  static const appleChannel = 'daily/apple_widgets';
  static const androidChannel = 'daily/android_widgets';
  static const windowsChannel = 'daily/windows_widgets';

  static const updateSnapshotMethod = 'updateSnapshot';
  static const pendingTodoActionsMethod = 'pendingTodoActions';
  static const acknowledgeTodoActionsMethod = 'acknowledgeTodoActions';
  static const todoActionsChangedCallback = 'todoActionsChanged';

  static String? channelNameFor(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appleChannel,
      TargetPlatform.android => androidChannel,
      TargetPlatform.windows => windowsChannel,
      TargetPlatform.linux || TargetPlatform.fuchsia => null,
    };
  }
}

class CalendarWidgetService {
  CalendarWidgetService({
    required EventRepository eventRepository,
    required SettingsRepository settingsRepository,
    TargetPlatform? targetPlatform,
    MethodChannel? channel,
    bool Function(CalendarEvent)? isEventVisible,
    DateTime? Function()? lmsVerifiedAt,
    Duration themeRefreshDelay = const Duration(milliseconds: 400),
  }) : _eventRepository = eventRepository,
       _settingsRepository = settingsRepository,
       _isEventVisible = isEventVisible,
       _lmsVerifiedAt = lmsVerifiedAt,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _themeRefreshDelay = themeRefreshDelay {
    final channelName = CalendarWidgetChannelContract.channelNameFor(
      _targetPlatform,
    );
    _channel =
        channel ?? (channelName == null ? null : MethodChannel(channelName));
    if (isSupported) {
      _channel!.setMethodCallHandler(handleNativeMethodCall);
    }
  }

  final EventRepository _eventRepository;
  final bool Function(CalendarEvent)? _isEventVisible;
  final DateTime? Function()? _lmsVerifiedAt;
  final SettingsRepository _settingsRepository;
  final TargetPlatform _targetPlatform;
  late final MethodChannel? _channel;
  final Duration _themeRefreshDelay;
  final _todoActionChanges = StreamController<void>.broadcast(sync: true);
  Future<void>? _refreshInFlight;
  bool _refreshRequested = false;
  DateTime? _requestedNow;
  int _themeRefreshGeneration = 0;
  bool _disposed = false;

  bool get isSupported =>
      !kIsWeb &&
      CalendarWidgetChannelContract.channelNameFor(_targetPlatform) != null;

  Stream<void> get todoActionChanges => _todoActionChanges.stream;

  @visibleForTesting
  Future<Object?> handleNativeMethodCall(MethodCall call) async {
    if (call.method ==
            CalendarWidgetChannelContract.todoActionsChangedCallback &&
        !_todoActionChanges.isClosed) {
      _todoActionChanges.add(null);
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _themeRefreshGeneration += 1;
    if (isSupported) {
      _channel?.setMethodCallHandler(null);
    }
    unawaited(_todoActionChanges.close());
  }

  Future<List<CalendarWidgetTodoAction>> pendingTodoActions() async {
    if (!isSupported) {
      return const [];
    }
    try {
      final raw = await _channel!.invokeListMethod<Object?>(
        CalendarWidgetChannelContract.pendingTodoActionsMethod,
      );
      return (raw ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(CalendarWidgetTodoAction.fromMap)
          .whereType<CalendarWidgetTodoAction>()
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<void> acknowledgeTodoActions(Iterable<String> tokens) async {
    if (!isSupported) {
      return;
    }
    final values = tokens.where((token) => token.isNotEmpty).toList();
    if (values.isEmpty) return;
    try {
      await _channel!.invokeMethod<void>(
        CalendarWidgetChannelContract.acknowledgeTodoActionsMethod,
        {'tokens': values},
      );
    } on MissingPluginException {
      // An unavailable surface leaves no acknowledgement work to perform.
    } on PlatformException {
      // Leave actions pending so a later app resume can retry them.
    }
  }

  Future<void> refresh({DateTime? now}) {
    if (!isSupported) {
      return Future.value();
    }

    _refreshRequested = true;
    _requestedNow = now;
    return _refreshInFlight ??= _drainRefreshRequests().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> refreshTheme({DateTime? now}) async {
    if (!isSupported) {
      return;
    }

    final generation = ++_themeRefreshGeneration;
    await Future<void>.delayed(_themeRefreshDelay);
    if (_disposed || generation != _themeRefreshGeneration) {
      return;
    }
    await refresh(now: now);
  }

  Future<void> _drainRefreshRequests() async {
    while (_refreshRequested) {
      _refreshRequested = false;
      final now = _requestedNow;
      _requestedNow = null;
      await _refreshOnce(now: now);
    }
  }

  Future<void> _refreshOnce({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final settings = _settingsRepository.load();
    final monthStart = DateTime(current.year, current.month);
    final leadingDays = settings.weekStartsOnMonday
        ? monthStart.weekday - DateTime.monday
        : monthStart.weekday % DateTime.daysPerWeek;
    final gridStart = shiftCalendarDateByDays(monthStart, -leadingDays);
    final gridEnd = shiftCalendarDateByDays(gridStart, 42);

    final results = await Future.wait([
      _eventRepository.eventsInRange(gridStart, gridEnd),
      _eventRepository.allEventsForSync(),
    ]);
    final snapshot = CalendarWidgetSnapshotBuilder.build(
      now: current,
      settings: settings,
      gridStart: gridStart,
      monthEvents: results[0]
          .where((event) => _isEventVisible?.call(event) ?? true)
          .toList(),
      allEvents: results[1]
          .where((event) => _isEventVisible?.call(event) ?? true)
          .toList(),
    );

    final verifiedAt = _lmsVerifiedAt?.call();
    final owner = _settingsRepository.dailyAccount()?.googleAccount?.email;
    snapshot['lmsVisibility'] = {
      'ownerId': owner?.trim().toLowerCase(),
      'checkedAt': verifiedAt?.millisecondsSinceEpoch,
      // A failed/expired school session stops refreshes, not access to an
      // owner's already synchronized events. The allowlist remains explicit.
      'eventIds': [
        for (final event in results[1])
          if (event.lms != null &&
              !event.isDeleted &&
              event.isVisibleToOwner(owner) &&
              (_isEventVisible?.call(event) ?? false))
            event.id,
      ],
    };
    try {
      await _channel!.invokeMethod<void>(
        CalendarWidgetChannelContract.updateSnapshotMethod,
        snapshot,
      );
    } on MissingPluginException {
      // Unit tests and partially configured embedders may omit the bridge.
    } on PlatformException {
      // Widget refresh must never block calendar mutations.
    }
  }
}

class CalendarWidgetSnapshotBuilder {
  const CalendarWidgetSnapshotBuilder._();

  static Map<String, Object?> build({
    required DateTime now,
    required AppSettings settings,
    required DateTime gridStart,
    required List<CalendarEvent> monthEvents,
    required List<CalendarEvent> allEvents,
  }) {
    final today = _dateOnly(now);
    final locale = resolvedLocaleForLanguage(
      settings.language,
      PlatformDispatcher.instance.locale,
    );
    final localeName = locale.toLanguageTag();
    final l10n = AppLocalizations(locale);
    String weekTitleFor(DateTime day) {
      final offset = settings.weekStartsOnMonday
          ? day.weekday - DateTime.monday
          : day.weekday % DateTime.daysPerWeek;
      final start = shiftCalendarDateByDays(day, -offset);
      final end = shiftCalendarDateByDays(start, 6);
      return '${DateFormat.MMMd(localeName).format(start)} - '
          '${DateFormat.MMMd(localeName).format(end)}';
    }
    final visibleMonthEvents = monthEvents
        .where((event) => _isVisible(event, settings))
        .toList(growable: false);
    final monthEventsByDay = _eventsByDay(
      visibleMonthEvents,
      gridStart,
      shiftCalendarDateByDays(gridStart, 42),
    );
    List<CalendarEvent> eventsOn(DateTime day) =>
        List<CalendarEvent>.from(monthEventsByDay[_dateKey(day)] ?? const [])
          ..sort((left, right) {
            if (left.allDay != right.allDay) {
              return left.allDay ? -1 : 1;
            }
            return left.startAt.compareTo(right.startAt);
          });
    final todayEvents = eventsOn(today);

    final ddayEvents =
        allEvents
            .where((event) => event.showDday && _isVisible(event, settings))
            .toList()
          ..sort((left, right) {
            final leftDistance = _dateOnly(
              left.startAt,
            ).difference(today).inDays.abs();
            final rightDistance = _dateOnly(
              right.startAt,
            ).difference(today).inDays.abs();
            final distanceOrder = leftDistance.compareTo(rightDistance);
            return distanceOrder != 0
                ? distanceOrder
                : left.startAt.compareTo(right.startAt);
          });

    return {
      'generatedAt': now.millisecondsSinceEpoch,
      'localeTag': localeName,
      'themeMode': settings.themeMode.name,
      'monthTitle': DateFormat.yMMMM(localeName).format(now),
      'weekTitle': weekTitleFor(today),
      // The day the derived "today" values were computed for. Native widgets
      // compare it with the device date and pick the matching `dailyViews`
      // entry instead of showing yesterday's values (#103).
      'snapshotDate': _dateKey(today),
      'dailyViews': List.generate(42, (index) {
        final day = _dateOnly(shiftCalendarDateByDays(gridStart, index));
        final dayEvents = eventsOn(day);
        return {
          'date': _dateKey(day),
          'todayTitle': DateFormat.MMMd(localeName).format(day),
          'weekTitle': weekTitleFor(day),
          'todayEvents': dayEvents
              .take(8)
              .map((event) => _eventJson(event, l10n))
              .toList(growable: false),
          'todayRemainingCount': dayEvents.length > 8
              ? dayEvents.length - 8
              : 0,
        };
      }),
      'weekStartsOnMonday': settings.weekStartsOnMonday,
      'monthDays': List.generate(42, (index) {
        final date = shiftCalendarDateByDays(gridStart, index);
        final dayStart = _dateOnly(date);
        final events = monthEventsByDay[_dateKey(dayStart)] ?? const [];
        return {
          'date': _dateKey(date),
          'day': date.day,
          'inMonth': date.year == now.year && date.month == now.month,
          'isToday': dayStart == today,
          'eventCount': events.length,
          'events': events
              .map(
                (event) => {
                  'id': event.occurrenceId ?? event.id,
                  'eventId': event.id,
                  'title': l10n.eventTitle(event.title, holiday: event.holiday),
                  'color': event.colorValue,
                  'completed': event.completed,
                },
              )
              .toList(growable: false),
        };
      }),
      'todayTitle': DateFormat.MMMd(localeName).format(now),
      'todayEvents': todayEvents
          .take(8)
          .map((event) => _eventJson(event, l10n))
          .toList(growable: false),
      'todayRemainingCount': todayEvents.length > 8
          ? todayEvents.length - 8
          : 0,
      'scheduleEvents':
          (visibleMonthEvents.toList()..sort((left, right) {
                if (left.allDay != right.allDay) {
                  return left.allDay ? -1 : 1;
                }
                return left.startAt.compareTo(right.startAt);
              }))
              .map((event) => _eventJson(event, l10n))
              .toList(growable: false),
      'ddays': ddayEvents
          .take(6)
          .map((event) {
            final target = _dateOnly(event.startAt);
            final remaining = target.difference(today).inDays;
            return {
              'id': event.id,
              'title': l10n.eventTitle(event.title, holiday: event.holiday),
              'dateLabel':
                  '${target.year}.${_two(target.month)}.${_two(target.day)}',
              'targetDate': _dateKey(target),
              'daysRemaining': remaining,
              'color': event.colorValue,
              'completed': event.completed,
            };
          })
          .toList(growable: false),
    };
  }

  static bool _isVisible(CalendarEvent event, AppSettings settings) {
    if (event.isDeleted ||
        settings.hiddenCategoryIds.contains(event.category.id)) {
      return false;
    }
    if (event.holiday && !settings.calendarShowHolidays) {
      return false;
    }
    return true;
  }

  static Map<String, List<CalendarEvent>> _eventsByDay(
    List<CalendarEvent> events,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final result = <String, List<CalendarEvent>>{};
    for (final event in events) {
      var cursor = _dateOnly(event.startAt);
      if (cursor.isBefore(rangeStart)) {
        cursor = rangeStart;
      }
      var eventEnd = _dateOnly(
        event.lms != null && event.startAt == event.endAt
            ? event.endAt
            : event.endAt.subtract(const Duration(microseconds: 1)),
      );
      final lastRangeDay = shiftCalendarDateByDays(rangeEnd, -1);
      if (eventEnd.isAfter(lastRangeDay)) {
        eventEnd = lastRangeDay;
      }
      while (!cursor.isAfter(eventEnd)) {
        result.putIfAbsent(_dateKey(cursor), () => []).add(event);
        cursor = shiftCalendarDateByDays(cursor, 1);
      }
    }
    for (final dayEvents in result.values) {
      dayEvents.sort((left, right) {
        if (left.allDay != right.allDay) {
          return left.allDay ? -1 : 1;
        }
        return left.startAt.compareTo(right.startAt);
      });
    }
    return result;
  }

  static Map<String, Object?> _eventJson(
    CalendarEvent event,
    AppLocalizations localizations,
  ) {
    return {
      'id': event.occurrenceId ?? event.id,
      'eventId': event.id,
      'title': localizations.eventTitle(event.title, holiday: event.holiday),
      'timeLabel': event.allDay
          ? localizations.text('종일')
          : '${_two(event.startAt.hour)}:${_two(event.startAt.minute)}',
      'color': event.colorValue,
      'startAt': event.startAt.millisecondsSinceEpoch,
      'endAt': event.endAt.millisecondsSinceEpoch,
      'allDay': event.allDay,
      'completed': event.completed,
    };
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${_two(value.month)}-${_two(value.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class CalendarWidgetTodoAction {
  const CalendarWidgetTodoAction({
    required this.token,
    required this.eventId,
    required this.completed,
    this.occurrenceId,
  });

  final String token;
  final String eventId;
  final bool completed;
  final String? occurrenceId;

  CalendarEvent? targetFor(CalendarEvent source) {
    final key = occurrenceId;
    if (!source.recurrence.isRepeating) {
      return key == null || key.isEmpty || key == source.id ? source : null;
    }
    // Legacy actions have no occurrence information. Never guess today's date
    // or treat a widget tap as an instruction to complete an entire series.
    if (key == null || !key.startsWith('${source.id}@')) return null;
    final start = DateTime.tryParse(key.substring(source.id.length + 1));
    if (start == null) return null;
    return source.copyWith(
      occurrenceId: key,
      startAt: start,
      endAt: start.add(source.duration),
    );
  }

  static CalendarWidgetTodoAction? fromMap(Map<Object?, Object?> map) {
    final token = map['token'];
    final eventId = map['eventId'];
    final completed = map['completed'];
    if (token is! String || eventId is! String || completed is! bool) {
      return null;
    }
    return CalendarWidgetTodoAction(
      token: token,
      eventId: eventId,
      completed: completed,
      occurrenceId: map['occurrenceId'] is String
          ? map['occurrenceId'] as String
          : null,
    );
  }
}
