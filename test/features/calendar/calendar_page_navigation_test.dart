import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

// #869: week, day and month pages share one paging state. These pin the
// observable paging behavior: swipes, Today and the position after a view
// switch, on a platform that commits on page change (Android) and one that
// commits at scroll end (Windows).
void main() {
  final platforms = TargetPlatformVariant(const {
    TargetPlatform.android,
    TargetPlatform.windows,
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily.test',
      version: '4.1.1',
      buildNumber: '411',
      buildSignature: '',
    );
  });

  Future<ProviderContainer> pumpCalendar(
    WidgetTester tester,
    CalendarViewMode viewMode,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = defaultTargetPlatform == TargetPlatform.windows
        ? const Size(1280, 860)
        : const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      settings.load().copyWith(
        defaultCalendarView: viewMode,
        monthNavigationMode: MonthNavigationMode.horizontal,
      ),
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

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime shiftDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  int monthIndex(DateTime month) => month.year * 12 + month.month - 1;

  // A touch drag on Android; on Windows a horizontal mouse wheel tick, which
  // takes the Windows burst path and commits at scroll end.
  Future<void> swipe(WidgetTester tester, String key, double dx) async {
    final target = find.byKey(ValueKey(key));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: tester.getCenter(target),
          scrollDelta: Offset(dx < 0 ? 30 : -30, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.drag(target, Offset(dx, 0));
    }
    await tester.pumpAndSettle();
  }

  // Same provider writes as the toolbar's Today button.
  Future<void> goToday(WidgetTester tester, ProviderContainer container) async {
    final now = today();
    container.read(visibleMonthProvider.notifier).state = DateTime(
      now.year,
      now.month,
    );
    container.read(selectedDateProvider.notifier).state = now;
    await tester.pumpAndSettle();
  }

  Future<void> setView(
    WidgetTester tester,
    ProviderContainer container,
    CalendarViewMode mode,
  ) async {
    container.read(calendarViewModeProvider.notifier).state = mode;
    await tester.pumpAndSettle();
  }

  for (final (mode, key, days) in [
    (CalendarViewMode.week, 'week-pointer-navigation', 7),
    (CalendarViewMode.day, 'day-pointer-navigation', 1),
  ]) {
    testWidgets('${mode.name} pages move by $days days and follow Today', (
      tester,
    ) async {
      final container = await pumpCalendar(tester, mode);
      DateTime selected() => container.read(selectedDateProvider);
      final start = selected();

      await swipe(tester, key, -300);
      expect(selected(), shiftDays(start, days));
      await swipe(tester, key, -300);
      expect(selected(), shiftDays(start, days * 2));
      await swipe(tester, key, 300);
      expect(selected(), shiftDays(start, days));

      await goToday(tester, container);
      expect(selected(), today());
      // After an external jump the page index is in sync again.
      await swipe(tester, key, 300);
      expect(selected(), shiftDays(today(), -days));
      expect(
        monthIndex(container.read(visibleMonthProvider)),
        monthIndex(shiftDays(today(), -days)),
      );
    }, variant: platforms);
  }

  testWidgets('month pages move by one month and follow Today', (tester) async {
    final container = await pumpCalendar(tester, CalendarViewMode.month);
    int visible() => monthIndex(container.read(visibleMonthProvider));
    final start = visible();

    await swipe(tester, 'month-pointer-navigation', -300);
    expect(visible(), start + 1);
    await swipe(tester, 'month-pointer-navigation', -300);
    expect(visible(), start + 2);

    await goToday(tester, container);
    expect(visible(), monthIndex(today()));
    await swipe(tester, 'month-pointer-navigation', 300);
    expect(visible(), monthIndex(today()) - 1);
  }, variant: platforms);

  testWidgets('switching views keeps the position reached by swiping', (
    tester,
  ) async {
    final container = await pumpCalendar(tester, CalendarViewMode.week);
    DateTime selected() => container.read(selectedDateProvider);
    final start = selected();

    await swipe(tester, 'week-pointer-navigation', -300);
    await swipe(tester, 'week-pointer-navigation', -300);
    final afterWeeks = shiftDays(start, 14);
    expect(selected(), afterWeeks);

    await setView(tester, container, CalendarViewMode.day);
    expect(selected(), afterWeeks);
    await swipe(tester, 'day-pointer-navigation', -300);
    final afterDay = shiftDays(afterWeeks, 1);
    expect(selected(), afterDay);

    await setView(tester, container, CalendarViewMode.week);
    await swipe(tester, 'week-pointer-navigation', 300);
    final backWeek = shiftDays(afterDay, -7);
    expect(selected(), backWeek);

    await setView(tester, container, CalendarViewMode.month);
    expect(
      monthIndex(container.read(visibleMonthProvider)),
      monthIndex(backWeek),
    );
    await swipe(tester, 'month-pointer-navigation', -300);
    expect(
      monthIndex(container.read(visibleMonthProvider)),
      monthIndex(backWeek) + 1,
    );
  }, variant: platforms);
}
