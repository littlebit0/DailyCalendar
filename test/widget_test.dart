import 'dart:async';

import 'package:daily/app/daily_app.dart';
import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/alarms/alarm_service.dart';
import 'package:daily/core/auth/apple_sign_in_service.dart';
import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:daily/features/events/presentation/event_completion_action.dart';
import 'package:daily/features/search/presentation/search_page.dart';
import 'package:daily/features/calendar/widgets/calendar_event_drag_layer.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openWelcomeStartPage(WidgetTester tester) async {
  for (var step = 0; step < 8; step += 1) {
    if (find.text('로컬로 시작').evaluate().isNotEmpty) return;
    final continueButton = find.text('계속');
    if (continueButton.evaluate().isNotEmpty) {
      await tester.tap(continueButton.first);
      await tester.pumpAndSettle();
      continue;
    }
    final laterButton = find.text('나중에');
    if (laterButton.evaluate().isNotEmpty) {
      await tester.tap(laterButton.first);
      await tester.pumpAndSettle();
      continue;
    }
    break;
  }
  expect(find.text('로컬로 시작'), findsOneWidget);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue =
        const [Locale('ko')];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('daily/android_alarms'),
          (call) async => switch (call.method) {
            'authorizationState' || 'requestAuthorization' => 'authorized',
            _ => null,
          },
        );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('daily/android_alarms'),
          null,
        );
  });

  test('quick Todo columns stay two on iOS and respond to macOS width', () {
    expect(quickTodoColumnCountForPlatform(TargetPlatform.iOS, 320), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.iOS, 1024), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 560), 1);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 700), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 1000), 3);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.windows, 560), 1);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.windows, 700), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.windows, 1000), 3);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.android, 430), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.android, 600), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.android, 1000), 3);
  });

  test('Android adaptive window classes follow shortest-side breakpoints', () {
    expect(
      dailyWindowClassFor(const Size(599, 1200)),
      DailyWindowClass.compact,
    );
    expect(dailyWindowClassFor(const Size(600, 1200)), DailyWindowClass.medium);
    expect(dailyWindowClassFor(const Size(839, 1400)), DailyWindowClass.medium);
    expect(
      dailyWindowClassFor(const Size(840, 1400)),
      DailyWindowClass.expanded,
    );
  });

  test(
    'calendar pointer navigation covers supported phone and desktop OSes',
    () {
      expect(supportsCalendarPointerNavigation(TargetPlatform.android), isTrue);
      expect(supportsCalendarPointerNavigation(TargetPlatform.iOS), isTrue);
      expect(supportsCalendarPointerNavigation(TargetPlatform.macOS), isTrue);
      expect(supportsCalendarPointerNavigation(TargetPlatform.windows), isTrue);
      expect(supportsCalendarPointerNavigation(TargetPlatform.linux), isTrue);
      expect(
        supportsCalendarPointerNavigation(TargetPlatform.fuchsia),
        isFalse,
      );
    },
  );

  test(
    'macOS and Windows use desktop text scales instead of iPhone scales',
    () {
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.macOS),
        1.0,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.large, TargetPlatform.macOS),
        1.15,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.macOS),
        1.3,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.windows),
        1.0,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.large, TargetPlatform.windows),
        1.15,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.windows),
        1.3,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.iOS),
        0.8,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.iOS),
        1.15,
      );
    },
  );

  test('Android and Windows expose the adjacent-month date setting', () {
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.android), isTrue);
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.windows), isTrue);
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.linux), isTrue);
  });

  testWidgets(
    'Android phone uses the mobile date header and unified navigation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'month',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.horizontal,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('android-horizontal-month-indicator')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('android-calendar-toolbar')),
        findsOneWidget,
      );
      expect(find.byTooltip('이전'), findsNothing);
      expect(find.byTooltip('다음'), findsNothing);
      expect(find.byTooltip('LLM'), findsOneWidget);
      expect(find.byTooltip('Siri'), findsNothing);
      final track = find.byKey(const ValueKey('bottom-mode-track'));
      final compactSize = tester.getSize(track);
      expect(compactSize.height, 42);
      await tester.tap(find.byTooltip('주간'));
      await tester.pumpAndSettle();
      expect(tester.getSize(track).height, 50);
      expect(tester.getSize(track).width, greaterThan(compactSize.width));
      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      expect(tester.getSize(track), compactSize);
      await tester.tap(find.byTooltip('LLM'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inline-ai-input')), findsOneWidget);
      expect(find.widgetWithText(TextField, '일정을 입력하세요'), findsOneWidget);
      expect(find.text('지금 듣는 중...'), findsNothing);
      expect(tester.takeException(), isNull);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Android medium tablet constrains the calendar content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('android-tablet-content-frame')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('android-tablet-content-constraint')),
          )
          .width,
      1120,
    );
    expect(find.byKey(const ValueKey('calendar-event-sidebar')), findsNothing);
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android expanded tablet uses the calendar detail sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('android-tablet-content-frame')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-event-sidebar')))
          .width,
      360,
    );
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('theme mode remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(themeMode: AppThemeMode.dark),
    );

    expect(repository.load().themeMode, AppThemeMode.dark);
    expect(DailyTheme.dark().brightness, Brightness.dark);
    expect(DailyTheme.light().brightness, Brightness.light);
    final darkTheme = DailyTheme.dark();
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xff000000));
    expect(
      darkTheme.colorScheme.surfaceContainerLowest,
      const Color(0xff000000),
    );
    expect(darkTheme.colorScheme.surface, const Color(0xff0a0b0d));
    expect(darkTheme.colorScheme.surfaceContainerHigh, const Color(0xff11141a));
  });

  test(
    'month navigation mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

      expect(
        repository.load().monthNavigationMode,
        MonthNavigationMode.vertical,
      );
    },
  );

  test(
    'week and day layout mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          weekDayLayoutMode: WeekDayLayoutMode.schedule,
        ),
      );

      expect(repository.load().weekDayLayoutMode, WeekDayLayoutMode.schedule);
    },
  );

  testWidgets(
    'schedule view scrolls time vertically and changes week horizontally',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'week',
        'weekDayLayoutMode': 'schedule',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('schedule-timeline')), findsWidgets);
      expect(
        find.byKey(const ValueKey('schedule-all-day-toggle')),
        findsWidgets,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      final initialDate = container.read(selectedDateProvider);
      final timeScroll = find
          .byKey(const ValueKey('schedule-time-scroll'))
          .first;
      final scrollable = tester.widget<SingleChildScrollView>(timeScroll);
      final initialOffset = scrollable.controller!.offset;
      await tester.drag(timeScroll, const Offset(0, -180));
      await tester.pumpAndSettle();

      expect(scrollable.controller!.offset, greaterThan(initialOffset));
      expect(container.read(selectedDateProvider), initialDate);

      await tester.tap(
        find.byKey(const ValueKey('schedule-all-day-toggle')).first,
      );
      await tester.pump();
      expect(find.byIcon(Icons.horizontal_rule_rounded), findsWidgets);

      await tester.drag(
        find.byKey(const ValueKey('schedule-timeline')).first,
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDateProvider).difference(initialDate).inDays,
        7,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'holding a dragged week event at the edge advances multiple weeks',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'week',
        'weekDayLayoutMode': 'list',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final now = DateTime.now();
      final startAt = DateTime(now.year, now.month, now.day, 9);
      final event = CalendarEvent(
        id: 'edge-drag-event',
        title: '가장자리 이동 일정',
        startAt: startAt,
        endAt: startAt.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: now,
        updatedAt: now,
      );
      final eventRepository = _RecordingStreamingEventRepository([event]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      final initialDate = container.read(selectedDateProvider);
      final eventTitle = find.textContaining('가장자리 이동 일정').first;
      expect(eventTitle, findsOneWidget);

      final start = tester.getCenter(eventTitle);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveTo(Offset(391, start.dy));

      await tester.pump(const Duration(milliseconds: 710));
      expect(
        container.read(selectedDateProvider).difference(initialDate).inDays,
        7,
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(
        container.read(selectedDateProvider).difference(initialDate).inDays,
        14,
      );

      await tester.pump(const Duration(milliseconds: 250));
      final targetDate = initialDate.add(const Duration(days: 14));
      final targetPanel = find.byKey(
        ValueKey(
          'week-day-panel-${targetDate.year}-${targetDate.month}-${targetDate.day}',
        ),
      );
      expect(targetPanel, findsOneWidget);
      await gesture.moveTo(tester.getCenter(targetPanel));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(eventRepository.savedEvents, hasLength(1));
      final moved = eventRepository.savedEvents.single;
      expect(
        DateTime(moved.startAt.year, moved.startAt.month, moved.startAt.day),
        DateTime(targetDate.year, targetDate.month, targetDate.day),
      );
      expect(moved.startAt.hour, event.startAt.hour);
      expect(moved.startAt.minute, event.startAt.minute);
      expect(moved.endAt.difference(moved.startAt), const Duration(hours: 1));

      await tester.pump(const Duration(milliseconds: 800));
      expect(
        container.read(selectedDateProvider).difference(initialDate).inDays,
        14,
      );

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('week list opens an insertion gap while reordering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'week',
      'weekDayLayoutMode': 'list',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    CalendarEvent event(String id, int hour) => CalendarEvent(
      id: id,
      title: id,
      startAt: DateTime(day.year, day.month, day.day, hour),
      endAt: DateTime(day.year, day.month, day.day, hour + 1),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    );
    final first = event('week-reorder-first', 9);
    final second = event('week-reorder-second', 10).copyWith(completed: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(
            _RecordingStreamingEventRepository([first, second]),
          ),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final firstDrag = find.byKey(
      ValueKey('week-event-drag-${first.id}@$dateKey'),
    );
    final secondDrag = find.byKey(
      ValueKey('week-event-drag-${second.id}@$dateKey'),
    );
    final firstRect = tester.getRect(firstDrag);
    final firstTop = firstRect.top;
    final gesture = await tester.startGesture(tester.getCenter(secondDrag));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(Offset(firstRect.center.dx, firstRect.top + 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final firstGap = find.byKey(
      ValueKey('week-event-gap-${day.toIso8601String()}-0'),
    );
    expect(tester.getSize(firstGap).height, greaterThan(30));
    expect(tester.getTopLeft(firstDrag).dy, greaterThan(firstTop + 30));

    await gesture.up();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    final savedOrder = settingsRepository
        .load()
        .calendarManualEventOrders[dateKey]
        ?.eventKeys;
    expect(savedOrder, [second.id, first.id]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.getTopLeft(secondDrag).dy,
      lessThan(tester.getTopLeft(firstDrag).dy),
    );
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'macOS year overview shows two columns and moves to adjacent years',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'month',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      final verticalMonthList = find.byKey(
        const ValueKey('continuous-month-scroll'),
      );
      final verticalMonthController = tester
          .widget<ListView>(verticalMonthList)
          .controller!;
      final wheelStart = verticalMonthController.offset;
      verticalMonthController.position.pointerScroll(120);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(verticalMonthController.offset, greaterThan(wheelStart));
      expect(verticalMonthController.offset, lessThan(wheelStart + 120));
      await tester.pumpAndSettle();
      expect(verticalMonthController.offset, closeTo(wheelStart + 120, 0.1));

      final year = container.read(visibleMonthProvider).year;
      await tester.tap(find.text('$year년').first);
      await tester.pumpAndSettle();

      expect(find.text('$year-${year + 1}년'), findsNothing);
      expect(find.byKey(ValueKey('mini-month-$year-1')), findsOneWidget);
      expect(find.byKey(ValueKey('mini-month-${year + 1}-1')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(ValueKey('mini-month-canvas-$year-1')))
            .height,
        greaterThan(100),
      );

      final overview = find.byKey(
        const ValueKey('year-overview-continuous-scroll'),
      );
      await tester.drag(overview, const Offset(0, 620));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('mini-month-${year - 1}-1')), findsOneWidget);
      expect(find.byKey(ValueKey('mini-month-${year - 200}-1')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('iOS year overview moves to the immediately previous year', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.save(
      settingsRepository.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final year = container.read(visibleMonthProvider).year;
    await tester.tap(find.text('$year년').first);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('year-overview-continuous-scroll')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('mini-month-${year - 1}-1')), findsOneWidget);
    expect(find.byKey(ValueKey('mini-month-${year - 200}-1')), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Apple platforms automatically request system authentication', () {
    expect(shouldAutomaticallyRequestBiometrics(TargetPlatform.macOS), isTrue);
    expect(shouldAutomaticallyRequestBiometrics(TargetPlatform.iOS), isTrue);
    expect(
      shouldAutomaticallyRequestBiometrics(
        TargetPlatform.android,
        alreadyAttempted: true,
      ),
      isFalse,
    );
  });

  test('app text size remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(appTextSize: AppTextSize.extraLarge),
    );

    expect(settingsRepository.load().appTextSize, AppTextSize.extraLarge);
  });

  test(
    'adjacent-month date visibility remains selected after reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);

      await settingsRepository.save(
        settingsRepository.load().copyWith(showAdjacentMonthDates: false),
      );

      expect(settingsRepository.load().showAdjacentMonthDates, isFalse);
    },
  );

  test('legacy default reminder migrates into the reminder list', () async {
    SharedPreferences.setMockInitialValues({'defaultReminderMinutes': 10});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    expect(settingsRepository.load().defaultReminderMinutesList, [10]);
  });

  test('multiple default reminders remain selected after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const [60, 10, 30, 10],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, [10, 30, 60]);
  });

  test('empty default reminder list remains disabled after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const <int>[],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, isEmpty);
  });

  test(
    'settings reset ignores missing keychain entitlement during cleanup',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultReminderMinutes': 10,
        'appleUserIdentifier': 'apple-user',
        'appleEmail': 'apple@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: const _MissingEntitlementSecureStorage(),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.load().onboardingCompleted, isFalse);
      expect(settingsRepository.load().defaultReminderMinutes, 60);
      expect(settingsRepository.appleAccount(), isNull);
    },
  );

  test(
    'Google Drive desktop session survives auth service recreation',
    () async {
      final storage = _MemorySecureStorage();
      await storage.write(
        key: 'daily.google_drive.access_token',
        value: 'access-token',
      );
      await storage.write(
        key: 'daily.google_drive.refresh_token',
        value: 'refresh-token',
      );
      await storage.write(
        key: 'daily.google_drive.expires_at',
        value: DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      await storage.write(
        key: 'daily.google_drive.email',
        value: 'persisted@example.com',
      );
      await storage.write(
        key: 'daily.google_drive.display_name',
        value: 'Persisted User',
      );

      final firstService = GoogleDriveAuthService(
        secureStorage: storage,
        useDesktopOAuth: true,
      );
      final secondService = GoogleDriveAuthService(
        secureStorage: storage,
        useDesktopOAuth: true,
      );

      expect(
        (await firstService.restorePreviousSignIn())?.email,
        'persisted@example.com',
      );
      expect(
        (await secondService.restorePreviousSignIn())?.email,
        'persisted@example.com',
      );
      expect(await secondService.authorizationHeaders(), {
        'Authorization': 'Bearer access-token',
      });
    },
  );

  test('Google Drive restore reports a missing keychain entitlement', () async {
    final service = GoogleDriveAuthService(
      secureStorage: const _MissingEntitlementSecureStorage(),
      useDesktopOAuth: true,
    );

    await expectLater(
      service.restorePreviousSignIn(),
      throwsA(isA<GoogleDriveAuthException>()),
    );
  });

  test(
    'app lock stores the configured PIN length with its secure hash',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final secureStorage = _MemorySecureStorage();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: secureStorage,
      );

      await settingsRepository.saveAppLockPin('13579');

      expect(await settingsRepository.appLockPinLength(), 5);
      expect(await settingsRepository.verifyAppLockPin('13579'), isTrue);
      expect(await settingsRepository.verifyAppLockPin('1357'), isFalse);

      await settingsRepository.deleteAppLockPin();

      expect(await settingsRepository.appLockPinLength(), isNull);
      expect(await settingsRepository.verifyAppLockPin('13579'), isFalse);
    },
  );

  test('legacy biometric app lock migrates to the system method', () async {
    SharedPreferences.setMockInitialValues({
      'appLockEnabled': true,
      'appLockBiometricsEnabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences: preferences).load();

    expect(settings.appLockMethod, AppLockMethod.system);
  });

  test('selected app lock method remains stored locally', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(
        appLockEnabled: true,
        appLockMethod: AppLockMethod.noPin,
      ),
    );

    expect(repository.load().appLockMethod, AppLockMethod.noPin);
  });

  test(
    'Apple account refresh keeps saved app login marker if revoked',
    () async {
      SharedPreferences.setMockInitialValues({
        'appleUserIdentifier': 'apple-user',
        'appleEmail': 'hwi@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final appleSignInService = AppleSignInService(
        settingsRepository: settingsRepository,
        targetPlatform: TargetPlatform.iOS,
        availabilityChecker: () async => true,
        credentialStateChecker: (_) async => CredentialState.revoked,
      );

      final account = await appleSignInService.refreshCurrentAccount();

      expect(account?.email, 'hwi@example.com');
      expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    },
  );

  test('Apple unknown auth error explains sideloaded IPA limitation', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.unknown,
          message: 'unknown',
        );
      },
    );

    await expectLater(
      appleSignInService.signIn(),
      throwsA(
        isA<AppleSignInException>().having(
          (error) => error.message,
          'message',
          allOf(contains('SideStore'), contains('Google로 계속')),
        ),
      ),
    );
  });

  test('Daily account keeps Apple and Google identities together', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'apple-user',
        email: 'apple@example.com',
      ),
    );
    final accountAfterApple = settingsRepository.dailyAccount();
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'google@example.com', displayName: 'Daily'),
    );
    final mergedAccount = settingsRepository.dailyAccount();

    expect(mergedAccount?.id, accountAfterApple?.id);
    expect(mergedAccount?.appleAccount?.userIdentifier, 'apple-user');
    expect(mergedAccount?.googleAccount?.email, 'google@example.com');
  });

  test(
    'Daily account reset removes merged Apple and Google identities',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveAppleAccount(
        const AppleAccount(userIdentifier: 'apple-user'),
      );
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'google@example.com'),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.dailyAccount(), isNull);
      expect(settingsRepository.appleAccount(), isNull);
    },
  );

  testWidgets('Apple sign-in restores an already linked Google session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'apple-user',
        email: 'hwi@example.com',
      ),
    );
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'linked@example.com'),
    );
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        expect(scopes, contains(AppleIDAuthorizationScopes.email));
        expect(scopes, contains(AppleIDAuthorizationScopes.fullName));
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: 'Hwi',
          familyName: 'Kim',
          authorizationCode: 'auth-code',
          email: 'hwi@example.com',
          identityToken: 'identity-token',
          state: null,
        );
      },
    );
    final googleAuthService = _FakeGoogleDriveAuthService(
      account: null,
      restoredAccount: const GoogleDriveAccount(email: 'linked@example.com'),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: googleAuthService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(googleAuthService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          appleSignInServiceProvider.overrideWithValue(appleSignInService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    expect(find.text('Apple로 계속'), findsOneWidget);

    await tester.tap(find.text('Apple로 계속'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsRepository.load().onboardingCompleted, isTrue);
    expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    expect(
      googleAuthService.restorePreviousSignInCalls,
      greaterThanOrEqualTo(1),
    );
    expect(googleAuthService.signInCalls, 0);
    expect(driveSyncService.startListeningOnlyCalls, greaterThanOrEqualTo(1));
    expect(
      driveSyncService.syncPendingChangesNowCalls,
      greaterThanOrEqualTo(1),
    );
    expect(find.byTooltip('LLM'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'onboarding requests notification permission only after consent',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final notificationService = _FakeNotification();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            alarmServiceProvider.overrideWithValue(
              const UnsupportedAlarmService(),
            ),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(account: null),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(notificationService.initializeCalls, 0);
      await tester.tap(find.text('계속'));
      await tester.pumpAndSettle();
      expect(find.text('익명 분석 허용'), findsOneWidget);
      expect(notificationService.initializeCalls, 0);

      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('Siri 단축어 추가하기'), findsOneWidget);
      expect(notificationService.initializeCalls, 0);

      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('알림 및 알람 허용'), findsOneWidget);
      expect(notificationService.initializeCalls, 0);

      await tester.tap(find.text('알림 및 알람 허용'));
      await tester.pumpAndSettle();
      expect(notificationService.initializeCalls, 1);
      expect(find.text('로컬로 시작'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '로컬로 시작'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Apple로 계속'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google로 계속'),
            )
            .onPressed,
        isNotNull,
      );

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'new ${platform.name} onboarding does not repeat analytics consent after permission',
      (tester) async {
        tester.view.physicalSize = platform == TargetPlatform.android
            ? const Size(430, 932)
            : const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final settingsRepository = SettingsRepository(preferences: preferences);
        final analytics = _FakeProductAnalytics(consentPromptCompleted: false);
        final permissionCompleter = Completer<void>();
        final notificationService = _FakeNotification(
          initializeCompleter: permissionCompleter,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settingsRepository),
              productAnalyticsProvider.overrideWithValue(analytics),
              notificationServiceProvider.overrideWithValue(
                notificationService,
              ),
              alarmServiceProvider.overrideWithValue(
                const UnsupportedAlarmService(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(account: null),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('오늘을 더\n가볍게 정리하세요.'), findsOneWidget);
        await tester.tap(find.text('계속'));
        await tester.pumpAndSettle();
        expect(find.text('익명 분석 허용'), findsOneWidget);

        await tester.tap(find.text('나중에'));
        await tester.pumpAndSettle();
        expect(analytics.completeConsentPromptCalls, 1);
        expect(analytics.consentPromptCompleted, isTrue);
        expect(find.text('익명 분석 허용'), findsNothing);
        expect(find.text('알림 및 알람 허용'), findsOneWidget);

        await tester.tap(find.text('알림 및 알람 허용'));
        await tester.pump();
        expect(notificationService.initializeCalls, 1);
        expect(find.text('알림과 알람을\n준비할까요?'), findsOneWidget);
        expect(find.text('익명 분석 허용'), findsNothing);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('익명 분석 허용'), findsNothing);

        permissionCompleter.complete();
        await tester.pumpAndSettle();
        expect(find.text('로컬로 시작'), findsOneWidget);
        expect(find.text('익명 분석 허용'), findsNothing);
        expect(analytics.completeConsentPromptCalls, 1);

        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('existing users choose analytics consent before calendar opens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final analytics = _FakeProductAnalytics(consentPromptCompleted: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          productAnalyticsProvider.overrideWithValue(analytics),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('익명 분석 허용'), findsOneWidget);
    expect(find.byType(MonthCalendarPage), findsNothing);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(analytics.consentPromptCompleted, isTrue);
    expect(analytics.enabled, isFalse);
    expect(find.byType(MonthCalendarPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Apple sign-in starts Daily without opening Google login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: 'Hwi',
          familyName: 'Kim',
          authorizationCode: 'auth-code',
          email: 'hwi@example.com',
          identityToken: 'identity-token',
          state: null,
        );
      },
    );
    final googleAuthService = _FakeGoogleDriveAuthService(
      account: null,
      signInAccount: const GoogleDriveAccount(email: 'linked@example.com'),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: googleAuthService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(googleAuthService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          appleSignInServiceProvider.overrideWithValue(appleSignInService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    await tester.tap(find.text('Apple로 계속'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    expect(settingsRepository.load().onboardingCompleted, isTrue);
    // App startup may make a silent restoration attempt, but Apple sign-in
    // itself must never open the interactive Google authentication flow.
    expect(
      googleAuthService.restorePreviousSignInCalls,
      greaterThanOrEqualTo(1),
    );
    expect(googleAuthService.signInCalls, 0);
    expect(driveSyncService.syncPendingChangesNowCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google sign-in preserves the linked Apple identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'linked-apple-user',
        email: 'apple@example.com',
      ),
    );
    final authService = _FakeGoogleDriveAuthService(
      account: null,
      signInAccount: const GoogleDriveAccount(
        email: 'google@example.com',
        displayName: 'Google User',
      ),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    await tester.tap(find.text('Google로 계속'));
    await tester.pumpAndSettle();

    final mergedAccount = settingsRepository.dailyAccount();
    expect(mergedAccount?.appleAccount?.userIdentifier, 'linked-apple-user');
    expect(mergedAccount?.googleAccount?.email, 'google@example.com');
    expect(settingsRepository.load().onboardingCompleted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'welcome keeps desktop Google auth active until the user cancels it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        signInCompleter: Completer<GoogleDriveAccount?>(),
        canCancelOnResume: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _openWelcomeStartPage(tester);

      await tester.tap(find.text('Google로 계속'));
      await tester.pump();

      expect(authService.signInCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google 연결 중'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 0);
      expect(find.text('연결 취소'), findsOneWidget);
      await tester.tap(find.text('연결 취소'));
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 1);
      expect(
        find.text('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google로 계속'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily opens and resumes on the selected quick view start screen',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'appleUserIdentifier': 'apple-user',
        'appleEmail': 'hwi@example.com',
        'appStartView': AppStartView.quickView.name,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final notificationService = _FakeNotification();
      final eventRepository = _FakeEventRepository();
      final googleAuthService = _FakeGoogleDriveAuthService();
      final driveSyncService = _FakeGoogleDriveSyncService(
        authService: googleAuthService,
        eventRepository: eventRepository,
        notificationService: notificationService,
        settingsRepository: settingsRepository,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(googleAuthService),
            googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-view-list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-view-month-pages')),
        findsOneWidget,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-view-list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-view-month-pages')),
        findsOneWidget,
      );

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Daily opens to the weekly calendar shell and swipes weeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      124,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      40,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('bottom-mode-switcher'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('calendar-bottom-bar'))).dx,
        0.1,
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-view-button'))).width,
      lessThan(96),
    );
    final compactViewButtonSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    final compactViewThumbSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-thumb-circle')),
    );
    expect(compactViewButtonSize, const Size(76, 40));
    expect(compactViewThumbSize, const Size.square(32));
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('calendar-view-track')),
          )
          .clipBehavior,
      Clip.none,
    );
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('bottom-mode-track')))
          .clipBehavior,
      Clip.none,
    );
    final calendarTrackDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('calendar-view-track')),
                )
                .decoration!
            as ShapeDecoration;
    final bottomTrackDecoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('bottom-mode-track')),
                )
                .decoration!
            as ShapeDecoration;
    expect(
      (calendarTrackDecoration.shape as StadiumBorder).side,
      BorderSide.none,
    );
    expect(
      (bottomTrackDecoration.shape as StadiumBorder).side,
      BorderSide.none,
    );
    expect(
      tester
          .widget<Stack>(
            find.byKey(const ValueKey('calendar-view-thumb-layer')),
          )
          .clipBehavior,
      Clip.none,
    );
    expect(
      tester
          .widget<Stack>(find.byKey(const ValueKey('bottom-mode-thumb-layer')))
          .clipBehavior,
      Clip.none,
    );
    expect(
      compactViewThumbSize.width,
      closeTo(compactViewThumbSize.height, 0.6),
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('일정 없음'), findsWidgets);
    expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
    expect(find.byTooltip('오늘'), findsOneWidget);
    final periodButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-period-button')),
    );
    final reservedSpaceRect = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-header-reserved-space')),
    );
    expect(periodButtonRect.width, lessThan(180));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-period-button')),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(periodButtonRect.left, lessThan(16));
    expect(reservedSpaceRect.left, closeTo(periodButtonRect.right, 0.1));
    expect(reservedSpaceRect.width, greaterThan(0));

    final compactViewButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    await tester.tapAt(
      Offset(
        compactViewButtonRect.left + compactViewButtonRect.width / 6,
        compactViewButtonRect.center.dy,
      ),
    );
    await tester.pumpAndSettle();
    final expandedViewButtonSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    expect(expandedViewButtonSize.width, greaterThan(76));
    expect(expandedViewButtonSize.height, greaterThan(40));
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))),
      const Size(124, 40),
    );

    final expandedViewButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    await tester.tapAt(
      Offset(
        expandedViewButtonRect.left + expandedViewButtonRect.width / 6,
        expandedViewButtonRect.center.dy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 90));

    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-view-button'))),
      expandedViewButtonSize,
    );
    await tester.pumpAndSettle();

    final iosToolbarBeforeQuickAccess = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-toolbar')),
    );
    await tester.drag(
      find.byKey(const ValueKey('bottom-mode-switcher')),
      const Offset(-70, 0),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getRect(find.byKey(const ValueKey('ios-calendar-toolbar'))),
      iosToolbarBeforeQuickAccess,
    );
    await tester.pumpAndSettle();

    expect(find.text('빠른 보기'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const ValueKey('bottom-mode-thumb')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-thumb-circle'))),
      const Size.square(40),
    );
    expect(find.byKey(const ValueKey('calendar-view-button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      152,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      48,
    );
    final quickAccessIcon = find.descendant(
      of: find.byKey(const ValueKey('bottom-mode-switcher')),
      matching: find.byIcon(Icons.view_agenda_outlined),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('bottom-mode-thumb-circle')))
          .dx,
      closeTo(tester.getCenter(quickAccessIcon).dx, 0.5),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('bottom-mode-switcher'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('calendar-bottom-bar'))).dx,
        0.1,
      ),
    );

    await tester.tap(quickAccessIcon);
    await tester.pump(const Duration(milliseconds: 90));

    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))),
      const Size(152, 48),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('달력'));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-view-button')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('calendar-view-button'))).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('bottom-mode-switcher'))).left,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startDate = container.read(selectedDateProvider);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bottom-mode-thumb')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-thumb-circle'))),
      const Size.square(32),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      124,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      40,
    );
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );

    final iosToolbarBeforeAi = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-toolbar')),
    );
    final calendarHeightBeforeAi = tester.getSize(find.byType(PageView)).height;

    await tester.tap(find.byTooltip('Siri'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inline-ai-layout-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inline-ai-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('inline-ai-panel')), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('inline-ai-layout-panel')))
          .height,
      greaterThan(0),
    );
    expect(
      tester.getSize(find.byType(PageView)).height,
      lessThan(calendarHeightBeforeAi),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('ios-calendar-toolbar'))),
      iosToolbarBeforeAi,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('AI 입력 닫기'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: true);

  testWidgets('iOS uses one liquid-style five-segment calendar navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final switcher = find.byKey(const ValueKey('bottom-mode-switcher'));
    expect(tester.getSize(switcher), const Size(281.6, 42));
    expect(find.byKey(const ValueKey('calendar-view-button')), findsNothing);
    expect(find.byTooltip('빠른 보기'), findsOneWidget);
    expect(find.byTooltip('주간'), findsOneWidget);
    expect(find.byTooltip('월간'), findsOneWidget);
    expect(find.byTooltip('일간'), findsOneWidget);
    expect(find.byTooltip('Siri'), findsOneWidget);

    final trackRect = tester.getRect(switcher);
    final thumb = find.byKey(const ValueKey('bottom-mode-thumb-circle'));
    expect(
      tester.getCenter(thumb).dx,
      closeTo(trackRect.left + trackRect.width * 0.3, 3),
    );

    await tester.tap(find.byTooltip('빠른 보기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-view-list')), findsOneWidget);
    expect(tester.getSize(switcher), const Size(320, 50));

    await tester.tap(find.byTooltip('월간'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(
      tester.getCenter(thumb).dx,
      closeTo(trackRect.left + trackRect.width * 0.5, 3),
    );

    final thumbSize = tester.getSize(thumb);
    await tester.tap(find.byTooltip('월간'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getSize(thumb), thumbSize);

    final pageListener = tester.widget<Listener>(
      find.byKey(const ValueKey('calendar-page-pointer-listener')),
    );
    pageListener.onPointerDown!(
      const PointerDownEvent(position: Offset(196, 120)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(switcher).height, inExclusiveRange(42, 50));
    await tester.pumpAndSettle();
    expect(tester.getSize(switcher), const Size(281.6, 42));

    final toolbarBeforeSiri = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-toolbar')),
    );
    await tester.tap(find.byTooltip('Siri'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inline-ai-layout-panel')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('ios-calendar-toolbar'))),
      toolbarBeforeSiri,
    );

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('iOS calendar view slider expands for English labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
      'language': AppLanguage.english.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final viewSlider = find.byKey(const ValueKey('bottom-mode-switcher'));
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.byTooltip('Siri'), findsOneWidget);
    expect(tester.getSize(viewSlider), const Size(281.6, 42));
    expect(find.byKey(const ValueKey('calendar-view-button')), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Signal typed event changes require explicit confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const signalChannel = MethodChannel('daily/signal_voice');
    final signalCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(signalChannel, (call) async {
          signalCalls.add(call);
          return switch (call.method) {
            'startListening' => throw PlatformException(
              code: 'listening_cancelled',
            ),
            'cancelListening' || 'speak' => null,
            'runSignal'
                when (call.arguments as Map<Object?, Object?>)['confirmed'] ==
                    false =>
              throw PlatformException(code: 'signal_confirmation_required'),
            'runSignal' => <String, Object?>{
              'message': '일정을 추가했습니다.',
              'success': true,
            },
            _ => throw PlatformException(code: 'unexpected_method'),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(signalChannel, null);
    });

    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Siri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('텍스트로 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('signal-text-input')),
      '내일 오전 9시부터 10시까지 운동 일정 추가',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('이 명령을 실행할까요?'), findsOneWidget);
    final previewCall = signalCalls.singleWhere(
      (call) => call.method == 'runSignal',
    );
    expect(previewCall.arguments, {
      'command': '내일 오전 9시부터 10시까지 운동 일정 추가',
      'confirmed': false,
    });

    await tester.tap(find.widgetWithText(FilledButton, '실행'));
    await tester.pumpAndSettle();

    final runCall = signalCalls
        .where((call) => call.method == 'runSignal')
        .last;
    expect(runCall.arguments, {
      'command': '내일 오전 9시부터 10시까지 운동 일정 추가',
      'confirmed': true,
    });
    expect(find.text('일정을 추가했습니다.'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets('$platform daily date placement and calendar holiday colors', (
      tester,
    ) async {
      tester.view.physicalSize = platform == TargetPlatform.macOS
          ? const Size(1440, 900)
          : const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = platform;
      try {
        SharedPreferences.setMockInitialValues({
          'onboardingCompleted': true,
          'defaultCalendarView': 'day',
        });
        final preferences = await SharedPreferences.getInstance();
        final repository = SettingsRepository(preferences: preferences);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repository),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyApp)),
        );
        final base = container.read(appSettingsProvider);
        final settings = base.copyWith(
          categories: [
            for (final category in base.categories)
              category.id == EventCategory.holiday.id
                  ? category.copyWith(colorValue: 0xff10b981)
                  : category,
          ],
        );
        for (final dark in [false, true]) {
          for (final (date, weekday, color) in [
            (DateTime(2026, 9, 5), '토요일', const Color(0xff2563eb)),
            (DateTime(2026, 9, 6), '일요일', const Color(0xffef4444)),
            (DateTime(2026, 3, 2), '월요일', const Color(0xff10b981)),
          ]) {
            container.read(selectedDateProvider.notifier).state = date;
            await tester.pumpAndSettle();
            container.read(appSettingsProvider.notifier).state = settings
                .copyWith(
                  themeMode: dark ? AppThemeMode.dark : AppThemeMode.light,
                  weekDayLayoutMode: WeekDayLayoutMode.list,
                );
            await tester.pumpAndSettle();
            final label = tester.widget<Text>(
              find
                  .byKey(const ValueKey('event-details-date-label'))
                  .hitTestable()
                  .first,
            );
            final spans = (label.textSpan! as TextSpan).children!
                .cast<TextSpan>();
            expect(
              spans.where((s) => s.style?.color != null).single.text,
              weekday,
              reason:
                  'selected=${container.read(selectedDateProvider)}, label=${label.textSpan!.toPlainText()}',
            );
            expect(
              spans.where((s) => s.style?.color != null).single.style!.color,
              color,
            );
            container.read(appSettingsProvider.notifier).state = container
                .read(appSettingsProvider)
                .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
            await tester.pumpAndSettle();
            final button = find.byKey(const ValueKey('calendar-period-button'));
            final text = tester.widget<Text>(
              find.descendant(of: button, matching: find.byType(Text)),
            );
            expect(
              text.textSpan!.toPlainText(),
              '2026년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일 $weekday',
            );
            final periodSpans = (text.textSpan! as TextSpan).children!
                .cast<TextSpan>();
            expect(
              periodSpans.where((s) => s.style?.color != null).single.text,
              weekday,
            );
            expect(
              periodSpans
                  .where((s) => s.style?.color != null)
                  .single
                  .style!
                  .color,
              color,
            );
            expect(text.style!.color, isNot(color));
            expect(
              find.byKey(
                ValueKey(
                  'schedule-day-header-${date.year}-${date.month}-${date.day}',
                ),
              ),
              findsNothing,
            );
            if (platform == TargetPlatform.macOS) {
              final sidebarLabel = tester.widget<Text>(
                find.byKey(const ValueKey('event-details-date-label')),
              );
              expect(
                (sidebarLabel.textSpan! as TextSpan).children!
                    .cast<TextSpan>()
                    .every((s) => s.style?.color == null),
                isTrue,
              );
            }
            expect(tester.takeException(), isNull);
          }
        }
        container.read(calendarViewModeProvider.notifier).state =
            CalendarViewMode.week;
        container.read(selectedDateProvider.notifier).state = DateTime(
          2026,
          3,
          2,
        );
        container.read(appSettingsProvider.notifier).state = settings.copyWith(
          weekDayLayoutMode: WeekDayLayoutMode.list,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find
                    .byKey(const ValueKey('week-list-weekday-2026-3-2'))
                    .hitTestable()
                    .first,
              )
              .style!
              .color,
          const Color(0xff10b981),
        );
        container.read(appSettingsProvider.notifier).state = settings.copyWith(
          weekDayLayoutMode: WeekDayLayoutMode.schedule,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find
                    .byKey(const ValueKey('schedule-day-header-2026-3-2'))
                    .hitTestable()
                    .first,
              )
              .style!
              .color,
          const Color(0xff10b981),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      '$platform quick view navigates months and preserves long list scrolling',
      (tester) async {
        tester.view.physicalSize = platform == TargetPlatform.macOS
            ? const Size(1440, 900)
            : const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({
          'onboardingCompleted': true,
          'appStartView': AppStartView.quickView.name,
        });
        final preferences = await SharedPreferences.getInstance();
        final repository = SettingsRepository(preferences: preferences);
        final events = List.generate(
          50,
          (index) => CalendarEvent(
            id: 'quick-long-$index',
            title: '일정 $index',
            startAt: DateTime(2026, 9, 15, 9),
            endAt: DateTime(2026, 9, 15, 10),
            allDay: false,
            category: EventCategory.basic,
            colorValue: EventCategory.basic.colorValue,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repository),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(
                _StreamingEventRepository(events),
              ),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyApp)),
        );
        final region = find.byKey(
          const ValueKey('quick-view-pointer-navigation'),
        );
        Future<void> wheel(Offset delta) => tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: tester.getCenter(region),
            scrollDelta: delta,
          ),
        );
        Future<void> month(DateTime date) async {
          container.read(visibleMonthProvider.notifier).state = date;
          await tester.pumpAndSettle();
        }

        for (final mode in MonthNavigationMode.values) {
          container.read(appSettingsProvider.notifier).state = container
              .read(appSettingsProvider)
              .copyWith(monthNavigationMode: mode);
          await tester.pumpAndSettle();
          await month(DateTime(2026, 12));
          const offset = Offset(-260, 0);
          expect(
            tester
                .widget<PageView>(
                  find.byKey(const ValueKey('quick-view-month-pages')),
                )
                .scrollDirection,
            Axis.horizontal,
          );
          if (platform == TargetPlatform.macOS) {
            await wheel(const Offset(1, 0));
          } else {
            await tester.fling(region, offset, 1000);
          }
          await tester.pumpAndSettle();
          expect(
            container.read(visibleMonthProvider),
            DateTime(2027, 1),
            reason: '$mode next',
          );
          if (platform == TargetPlatform.macOS) {
            for (var tick = 0; tick < 4; tick++) {
              await wheel(const Offset(1, 0));
              await tester.pump(const Duration(milliseconds: 20));
            }
            await tester.pumpAndSettle();
            expect(
              container.read(visibleMonthProvider),
              DateTime(2027, 5),
              reason: '$mode rapid ticks',
            );
            await wheel(const Offset(-1, 0));
            await tester.pumpAndSettle();
            expect(container.read(visibleMonthProvider), DateTime(2027, 4));
            await wheel(const Offset(0, 1));
            await tester.pumpAndSettle();
            expect(
              container.read(visibleMonthProvider),
              DateTime(2027, 5),
              reason: '$mode vertical wheel',
            );
            await tester.trackpadFling(region, offset, 1000);
            await tester.pumpAndSettle();
            expect(
              container.read(visibleMonthProvider),
              DateTime(2027, 6),
              reason: '$mode trackpad',
            );
          } else {
            await tester.fling(region, -offset, 1000);
            await tester.pumpAndSettle();
            expect(
              container.read(visibleMonthProvider),
              DateTime(2026, 12),
              reason: '$mode previous',
            );
          }
        }
        await month(DateTime(2026, 9));
        final list = find
            .byKey(const ValueKey('quick-view-list'))
            .hitTestable()
            .first;
        final listState = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        );
        expect(listState.position.maxScrollExtent, greaterThan(500));
        if (platform == TargetPlatform.macOS) {
          await wheel(const Offset(0, 80));
        } else {
          await tester.drag(list, const Offset(0, -180));
        }
        await tester.pumpAndSettle();
        expect(listState.position.pixels, greaterThan(0));
        expect(container.read(visibleMonthProvider), DateTime(2026, 9));
        listState.position.jumpTo(listState.position.maxScrollExtent);
        await tester.pumpAndSettle();
        if (platform == TargetPlatform.macOS) {
          await wheel(const Offset(0, 1));
        } else {
          await tester.drag(list, const Offset(0, -160));
          await tester.pumpAndSettle();
          expect(container.read(visibleMonthProvider), DateTime(2026, 9));
          await tester.fling(region, const Offset(-260, 0), 1000);
        }
        await tester.pumpAndSettle();
        expect(container.read(visibleMonthProvider), DateTime(2026, 10));
        // Quick view remains month-based even when opened from a day calendar.
        container.read(calendarViewModeProvider.notifier).state =
            CalendarViewMode.day;
        await tester.pumpAndSettle();
        if (platform == TargetPlatform.macOS) {
          await tester.tap(find.byTooltip('다음'));
          await tester.pumpAndSettle();
          expect(container.read(visibleMonthProvider), DateTime(2026, 11));
        }
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      '$platform double tap toggles only its event across calendar and detail entries',
      (tester) async {
        tester.view.physicalSize =
            platform == TargetPlatform.macOS ||
                platform == TargetPlatform.windows
            ? const Size(1440, 900)
            : const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
        final preferences = await SharedPreferences.getInstance();
        final settings = SettingsRepository(preferences: preferences);
        final date = DateTime(2026, 9, 7);
        CalendarEvent event(String id, {bool allDay = false}) => CalendarEvent(
          id: id,
          title: '동일 제목',
          startAt: date.add(Duration(hours: allDay ? 0 : 9)),
          endAt: date.add(Duration(hours: allDay ? 24 : 10)),
          allDay: allDay,
          category: EventCategory.basic,
          colorValue: EventCategory.basic.colorValue,
          createdAt: date,
          updatedAt: date,
        );
        final repository = _CompletionEventRepository([
          event('double-first'),
          event('double-other'),
          event('double-all-day', allDay: true),
        ]);
        addTearDown(() => unawaited(repository.close()));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(repository),
              eventCommandServiceProvider.overrideWithValue(
                EventCommandService(
                  repository: repository,
                  settingsRepository: settings,
                  notificationService: _FakeNotification(),
                  syncService: _FakeSync(),
                ),
              ),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyApp)),
        );
        container.read(visibleMonthProvider.notifier).state = DateTime(2026, 9);
        container.read(selectedDateProvider.notifier).state = date;
        await tester.pumpAndSettle();
        Finder action(String id, {Finder? within}) {
          final finder = find.byWidgetPredicate(
            (w) => w is EventCompletionAction && w.event.id == id,
          );
          return (within == null
                  ? finder
                  : find.descendant(of: within, matching: finder))
              .hitTestable()
              .first;
        }

        Future<void> toggle(Finder target, String id, bool expected) async {
          final kind =
              platform == TargetPlatform.macOS ||
                  platform == TargetPlatform.windows
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch;
          await tester.tap(target, kind: kind);
          await tester.pump(const Duration(milliseconds: 60));
          await tester.tap(target, kind: kind);
          await tester.pumpAndSettle();
          expect((await repository.findById(id))!.completed, expected);
          expect((await repository.findById('double-other'))!.completed, false);
          expect(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_EventDetailSheet',
            ),
            findsNothing,
          );
        }

        for (final (mode, layout) in [
          (CalendarViewMode.month, WeekDayLayoutMode.list),
          (CalendarViewMode.week, WeekDayLayoutMode.list),
          (CalendarViewMode.day, WeekDayLayoutMode.list),
          (CalendarViewMode.week, WeekDayLayoutMode.schedule),
          (CalendarViewMode.day, WeekDayLayoutMode.schedule),
        ]) {
          container.read(calendarViewModeProvider.notifier).state = mode;
          container.read(appSettingsProvider.notifier).state = container
              .read(appSettingsProvider)
              .copyWith(weekDayLayoutMode: layout);
          await tester.pumpAndSettle();
          final region = find.byKey(
            ValueKey('${mode.name}-pointer-navigation'),
          );
          await toggle(
            action('double-first', within: region),
            'double-first',
            true,
          );
          expect(
            find.byType(BottomSheet),
            findsNothing,
            reason: '$mode/$layout double tap must not open day details',
          );
          await toggle(
            action('double-first', within: region),
            'double-first',
            false,
          );
          if (layout == WeekDayLayoutMode.schedule) {
            await toggle(
              action('double-all-day', within: region),
              'double-all-day',
              true,
            );
            await toggle(
              action('double-all-day', within: region),
              'double-all-day',
              false,
            );
          }
        }
        container.read(calendarViewModeProvider.notifier).state =
            CalendarViewMode.month;
        await tester.pumpAndSettle();
        // One tap still selects the day; its list supports the same double tap.
        await tester.tap(
          action(
            'double-first',
            within: find.byKey(const ValueKey('month-pointer-navigation')),
          ),
        );
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();
        final dayEntry = find
            .byKey(const ValueKey('event-open-double-first'))
            .hitTestable()
            .first;
        await toggle(dayEntry, 'double-first', true);
        await toggle(dayEntry, 'double-first', false);
        if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(15, 150));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('검색').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '동일 제목');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final inline = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_InlineSearchPanel',
        );
        await toggle(
          action('double-first', within: inline),
          'double-first',
          true,
        );
        await toggle(
          action('double-first', within: inline),
          'double-first',
          false,
        );
        expect(find.byType(TextField), findsWidgets);
        await tester.tap(find.byTooltip('검색 닫기').first);
        await tester.pumpAndSettle();
        unawaited(
          Navigator.of(
            tester.element(find.byType(MonthCalendarPage)),
          ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage())),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '동일 제목');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await toggle(
          action('double-first', within: find.byType(SearchPage)),
          'double-first',
          true,
        );
        await toggle(
          action('double-first', within: find.byType(SearchPage)),
          'double-first',
          false,
        );
        expect(find.byType(SearchPage), findsOneWidget);
        Navigator.of(tester.element(find.byType(SearchPage))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('빠른 보기').first);
        await tester.pumpAndSettle();
        await toggle(
          find.byKey(const ValueKey('quick-todo-open-double-first')),
          'double-first',
          true,
        );
        await toggle(
          find.byKey(const ValueKey('quick-todo-open-double-first')),
          'double-first',
          false,
        );
        await tester.tap(
          find.byKey(const ValueKey('quick-todo-open-double-first')),
        );
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_EventDetailSheet',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'completion gesture preserves protected records and retries failed saves',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final date = DateTime(2026, 9, 7, 9);
      final event = CalendarEvent(
        id: 'protected-completion',
        title: '일정',
        startAt: date,
        endAt: date.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: date,
        updatedAt: date,
      );
      final repository = _CompletionEventRepository([event]);
      addTearDown(() => unawaited(repository.close()));
      final container = ProviderContainer(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repository),
          eventCommandServiceProvider.overrideWithValue(
            EventCommandService(
              repository: repository,
              settingsRepository: settings,
              notificationService: _FakeNotification(),
              syncService: _FakeSync(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      var opened = 0;
      Future<void> show(CalendarEvent displayed) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: EventCompletionAction(
                  event: displayed,
                  builder: (onDoubleTap) => GestureDetector(
                    onTap: () => opened++,
                    onDoubleTap: onDoubleTap,
                    child: const SizedBox(
                      width: 200,
                      height: 80,
                      child: Text('일정'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> doubleTap() async {
        await tester.tap(find.text('일정'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.text('일정'));
        await tester.pumpAndSettle();
      }

      for (final protected in [
        event.copyWith(readOnly: true),
        event.copyWith(holiday: true),
        event.copyWith(systemEvent: true),
      ]) {
        await show(protected);
        await doubleTap();
        expect((await repository.findById(event.id))!.completed, false);
      }
      expect(opened, 6);
      await repository.save(event.copyWith(readOnly: true));
      await show(event);
      await doubleTap();
      expect((await repository.findById(event.id))!.completed, false);
      await repository.save(event.copyWith(deletedAt: date));
      await doubleTap();
      expect((await repository.findById(event.id))!.completed, false);
      await repository.save(event.copyWith(completed: true));
      await doubleTap();
      expect(
        (await repository.findById(event.id))!.completed,
        false,
        reason: 'Toggle the current record, not stale search completion state',
      );
      repository.failNextSave = true;
      await doubleTap();
      expect((await repository.findById(event.id))!.completed, false);
      expect(find.byType(SnackBar), findsOneWidget);
      await doubleTap();
      expect((await repository.findById(event.id))!.completed, true);
      expect(opened, 6);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'completion gesture changes only the selected recurring occurrence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final date = DateTime(2026, 9, 7, 9);
      final source = CalendarEvent(
        id: 'series-completion',
        title: '반복 일정',
        startAt: date,
        endAt: date.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: date,
        updatedAt: date,
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final occurrence = source.copyWith(
        occurrenceId: 'series-completion@2026-09-08',
        startAt: date.add(const Duration(days: 1)),
        endAt: date.add(const Duration(days: 1, hours: 1)),
      );
      final repository = _CompletionEventRepository([source]);
      addTearDown(() => unawaited(repository.close()));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(repository),
            eventCommandServiceProvider.overrideWithValue(
              EventCommandService(
                repository: repository,
                settingsRepository: settings,
                notificationService: _FakeNotification(),
                syncService: _FakeSync(),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: EventCompletionAction(
                  event: occurrence,
                  builder: (onDoubleTap) => GestureDetector(
                    onDoubleTap: onDoubleTap,
                    child: const Text('반복 일정'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('반복 일정'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('반복 일정'));
      await tester.pumpAndSettle();
      final series = (await repository.findById(source.id))!;
      expect(series.completed, false);
      expect(series.recurrence.excludedDates, [DateTime(2026, 9, 8)]);
      final detached = (await repository.search(
        '반복 일정',
      )).singleWhere((e) => e.id != source.id);
      expect(detached.completed, true);
      expect(detached.startAt, occurrence.startAt);
      expect(detached.occurrenceId, isNull);
      expect(detached.recurrence.isRepeating, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('macOS schedule day view includes the selected-day sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'day',
      'weekDayLayoutMode': 'schedule',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('schedule-timeline')), findsOneWidget);
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(MonthCalendarPage))).width,
      greaterThanOrEqualTo(720),
    );
    expect(
      Theme.of(tester.element(find.byType(MonthCalendarPage))).platform,
      TargetPlatform.macOS,
    );
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final sidebarBefore = tester.getRect(
      find.byKey(const ValueKey('calendar-event-sidebar')),
    );
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.week;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getRect(find.byKey(const ValueKey('calendar-event-sidebar'))),
      sidebarBefore,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar')),
      findsOneWidget,
    );

    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.month;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getRect(find.byKey(const ValueKey('calendar-event-sidebar'))),
      sidebarBefore,
    );
    await tester.pumpAndSettle();

    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.day;
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.list);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('calendar-event-sidebar-transition')),
          )
          .width,
      inExclusiveRange(0, 360),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-event-sidebar')), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS event feedback follows the month and sidebar surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final now = DateTime.now();
    final event = CalendarEvent(
      id: 'adaptive-feedback-event',
      title: '표면에 맞는 일정',
      startAt: DateTime(now.year, now.month, 12, 9),
      endAt: DateTime(now.year, now.month, 12, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(
            _PendingSaveStreamingEventRepository([event]),
          ),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final calendarSurface = find.byKey(
      const ValueKey('calendar-content-repaint-boundary'),
    );
    final calendarEvent = find
        .descendant(
          of: calendarSurface,
          matching: find.byType(CalendarEventDraggable),
        )
        .first;
    final sidebar = find.byKey(const ValueKey('calendar-event-sidebar'));
    expect(calendarEvent, findsOneWidget);
    expect(sidebar, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(calendarEvent),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 360));
    final feedback = find.byKey(
      const ValueKey('calendar-event-drag-feedback-adaptive-feedback-event'),
    );
    expect(feedback, findsOneWidget);
    final monthFeedbackSize = tester.getSize(feedback);

    await gesture.moveTo(tester.getCenter(sidebar));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar-feedback-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar-feedback-time')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 85));
    final growingFeedbackSize = tester.getSize(feedback);
    final growingLetterboxSize = tester.getSize(
      find.byKey(const ValueKey('calendar-event-target-feedback-sidebar')),
    );
    expect(growingFeedbackSize.width, greaterThan(monthFeedbackSize.width));
    expect(growingFeedbackSize.width, lessThan(328));
    expect(growingFeedbackSize.height, greaterThan(monthFeedbackSize.height));
    expect(growingFeedbackSize.height, lessThan(76));
    expect(growingLetterboxSize, growingFeedbackSize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('calendar-event-target-feedback-sidebar')),
      findsOneWidget,
    );
    expect(tester.getSize(feedback), const Size(328, 76));
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar-feedback-time')),
      findsOneWidget,
    );

    await gesture.moveTo(tester.getCenter(calendarEvent));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 85));
    final shrinkingFeedbackSize = tester.getSize(feedback);
    final shrinkingLetterboxSize = tester.getSize(
      find.byKey(const ValueKey('calendar-event-compact-feedback')),
    );
    expect(shrinkingFeedbackSize.width, lessThan(328));
    expect(shrinkingFeedbackSize.width, greaterThan(monthFeedbackSize.width));
    expect(shrinkingFeedbackSize.height, lessThan(76));
    expect(shrinkingFeedbackSize.height, greaterThan(monthFeedbackSize.height));
    expect(shrinkingLetterboxSize, shrinkingFeedbackSize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('calendar-event-compact-feedback')),
      findsOneWidget,
    );
    expect(tester.getSize(feedback).height, 19);

    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(feedback, findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS uses its header toolbar without the iOS bottom bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('macos-calendar-toolbar')))
          .height,
      lessThan(64),
    );
    expect(find.byKey(const ValueKey('calendar-bottom-bar')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startDate = container.read(selectedDateProvider);
    final weekPageView = tester.widget<PageView>(find.byType(PageView));
    expect(weekPageView.physics, isA<PageScrollPhysics>());
    final weekController = weekPageView.controller!;

    await tester.tap(find.byTooltip('이전'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(weekController.page, greaterThan(11999));
    expect(weekController.page, lessThan(12000));

    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day - 7),
    );

    final weekNavigation = find.byKey(
      const ValueKey('week-pointer-navigation'),
    );
    final weekListener = tester.widget<Listener>(weekNavigation);
    weekListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        scrollDelta: Offset(30, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getTopLeft(weekNavigation) + const Offset(50, 12),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );

    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    await tester.trackpadFling(weekNavigation, const Offset(-240, 0), 1200);
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );
    await tester.trackpadFling(weekNavigation, const Offset(240, 0), 1200);
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
    await tester.pumpAndSettle();
    final scheduleWeekNavigation = find.byKey(
      const ValueKey('week-pointer-navigation'),
    );
    await tester.trackpadFling(
      scheduleWeekNavigation,
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );
    await tester.trackpadFling(
      scheduleWeekNavigation,
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.list);
    await tester.pumpAndSettle();

    final macToolbarBeforeTransition = tester.getRect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
    );
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.day;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getRect(find.byKey(const ValueKey('macos-calendar-toolbar'))),
      macToolbarBeforeTransition,
    );
    final viewTransitions = tester
        .widgetList<SlideTransition>(
          find.descendant(
            of: find.byKey(const ValueKey('calendar-content-switcher')),
            matching: find.byType(SlideTransition),
          ),
        )
        .where((transition) => transition.child?.key is ValueKey<int>)
        .toList();
    expect(
      viewTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(3),
          )
          .position
          .value
          .dx,
      greaterThan(0),
    );
    expect(
      viewTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(1),
          )
          .position
          .value
          .dx,
      lessThan(0),
    );
    await tester.pumpAndSettle();
    final dayListener = tester.widget<Listener>(
      find.byKey(const ValueKey('day-pointer-navigation')),
    );
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<PageScrollPhysics>(),
    );
    dayListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        scrollDelta: Offset(30, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 1),
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position:
            tester.getTopLeft(
              find.byKey(const ValueKey('day-pointer-navigation')),
            ) +
            const Offset(50, 12),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    final listDateAfterVerticalWheel = DateTime(
      startDate.year,
      startDate.month,
      startDate.day + 2,
    );
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    await tester.trackpadFling(
      find.byKey(const ValueKey('day-pointer-navigation')),
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 3),
    );
    await tester.trackpadFling(
      find.byKey(const ValueKey('day-pointer-navigation')),
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
    await tester.pumpAndSettle();
    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
    expect(
      container.read(appSettingsProvider).weekDayLayoutMode,
      WeekDayLayoutMode.schedule,
    );
    expect(find.byKey(const ValueKey('schedule-timeline')), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-event-sidebar')),
      findsOneWidget,
    );
    final scheduleDayNavigation = find.byKey(
      const ValueKey('day-pointer-navigation'),
    );
    await tester.trackpadFling(
      scheduleDayNavigation,
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 3),
    );
    await tester.trackpadFling(
      scheduleDayNavigation,
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(scheduleDayNavigation),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);

    final scheduleTimeScroll = find
        .byKey(const ValueKey('schedule-time-scroll'))
        .first;
    final scheduleScrollable = tester.widget<SingleChildScrollView>(
      scheduleTimeScroll,
    );
    final scheduleOffsetBeforeWheel = scheduleScrollable.controller!.offset;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(scheduleTimeScroll),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    expect(
      scheduleScrollable.controller!.offset,
      greaterThan(scheduleOffsetBeforeWheel),
    );
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.list);
    await tester.pumpAndSettle();

    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.month;
    await tester.pumpAndSettle();
    final monthBeforeScroll = container.read(visibleMonthProvider);
    expect(
      tester
          .widget<PageView>(
            find.descendant(
              of: find.byKey(const ValueKey('month-pointer-navigation')),
              matching: find.byType(PageView),
            ),
          )
          .physics,
      isA<PageScrollPhysics>(),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(
          find.byKey(const ValueKey('month-pointer-navigation')),
        ),
        scrollDelta: const Offset(0, 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 1),
    );

    for (var index = 0; index < 4; index++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: tester.getCenter(
            find.byKey(const ValueKey('month-pointer-navigation')),
          ),
          scrollDelta: const Offset(1, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 5),
    );
    await tester.pumpAndSettle();
    await tester.trackpadFling(
      find.byKey(const ValueKey('month-pointer-navigation')),
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 6),
    );
    await tester.trackpadFling(
      find.byKey(const ValueKey('month-pointer-navigation')),
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 5),
    );

    await tester.tap(find.byTooltip('빠른 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final quickAccessTransitions = tester
        .widgetList<SlideTransition>(
          find.descendant(
            of: find.byKey(const ValueKey('calendar-content-switcher')),
            matching: find.byType(SlideTransition),
          ),
        )
        .where((transition) => transition.child?.key is ValueKey<int>)
        .toList();
    expect(
      quickAccessTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(0),
          )
          .position
          .value
          .dx,
      lessThan(0),
    );
    expect(
      quickAccessTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(2),
          )
          .position
          .value
          .dx,
      greaterThan(0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quick-view-month-pages')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-bottom-bar')), findsNothing);

    final viewSwitch = find.byType(SegmentedButton<CalendarViewMode>);
    for (final entry in const [
      (CalendarViewMode.week, '주'),
      (CalendarViewMode.month, '월'),
      (CalendarViewMode.day, '일'),
    ]) {
      container.read(calendarViewModeProvider.notifier).state = entry.$1;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('빠른 보기'));
      await tester.pumpAndSettle();

      final segment = find.descendant(
        of: viewSwitch,
        matching: find.text(entry.$2),
      );
      await tester.tap(segment);
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(container.read(calendarViewModeProvider), entry.$1);
    }

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'macOS real mouse signals move every single tick without pixel-scroll competition',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        SharedPreferences.setMockInitialValues({
          'onboardingCompleted': true,
          'defaultCalendarView': 'month',
          'monthNavigationMode': 'horizontal',
        });
        final preferences = await SharedPreferences.getInstance();
        final repository = SettingsRepository(preferences: preferences);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repository),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyApp)),
        );
        for (final (mode, layout) in [
          (CalendarViewMode.month, WeekDayLayoutMode.list),
          (CalendarViewMode.week, WeekDayLayoutMode.list),
          (CalendarViewMode.day, WeekDayLayoutMode.list),
          (CalendarViewMode.week, WeekDayLayoutMode.schedule),
          (CalendarViewMode.day, WeekDayLayoutMode.schedule),
        ]) {
          container.read(appSettingsProvider.notifier).state = container
              .read(appSettingsProvider)
              .copyWith(
                weekDayLayoutMode: layout,
                monthNavigationMode: MonthNavigationMode.horizontal,
              );
          container.read(calendarViewModeProvider.notifier).state = mode;
          await tester.pumpAndSettle();
          final region = find.byKey(
            ValueKey('${mode.name}-pointer-navigation'),
          );
          final page = tester
              .widget<PageView>(
                find.descendant(of: region, matching: find.byType(PageView)),
              )
              .controller!;
          final start = page.page!;
          Future<void> wheel(double delta) => tester.sendEventToBinding(
            PointerScrollEvent(
              kind: PointerDeviceKind.mouse,
              position: tester.getCenter(region),
              scrollDelta: Offset(delta, 0),
            ),
          );
          await wheel(1);
          await tester.pump();
          expect(
            page.page,
            closeTo(start, .001),
            reason: '$mode/$layout must animate, not pixel-jump',
          );
          await tester.pumpAndSettle();
          expect(
            page.page,
            closeTo(start + 1, .001),
            reason: '$mode/$layout single horizontal tick',
          );
          for (var tick = 0; tick < 4; tick++) {
            await wheel(1);
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(
            page.page,
            closeTo(start + 5, .001),
            reason: '$mode/$layout rapid ticks',
          );
          await wheel(-1);
          await tester.pumpAndSettle();
          expect(
            page.page,
            closeTo(start + 4, .001),
            reason: '$mode/$layout reverse tick',
          );
          await tester.trackpadFling(region, const Offset(-240, 0), 1200);
          await tester.pumpAndSettle();
          expect(
            page.page,
            closeTo(start + 5, .001),
            reason: '$mode/$layout trackpad remains enabled',
          );
          if (layout == WeekDayLayoutMode.schedule) {
            final scroll = find
                .descendant(
                  of: region,
                  matching: find.byKey(const ValueKey('schedule-time-scroll')),
                )
                .hitTestable()
                .first;
            final controller = tester
                .widget<SingleChildScrollView>(scroll)
                .controller!;
            final before = controller.offset;
            await tester.sendEventToBinding(
              PointerScrollEvent(
                kind: PointerDeviceKind.mouse,
                position: tester.getCenter(scroll),
                scrollDelta: const Offset(0, 80),
              ),
            );
            await tester.pumpAndSettle();
            expect(controller.offset, greaterThan(before));
            expect(page.page, closeTo(start + 5, .001));
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'Windows mouse wheel bursts move week day and month one page at a time',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      final startDate = container.read(selectedDateProvider);

      Future<void> sendMouseWheel(Finder region, Offset delta) async {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: tester.getCenter(region),
            scrollDelta: delta,
          ),
        );
      }

      container.read(calendarViewModeProvider.notifier).state =
          CalendarViewMode.week;
      await tester.pumpAndSettle();
      final weekNavigation = find.byKey(
        const ValueKey('week-pointer-navigation'),
      );
      await sendMouseWheel(weekNavigation, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        container.read(selectedDateProvider),
        DateTime(startDate.year, startDate.month, startDate.day + 7),
      );
      await sendMouseWheel(weekNavigation, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), startDate);

      container.read(calendarViewModeProvider.notifier).state =
          CalendarViewMode.day;
      await tester.pumpAndSettle();
      final dayNavigation = find.byKey(
        const ValueKey('day-pointer-navigation'),
      );
      await sendMouseWheel(dayNavigation, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        container.read(selectedDateProvider),
        DateTime(startDate.year, startDate.month, startDate.day + 1),
      );
      await sendMouseWheel(dayNavigation, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), startDate);

      container.read(appSettingsProvider.notifier).state = container
          .read(appSettingsProvider)
          .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
      await tester.pumpAndSettle();
      final scheduleTimeScroll = find
          .byKey(const ValueKey('schedule-time-scroll'))
          .first;
      final scheduleScrollable = tester.widget<SingleChildScrollView>(
        scheduleTimeScroll,
      );
      final scheduleOffsetBeforeWheel = scheduleScrollable.controller!.offset;
      await sendMouseWheel(scheduleTimeScroll, const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), startDate);
      expect(
        scheduleScrollable.controller!.offset,
        greaterThan(scheduleOffsetBeforeWheel),
      );

      container.read(calendarViewModeProvider.notifier).state =
          CalendarViewMode.month;
      await tester.pumpAndSettle();
      final monthNavigation = find.byKey(
        const ValueKey('month-pointer-navigation'),
      );
      final startMonth = container.read(visibleMonthProvider);

      for (var index = 0; index < 4; index++) {
        await sendMouseWheel(monthNavigation, const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      expect(
        container.read(visibleMonthProvider),
        DateTime(startMonth.year, startMonth.month + 1),
      );

      final monthPageView = tester.widget<PageView>(
        find.descendant(of: monthNavigation, matching: find.byType(PageView)),
      );
      final pageBeforeHorizontalTilt = monthPageView.controller!.page!;
      for (var index = 0; index < 4; index++) {
        await sendMouseWheel(monthNavigation, const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(
        monthPageView.controller!.page,
        closeTo(pageBeforeHorizontalTilt, 0.001),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        monthPageView.controller!.page,
        greaterThan(pageBeforeHorizontalTilt),
      );
      expect(
        container.read(visibleMonthProvider),
        DateTime(startMonth.year, startMonth.month + 1),
        reason:
            'Windows must not rebuild the calendar provider tree while the '
            'page transition is still animating.',
      );
      await tester.pumpAndSettle();
      expect(
        container.read(visibleMonthProvider),
        DateTime(startMonth.year, startMonth.month + 2),
      );
      await sendMouseWheel(monthNavigation, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(
        container.read(visibleMonthProvider),
        DateTime(startMonth.year, startMonth.month + 1),
      );

      await sendMouseWheel(monthNavigation, const Offset(120, 0));
      await tester.trackpadFling(monthNavigation, const Offset(-240, 0), 1200);
      await tester.pumpAndSettle();
      expect(
        container.read(visibleMonthProvider),
        DateTime(startMonth.year, startMonth.month + 2),
      );

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('app lock covers Settings immediately after backgrounding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _MemorySecureStorage();
    final settingsRepository = SettingsRepository(
      preferences: preferences,
      secureStorage: secureStorage,
    );
    await settingsRepository.saveAppLockPin('13579');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    expect(find.text('잠금 상태입니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final digit in ['1', '3', '5', '7', '9']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final digit in ['1', '3', '5', '7', '9']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no-PIN app lock obscures only while the app is inactive', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
      'appLockMethod': AppLockMethod.noPin.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.widgetWithText(TextButton, '1'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    expect(find.text('잠금 상태에서는 화면을 볼 수 없습니다.'), findsOneWidget);
    expect(find.text('잠금 해제'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.byTooltip('설정'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS PIN lock accepts keyboard digits after unlock button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
      'appLockMethod': AppLockMethod.appPin.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(
      preferences: preferences,
      secureStorage: _MemorySecureStorage(),
    );
    await settingsRepository.saveAppLockPin('13579');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('잠금 상태입니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit9,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      if (key != LogicalKeyboardKey.digit9) {
        final index = switch (key) {
          LogicalKeyboardKey.digit1 => 0,
          LogicalKeyboardKey.digit3 => 1,
          LogicalKeyboardKey.digit5 => 2,
          _ => 3,
        };
        expect(find.byKey(ValueKey('pin-unlock-dot-$index')), findsOneWidget);
      }
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.byTooltip('설정'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'macOS biometric cancellation returns to PIN without requesting again',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('daily/apple_authentication');
      final authenticationResult = Completer<bool>();
      var authenticationRequests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authenticateBiometricsOrCompanion') {
              authenticationRequests += 1;
              return authenticationResult.future;
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'appLockEnabled': true,
        'appLockMethod': AppLockMethod.appPin.name,
        'appLockBiometricsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: _MemorySecureStorage(),
      );
      await settingsRepository.saveAppLockPin('13579');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(account: null),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pump();
      expect(authenticationRequests, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      authenticationResult.complete(false);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(authenticationRequests, 1);
      expect(find.text('PIN 입력'), findsOneWidget);
      expect(find.byKey(const ValueKey('show-pin-entry-button')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily restores saved Google Drive session and starts sync without prompt',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        restoredAccount: const GoogleDriveAccount(
          email: 'restored@example.com',
        ),
      );
      final syncService = _FakeSync();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(syncService),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(authService.restorePreviousSignInCalls, 1);
      expect(authService.authorizationHeadersCalls, 1);
      expect(authService.signInCalls, 0);
      expect(syncService.startCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily retries a temporary Google Drive restore failure without prompting',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'restored@example.com'),
      );
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        restoredAccount: const GoogleDriveAccount(
          email: 'restored@example.com',
        ),
        restoreFailuresRemaining: 1,
      );
      final syncService = _FakeSync();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(syncService),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(authService.restorePreviousSignInCalls, 2);
      expect(authService.authorizationHeadersCalls, 1);
      expect(authService.signInCalls, 0);
      expect(syncService.startCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('settings shows restored Google Drive account after restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(
      account: null,
      restoredAccount: const GoogleDriveAccount(email: 'restored@example.com'),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(authService.currentAccount?.email, 'restored@example.com');
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'restored@example.com' ||
                widget.semanticsLabel == 'restored@example.com'),
      ),
      findsOneWidget,
    );
    expect(authService.signInCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings displays matching app version and build label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'com.littlebit0.daily',
      version: '2.7.1',
      buildNumber: '1',
      buildSignature: '',
    );
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final aboutNavigation = find.byKey(
      const ValueKey('about-settings-navigation'),
    );
    await tester.dragUntilVisible(
      aboutNavigation,
      find.byType(ListView),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(aboutNavigation);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == '버전 2.7.1 (2.7.1) · 더블 클릭하여 Github 확인하기' ||
                widget.semanticsLabel ==
                    '버전 2.7.1 (2.7.1) · 더블 클릭하여 Github 확인하기'),
      ),
      findsOneWidget,
    );
    final versionTile = find.byKey(const ValueKey('daily-version-github-link'));
    expect(versionTile, findsOneWidget);
    expect(tester.widget<GestureDetector>(versionTile).onDoubleTap, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Windows settings controls animate while persistence is still pending',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = _DelayedSettingsRepository(
        preferences: preferences,
      );
      final authService = _FakeGoogleDriveAuthService(account: null);
      final notificationService = _FakeNotification();
      final eventRepository = _FakeEventRepository();
      final driveSyncService = _FakeGoogleDriveSyncService(
        authService: authService,
        eventRepository: eventRepository,
        notificationService: notificationService,
        settingsRepository: settingsRepository,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
            googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('appearance-settings-navigation')),
      );
      await tester.pumpAndSettle();

      final settingsContext = tester.element(find.byType(SettingsPage));
      final container = ProviderScope.containerOf(settingsContext);
      final themeControl = find.byKey(const ValueKey('app-theme-mode-slider'));
      final indicator = find.descendant(
        of: themeControl,
        matching: find.byKey(
          const ValueKey('settings-capsule-selection-indicator'),
        ),
      );
      final renderedIndicator = find.descendant(
        of: indicator,
        matching: find.byType(Align),
      );
      final indicatorPressScale = find.descendant(
        of: indicator,
        matching: find.byKey(
          const ValueKey('settings-capsule-selection-press-scale'),
        ),
      );
      final renderedIndicatorPressScale = find.descendant(
        of: indicatorPressScale,
        matching: find.byType(ScaleTransition),
      );
      final darkThemeOption = find.descendant(
        of: themeControl,
        matching: find.byKey(const ValueKey('settings-capsule-option-2')),
      );
      expect(indicator, findsOneWidget);
      expect(renderedIndicator, findsOneWidget);
      expect(indicatorPressScale, findsOneWidget);
      expect(renderedIndicatorPressScale, findsOneWidget);
      expect(darkThemeOption, findsOneWidget);
      expect(
        find.descendant(of: themeControl, matching: find.byType(InkWell)),
        findsNWidgets(3),
      );
      final darkThemeSemantics = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: darkThemeOption,
              matching: find.byType(Semantics),
            ),
          )
          .singleWhere(
            (widget) => widget.properties.inMutuallyExclusiveGroup == true,
          );
      expect(darkThemeSemantics.properties.selected, isFalse);
      expect(darkThemeSemantics.properties.button, isTrue);
      expect(
        tester
            .widget<Align>(renderedIndicator)
            .alignment
            .resolve(TextDirection.ltr)
            .x,
        -1,
      );

      final themeRect = tester.getRect(themeControl);
      final themeGesture = await tester.startGesture(
        Offset(themeRect.right - themeRect.width / 6, themeRect.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final pressedScale16 = tester
          .widget<ScaleTransition>(renderedIndicatorPressScale)
          .scale
          .value;
      final pressedX16 = tester
          .widget<Align>(renderedIndicator)
          .alignment
          .resolve(TextDirection.ltr)
          .x;
      expect(pressedScale16, greaterThan(0.93));
      expect(pressedScale16, lessThan(1));
      expect(pressedX16, greaterThan(-1));
      expect(pressedX16, lessThan(1));

      await tester.pump(const Duration(milliseconds: 34));
      final pressedScale50 = tester
          .widget<ScaleTransition>(renderedIndicatorPressScale)
          .scale
          .value;
      final pressedX50 = tester
          .widget<Align>(renderedIndicator)
          .alignment
          .resolve(TextDirection.ltr)
          .x;
      expect(pressedScale50, greaterThanOrEqualTo(0.93));
      expect(pressedScale50, lessThan(pressedScale16));
      expect(pressedX50, greaterThan(pressedX16));
      expect(pressedX50, lessThan(1));

      await themeGesture.up();
      await tester.pump();

      expect(settingsRepository.saveCalls, 0);
      expect(
        container.read(appSettingsProvider).themeMode,
        AppThemeMode.system,
      );
      await tester.pump(const Duration(milliseconds: 50));
      final midAnimationX = tester
          .widget<Align>(renderedIndicator)
          .alignment
          .resolve(TextDirection.ltr)
          .x;
      final releasedScale50 = tester
          .widget<ScaleTransition>(renderedIndicatorPressScale)
          .scale
          .value;
      expect(midAnimationX, greaterThan(pressedX50));
      expect(midAnimationX, lessThan(1));
      expect(releasedScale50, greaterThan(pressedScale50));

      await tester.pump(const Duration(milliseconds: 189));
      expect(settingsRepository.saveCalls, 0);
      expect(
        tester
            .widget<Align>(renderedIndicator)
            .alignment
            .resolve(TextDirection.ltr)
            .x,
        1,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(settingsRepository.saveCalls, 1);
      expect(settingsRepository.hasPendingSave, isTrue);

      settingsRepository.releasePendingSave();
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.dark);
      final selectedThemeSemantics = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: darkThemeOption,
              matching: find.byType(Semantics),
            ),
          )
          .singleWhere(
            (widget) => widget.properties.inMutuallyExclusiveGroup == true,
          );
      expect(selectedThemeSemantics.properties.selected, isTrue);

      final cancelledThemeGesture = await tester.startGesture(
        tester.getCenter(darkThemeOption),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final cancelledThemePressedScale = tester
          .widget<ScaleTransition>(renderedIndicatorPressScale)
          .scale
          .value;
      expect(cancelledThemePressedScale, lessThan(1));
      await cancelledThemeGesture.moveBy(const Offset(0, kTouchSlop + 8));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(indicatorPressScale).scale, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<ScaleTransition>(renderedIndicatorPressScale).scale.value,
        greaterThan(cancelledThemePressedScale),
      );
      await cancelledThemeGesture.up();
      await tester.pumpAndSettle();
      expect(settingsRepository.saveCalls, 1);

      final secondaryThemeGesture = await tester.startGesture(
        tester.getCenter(darkThemeOption),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<ScaleTransition>(renderedIndicatorPressScale).scale.value,
        1,
      );
      await secondaryThemeGesture.up();
      await tester.pumpAndSettle();
      expect(settingsRepository.saveCalls, 1);

      settingsRepository.blockNextSave();
      final dragThemeRect = tester.getRect(themeControl);
      final horizontalThemeGesture = await tester.startGesture(
        Offset(
          dragThemeRect.right - dragThemeRect.width / 6,
          dragThemeRect.center.dy,
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await horizontalThemeGesture.moveTo(dragThemeRect.center);
      await tester.pump();
      await horizontalThemeGesture.up();
      await tester.pump();
      expect(settingsRepository.saveCalls, 1);
      await tester.pump(const Duration(milliseconds: 239));
      expect(settingsRepository.saveCalls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(settingsRepository.saveCalls, 2);
      expect(settingsRepository.hasPendingSave, isTrue);
      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.dark);
      settingsRepository.releasePendingSave();
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.light);

      final lunarToggle = find.byKey(const ValueKey('show-lunar-dates-toggle'));
      final lunarPressScale = find.ancestor(
        of: lunarToggle,
        matching: find.byKey(const ValueKey('settings-switch-press-scale')),
      );
      final renderedLunarPressScale = find.descendant(
        of: lunarPressScale,
        matching: find.byType(ScaleTransition),
      );
      expect(lunarPressScale, findsOneWidget);
      expect(renderedLunarPressScale, findsOneWidget);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isTrue);
      final cancelledLunarGesture = await tester.startGesture(
        tester.getCenter(lunarToggle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final cancelledLunarPressedScale = tester
          .widget<ScaleTransition>(renderedLunarPressScale)
          .scale
          .value;
      expect(cancelledLunarPressedScale, lessThan(1));
      await cancelledLunarGesture.moveBy(const Offset(0, kTouchSlop + 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<ScaleTransition>(renderedLunarPressScale).scale.value,
        greaterThan(cancelledLunarPressedScale),
      );
      await cancelledLunarGesture.up();
      await tester.pumpAndSettle();
      expect(settingsRepository.saveCalls, 2);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isTrue);

      settingsRepository.blockNextSave();
      final lunarGesture = await tester.startGesture(
        tester.getCenter(lunarToggle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final lunarPressedScale16 = tester
          .widget<ScaleTransition>(renderedLunarPressScale)
          .scale
          .value;
      expect(lunarPressedScale16, greaterThan(0.985));
      expect(lunarPressedScale16, lessThan(1));

      await tester.pump(const Duration(milliseconds: 34));
      final lunarPressedScale50 = tester
          .widget<ScaleTransition>(renderedLunarPressScale)
          .scale
          .value;
      expect(lunarPressedScale50, greaterThanOrEqualTo(0.985));
      expect(lunarPressedScale50, lessThan(lunarPressedScale16));

      await lunarGesture.up();
      await tester.pump();

      expect(settingsRepository.saveCalls, 2);
      expect(container.read(appSettingsProvider).showLunarDates, isTrue);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      final lunarReleasedScale50 = tester
          .widget<ScaleTransition>(renderedLunarPressScale)
          .scale
          .value;
      expect(lunarReleasedScale50, greaterThan(lunarPressedScale50));
      await tester.pump(const Duration(milliseconds: 189));
      expect(settingsRepository.saveCalls, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(settingsRepository.saveCalls, 3);
      expect(settingsRepository.hasPendingSave, isTrue);

      final weekStartControl = find.byKey(const ValueKey('week-start-toggle'));
      final weekStartRect = tester.getRect(weekStartControl);
      Object? saveError;
      await runZonedGuarded<Future<void>>(
        () => tester.tapAt(
          Offset(
            weekStartRect.right - weekStartRect.width / 4,
            weekStartRect.center.dy,
          ),
        ),
        (error, _) => saveError = error,
      );
      await tester.pump();
      expect(settingsRepository.saveCalls, 3);

      settingsRepository.releasePendingSave();
      settingsRepository.blockNextSave();
      settingsRepository.failNextSave();
      await tester.pump(const Duration(milliseconds: 240));
      expect(settingsRepository.saveCalls, 4);
      expect(container.read(appSettingsProvider).showLunarDates, isTrue);
      expect(container.read(appSettingsProvider).weekStartsOnMonday, isFalse);
      expect(settingsRepository.hasPendingSave, isTrue);

      settingsRepository.releasePendingSave();
      await tester.pump();
      expect(saveError, isA<StateError>());
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).weekStartsOnMonday, isFalse);
      expect(settingsRepository.load().weekStartsOnMonday, isFalse);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isFalse);
      final disposeGesture = await tester.startGesture(
        tester.getCenter(lunarToggle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeGesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Windows lunar toggle persists the latest value after two rapid saves',
    (tester) async {
      final (container, settingsRepository) =
          await _pumpWindowsAppearanceSettings(tester);
      final lunarToggle = find.byKey(const ValueKey('show-lunar-dates-toggle'));

      expect(tester.widget<SwitchListTile>(lunarToggle).value, isTrue);
      await tester.tap(lunarToggle);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isFalse);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(lunarToggle);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isTrue);

      await tester.pump(const Duration(milliseconds: 139));
      expect(settingsRepository.saveCalls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(settingsRepository.saveCalls, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(settingsRepository.saveCalls, 1);

      settingsRepository.releasePendingSave();
      await tester.pumpAndSettle();

      expect(settingsRepository.saveCalls, 2);
      expect(settingsRepository.load().showLunarDates, isTrue);
      expect(container.read(appSettingsProvider).showLunarDates, isTrue);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Windows delayed save publishes settings merged with an external change',
    (tester) async {
      final (container, settingsRepository) =
          await _pumpWindowsAppearanceSettings(tester);
      final lunarToggle = find.byKey(const ValueKey('show-lunar-dates-toggle'));

      await tester.tap(lunarToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(settingsRepository.saveCalls, 1);

      final externalBase = settingsRepository.load();
      await settingsRepository.saveWithoutDelay(
        externalBase.copyWith(weekStartsOnMonday: true),
        markSyncPending: false,
        changedFrom: externalBase,
      );
      expect(settingsRepository.load().showLunarDates, isTrue);
      expect(settingsRepository.load().weekStartsOnMonday, isTrue);

      settingsRepository.releasePendingSave();
      await tester.pumpAndSettle();

      final persisted = settingsRepository.load();
      final published = container.read(appSettingsProvider);
      expect(persisted.showLunarDates, isFalse);
      expect(persisted.weekStartsOnMonday, isTrue);
      expect(published.showLunarDates, isFalse);
      expect(published.weekStartsOnMonday, isTrue);
      expect(tester.widget<SwitchListTile>(lunarToggle).value, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('settings manages the four start screens in one control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appStartView': AppStartView.quickView.name,
      'defaultCalendarView': CalendarViewMode.day.name,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final authService = _FakeGoogleDriveAuthService();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('appearance-settings-navigation')),
    );
    await tester.pumpAndSettle();

    final settingsList = find.byType(ListView).last;
    final monthNavigationControl = find.byKey(
      const ValueKey('month-navigation-mode-slider'),
    );
    await tester.dragUntilVisible(
      monthNavigationControl,
      settingsList,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(monthNavigationControl).dy,
      greaterThan(tester.getBottomLeft(find.text('월간 이동 방식')).dy),
    );

    final startControl = find.byKey(const ValueKey('app-start-view-slider'));
    await tester.dragUntilVisible(
      startControl,
      settingsList,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(startControl, findsOneWidget);
    expect(tester.getSize(startControl).width, 277);
    final startTitle = find.text('첫 화면');
    const startDescriptionText = '앱을 열었을 때 먼저 보여줄 화면';
    final startDescription = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.semanticsLabel == startDescriptionText,
    );
    expect(startTitle, findsOneWidget);
    expect(startDescription, findsOneWidget);
    expect(tester.getSize(startTitle).width, greaterThan(40));
    expect(tester.getSize(startDescription).width, greaterThan(180));
    expect(
      tester.getTopLeft(startControl).dy,
      greaterThan(tester.getBottomLeft(startDescription).dy),
    );
    expect(
      find.byKey(const ValueKey('default-calendar-view-slider')),
      findsNothing,
    );

    var rect = tester.getRect(startControl);
    await tester.tapAt(Offset(rect.left + rect.width * 0.625, rect.center.dy));
    await tester.pumpAndSettle();

    var stored = settingsRepository.load();
    expect(stored.appStartView, AppStartView.calendar);
    expect(stored.defaultCalendarView, CalendarViewMode.month);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage).last),
    );
    expect(container.read(calendarViewModeProvider), CalendarViewMode.month);

    rect = tester.getRect(startControl);
    await tester.tapAt(Offset(rect.left + rect.width * 0.125, rect.center.dy));
    await tester.pumpAndSettle();

    stored = settingsRepository.load();
    expect(stored.appStartView, AppStartView.quickView);
    expect(stored.defaultCalendarView, CalendarViewMode.month);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'Android compact start screen control stacks below readable copy',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final notificationService = _FakeNotification();
      final eventRepository = _FakeEventRepository();
      final authService = _FakeGoogleDriveAuthService();
      final driveSyncService = _FakeGoogleDriveSyncService(
        authService: authService,
        eventRepository: eventRepository,
        notificationService: notificationService,
        settingsRepository: settingsRepository,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
            googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('appearance-settings-navigation')),
      );
      await tester.pumpAndSettle();

      final settingsList = find.byType(ListView).last;
      final startControl = find.byKey(const ValueKey('app-start-view-slider'));
      await tester.dragUntilVisible(
        startControl,
        settingsList,
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();

      final startTitle = find.text('첫 화면');
      const startDescriptionText = '앱을 열었을 때 먼저 보여줄 화면';
      final startDescription = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.semanticsLabel == startDescriptionText ||
                widget.data == startDescriptionText),
      );
      expect(tester.getSize(startTitle).width, greaterThan(40));
      expect(tester.getSize(startDescription).width, greaterThan(180));
      expect(tester.getSize(startControl).width, greaterThan(260));
      expect(
        tester.getTopLeft(startControl).dy,
        greaterThan(tester.getBottomLeft(startDescription).dy),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('settings keeps controls inline at macOS width', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final authService = _FakeGoogleDriveAuthService();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('appearance-settings-navigation')),
    );
    await tester.pumpAndSettle();
    final startControl = find.byKey(const ValueKey('app-start-view-slider'));
    await tester.dragUntilVisible(
      startControl,
      find.byType(ListView).last,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    final controlRect = tester.getRect(startControl);
    final titleRect = tester.getRect(find.text('첫 화면'));
    expect(controlRect.width, 248);
    expect(controlRect.left, greaterThan(titleRect.right));
    expect((controlRect.center.dy - titleRect.center.dy).abs(), lessThan(16));

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings rows keep icons and layout at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    void expectVisibleRowsHaveIcons() {
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.leading, isNotNull);
      }
      for (final tile in tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      )) {
        expect(tile.secondary, isNotNull);
      }
      expect(tester.takeException(), isNull);
    }

    expectVisibleRowsHaveIcons();
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('siri-shortcut-setup')), findsOneWidget);
    const siriDescription = '시그널 단축어를 추가하고 Siri에서 Daily 명령을 사용합니다.';
    final responsiveDescription = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == siriDescription,
    );
    expect(responsiveDescription, findsOneWidget);
    final renderedDescription = tester
        .widget<Text>(responsiveDescription)
        .data!;
    expect(renderedDescription, contains('\n'));
    expect(
      renderedDescription.replaceAll('\u2060', '').replaceAll('\n', ' '),
      siriDescription,
    );

    final mainList = find.byType(ListView);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('about-settings-navigation')),
      mainList,
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-settings-navigation')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    expectVisibleRowsHaveIcons();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('notification-settings-navigation')),
      mainList,
      const Offset(0, 560),
    );
    final notificationSettingsTile = find.byKey(
      const ValueKey('notification-settings-navigation'),
    );
    await tester.ensureVisible(notificationSettingsTile);
    await tester.pumpAndSettle();
    await tester.tap(notificationSettingsTile);
    await tester.pumpAndSettle();
    expect(find.text('알림 테스트'), findsNothing);
    expect(
      find.byKey(const ValueKey('system-notification-settings')),
      findsOneWidget,
    );
    expect(find.text('기본 일정 알림'), findsOneWidget);
    expectVisibleRowsHaveIcons();
    final notificationList = find.byType(ListView);
    for (var index = 0; index < 4; index++) {
      await tester.drag(notificationList, const Offset(0, -520));
      await tester.pumpAndSettle();
      expectVisibleRowsHaveIcons();
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    final accountSettingsTile = find.byKey(
      const ValueKey('account-settings-navigation'),
    );
    await Scrollable.ensureVisible(
      tester.element(accountSettingsTile),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
    await tester.tap(accountSettingsTile);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expectVisibleRowsHaveIcons();

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('privacy settings opt in and delete queued analytics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final analytics = _FakeProductAnalytics();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          productAnalyticsProvider.overrideWithValue(analytics),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('privacy-settings-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anonymous-analytics-toggle')));
    await tester.pump();
    expect(analytics.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('delete-analytics-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(analytics.deleteCalls, 1);
    expect(find.text('전송 대기 분석 데이터를 삭제했습니다.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PIN setup reveals dots only as digits are entered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('privacy-settings-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '앱 잠금'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PIN 잠금').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pin-entry-dots')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-entry-dot-0')), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '1'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pin-entry-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-entry-dot-1')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('category handle reorders both directions on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final categories = [
        EventCategory.basic,
        EventCategory.holiday,
        EventCategory.custom(label: 'Study', colorValue: 0xff10b981),
        EventCategory.custom(label: 'Exercise', colorValue: 0xffef4444),
      ];
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          categories: categories,
          hiddenCategoryIds: [categories[2].id],
          calendarEventSortPriority: CalendarEventSortPriority.category,
        ),
      );
      final authService = _FakeGoogleDriveAuthService(account: null);
      final notificationService = _FakeNotification();
      final eventRepository = _FakeEventRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
            googleDriveSyncServiceProvider.overrideWithValue(
              _FakeGoogleDriveSyncService(
                authService: authService,
                eventRepository: eventRepository,
                notificationService: notificationService,
                settingsRepository: settingsRepository,
              ),
            ),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('category-settings-navigation')),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage).last),
      );
      final pointerKind =
          platform == TargetPlatform.iOS || platform == TargetPlatform.android
          ? PointerDeviceKind.touch
          : PointerDeviceKind.mouse;

      Future<void> dragCategory(int from, int to) async {
        final handles = find.byIcon(Icons.drag_indicator);
        final start = tester.getCenter(handles.at(from)) - const Offset(18, 0);
        final target = tester.getCenter(handles.at(to));
        final gesture = await tester.startGesture(start, kind: pointerKind);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        final end = target + Offset(0, from < to ? 2 : -2);
        for (var step = 1; step <= 10; step++) {
          await gesture.moveTo(Offset.lerp(start, end, step / 10)!);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      void expectOrder(List<EventCategory> expected) {
        final ids = expected.map((category) => category.id).toList();
        expect(
          container.read(appSettingsProvider).categories.map((item) => item.id),
          ids,
        );
        expect(
          settingsRepository.load().categories.map((item) => item.id),
          ids,
        );
        expect(settingsRepository.load().hiddenCategoryIds, [categories[2].id]);
        expect(
          settingsRepository.load().calendarEventSortPriority,
          CalendarEventSortPriority.category,
        );
        expect(
          settingsRepository.load().categories.map((item) => item.toJson()),
          expected.map((item) => item.toJson()),
        );
        final positions = expected.map(
          (category) => tester
              .getTopLeft(find.byKey(ValueKey('category-${category.id}')))
              .dy,
        );
        expect(positions, orderedEquals(positions.toList()..sort()));
      }

      await dragCategory(3, 0);
      expectOrder([categories[3], ...categories.take(3)]);
      await dragCategory(0, 1);
      expectOrder([categories[0], categories[3], categories[1], categories[2]]);
      await dragCategory(1, 3);
      expectOrder(categories);
      await tester.tap(find.byIcon(Icons.drag_indicator).first);
      await tester.pumpAndSettle();
      expectOrder(categories);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('category-settings-navigation')),
      );
      await tester.pumpAndSettle();
      expectOrder(categories);

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('category RGB picker renders above the category editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('category-settings-navigation')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-reorder-list')), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('event-sort-priority-slider')),
      findsOneWidget,
    );
    expect(find.byTooltip('길게 눌러 순서 변경'), findsNWidgets(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('category-reorder-list')),
    );
    // onReorderItem reports the destination after removing the source item.
    reorderable.onReorderItem!(0, 1);
    expect(
      container
          .read(appSettingsProvider)
          .categories
          .map((category) => category.id),
      [EventCategory.holiday.id, EventCategory.basic.id],
    );
    await tester.pumpAndSettle();
    expect(
      settingsRepository.load().categories.map((category) => category.id),
      [EventCategory.holiday.id, EventCategory.basic.id],
    );

    await tester.tap(find.text('분류 우선'));
    await tester.pumpAndSettle();
    expect(
      settingsRepository.load().calendarEventSortPriority,
      CalendarEventSortPriority.category,
    );

    await tester.tap(find.byTooltip('분류 수정').first);
    await tester.pumpAndSettle();

    expect(find.text('분류 수정'), findsOneWidget);
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .every(
            (chip) => chip.shape is CircleBorder && chip.showCheckmark == false,
          ),
      isTrue,
    );
    for (final chip in find.byType(ChoiceChip).evaluate()) {
      final size = tester.getSize(
        find.byElementPredicate((element) => element == chip),
      );
      expect(size.width, size.height);
    }
    await tester.tap(find.byTooltip('사용자 지정 색상'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('사용자 지정 색상'), findsOneWidget);
    expect(find.byKey(const Key('category-color-palette')), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('linked Google metadata requires a valid auth session to sync', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'linked@example.com'),
    );
    final authService = _FakeGoogleDriveAuthService(
      account: const GoogleDriveAccount(email: 'linked@example.com'),
      authorizationAvailable: false,
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'linked@example.com' ||
                widget.semanticsLabel == 'linked@example.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('Google 다시 연결'), findsOneWidget);
    expect(find.text('지금 동기화'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'Google Drive backup and restore are separate actions in one row on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
          FlutterSecureStorage.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final settingsRepository = SettingsRepository(
            preferences: preferences,
          );
          await settingsRepository.saveGoogleAccount(
            const GoogleAccount(email: 'linked@example.com'),
          );
          final authService = _FakeGoogleDriveAuthService(
            account: const GoogleDriveAccount(email: 'linked@example.com'),
          );
          final notificationService = _FakeNotification();
          final eventRepository = _FakeEventRepository();
          final driveSyncService = _FakeGoogleDriveSyncService(
            authService: authService,
            eventRepository: eventRepository,
            notificationService: notificationService,
            settingsRepository: settingsRepository,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                settingsRepositoryProvider.overrideWithValue(
                  settingsRepository,
                ),
                notificationServiceProvider.overrideWithValue(
                  notificationService,
                ),
                eventRepositoryProvider.overrideWithValue(eventRepository),
                googleDriveAuthServiceProvider.overrideWithValue(authService),
                googleDriveSyncServiceProvider.overrideWithValue(
                  driveSyncService,
                ),
                syncServiceProvider.overrideWithValue(_FakeSync()),
              ],
              child: const MaterialApp(home: SettingsPage()),
            ),
          );
          await tester.pumpAndSettle();
          await _openAccountSettings(tester);
          await tester.drag(find.byType(ListView), const Offset(0, -2200));
          await tester.pumpAndSettle();

          final actionRow = find.byKey(
            const ValueKey('google-drive-backup-restore-row'),
          );
          expect(actionRow, findsOneWidget);
          expect(
            find.descendant(of: actionRow, matching: find.text('복원')),
            findsOneWidget,
          );

          await tester.tap(find.text('백업'));
          await tester.pumpAndSettle();
          expect(driveSyncService.syncPendingChangesNowCalls, 1);
          expect(driveSyncService.restoreNowCalls, 0);

          await tester.tap(find.text('복원'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, '복원'));
          await tester.pumpAndSettle();
          expect(driveSyncService.restoreNowCalls, 1);
          expect(driveSyncService.backupPrompts, [
            platform != TargetPlatform.android,
          ]);
          expect(driveSyncService.restorePrompts, [
            platform != TargetPlatform.android,
          ]);

          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('swiping the monthly calendar moves to the next month', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startMonth = container.read(visibleMonthProvider);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(visibleMonthProvider),
      DateTime(startMonth.year, startMonth.month + 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'vertical month drag skips blanks and continues into the next month',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 754);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'month',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        8,
        31,
      );
      container.read(visibleMonthProvider.notifier).state = DateTime(2026, 8);
      await tester.pumpAndSettle();

      final list = find.byKey(const ValueKey('continuous-month-scroll'));
      await tester.drag(list, const Offset(0, -360));
      await tester.pumpAndSettle();

      final august = find.byKey(const ValueKey('continuous-month-2026-8'));
      final september = find.byKey(const ValueKey('continuous-month-2026-9'));
      final august31 = find.descendant(
        of: august,
        matching: find.byKey(const ValueKey('day-cell-2026-8-31')),
      );
      final september2 = find.descendant(
        of: september,
        matching: find.byKey(const ValueKey('day-cell-2026-9-2')),
      );
      expect(august31, findsOneWidget);
      expect(september2, findsOneWidget);

      final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await drag.down(tester.getCenter(august31));
      await drag.moveTo(tester.getCenter(september2));
      await tester.pump();
      final rangedGrids = tester
          .widgetList<CalendarMonthGrid>(find.byType(CalendarMonthGrid))
          .where(
            (grid) =>
                grid.externalRangeStart != null &&
                grid.externalRangeEnd != null,
          )
          .toList();
      expect(rangedGrids, isNotEmpty);
      expect(rangedGrids.first.externalRangeStart, DateTime(2026, 8, 31));
      expect(rangedGrids.first.externalRangeEnd, DateTime(2026, 9, 2));
      expect(
        find.byKey(const ValueKey('selected-range-2026-8-30')),
        findsWidgets,
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorDialog), findsOneWidget);
      final editor = tester.widget<EventEditorDialog>(
        find.byType(EventEditorDialog),
      );
      expect(editor.initialDate, DateTime(2026, 8, 31));
      expect(editor.initialEndDate, DateTime(2026, 9, 2));

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('vertical month position stays fixed while search opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 754);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.save(
      settingsRepository.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    ListView monthList() => tester.widget<ListView>(
      find.byKey(const ValueKey('continuous-month-scroll')),
    );

    final initialList = monthList();
    initialList.controller!.jumpTo(
      initialList.controller!.offset + initialList.itemExtent! * 2.25,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final monthBeforeSearch = container.read(visibleMonthProvider);
    final settledList = monthList();
    final itemExtentBefore = settledList.itemExtent!;
    final logicalOffsetBefore =
        settledList.controller!.offset / settledList.itemExtent!;

    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();

    final resizedList = monthList();
    final logicalOffsetAfter =
        resizedList.controller!.offset / resizedList.itemExtent!;
    expect(container.read(visibleMonthProvider), monthBeforeSearch);
    expect(resizedList.itemExtent, itemExtentBefore);
    expect(logicalOffsetAfter, closeTo(logicalOffsetBefore, 0.01));

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('day schedule sheet expands and keeps its list draggable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final month = container.read(visibleMonthProvider);
    final dayCell = find
        .byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('day-cell-${month.year}-${month.month}-');
        })
        .hitTestable()
        .first;
    expect(dayCell, findsOneWidget);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.68);
    expect(sheet.minChildSize, 0.4);
    expect(sheet.maxChildSize, 0.96);
    expect(sheet.snap, isTrue);
    expect(sheet.shouldCloseOnMinExtent, isFalse);
    expect(
      tester
          .widget<EventDetailsPanel>(find.byType(EventDetailsPanel))
          .scrollController,
      isNotNull,
    );

    final selectedDate = container.read(selectedDateProvider);
    final targetDay = selectedDate.day == 1 ? 2 : 1;
    final targetCell = find.byKey(
      ValueKey('day-cell-${month.year}-${month.month}-$targetDay'),
    );
    expect(targetCell, findsOneWidget);

    await tester.tapAt(tester.getCenter(targetCell));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailsPanel), findsNothing);
    expect(container.read(selectedDateProvider), selectedDate);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (platform, navigationMode) in [
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android])
      for (final mode in MonthNavigationMode.values) (platform, mode),
  ]) {
    testWidgets(
      '$platform $navigationMode day sheet reveals the whole month and restores after a drag',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({
          'onboardingCompleted': true,
          'defaultCalendarView': 'month',
          'monthNavigationMode': navigationMode.name,
        });
        final preferences = await SharedPreferences.getInstance();
        final settingsRepository = SettingsRepository(preferences: preferences);
        final now = DateTime.now();
        final sourceDate = DateTime(now.year, now.month, 2);
        final targetDate = DateTime(now.year, now.month, 3);
        final coveredDate = DateTime(now.year, now.month, 28);
        final event = CalendarEvent(
          id: 'sheet-month-drag-event',
          title: '월간 이동 일정',
          startAt: DateTime(
            sourceDate.year,
            sourceDate.month,
            sourceDate.day,
            9,
          ),
          endAt: DateTime(
            sourceDate.year,
            sourceDate.month,
            sourceDate.day,
            10,
          ),
          allDay: false,
          category: EventCategory.basic,
          colorValue: EventCategory.basic.colorValue,
          createdAt: now,
          updatedAt: now,
        );
        final earlierEvent = event.copyWith(
          id: 'sheet-earlier-event',
          title: '앞 일정',
          startAt: event.startAt.subtract(const Duration(hours: 2)),
          endAt: event.endAt.subtract(const Duration(hours: 2)),
        );
        final eventRepository = _PendingSaveStreamingEventRepository([
          earlierEvent,
          event,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settingsRepository),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(eventRepository),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyApp)),
        );

        final sourceCell = find
            .byKey(
              ValueKey(
                'day-cell-${sourceDate.year}-${sourceDate.month}-${sourceDate.day}',
              ),
            )
            .hitTestable(at: const Alignment(0, -0.8))
            .first;
        final targetCell = find
            .byKey(
              ValueKey(
                'day-cell-${targetDate.year}-${targetDate.month}-${targetDate.day}',
              ),
            )
            .hitTestable()
            .first;
        expect(sourceCell, findsOneWidget);
        expect(targetCell, findsOneWidget);
        final targetPosition = tester.getCenter(targetCell);
        final coveredCell = find
            .byKey(
              ValueKey('day-cell-${coveredDate.year}-${coveredDate.month}-28'),
            )
            .hitTestable()
            .first;
        final coveredCellRect = tester.getRect(coveredCell);
        final calendar = find.byKey(
          const ValueKey('calendar-content-repaint-boundary'),
        );
        final calendarRect = tester.getRect(calendar);

        await tester.tapAt(
          tester.getRect(sourceCell).topCenter + const Offset(0, 4),
        );
        await tester.pumpAndSettle();

        final eventDrag = find.byKey(
          const ValueKey('event-drag-sheet-month-drag-event'),
        );
        expect(eventDrag, findsOneWidget);
        final originalEventSize = tester.getSize(eventDrag);
        final initialSheetHeight = tester
            .getSize(find.byType(EventDetailsPanel))
            .height;
        var gesture = await tester.startGesture(tester.getCenter(eventDrag));
        await tester.pump(const Duration(milliseconds: 350));

        final feedback = find.byKey(
          const ValueKey('calendar-event-drag-feedback-sheet-month-drag-event'),
        );
        expect(feedback, findsOneWidget);
        expect(
          find.byWidgetPredicate((widget) => widget is DragTarget),
          findsWidgets,
        );
        expect(tester.getSize(feedback), originalEventSize);
        final originalOpacity = tester.widget<Opacity>(
          find.descendant(of: eventDrag, matching: find.byType(Opacity)),
        );
        expect(originalOpacity.opacity, 0);
        await gesture.moveBy(const Offset(12, 8));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), originalEventSize);
        expect(
          find.byKey(const ValueKey('calendar-event-source-feedback')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byType(EventDetailsPanel)).height,
          initialSheetHeight,
        );
        final sheetBounds = tester.getRect(find.byType(BottomSheet));
        expect(sheetBounds.contains(coveredCellRect.center), isTrue);
        await gesture.moveTo(
          Offset(sheetBounds.center.dx, sheetBounds.top + 8),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), originalEventSize);
        expect(
          tester.getSize(find.byType(EventDetailsPanel)).height,
          initialSheetHeight,
        );
        expect(
          find
              .byKey(
                ValueKey(
                  'event-drop-target-${targetDate.year}-${targetDate.month}-${targetDate.day}',
                ),
              )
              .hitTestable(),
          findsOneWidget,
        );

        await gesture.moveTo(targetPosition);
        await tester.pump();
        expect(tester.getSize(feedback), originalEventSize);
        await tester.pump(const Duration(milliseconds: 85));
        final shrinkingSize = tester.getSize(feedback);
        expect(
          shrinkingSize.height,
          inExclusiveRange(13, originalEventSize.height),
        );
        expect(shrinkingSize.width, lessThan(originalEventSize.width));
        await tester.pump(const Duration(milliseconds: 220));
        expect(
          tester.getSize(find.byType(EventDetailsPanel)).height,
          initialSheetHeight,
        );
        expect(tester.getRect(calendar), calendarRect);
        expect(tester.getRect(coveredCell), coveredCellRect);
        expect(
          tester.getTopLeft(find.byType(BottomSheet)).dy,
          greaterThanOrEqualTo(calendarRect.bottom),
        );
        expect(feedback, findsOneWidget);
        expect(
          find.byKey(const ValueKey('calendar-event-compact-feedback')),
          findsOneWidget,
        );
        expect(tester.getSize(feedback).height, 13);
        expect(
          tester.getSize(feedback).width,
          lessThan(originalEventSize.width),
        );
        final compactSize = tester.getSize(feedback);
        await gesture.moveTo(coveredCellRect.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), compactSize);
        expect(tester.getRect(calendar), calendarRect);
        expect(
          find
              .byKey(
                ValueKey(
                  'event-drop-target-${coveredDate.year}-${coveredDate.month}-28',
                ),
              )
              .hitTestable(),
          findsOneWidget,
        );
        final returnPosition = tester.getCenter(find.byType(BottomSheet));
        await gesture.moveTo(returnPosition);
        await tester.pump();
        expect(tester.getSize(feedback), compactSize);
        await tester.pump(const Duration(milliseconds: 85));
        final growingSize = tester.getSize(feedback);
        expect(
          growingSize.height,
          inExclusiveRange(13, originalEventSize.height),
        );
        expect(
          growingSize.width,
          inExclusiveRange(compactSize.width, originalEventSize.width),
        );
        expect(tester.getCenter(feedback), returnPosition);
        expect(
          find.descendant(of: feedback, matching: find.text(event.title)),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), originalEventSize);
        expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);
        expect(
          find.byKey(const ValueKey('calendar-event-source-feedback')),
          findsOneWidget,
        );
        expect(eventRepository.savedEvents, isEmpty);

        final earlierDrag = find.byKey(
          const ValueKey('event-drag-sheet-earlier-event'),
        );
        final earlierRect = tester.getRect(earlierDrag);
        await gesture.moveTo(
          Offset(earlierRect.center.dx, earlierRect.top + 2),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), originalEventSize);
        await gesture.moveBy(const Offset(0, 1));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          container
              .read(appSettingsProvider)
              .calendarManualEventOrders
              .values
              .single
              .eventKeys,
          [event.id, earlierEvent.id],
        );
        expect(eventRepository.savedEvents, isEmpty);
        expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);

        gesture = await tester.startGesture(tester.getCenter(eventDrag));
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.moveTo(targetPosition);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 85));
        expect(
          tester.getSize(feedback).height,
          inExclusiveRange(13, originalEventSize.height),
        );
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getSize(feedback), compactSize);
        await gesture.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(eventRepository.savedEvents, isEmpty);
        expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);
        expect(feedback, findsNothing);

        final dropGesture = await tester.startGesture(
          tester.getCenter(eventDrag),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await dropGesture.moveTo(targetPosition);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        await dropGesture.moveTo(coveredCellRect.center);
        await tester.pump();
        await dropGesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);

        expect(eventRepository.savedEvents, hasLength(1));
        expect(
          find.byKey(
            ValueKey(
              'event-drop-target-${targetDate.year}-${targetDate.month}-${targetDate.day}',
            ),
          ),
          findsNothing,
        );
        final saved = eventRepository.savedEvents.single;
        expect(saved.startAt, DateTime(now.year, now.month, 28, 9));
        expect(saved.endAt, DateTime(now.year, now.month, 28, 10));

        await tester.tapAt(targetPosition);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(EventDetailsPanel), findsNothing);
        expect(container.read(selectedDateProvider), sourceDate);

        await tester.tap(coveredCell);
        await tester.pump();
        expect(container.read(selectedDateProvider), coveredDate);

        eventRepository.completeSave();
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('canceling an event drag restores the lifted event in place', (
    tester,
  ) async {
    final now = DateTime.now();
    final event = CalendarEvent(
      id: 'cancel-drag-event',
      title: '취소 복귀 일정',
      startAt: now,
      endAt: now.add(const Duration(hours: 1)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: CalendarEventDraggable(
                key: const ValueKey('cancel-event-drag'),
                event: event,
                child: const Material(
                  child: SizedBox(
                    height: 64,
                    child: Center(child: Text('취소 복귀 일정')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final draggable = find.byKey(const ValueKey('cancel-event-drag'));
    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 350));

    final feedback = find.byKey(
      const ValueKey('calendar-event-drag-feedback-cancel-drag-event'),
    );
    expect(feedback, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: draggable, matching: find.byType(Opacity)),
          )
          .opacity,
      0,
    );

    await gesture.moveBy(const Offset(120, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(feedback, findsNothing);
    expect(find.text('취소 복귀 일정'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Daily reschedules saved event notifications on app start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final event = CalendarEvent(
      id: 'event-notify',
      title: '알림 테스트',
      startAt: DateTime.now().add(const Duration(hours: 1)),
      endAt: DateTime.now().add(const Duration(hours: 2)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      reminderMinutesBefore: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final notificationService = _FakeNotification();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(
            _FakeEventRepository(events: [event]),
          ),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(notificationService.initializeCalls, 1);
    expect(notificationService.scheduledEventIds, ['event-notify']);
    expect(notificationService.scheduledImmediateFlags, [false]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('local data reset does not require Google account deletion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초기화'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('오늘을 더\n가볍게 정리하세요.'), findsOneWidget);
    expect(driveSyncService.deleteCloudBackupCalls, 0);
    expect(authService.signOutCalls, 0);
    expect(eventRepository.clearAllCalls, 1);
    expect(notificationService.cancelMorningBriefingCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('local data reset continues when notification cleanup fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification(
      failCancelEventReminder: true,
      failCancelMorningBriefing: true,
    );
    final eventRepository = _FakeEventRepository(
      events: [
        CalendarEvent(
          id: 'reset-event',
          title: '초기화 테스트',
          startAt: DateTime.now().add(const Duration(hours: 1)),
          endAt: DateTime.now().add(const Duration(hours: 2)),
          allDay: false,
          category: EventCategory.basic,
          colorValue: EventCategory.basic.colorValue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초기화'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('오늘을 더\n가볍게 정리하세요.'), findsOneWidget);
    expect(eventRepository.clearAllCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'settings keeps desktop Google auth active until the user cancels it',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        signInCompleter: Completer<GoogleDriveAccount?>(),
        canCancelOnResume: true,
      );
      final notificationService = _FakeNotification();
      final eventRepository = _FakeEventRepository();
      final driveSyncService = _FakeGoogleDriveSyncService(
        authService: authService,
        eventRepository: eventRepository,
        notificationService: notificationService,
        settingsRepository: settingsRepository,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(notificationService),
            eventRepositoryProvider.overrideWithValue(eventRepository),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
            googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
            syncServiceProvider.overrideWithValue(_FakeSync()),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      await _openAccountSettings(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Google로 계속'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Google로 계속'));
      await tester.pump();

      expect(authService.signInCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Google 연결 중'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 0);
      expect(find.text('연결 취소'), findsOneWidget);
      await tester.tap(find.text('연결 취소'));
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 1);
      expect(
        find.text('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Google로 계속'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('logout clears local accounts and keeps Drive cloud backup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
    });
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService();
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();

    expect(authService.signOutCalls, 1);
    expect(driveSyncService.syncNowCalls, 0);
    expect(driveSyncService.syncPendingChangesNowCalls, 1);
    expect(eventRepository.clearAllCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);
    expect(settingsRepository.appleAccount(), isNull);
    expect(find.text('오늘을 더\n가볍게 정리하세요.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform quick view shows two categorized Todo cards per row',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
        final preferences = await SharedPreferences.getInstance();
        final settingsRepository = SettingsRepository(preferences: preferences);
        const work = EventCategory(
          id: 'work',
          label: '업무',
          colorValue: 0xff7c3aed,
        );
        await settingsRepository.save(
          settingsRepository.load().copyWith(
            categories: const [EventCategory.basic, work],
            calendarEventTitleAlignment: CalendarEventTitleAlignment.center,
          ),
        );
        final now = DateTime.now();
        CalendarEvent event(String id, String title, EventCategory category) {
          final start = DateTime(now.year, now.month, 12, 9);
          return CalendarEvent(
            id: id,
            title: title,
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
            allDay: false,
            category: category,
            colorValue: category.colorValue,
            createdAt: start,
            updatedAt: start,
          );
        }

        final eventRepository = _StreamingEventRepository([
          event('basic-todo', '개인 일정', EventCategory.basic),
          event('work-todo', '업무 일정', work).copyWith(completed: true),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settingsRepository),
              notificationServiceProvider.overrideWithValue(
                _FakeNotification(),
              ),
              syncServiceProvider.overrideWithValue(_FakeSync()),
              eventRepositoryProvider.overrideWithValue(eventRepository),
              googleDriveAuthServiceProvider.overrideWithValue(
                _FakeGoogleDriveAuthService(),
              ),
            ],
            child: const DailyApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('빠른 보기'));
        await tester.pumpAndSettle();

        final basicCard = find.byKey(
          const ValueKey('quick-todo-category-basic'),
        );
        final workCard = find.byKey(const ValueKey('quick-todo-category-work'));
        expect(basicCard, findsOneWidget);
        expect(workCard, findsOneWidget);
        expect(tester.getTopLeft(basicCard).dy, tester.getTopLeft(workCard).dy);
        expect(find.byType(Checkbox), findsNWidgets(2));
        expect(
          tester.widget<Text>(find.text('업무 일정')).style?.decorationStyle,
          TextDecorationStyle.solid,
        );
        expect(
          tester.widget<Text>(find.text('업무 일정')).style?.decorationThickness,
          lessThan(2),
        );
        expect(
          tester.widget<Text>(find.text('업무 일정')).style?.color,
          Color(work.colorValue),
        );
        expect(
          tester.widget<Text>(find.text('업무 일정')).textAlign,
          TextAlign.start,
        );

        await tester.tap(
          find.byKey(const ValueKey('quick-todo-open-work-todo')),
        );
        await tester.pumpAndSettle();
        expect(find.text('추가 상세정보가 없습니다.'), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'calendar filter save preserves a concurrent unrelated setting change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': CalendarViewMode.month.name,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = _ConcurrentCalendarSettingsRepository(
        preferences: preferences,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );

      settingsRepository.injectThemeChangeBeforeNextSave();
      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();
      final ddaySwitch = find.descendant(
        of: find.byType(SwitchListTile).first,
        matching: find.byType(Switch),
      );
      expect(ddaySwitch, findsOneWidget);
      await tester.tap(ddaySwitch);
      await tester.pumpAndSettle();

      expect(settingsRepository.capturedChangedFrom, isNotNull);
      expect(settingsRepository.capturedChangedFrom!.calendarDdayOnly, isFalse);
      expect(settingsRepository.load().calendarDdayOnly, isTrue);
      expect(settingsRepository.load().themeMode, AppThemeMode.dark);
      expect(container.read(appSettingsProvider).themeMode, AppThemeMode.dark);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<(ProviderContainer, _DelayedSettingsRepository)>
_pumpWindowsAppearanceSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
  FlutterSecureStorage.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final settingsRepository = _DelayedSettingsRepository(
    preferences: preferences,
  );
  final authService = _FakeGoogleDriveAuthService(account: null);
  final notificationService = _FakeNotification();
  final eventRepository = _FakeEventRepository();
  final driveSyncService = _FakeGoogleDriveSyncService(
    authService: authService,
    eventRepository: eventRepository,
    notificationService: notificationService,
    settingsRepository: settingsRepository,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        notificationServiceProvider.overrideWithValue(notificationService),
        syncServiceProvider.overrideWithValue(_FakeSync()),
        eventRepositoryProvider.overrideWithValue(eventRepository),
        googleDriveAuthServiceProvider.overrideWithValue(authService),
        googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('appearance-settings-navigation')),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsPage)),
  );
  return (container, settingsRepository);
}

Future<void> _openAccountSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-settings-navigation')));
  await tester.pumpAndSettle();
  expect(find.text('계정 설정'), findsOneWidget);
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  _FakeGoogleDriveAuthService({
    this.account = const GoogleDriveAccount(email: 'tester@example.com'),
    this.restoredAccount,
    this.signInAccount,
    this.signInCompleter,
    this.canCancelOnResume = false,
    this.restoreFailuresRemaining = 0,
    this.authorizationAvailable = true,
  });

  GoogleDriveAccount? account;
  final GoogleDriveAccount? restoredAccount;
  final GoogleDriveAccount? signInAccount;
  final Completer<GoogleDriveAccount?>? signInCompleter;
  final bool canCancelOnResume;
  int restoreFailuresRemaining;
  final bool authorizationAvailable;
  var cancelPendingSignInCalls = 0;
  var authorizationHeadersCalls = 0;
  var restorePreviousSignInCalls = 0;
  var signInCalls = 0;
  var signOutCalls = 0;

  @override
  GoogleDriveAccount? get currentAccount => account;

  @override
  bool get canCancelPendingSignInOnResume => canCancelOnResume;

  @override
  Future<void> initialize() async {}

  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async {
    restorePreviousSignInCalls += 1;
    if (restoreFailuresRemaining > 0) {
      restoreFailuresRemaining -= 1;
      throw const GoogleDriveAuthException('temporary restore failure');
    }
    account ??= restoredAccount;
    return account;
  }

  @override
  Future<GoogleDriveAccount?> signIn({
    bool forceAccountSelection = false,
  }) async {
    signInCalls += 1;
    if (signInCompleter != null) {
      return signInCompleter!.future;
    }
    account ??= signInAccount;
    return account;
  }

  @override
  void cancelPendingSignIn() {
    cancelPendingSignInCalls += 1;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    authorizationHeadersCalls += 1;
    if (account == null || !authorizationAvailable) {
      return null;
    }
    return const {'Authorization': 'Bearer test-token'};
  }
}

class _DelayedSettingsRepository extends SettingsRepository {
  _DelayedSettingsRepository({required super.preferences});

  var _saveGate = Completer<void>();
  var _failNextSave = false;
  var saveCalls = 0;

  bool get hasPendingSave => !_saveGate.isCompleted;

  void releasePendingSave() {
    if (!_saveGate.isCompleted) {
      _saveGate.complete();
    }
  }

  void blockNextSave() {
    if (!_saveGate.isCompleted) {
      throw StateError('The current settings save is still pending.');
    }
    _saveGate = Completer<void>();
  }

  void failNextSave() {
    _failNextSave = true;
  }

  Future<void> saveWithoutDelay(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) {
    return super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }

  @override
  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) async {
    saveCalls += 1;
    final gate = _saveGate;
    final shouldFail = _failNextSave;
    _failNextSave = false;
    await gate.future;
    if (shouldFail) {
      throw StateError('settings save failed');
    }
    await super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }
}

class _ConcurrentCalendarSettingsRepository extends SettingsRepository {
  _ConcurrentCalendarSettingsRepository({required super.preferences});

  var _injectThemeChange = false;
  AppSettings? capturedChangedFrom;

  void injectThemeChangeBeforeNextSave() {
    capturedChangedFrom = null;
    _injectThemeChange = true;
  }

  @override
  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) async {
    if (_injectThemeChange) {
      _injectThemeChange = false;
      capturedChangedFrom = changedFrom;
      final concurrentBase = load();
      await super.save(
        concurrentBase.copyWith(themeMode: AppThemeMode.dark),
        markSyncPending: false,
        changedFrom: concurrentBase,
      );
    }
    await super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }
}

class _FakeGoogleDriveSyncService extends GoogleDriveSyncService {
  _FakeGoogleDriveSyncService({
    required super.authService,
    required super.eventRepository,
    required super.notificationService,
    required super.settingsRepository,
  });

  var deleteCloudBackupCalls = 0;
  var startListeningOnlyCalls = 0;
  var syncNowCalls = 0;
  var syncOnResumeCalls = 0;
  var syncPendingChangesNowCalls = 0;
  var restoreNowCalls = 0;
  final backupPrompts = <bool>[];
  final restorePrompts = <bool>[];

  @override
  Future<void> queueSettingsBackup() async {}

  @override
  Future<void> startListeningOnly({bool flushPendingChanges = true}) async {
    startListeningOnlyCalls += 1;
  }

  @override
  Future<void> syncNow({bool promptIfNecessary = false}) async {
    syncNowCalls += 1;
  }

  @override
  Future<void> syncOnResume({bool promptIfNecessary = false}) async {
    syncOnResumeCalls += 1;
  }

  @override
  Future<void> syncPendingChangesNow({
    bool promptIfNecessary = false,
    bool restoreAfterBackup = false,
  }) async {
    syncPendingChangesNowCalls += 1;
    backupPrompts.add(promptIfNecessary);
  }

  @override
  Future<void> restoreNow({bool promptIfNecessary = false}) async {
    restoreNowCalls += 1;
    restorePrompts.add(promptIfNecessary);
  }

  @override
  Future<void> deleteCloudBackup({bool promptIfNecessary = false}) async {
    deleteCloudBackupCalls += 1;
  }
}

class _FakeNotification implements NotificationService {
  _FakeNotification({
    this.failCancelEventReminder = false,
    this.failCancelMorningBriefing = false,
    this.initializeCompleter,
  });

  final bool failCancelEventReminder;
  final bool failCancelMorningBriefing;
  final Completer<void>? initializeCompleter;
  var cancelMorningBriefingCalls = 0;
  var initializeCalls = 0;
  final scheduledEventIds = <String>[];
  final scheduledImmediateFlags = <bool>[];

  @override
  Future<void> cancelMorningBriefing() async {
    cancelMorningBriefingCalls += 1;
    if (failCancelMorningBriefing) {
      throw Exception('cancel morning briefing failed');
    }
  }

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    if (failCancelEventReminder) {
      throw Exception('cancel event reminder failed');
    }
  }

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    await initializeCompleter?.future;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduledEventIds.add(event.id);
    scheduledImmediateFlags.add(allowImmediate);
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<int> pendingNotificationCount() async => scheduledEventIds.length;

  @override
  Future<String> permissionSummary() async => '테스트 권한 · 예약 0개';
}

class _FakeSync implements SyncService {
  @override
  Future<void> queueSettingsBackup() async {}

  var startCalls = 0;

  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}

  @override
  Future<void> start() async {
    startCalls += 1;
  }
}

class _FakeProductAnalytics implements ProductAnalytics {
  _FakeProductAnalytics({bool consentPromptCompleted = true}) {
    _consentPromptCompleted.value = consentPromptCompleted;
  }

  final ValueNotifier<bool> _enabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _consentPromptCompleted = ValueNotifier<bool>(true);
  final records = <AnalyticsRecord>[];
  var deleteCalls = 0;
  var completeConsentPromptCalls = 0;

  @override
  bool get consentPromptCompleted => _consentPromptCompleted.value;

  @override
  ValueListenable<bool> get consentPromptCompletedListenable =>
      _consentPromptCompleted;

  @override
  bool get enabled => _enabled.value;

  @override
  ValueListenable<bool> get enabledListenable => _enabled;

  @override
  int get pendingEventCount => records.length;

  @override
  Future<void> completeConsentPrompt({required bool enabled}) async {
    completeConsentPromptCalls += 1;
    await setEnabled(enabled);
    _consentPromptCompleted.value = true;
  }

  @override
  Future<void> deletePendingData() async {
    deleteCalls += 1;
    records.clear();
  }

  @override
  void dispose() {
    _enabled.dispose();
    _consentPromptCompleted.dispose();
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> record(AnalyticsRecord record) async {
    if (enabled) records.add(record);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled.value = enabled;
    if (!enabled) await deletePendingData();
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({List<CalendarEvent> events = const []})
    : _events = events;

  final List<CalendarEvent> _events;
  var clearAllCalls = 0;

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<void> save(CalendarEvent event) async {}

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {}

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Future<CalendarEvent?> findById(String id) async => null;

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => const [];

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => _events;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    final affected = <CalendarEvent>[];
    for (var index = 0; index < _events.length; index++) {
      final event = _events[index];
      if (event.deletedAt != null || event.category.id != previous.id) {
        continue;
      }
      final next = event.copyWith(
        category: updated,
        colorValue: updated.colorValue,
        updatedAt: updatedAt,
        syncStatus: 'pending',
        holiday: updated.id == EventCategory.holiday.id,
      );
      _events[index] = next;
      affected.add(next);
    }
    return affected;
  }

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    return _events
        .where(
          (event) =>
              event.deletedAt == null &&
              event.startAt.isBefore(rangeEnd) &&
              event.endAt.isAfter(rangeStart),
        )
        .toList();
  }

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(const []);
  }

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> clearAll() async {
    clearAllCalls += 1;
  }
}

class _StreamingEventRepository extends _FakeEventRepository {
  _StreamingEventRepository(List<CalendarEvent> events) : super(events: events);

  @override
  Future<CalendarEvent?> findById(String id) async {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(
      _events
          .where(
            (event) =>
                event.deletedAt == null &&
                event.startAt.isBefore(rangeEnd) &&
                event.endAt.isAfter(rangeStart),
          )
          .toList(),
    );
  }
}

class _CompletionEventRepository extends _StreamingEventRepository {
  _CompletionEventRepository(super.events);
  final _changes = StreamController<void>.broadcast();
  bool failNextSave = false;
  Future<void> close() => _changes.close();

  @override
  Future<void> save(CalendarEvent event) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index < 0) {
      _events.add(event);
    } else {
      _events[index] = event;
    }
    _changes.add(null);
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    for (final event in events) {
      await save(event);
    }
  }

  @override
  Future<List<CalendarEvent>> search(String query) async =>
      _events.where((e) => e.title.contains(query)).toList();

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime start,
    DateTime end,
  ) async* {
    List<CalendarEvent> snapshot() => _events
        .where(
          (e) =>
              e.deletedAt == null &&
              e.startAt.isBefore(end) &&
              e.endAt.isAfter(start),
        )
        .toList();
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }
}

class _RecordingStreamingEventRepository extends _StreamingEventRepository {
  _RecordingStreamingEventRepository(super.events);

  final savedEvents = <CalendarEvent>[];

  @override
  Future<void> save(CalendarEvent event) async {
    savedEvents.add(event);
  }
}

class _PendingSaveStreamingEventRepository
    extends _RecordingStreamingEventRepository {
  _PendingSaveStreamingEventRepository(super.events);

  final _saveCompleter = Completer<void>();

  @override
  Future<void> save(CalendarEvent event) async {
    savedEvents.add(event);
    await _saveCompleter.future;
  }

  void completeSave() {
    if (!_saveCompleter.isCompleted) {
      _saveCompleter.complete();
    }
  }
}

class _MissingEntitlementSecureStorage extends FlutterSecureStorage {
  const _MissingEntitlementSecureStorage();

  PlatformException get _error => PlatformException(
    code: 'Unexpected security result code',
    message: "A required entitlement isn't present.",
    details: -34018,
  );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw _error;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw _error;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw _error;
  }
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}
