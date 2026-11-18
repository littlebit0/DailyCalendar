import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
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

// #965: the search panel is page state, not a route, so Android's back button
// popped the root route and left the app instead of closing the panel.
void main() {
  testWidgets(
    'back closes the open search panel and only then leaves the app',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 860);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var appExits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') appExits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
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

      await tester.tap(find.byTooltip('검색').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('검색 닫기'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip('검색 닫기'), findsNothing);
      expect(find.byType(MonthCalendarPage), findsOneWidget);
      expect(appExits, 0);

      // Nothing left to close: back behaves as before and leaves the app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appExits, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
