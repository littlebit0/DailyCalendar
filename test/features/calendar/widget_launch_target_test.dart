import 'dart:async';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/widgets/calendar_widget_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/imogi/presentation/imogi_page.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

class _Repository implements EventRepository {
  _Repository(this.event);

  final CalendarEvent event;

  @override
  Future<CalendarEvent?> findById(String id) async =>
      id == event.id ? event : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _event = CalendarEvent(
  id: 'weekly',
  title: 'Weekly review',
  startAt: DateTime(2026, 9, 1, 9),
  endAt: DateTime(2026, 9, 1, 10),
  allDay: false,
  category: EventCategory.basic,
  colorValue: EventCategory.basic.colorValue,
  recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

// #874: a home-screen widget tap opens its day or event in the app.
void main() {
  const channel = MethodChannel(CalendarWidgetChannelContract.androidChannel);
  late List<Map<String, Object?>> targets;

  setUp(() {
    targets = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method ==
              CalendarWidgetChannelContract.takeLaunchTargetMethod) {
            return targets.isEmpty ? null : targets.removeAt(0);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads only a valid date or event id', () {
    final target = CalendarWidgetLaunchTarget.fromMap({
      'eventId': 'weekly',
      'date': '2026-11-18',
    })!;
    expect(target.eventId, 'weekly');
    expect(target.date, DateTime(2026, 11, 18));
    expect(CalendarWidgetLaunchTarget.fromMap({'date': '2026-1-8'}), isNull);
    expect(CalendarWidgetLaunchTarget.fromMap({'eventId': ''}), isNull);
  });

  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily.test',
      version: '4.2.0',
      buildNumber: '420',
      buildSignature: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          appSettingsProvider.overrideWith((_) => settings.load()),
          timetableStoreProvider.overrideWithValue(settings.timetableStore),
          eventsInRangeProvider.overrideWith(
            (_, _) => Stream.value(const <CalendarEvent>[]),
          ),
          visibleEventRepositoryProvider.overrideWithValue(_Repository(_event)),
          googleDriveAuthServiceProvider.overrideWithValue(_SilentAuth()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: DailyTheme.light(),
          home: const MonthCalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MonthCalendarPage)),
    );
  }

  testWidgets('a cold-start date tap selects that day once', (tester) async {
    targets.add({'date': '2026-12-24'});
    final container = await pumpPage(tester);
    expect(container.read(selectedDateProvider), DateTime(2026, 12, 24));
    expect(container.read(visibleMonthProvider), DateTime(2026, 12));
    expect(find.byType(EventDetailsPanel), findsNothing);
    expect(targets, isEmpty);
  });

  testWidgets('a tap while running opens the tapped occurrence', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    targets.add({'eventId': 'weekly', 'date': '2026-09-15'});
    await container
        .read(calendarWidgetServiceProvider)
        .handleNativeMethodCall(
          const MethodCall(
            CalendarWidgetChannelContract.launchTargetOpenedCallback,
          ),
        );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 9, 15));
    // Edits and deletes from these details apply to the tapped occurrence.
    final panel = tester.widget<EventDetailsPanel>(
      find.byType(EventDetailsPanel),
    );
    expect(panel.initialEvent!.startAt, DateTime(2026, 9, 15, 9));
    expect(panel.initialEvent!.occurrenceId, isNotNull);
    expect(find.text('Weekly review'), findsWidgets);
  });

  testWidgets('a date tap closes an open day sheet', (tester) async {
    final container = await pumpPage(tester);
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.month;
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final day = today.day == 15 ? 16 : 15;
    await tester.tap(
      find.byKey(ValueKey('day-cell-${today.year}-${today.month}-$day')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsPanel), findsOneWidget);
    targets.add({'date': '2026-12-24'});
    await container
        .read(calendarWidgetServiceProvider)
        .handleNativeMethodCall(
          const MethodCall(
            CalendarWidgetChannelContract.launchTargetOpenedCallback,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsPanel), findsNothing);
    expect(container.read(selectedDateProvider), DateTime(2026, 12, 24));
  });

  testWidgets('a date tap closes pages opened over the calendar', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('settings page')),
        ),
      ),
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const PopScope(
            canPop: false,
            child: Scaffold(body: Text('busy page')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    targets.add({'date': '2026-12-24'});
    Future<void> tap() async {
      await container
          .read(calendarWidgetServiceProvider)
          .handleNativeMethodCall(
            const MethodCall(
              CalendarWidgetChannelContract.launchTargetOpenedCallback,
            ),
          );
      await tester.pumpAndSettle();
    }

    await tap();
    // A page that refuses to pop is kept, with everything under it.
    expect(find.text('busy page'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    targets.add({'date': '2026-12-25'});
    await tap();
    expect(find.text('settings page'), findsNothing);
    expect(find.byType(MonthCalendarPage), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2026, 12, 25));
  });

  testWidgets('a date tap leaves the Imogi tab for the calendar', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    await tester.tap(find.byTooltip('잊모기'));
    await tester.pumpAndSettle();
    expect(find.byType(ImogiPage), findsOneWidget);
    targets.add({'date': '2026-12-24'});
    await container
        .read(calendarWidgetServiceProvider)
        .handleNativeMethodCall(
          const MethodCall(
            CalendarWidgetChannelContract.launchTargetOpenedCallback,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byType(ImogiPage), findsNothing);
    expect(container.read(selectedDateProvider), DateTime(2026, 12, 24));
  });
}
