import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _supportedProfile = AcademicProfile(
  universityId: 'academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
  campus: '서울캠퍼스',
);

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

Finder _toolbarAction(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is DailyIconAction && widget.tooltip == tooltip,
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  TargetPlatform platform,
  Size size, {
  AcademicProfile? profile = _supportedProfile,
}) async {
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
  final auth = _SilentAuth();
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
        appSettingsProvider.overrideWith(
          (_) => settings.load().copyWith(
            academicProfile: profile,
            weekDayLayoutMode: WeekDayLayoutMode.schedule,
          ),
        ),
        timetableStoreProvider.overrideWithValue(settings.timetableStore),
        eventsInRangeProvider.overrideWith(
          (_, _) => Stream.value(const <CalendarEvent>[]),
        ),
        googleDriveAuthServiceProvider.overrideWithValue(auth),
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
  return ProviderScope.containerOf(
    tester.element(find.byType(MonthCalendarPage)),
  );
}

Future<void> _openTimetable(WidgetTester tester) async {
  await tester.tap(find.byTooltip('시간표'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('timetable-primary-title')), findsOneWidget);
  expect(find.byType(BackButton), findsNothing);
  expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
  expect(find.byKey(const ValueKey('calendar-period-button')), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> _chooseView(WidgetTester tester, CalendarViewMode mode) async {
  final switcher = find.byType(SegmentedButton<CalendarViewMode>);
  if (switcher.evaluate().isNotEmpty) {
    final widget = tester.widget<SegmentedButton<CalendarViewMode>>(switcher);
    expect(widget.selected, isEmpty);
    final label = switch (mode) {
      CalendarViewMode.week => '주',
      CalendarViewMode.month => '월',
      CalendarViewMode.day => '일',
    };
    await tester.tap(find.descendant(of: switcher, matching: find.text(label)));
  } else {
    await tester.tap(
      find.byTooltip(switch (mode) {
        CalendarViewMode.week => '주간',
        CalendarViewMode.month => '월간',
        CalendarViewMode.day => '일간',
      }),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.macOS, const Size(1000, 800)),
    (TargetPlatform.windows, const Size(1000, 800)),
    (TargetPlatform.linux, const Size(1000, 800)),
    (TargetPlatform.iOS, const Size(393, 852)),
    (TargetPlatform.android, const Size(393, 852)),
    (TargetPlatform.iOS, const Size(1024, 768)),
    (TargetPlatform.android, const Size(1024, 768)),
  ]) {
    testWidgets(
      '$platform $size timetable keeps views, quick view and settings reachable',
      (tester) async {
        final container = await _mount(tester, platform, size);
        final initialDate = container.read(selectedDateProvider);
        for (final mode in CalendarViewMode.values) {
          await _openTimetable(tester);
          expect(find.byKey(const ValueKey('timetable-page')), findsOneWidget);
          await _chooseView(tester, mode);
          expect(container.read(calendarViewModeProvider), mode);
          expect(container.read(selectedDateProvider), initialDate);
          expect(find.byKey(const ValueKey('timetable-page')), findsNothing);
          expect(
            find.byKey(const ValueKey('calendar-period-button')),
            findsOneWidget,
          );
        }

        await _openTimetable(tester);
        await tester.tap(find.byTooltip('빠른 보기'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('quick-view-list')), findsOneWidget);
        expect(find.byKey(const ValueKey('timetable-page')), findsNothing);

        await _openTimetable(tester);
        await tester.tap(find.byTooltip('설정'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        Navigator.of(tester.element(find.byType(SettingsPage))).pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('timetable-page')), findsOneWidget);
        expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final profile in <AcademicProfile?>[
    null,
    const AcademicProfile(
      universityId: 'other-university',
      universityName: '다른 대학교',
      schoolKind: 'fourYear',
    ),
  ]) {
    testWidgets('academic gate still allows leaving timetable: $profile', (
      tester,
    ) async {
      final container = await _mount(
        tester,
        TargetPlatform.macOS,
        const Size(900, 700),
        profile: profile,
      );
      await _openTimetable(tester);
      expect(find.byKey(const ValueKey('timetable-page')), findsNothing);
      await _chooseView(tester, CalendarViewMode.month);
      expect(container.read(calendarViewModeProvider), CalendarViewMode.month);
      expect(
        find.byKey(const ValueKey('calendar-period-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final (profile, university, campus) in const [
    (
      AcademicProfile(
        universityId: 'institution:academyinfo:0000082',
        universityName: '단국대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0002726',
      ),
      'dku',
      'cheonan',
    ),
    (
      AcademicProfile(
        universityId: 'institution:academyinfo:0000023',
        universityName: '전남대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000024',
      ),
      'jnu',
      'yeosu',
    ),
  ]) {
    testWidgets('search route follows the saved $university profile', (
      tester,
    ) async {
      await _mount(
        tester,
        TargetPlatform.macOS,
        const Size(1000, 800),
        profile: profile,
      );
      await _openTimetable(tester);
      await tester.tap(find.byKey(const ValueKey('timetable-search')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final search = tester.widget<UniversityCoursePage>(
        find.byType(UniversityCoursePage),
      );
      expect(search.university, university);
      expect(search.initialCampus, campus);
      expect(find.byTooltip('설정'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timetable-primary-title')),
        findsOneWidget,
      );
      expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'timetable header keeps compact geometry across resize and text scale',
    (tester) async {
      await _mount(tester, TargetPlatform.macOS, const Size(1000, 800));
      await _openTimetable(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in [
        const Size(600, 500),
        const Size(900, 390),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final header = tester.getRect(
          find.byKey(const ValueKey('macos-calendar-toolbar')),
        );
        final settings = tester.getRect(find.byTooltip('설정'));
        expect(header.height, lessThan(76));
        expect(settings.right, lessThanOrEqualTo(size.width));
        expect(settings.top, greaterThanOrEqualTo(header.top));
        expect(settings.bottom, lessThanOrEqualTo(header.bottom));
        expect(
          tester.getRect(_toolbarAction('설정')).right,
          closeTo(header.right - 14, .01),
        );
        expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
        expect(find.byTooltip('빠른 보기').hitTestable(), findsOneWidget);
        expect(
          find.byType(SegmentedButton<CalendarViewMode>).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'desktop actions stay at the right inset for every primary view',
    (tester) async {
      await _mount(tester, TargetPlatform.macOS, const Size(1440, 900));
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      void expectRightAligned() {
        final header = tester.getRect(
          find.byKey(const ValueKey('macos-calendar-toolbar')),
        );
        final lastAction = tester.getRect(_toolbarAction('설정'));
        expect(lastAction.right, closeTo(header.right - 14, .01));
        final order = [
          if (find.byTooltip('이전').evaluate().isNotEmpty) ...[
            _toolbarAction('이전'),
            _toolbarAction('다음'),
            _toolbarAction('오늘'),
            _toolbarAction('검색'),
            _toolbarAction('검색/필터'),
          ],
          _toolbarAction('Siri'),
          _toolbarAction('시간표'),
          _toolbarAction('빠른 보기'),
          find.byType(SegmentedButton<CalendarViewMode>),
          _toolbarAction('설정'),
        ];
        for (var index = 1; index < order.length; index++) {
          expect(
            tester.getRect(order[index - 1]).right,
            closeTo(tester.getRect(order[index]).left, .01),
            reason: 'toolbar actions must be contiguous and ordered',
          );
        }
        expect(find.byTooltip('Siri').hitTestable(), findsOneWidget);
        expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      for (final scale in [1.0, 1.8]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final size in [
          const Size(720, 500),
          const Size(900, 390),
          const Size(1440, 900),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          for (final mode in CalendarViewMode.values) {
            await _openTimetable(tester);
            expectRightAligned();
            await _chooseView(tester, mode);
            expectRightAligned();
          }
          await tester.tap(find.byTooltip('빠른 보기'));
          await tester.pumpAndSettle();
          expectRightAligned();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
