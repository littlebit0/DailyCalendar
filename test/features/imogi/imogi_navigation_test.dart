import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:flutter/foundation.dart';
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

Future<SettingsRepository> _mount(
  WidgetTester tester,
  TargetPlatform platform,
  Size size,
) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsRepository(
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
        theme: DailyTheme.light().copyWith(platform: platform),
        home: const MonthCalendarPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

String? _badge(WidgetTester tester) {
  final badge = tester.widget<Badge>(
    find.byKey(const ValueKey('imogi-tab-badge')),
  );
  if (!badge.isLabelVisible) return null;
  return (badge.label! as Text).data;
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.iOS, const Size(375, 667)),
    (TargetPlatform.android, const Size(393, 852)),
    (TargetPlatform.macOS, const Size(1000, 800)),
  ]) {
    testWidgets('$platform imogi tab adds items and tracks the open badge', (
      tester,
    ) async {
      final settings = await _mount(tester, platform, size);
      expect(_badge(tester), isNull);

      await tester.tap(find.byTooltip('잊모기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('imogi-primary-title')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-period-button')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('imogi-quick-add')),
        '택배 반품하기',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('택배 반품하기'), findsOneWidget);
      expect(_badge(tester), '1');

      final item = settings.imogiStore.items.single;
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('imogi-item-${item.id}')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.imogiStore.openCount, 0);
      expect(_badge(tester), isNull);
      expect(find.text('완료한 잊모기 1개'), findsOneWidget);

      // Leaving the tab restores the calendar without listing imogi there.
      final views = find.byType(SegmentedButton<CalendarViewMode>);
      if (views.evaluate().isNotEmpty) {
        await tester.tap(find.descendant(of: views, matching: find.text('월')));
      } else {
        await tester.tap(find.byTooltip('월간'));
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-period-button')),
        findsOneWidget,
      );
      expect(find.text('택배 반품하기'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
