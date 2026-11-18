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

// #962: switching the month navigation mode with the calendar open showed a
// different month than the header until the first swipe.
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
    await settings.save(
      settings.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
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

  int monthIndex(DateTime month) => month.year * 12 + month.month - 1;

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

  Future<void> setMode(
    WidgetTester tester,
    ProviderContainer container,
    MonthNavigationMode mode,
  ) async {
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(monthNavigationMode: mode);
    await tester.pumpAndSettle();
  }

  testWidgets('switching navigation mode keeps the header month on screen', (
    tester,
  ) async {
    final container = await pumpCalendar(tester);
    final opened = monthIndex(container.read(visibleMonthProvider));

    final list = find.byKey(const ValueKey('continuous-month-scroll'));
    for (var i = 0; i < 30; i++) {
      if (monthIndex(container.read(visibleMonthProvider)) - opened >= 3) {
        break;
      }
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    final afterVertical = monthIndex(container.read(visibleMonthProvider));
    expect(afterVertical - opened, greaterThanOrEqualTo(3));

    await setMode(tester, container, MonthNavigationMode.horizontal);
    expect(monthIndex(shownMonth(tester)), afterVertical);
    expect(monthIndex(container.read(visibleMonthProvider)), afterVertical);

    await tester.drag(
      find.byKey(const ValueKey('month-pointer-navigation')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(monthIndex(container.read(visibleMonthProvider)), afterVertical + 1);
    expect(monthIndex(shownMonth(tester)), afterVertical + 1);

    await setMode(tester, container, MonthNavigationMode.vertical);
    expect(monthIndex(container.read(visibleMonthProvider)), afterVertical + 1);
    expect(monthIndex(shownMonth(tester)), afterVertical + 1);
  });
}
