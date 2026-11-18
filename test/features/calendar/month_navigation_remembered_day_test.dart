import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
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

// #963: month navigation clamps the selected day to shorter months but keeps
// the day the user picked, so Jan 31 -> Feb 28 -> Jan 31.
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

  Future<void> select(
    WidgetTester tester,
    ProviderContainer container,
    DateTime date,
  ) async {
    container.read(visibleMonthProvider.notifier).state = DateTime(
      date.year,
      date.month,
    );
    container.read(selectedDateProvider.notifier).state = date;
    await tester.pumpAndSettle();
  }

  Future<DateTime> move(
    WidgetTester tester,
    ProviderContainer container,
    int delta,
  ) async {
    await tester.drag(
      find.byKey(const ValueKey('month-pointer-navigation')),
      Offset(delta > 0 ? -300 : 300, 0),
    );
    await tester.pumpAndSettle();
    return container.read(selectedDateProvider);
  }

  Future<void> tapDay(WidgetTester tester, DateTime day) async {
    await tester.tap(
      find.byKey(ValueKey('day-cell-${day.year}-${day.month}-${day.day}')),
    );
    await tester.pumpAndSettle();
    // Close the day sheet a narrow window opens for the tapped date.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('month moves restore the picked month-end day', (tester) async {
    final container = await pumpCalendar(tester);
    await select(tester, container, DateTime(2026, 1, 31));

    expect(await move(tester, container, 1), DateTime(2026, 2, 28));
    expect(await move(tester, container, 1), DateTime(2026, 3, 31));
    expect(await move(tester, container, 1), DateTime(2026, 4, 30));
    expect(await move(tester, container, -1), DateTime(2026, 3, 31));
    expect(await move(tester, container, -1), DateTime(2026, 2, 28));
    expect(await move(tester, container, -1), DateTime(2026, 1, 31));
  });

  testWidgets('leap February shows the 29th and keeps the picked day', (
    tester,
  ) async {
    final container = await pumpCalendar(tester);
    await select(tester, container, DateTime(2028, 1, 31));
    expect(await move(tester, container, 1), DateTime(2028, 2, 29));
    expect(await move(tester, container, 1), DateTime(2028, 3, 31));

    await select(tester, container, DateTime(2028, 2, 29));
    expect(await move(tester, container, 1), DateTime(2028, 3, 29));
    expect(await move(tester, container, 1), DateTime(2028, 4, 29));
    expect(await move(tester, container, -1), DateTime(2028, 3, 29));
    expect(await move(tester, container, -1), DateTime(2028, 2, 29));
  });

  testWidgets('a directly picked day replaces the remembered day', (
    tester,
  ) async {
    final container = await pumpCalendar(tester);
    await select(tester, container, DateTime(2026, 1, 31));
    expect(await move(tester, container, 1), DateTime(2026, 2, 28));

    // Picking the shown clamped date itself also counts as a new pick.
    await tapDay(tester, DateTime(2026, 2, 28));
    expect(container.read(selectedDateProvider), DateTime(2026, 2, 28));
    expect(await move(tester, container, 1), DateTime(2026, 3, 28));

    await tapDay(tester, DateTime(2026, 3, 15));
    expect(await move(tester, container, -1), DateTime(2026, 2, 15));
    expect(await move(tester, container, -1), DateTime(2026, 1, 15));
  });

  testWidgets('Today replaces the remembered day', (tester) async {
    final container = await pumpCalendar(tester);
    await select(tester, container, DateTime(2026, 1, 31));
    expect(await move(tester, container, 1), DateTime(2026, 2, 28));

    await tester.tap(find.byTooltip('오늘'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(container.read(selectedDateProvider), today);

    final next = DateTime(today.year, today.month + 1);
    final nextLast = DateUtils.getDaysInMonth(next.year, next.month);
    expect(
      await move(tester, container, 1),
      DateTime(
        next.year,
        next.month,
        today.day > nextLast ? nextLast : today.day,
      ),
    );
    expect(await move(tester, container, -1), today);
  });
}
