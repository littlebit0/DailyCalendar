import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/app_settings.dart';
import '../localization/app_localizations.dart';
import '../platform/windows_build_identity.dart';
import '../settings/settings_repository.dart';
import '../time/korea_time.dart';
import 'notification_service.dart';
import 'linux_notification_scheduler.dart';
import 'reminder_delivery_plan.dart';

@immutable
class WindowsNotificationIdentity {
  const WindowsNotificationIdentity({
    required this.appName,
    required this.appUserModelId,
    required this.guid,
  });

  final String appName;
  final String appUserModelId;
  final String guid;
}

const windowsProductionNotificationIdentity = WindowsNotificationIdentity(
  appName: 'DailyCalendar',
  appUserModelId: 'Personal.Daily.Calendar',
  guid: '4c124e1f-e041-4f68-aa1e-9ee8ec1a4fb7',
);

const windowsTestNotificationIdentity = WindowsNotificationIdentity(
  appName: 'DailyCalendar Test',
  appUserModelId: 'Personal.Daily.Calendar.Test',
  guid: '0734c50a-0934-4e91-ad45-58f8d2ea41d5',
);

@visibleForTesting
WindowsNotificationIdentity windowsNotificationIdentityForBuild({
  required bool isTestEdition,
}) {
  return isTestEdition
      ? windowsTestNotificationIdentity
      : windowsProductionNotificationIdentity;
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required SettingsRepository settingsRepository,
    required EventRepository eventRepository,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _settingsRepository = settingsRepository,
       _eventRepository = eventRepository,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _briefingId = 800000;
  static const _briefingScheduleDays = 14;
  static const _androidChannelId = 'daily_reminders';
  static const _androidChannelName = 'Daily reminders';
  static const _androidChannelDescription =
      'Calendar reminders and daily briefing';
  static const _nativeNotificationChannel = MethodChannel(
    'daily/native_notifications',
  );
  static const _dueReminderGrace = Duration(minutes: 2);
  static const _commonReminderMinutes = [0, 5, 10, 15, 30, 60, 1440];
  static const _commonDdayOffsets = [
    -365,
    -180,
    -90,
    -60,
    -30,
    -14,
    -7,
    -3,
    -1,
    0,
  ];

  final SettingsRepository _settingsRepository;
  final EventRepository _eventRepository;
  final FlutterLocalNotificationsPlugin _plugin;
  final _linuxScheduler = LinuxNotificationScheduler();
  var _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(KoreaTime.timeZoneName));

    if (_usesNativeMacNotifications) {
      await _nativeNotificationChannel.invokeMethod<bool>('initialize');
      _initialized = true;
      return;
    }

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final windowsIdentity = windowsNotificationIdentityForBuild(
      isTestEdition: isWindowsTestEdition,
    );
    final windows = WindowsInitializationSettings(
      appName: windowsIdentity.appName,
      appUserModelId: windowsIdentity.appUserModelId,
      guid: windowsIdentity.guid,
    );
    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: windows,
      linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    await _plugin.initialize(settings: settings);
    if (_usesLinuxNotifications) {
      await _linuxScheduler.initialize();
    }
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    await initialize();
    if (event.deletedAt != null ||
        event.completed ||
        event.systemEvent ||
        event.readOnly) {
      return;
    }

    final settings = _settingsRepository.load();
    final l10n = _localizations(settings);
    final reminderMinutesList = event.reminderMinutesBeforeList;
    final title = l10n.eventTitle(event.title, holiday: event.holiday);
    final base = _baseReminderTime(event, settings);
    var deliveredImmediateReminder = false;
    for (final reminderMinutes in reminderMinutesList) {
      if (event.alarmEnabled && reminderMinutes == 0) {
        continue;
      }
      final reminderAt = base.subtract(Duration(minutes: reminderMinutes));
      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: base,
        eventEndAt: event.endAt,
        now: DateTime.now(),
        allowImmediate: allowImmediate,
        dueGrace: _dueReminderGrace,
      );
      if (plan.type == ReminderDeliveryType.immediate) {
        if (deliveredImmediateReminder) {
          continue;
        }
        deliveredImmediateReminder = true;
      }
      await _deliverPlan(
        id: _eventNotificationId(event.id, reminderMinutes),
        title: title,
        body: reminderMinutes == 0 || plan.deliverAt == base
            ? l10n.text('일정이 시작됩니다.')
            : l10n.text(
                '일정 시작 {time}입니다.',
                args: {'time': _minutesLabel(reminderMinutes, l10n)},
              ),
        plan: plan,
        payload: '${event.id}:reminder:$reminderMinutes',
      );
    }

    if (!event.showDday) {
      return;
    }
    for (final offset in settings.dDayReminderOffsets.toSet()) {
      final scheduled = DateTime(
        event.startAt.year,
        event.startAt.month,
        event.startAt.day,
        settings.allDayReminderHour,
        settings.allDayReminderMinute,
      ).add(Duration(days: offset));
      await _deliverPlan(
        id: _eventDdayNotificationId(event.id, offset),
        title: '${_ddayLabel(offset)} $title',
        body: l10n.text('D-day 일정 알림입니다.'),
        plan: scheduled.isAfter(DateTime.now())
            ? ReminderDeliveryPlan.scheduled(scheduled)
            : const ReminderDeliveryPlan.none(),
        payload: '${event.id}:dday:$offset',
      );
    }
  }

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    await initialize();
    await _cancelPendingNotification(_legacyEventNotificationId(eventId));
    final reminderMinutes = {
      ..._commonReminderMinutes,
      ..._settingsRepository.load().defaultReminderMinutesList,
      ...reminderMinutesBeforeList,
    };
    for (final minutes in reminderMinutes) {
      await _cancelPendingNotification(_eventNotificationId(eventId, minutes));
    }
    final offsets = {
      ..._commonDdayOffsets,
      ..._settingsRepository.load().dDayReminderOffsets,
    };
    for (final offset in offsets) {
      await _cancelPendingNotification(
        _eventDdayNotificationId(eventId, offset),
      );
    }
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    final l10n = _localizations(_settingsRepository.load());
    await cancelMorningBriefing();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    for (var dayOffset = 0; dayOffset < _briefingScheduleDays; dayOffset++) {
      final briefingAt = scheduled.add(Duration(days: dayOffset));
      await _scheduleNotification(
        id: _morningBriefingNotificationId(dayOffset),
        title: l10n.text('오늘의 일정'),
        body: await _morningBriefingBody(briefingAt),
        scheduled: briefingAt,
        payload: 'morning_briefing',
      );
    }
  }

  @override
  Future<void> cancelMorningBriefing() async {
    await initialize();
    await _cancelPendingNotification(_briefingId);
    for (var dayOffset = 0; dayOffset < _briefingScheduleDays; dayOffset++) {
      await _cancelPendingNotification(
        _morningBriefingNotificationId(dayOffset),
      );
    }
  }

  Future<String> _morningBriefingBody(DateTime briefingDate) async {
    final today = DateTime(
      briefingDate.year,
      briefingDate.month,
      briefingDate.day,
    );
    final tomorrow = today.add(const Duration(days: 1));
    final settings = _settingsRepository.load();
    final l10n = _localizations(settings);
    final events =
        (await _eventRepository.eventsInRange(
            today,
            tomorrow,
          )).where((event) => !event.isDeleted && !event.completed).toList()
          ..sort((a, b) {
            if (a.allDay != b.allDay) {
              return a.allDay ? -1 : 1;
            }
            return a.startAt.compareTo(b.startAt);
          });
    if (events.isEmpty) {
      return l10n.text('오늘 등록된 일정이 없습니다.');
    }

    const maxItems = 4;
    final visible = events
        .take(maxItems)
        .map((event) => _briefingEventLabel(event, settings));
    final hiddenCount = events.length - maxItems;
    final suffix = hiddenCount > 0
        ? l10n.text(' 외 {count}개 더 있습니다.', args: {'count': hiddenCount})
        : '';
    return '${visible.join(' · ')}$suffix';
  }

  String _briefingEventLabel(CalendarEvent event, AppSettings settings) {
    final title = _localizations(
      settings,
    ).eventTitle(event.title, holiday: event.holiday);
    if (event.allDay) {
      return '${_localizations(settings).text('종일')} $title';
    }
    final hour = event.startAt.hour.toString().padLeft(2, '0');
    final minute = event.startAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $title';
  }

  @override
  Future<int> pendingNotificationCount() async {
    await initialize();
    if (_usesLinuxNotifications) {
      return _linuxScheduler.pendingCount();
    }
    if (_usesNativeMacNotifications) {
      final count = await _nativeNotificationChannel.invokeMethod<int>(
        'pendingCount',
      );
      return count ?? 0;
    }
    final requests = await _plugin.pendingNotificationRequests();
    return requests.length;
  }

  @override
  Future<String> permissionSummary() async {
    await initialize();
    final summary = <String>[];
    if (_usesLinuxNotifications) {
      return 'Linux desktop session · ${await pendingNotificationCount()} pending';
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final notificationsEnabled = await androidPlugin
          .areNotificationsEnabled();
      final exactNotificationsEnabled = await androidPlugin
          .canScheduleExactNotifications();
      summary.add('알림 ${notificationsEnabled == true ? '허용' : '차단'}');
      summary.add(
        '정확 알림 ${exactNotificationsEnabled == true ? '허용' : '확인 필요'}',
      );
    }

    final iosPermissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    final nativeMacPermissions = _usesNativeMacNotifications
        ? await _nativeNotificationChannel.invokeMapMethod<String, Object?>(
            'checkPermissions',
          )
        : null;
    final darwinPermissions = iosPermissions;
    if (nativeMacPermissions != null) {
      summary.add(
        '알림 ${nativeMacPermissions['isEnabled'] == true ? '허용' : '차단'}',
      );
      summary.add(
        '알림센터 ${nativeMacPermissions['notificationCenterEnabled'] == true ? '허용' : '차단'}',
      );
      summary.add(
        '배너 ${nativeMacPermissions['isAlertEnabled'] == true ? '허용' : '차단'}',
      );
      summary.add(
        '스타일 ${_macAlertStyleLabel(nativeMacPermissions['alertStyle'])}',
      );
      summary.add(
        '사운드 ${nativeMacPermissions['isSoundEnabled'] == true ? '허용' : '차단'}',
      );
      summary.add(
        '예약 전달 ${nativeMacPermissions['scheduledDeliveryEnabled'] == true ? '켜짐' : '꺼짐'}',
      );
    }
    if (darwinPermissions != null) {
      summary.add('알림 ${darwinPermissions.isEnabled ? '허용' : '차단'}');
      summary.add('배너 ${darwinPermissions.isAlertEnabled ? '허용' : '차단'}');
      summary.add('사운드 ${darwinPermissions.isSoundEnabled ? '허용' : '차단'}');
    }

    if (summary.isEmpty) {
      summary.add('권한 상태 확인 불가');
    }
    final deliveredCount = await _deliveredNotificationCount();
    summary.add('예약 ${await pendingNotificationCount()}개');
    summary.add('도착 $deliveredCount개');
    return summary.join(' · ');
  }

  Future<int> _deliveredNotificationCount() async {
    try {
      if (_usesNativeMacNotifications) {
        final count = await _nativeNotificationChannel.invokeMethod<int>(
          'deliveredCount',
        );
        return count ?? 0;
      }
      final notifications = await _plugin.getActiveNotifications();
      return notifications.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _deliverPlan({
    required int id,
    required String title,
    required String body,
    required ReminderDeliveryPlan plan,
    required String payload,
  }) async {
    final deliverAt = plan.deliverAt;
    if (deliverAt == null) {
      return;
    }
    switch (plan.type) {
      case ReminderDeliveryType.none:
        return;
      case ReminderDeliveryType.immediate:
        await _showNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      case ReminderDeliveryType.scheduled:
        await _scheduleNotification(
          id: id,
          title: title,
          body: body,
          scheduled: deliverAt,
          payload: payload,
        );
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (_usesNativeMacNotifications) {
      await _nativeNotificationChannel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      });
      return;
    }
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails(),
      payload: payload,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduled,
    required String payload,
    bool repeatsDaily = false,
  }) async {
    if (_usesLinuxNotifications) {
      await _linuxScheduler.schedule(
        id: id,
        title: title,
        body: body,
        scheduled: scheduled,
        repeatsDaily: repeatsDaily,
      );
      return;
    }
    if (_usesNativeMacNotifications) {
      await _nativeNotificationChannel.invokeMethod<void>('schedule', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'scheduledAtMillis': scheduled.millisecondsSinceEpoch,
        'repeatsDaily': repeatsDaily,
      });
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: repeatsDaily ? DateTimeComponents.time : null,
      payload: payload,
    );
  }

  Future<void> _cancelNotification(int id) async {
    if (_usesLinuxNotifications) {
      await _linuxScheduler.cancel(id);
    }
    if (_usesNativeMacNotifications) {
      await _nativeNotificationChannel.invokeMethod<void>('cancel', {'id': id});
      return;
    }
    await _plugin.cancel(id: id);
  }

  Future<void> _cancelPendingNotification(int id) async {
    if (_usesNativeDarwinNotificationControl) {
      await _nativeNotificationChannel.invokeMethod<void>('cancelPending', {
        'id': id,
      });
      return;
    }
    await _cancelNotification(id);
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final canScheduleExact = await androidPlugin
        .canScheduleExactNotifications();
    return canScheduleExact == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  DateTime _baseReminderTime(CalendarEvent event, AppSettings settings) {
    if (!event.allDay) {
      return event.startAt;
    }
    return DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
      settings.allDayReminderHour,
      settings.allDayReminderMinute,
    );
  }

  bool get _usesNativeMacNotifications =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  bool get _usesLinuxNotifications =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool get _usesNativeDarwinNotificationControl =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      ),
      windows: WindowsNotificationDetails(
        duration: WindowsNotificationDuration.short,
      ),
    );
  }

  int _legacyEventNotificationId(String eventId) {
    return _notificationId(eventId, 1000);
  }

  int _eventNotificationId(String eventId, int reminderMinutes) {
    return _notificationId('$eventId:reminder:$reminderMinutes', 1000);
  }

  int _morningBriefingNotificationId(int dayOffset) {
    return _briefingId + 100 + dayOffset;
  }

  int _eventDdayNotificationId(String eventId, int offset) {
    return _notificationId('$eventId:dday:$offset', 500000);
  }

  int _notificationId(String value, int seed) {
    final maxId = pow(2, 31).toInt();
    return value.codeUnits.fold<int>(
      seed,
      (hash, code) => (hash * 31 + code) % maxId,
    );
  }

  String _minutesLabel(int minutes, [AppLocalizations? localizations]) {
    final l10n = localizations ?? _localizations(_settingsRepository.load());
    if (minutes == 0) {
      return l10n.text('정시');
    }
    if (minutes < 60) {
      return l10n.text('{count}분 전', args: {'count': minutes});
    }
    if (minutes % 1440 == 0) {
      return l10n.text('{count}일 전', args: {'count': minutes ~/ 1440});
    }
    if (minutes % 60 == 0) {
      return l10n.text('{count}시간 전', args: {'count': minutes ~/ 60});
    }
    return l10n.text('{count}분 전', args: {'count': minutes});
  }

  AppLocalizations _localizations(AppSettings settings) => AppLocalizations(
    resolvedLocaleForLanguage(
      settings.language,
      PlatformDispatcher.instance.locale,
    ),
  );

  String _ddayLabel(int offset) {
    if (offset == 0) {
      return 'D-day';
    }
    return offset < 0 ? 'D$offset' : 'D+$offset';
  }

  String _macAlertStyleLabel(Object? rawValue) {
    return switch (rawValue) {
      0 => '없음',
      1 => '배너',
      2 => '알림',
      _ => '확인 필요',
    };
  }
}
