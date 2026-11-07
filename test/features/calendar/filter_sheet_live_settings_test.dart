import 'dart:async';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

// The sheet's search field blinks its cursor, so it never settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [future] completes, so queued saves and frames both run.
Future<void> _until(WidgetTester tester, Future<Object?> future) async {
  var done = false;
  unawaited(future.whenComplete(() => done = true));
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done, isTrue, reason: 'save did not finish');
  await future;
  await _frames(tester);
}

final _macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  late SettingsRepository settings;
  late ProviderContainer container;

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'daily.test',
      version: '3.5.2',
      buildNumber: '352',
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
          theme: DailyTheme.light().copyWith(platform: TargetPlatform.macOS),
          home: const MonthCalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(MonthCalendarPage)),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is DailyIconAction && widget.tooltip == '검색/필터',
      ),
    );
    await _frames(tester);
  }

  // Stands in for a Drive restore or another screen: stored, then published.
  Future<void> externally(
    WidgetTester tester,
    Future<void> Function() change,
  ) async {
    await _until(tester, change());
    container.read(appSettingsProvider.notifier).state = settings.load();
    await _frames(tester);
  }

  FilterChip chip(WidgetTester tester, String id) {
    final category = settings.load().categories.firstWhere((c) => c.id == id);
    final label = tester
        .element(find.byType(MonthCalendarPage))
        .l10n
        .categoryName(id: category.id, label: category.label);
    return tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
  }

  Set<String> storedHidden() => settings.load().hiddenCategoryIds.toSet();

  Future<void> toggle(WidgetTester tester, String id) async {
    final hide = chip(tester, id).selected;
    chip(tester, id).onSelected!(!hide);
    // The sheet's save runs in the settings queue; wait for it to land.
    await _until(
      tester,
      Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return storedHidden().contains(id) != hide;
      }),
    );
  }

  testWidgets('an open sheet follows and keeps external hide changes', (
    tester,
  ) async {
    await openSheet(tester);
    final ids = settings.load().categories.map((c) => c.id).toList();
    final a = ids[0];
    final b = ids[1];
    expect(chip(tester, a).selected, isTrue);

    await externally(tester, () => settings.setCategoryHidden(a, true));
    expect(chip(tester, a).selected, isFalse);

    await toggle(tester, b);
    expect(storedHidden(), {a, b});
    expect(chip(tester, a).selected, isFalse);
    expect(chip(tester, b).selected, isFalse);

    await externally(tester, () => settings.setCategoryHidden(a, false));
    expect(chip(tester, a).selected, isTrue);

    await toggle(tester, b);
    expect(storedHidden(), isEmpty, reason: 'A must not be hidden again');
    expect(chip(tester, b).selected, isTrue);
  }, variant: _macOS);

  testWidgets('repeated and concurrent toggles all land', (tester) async {
    await openSheet(tester);
    final ids = settings.load().categories.map((c) => c.id).toList();
    final a = ids[0];
    final b = ids[1];
    final onA = chip(tester, a).onSelected!;
    final onB = chip(tester, b).onSelected!;
    // Fired back to back, before any of the saves completes.
    onA(false);
    onB(false);
    onB(true);
    onB(false);
    await _until(
      tester,
      Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return storedHidden().length != 2;
      }),
    );
    await _until(
      tester,
      Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    expect(storedHidden(), {a, b});
    expect(chip(tester, a).selected, isFalse);
    expect(chip(tester, b).selected, isFalse);
  }, variant: _macOS);

  testWidgets('display switches follow external changes', (tester) async {
    await openSheet(tester);
    SwitchListTile tile(String title) => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, title),
    );
    final holidays = settings.load().calendarShowHolidays;
    expect(tile('공휴일 표시').value, holidays);
    await externally(
      tester,
      () => settings.save(
        settings.load().copyWith(
          calendarShowHolidays: !holidays,
          calendarDdayOnly: true,
        ),
      ),
    );
    expect(tile('공휴일 표시').value, !holidays);
    expect(tile('D-day 일정만 보기').value, isTrue);
  }, variant: _macOS);
}
