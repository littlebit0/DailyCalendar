import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/weather/weather_controller.dart';
import 'package:daily/core/weather/weather_store.dart';
import 'package:daily/core/weather/weather_widgets.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:daily/features/settings/presentation/weather_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/weather_test.dart' as fixture;

void main() {
  setUpAll(() async {
    for (final locale in ['ko', 'en', 'ja', 'zh_TW']) {
      await initializeDateFormatting(locale);
    }
  });
  for (final size in [
    const Size(320, 740),
    const Size(393, 850),
    const Size(1100, 850),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'weather in month/week/day remains within $size $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final service = fixture.TestWeatherService();
          final controller = WeatherController(
            store: await fixture.weatherStore(
              const WeatherSettings(enabled: true, regionId: '1100000000'),
            ),
            service: service,
            location: fixture.TestWeatherLocation(),
            clock: () => fixture.weatherClock,
          );
          await controller.refresh();
          addTearDown(controller.dispose);
          for (final locale in AppLocalizations.supportedLocales) {
            final date = DateTime(2026, 9, 11);
            final views = <Widget>[
              CalendarMonthGrid(
                month: DateTime(2026, 9),
                selectedDate: date,
                events: const [],
                weekStartsOnMonday: false,
                showLunarDates: true,
                onDateSelected: (_) {},
              ),
              ScheduleTimelineView(
                days: [for (var d = 6; d <= 12; d++) DateTime(2026, 9, d)],
                events: const [],
                selectedDate: date,
                use24HourTime: true,
                showAllDayEvents: true,
                holidayBackgroundEnabled: false,
                holidayColorValue: 0xffef4444,
                onShowAllDayEventsChanged: (_) {},
                onDateSelected: (_) {},
              ),
              ScheduleTimelineView(
                days: [date],
                events: const [],
                selectedDate: date,
                use24HourTime: true,
                showAllDayEvents: true,
                showDateHeader: false,
                holidayBackgroundEnabled: false,
                holidayColorValue: 0xffef4444,
                onShowAllDayEventsChanged: (_) {},
                onDateSelected: (_) {},
              ),
              CalendarWeather(date: date, detailed: true),
            ];
            for (final view in views) {
              await tester.pumpWidget(
                _app(controller, view, locale, brightness),
              );
              await tester.pumpAndSettle();
              final weather = find.byKey(const ValueKey('weather-2026-9-11'));
              expect(weather, findsOneWidget);
              final rect = tester.getRect(weather);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
              expect(tester.takeException(), isNull);
            }
          }
          expect(service.requests, 1);
          await controller.configure(
            controller.settings.copyWith(enabled: false),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('weather-2026-9-11')), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'settings region search and weather toggle work without location permission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final location = fixture.TestWeatherLocation();
      final service = fixture.TestWeatherService();
      final controller = WeatherController(
        store: await fixture.weatherStore(),
        service: service,
        location: location,
        clock: () => fixture.weatherClock,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [weatherControllerProvider.overrideWithValue(controller)],
          child: _app(
            controller,
            const WeatherSettingsPage(),
            const Locale('ko'),
            Brightness.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      await tester.tap(find.byKey(const ValueKey('weather-region')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('weather-region-search')),
        '부산',
      );
      await tester.pumpAndSettle();
      expect(find.text('서울특별시'), findsNothing);
      await tester.tap(find.text('부산광역시'));
      await tester.pumpAndSettle();
      expect(controller.settings.regionId, fixture.busan.id);
      expect(service.requests, 0);
      await tester.tap(find.byKey(const ValueKey('weather-enabled')));
      await tester.pumpAndSettle();
      expect(controller.settings.enabled, isTrue);
      expect(controller.region?.id, fixture.busan.id);
      expect(location.permissionRequests, isEmpty);
      expect(service.requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _app(
  WeatherController controller,
  Widget child,
  Locale locale,
  Brightness brightness,
) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  theme: brightness == Brightness.dark ? DailyTheme.dark() : DailyTheme.light(),
  builder: (context, child) => WeatherScope(
    controller: controller,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
  ),
  home: Scaffold(body: child),
);
