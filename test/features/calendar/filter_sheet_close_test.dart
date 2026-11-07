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

final _android = TargetPlatformVariant.only(TargetPlatform.android);

// #775: closing the sheet while it is still animating out used to rebuild
// its search field after the field's controller had been disposed.
void main() {
  late SettingsRepository settings;
  late ProviderContainer container;

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
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
          theme: DailyTheme.light(),
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
    // The search field autofocuses: the keyboard comes up.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(TextField), findsOneWidget);
  }

  /// Runs the exit animation frame by frame while the keyboard goes down and
  /// the settings change, both of which rebuild the closing sheet.
  Future<void> closeWith(
    WidgetTester tester,
    Future<void> Function() dismiss,
  ) async {
    await dismiss();
    tester.view.viewInsets = FakeViewPadding.zero;
    for (var i = 0; i < 40; i++) {
      if (i == 3) {
        container.read(appSettingsProvider.notifier).state = settings
            .load()
            .copyWith();
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $i');
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(MonthCalendarPage), findsOneWidget);
  }

  testWidgets('closing with X does not reuse a disposed controller', (
    tester,
  ) async {
    await openSheet(tester);
    await closeWith(tester, () => tester.tap(find.byTooltip('닫기')));
  }, variant: _android);

  testWidgets('closing with 완료 does not reuse a disposed controller', (
    tester,
  ) async {
    await openSheet(tester);
    await closeWith(tester, () async {
      await tester.ensureVisible(find.text('완료'));
      await tester.tap(find.text('완료'));
    });
  }, variant: _android);

  testWidgets('closing by tapping outside does not reuse a disposed '
      'controller', (tester) async {
    await openSheet(tester);
    await closeWith(tester, () => tester.tapAt(const Offset(200, 10)));
  }, variant: _android);

  // The sheet's list is the primary scroll view and always takes vertical
  // drags, so the sheet is not dragged closed; Android's back closes it.
  testWidgets('closing with the back button does not reuse a disposed '
      'controller', (tester) async {
    await openSheet(tester);
    await closeWith(tester, () => tester.binding.handlePopRoute());
  }, variant: _android);

  testWidgets('a typed query is kept after closing', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), ' 회의 ');
    await closeWith(tester, () => tester.tap(find.byTooltip('닫기')));
    expect(container.read(calendarSearchQueryProvider), '회의');
  }, variant: _android);
}
