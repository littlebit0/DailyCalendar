import 'dart:io';

import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:daily/features/timetable/presentation/weekly_timetable_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  for (final height in [350.0, 430.0]) {
    for (final missingPeriod in [false, true]) {
      testWidgets('320x$height with 2x text keeps course search usable '
          '${missingPeriod ? 'without' : 'with'} semester dates', (
        tester,
      ) async {
        tester.view.physicalSize = Size(320, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final repo = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        await repo.timetableStore.selectTerm(missingPeriod ? 2028 : 2026, '2');
        if (!missingPeriod) {
          await repo.timetableStore.setTermPeriod(
            2026,
            '2',
            TimetablePeriod(
              start: DateTime(2026, 9, 1),
              end: DateTime(2026, 12, 21),
            ),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: DailyTheme.light(),
              locale: const Locale('ko'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: TimetablePage(
                  loadCatalog: () =>
                      UniversityCatalog.load(bundle: _FileBundle()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repo.timetableStore.activePeriod == null, missingPeriod);

        await tester.tap(find.byKey(const ValueKey('timetable-search')));
        await tester.pumpAndSettle();
        final grid = find.byType(WeeklyTimetableGrid);
        final panel = find.byType(UniversityCoursePanel);
        expect(tester.getRect(panel).height, greaterThanOrEqualTo(180));
        expect(grid, findsNothing);
        expect(find.byType(UniversityCoursePage), findsOneWidget);
        expect(tester.takeException(), isNull);

        final search = find.byKey(const ValueKey('course-search'));
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        expect(tester.getRect(search).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(search).bottom, lessThanOrEqualTo(height));
        await tester.tap(search);
        await tester.enterText(search, 'HAAA6005');
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(search).controller!.text, 'HAAA6005');
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('timetable-week-toggle'));
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byType(UniversityCoursePanel), findsNothing);
        expect(tester.widget<WeeklyTimetableGrid>(grid).showDates, isTrue);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(tester.widget<WeeklyTimetableGrid>(grid).showDates, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
