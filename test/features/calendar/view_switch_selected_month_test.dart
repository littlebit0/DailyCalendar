import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

// #964: picking a date of another month in week/day view and then switching to
// month view opened the previously shown month instead of the picked date's.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'defaultCalendarView': 'month'});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily.test',
      version: '4.1.1',
      buildNumber: '411',
      buildSignature: '',
    );
  });

  Future<ProviderContainer> pumpCalendar(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          appSettingsProvider.overrideWith((_) => settings.load()),
          timetableStoreProvider.overrideWithValue(settings.timetableStore),
          eventsInRangeProvider.overrideWith(
            (ref, _) => Stream.value(const <CalendarEvent>[]),
          ),
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

  /// Month of the grid painted under the middle of the calendar area.
  DateTime shownMonth(WidgetTester tester) {
    final probe = tester.getCenter(find.byType(MonthCalendarPage));
    for (final element in find.byType(CalendarMonthGrid).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(probe)) {
        return (element.widget as CalendarMonthGrid).month;
      }
    }
    throw StateError('no month grid under $probe');
  }

  Future<void> show(
    WidgetTester tester,
    ProviderContainer container, {
    required CalendarViewMode mode,
    required DateTime month,
    required DateTime selected,
  }) async {
    container.read(visibleMonthProvider.notifier).state = month;
    container.read(selectedDateProvider.notifier).state = selected;
    container.read(calendarViewModeProvider.notifier).state = mode;
    await tester.pumpAndSettle();
  }

  Future<void> tapDay(WidgetTester tester, DateTime day) async {
    final panel = find.byKey(
      ValueKey('week-day-panel-${day.year}-${day.month}-${day.day}'),
    );
    await tester.ensureVisible(panel);
    await tester.pumpAndSettle();
    await tester.tap(panel);
    await tester.pumpAndSettle();
  }

  Future<void> closeDaySheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(MonthCalendarPage))).pop();
    await tester.pumpAndSettle();
  }

  Future<void> switchToMonth(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.month;
    await tester.pumpAndSettle();
  }

  testWidgets('week view: next-month date opens that month', (tester) async {
    final container = await pumpCalendar(tester);
    await show(
      tester,
      container,
      mode: CalendarViewMode.week,
      month: DateTime(2026, 4),
      selected: DateTime(2026, 4, 29),
    );

    await tapDay(tester, DateTime(2026, 5, 1));
    await closeDaySheet(tester);
    await switchToMonth(tester, container);

    expect(container.read(selectedDateProvider), DateTime(2026, 5, 1));
    expect(container.read(visibleMonthProvider), DateTime(2026, 5));
    expect(shownMonth(tester), DateTime(2026, 5));
  });

  testWidgets('day view: previous-month date opens that month', (
    tester,
  ) async {
    final container = await pumpCalendar(tester);
    // Month view keeps its month when an adjacent-month cell is picked, so
    // the day view can open on a date outside the shown month.
    // In the day view only the schedule layout's time grid picks a date.
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
    await show(
      tester,
      container,
      mode: CalendarViewMode.day,
      month: DateTime(2026, 3),
      selected: DateTime(2026, 2, 28),
    );

    await tester.tap(
      find.byKey(const ValueKey('schedule-time-scroll')).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await switchToMonth(tester, container);

    expect(container.read(selectedDateProvider), DateTime(2026, 2, 28));
    expect(container.read(visibleMonthProvider), DateTime(2026, 2));
    expect(shownMonth(tester), DateTime(2026, 2));
  });

  testWidgets('week view: same-month date keeps the month', (tester) async {
    final container = await pumpCalendar(tester);
    await show(
      tester,
      container,
      mode: CalendarViewMode.week,
      month: DateTime(2026, 4),
      selected: DateTime(2026, 4, 29),
    );

    await tapDay(tester, DateTime(2026, 4, 27));
    await closeDaySheet(tester);
    await switchToMonth(tester, container);

    expect(container.read(selectedDateProvider), DateTime(2026, 4, 27));
    expect(container.read(visibleMonthProvider), DateTime(2026, 4));
    expect(shownMonth(tester), DateTime(2026, 4));
  });
}
