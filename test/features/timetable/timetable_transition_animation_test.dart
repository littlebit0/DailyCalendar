import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = AcademicProfile(
  universityId: 'academyinfo:0000117',
  universityName: '상명대학교',
  schoolKind: 'fourYear',
);

class _SilentAuth extends GoogleDriveAuthService {
  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async => null;
}

final _switcher = find.byKey(const ValueKey('calendar-content-switcher'));
final _toolbar = find.byWidgetPredicate(
  (widget) => <Key>{
    const ValueKey('macos-calendar-toolbar'),
    const ValueKey('ios-calendar-toolbar'),
    const ValueKey('android-calendar-toolbar'),
  }.contains(widget.key),
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  TargetPlatform platform, {
  AcademicProfile? profile = _profile,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = switch (platform) {
    TargetPlatform.iOS || TargetPlatform.android => const Size(393, 852),
    _ => const Size(1000, 800),
  };
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
        appSettingsProvider.overrideWith(
          (_) => settings.load().copyWith(
            academicProfile: profile,
            defaultCalendarView: CalendarViewMode.month,
            weekDayLayoutMode: WeekDayLayoutMode.schedule,
          ),
        ),
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

Future<void> _unmount(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  debugDefaultTargetPlatformOverride = null;
}

Future<void> _choose(WidgetTester tester, int identity) async {
  if (identity == -1 || identity == 0) {
    await tester.tap(find.byTooltip(identity == -1 ? '시간표' : '빠른 보기'));
    return;
  }
  final segmented = find.byType(SegmentedButton<CalendarViewMode>);
  if (segmented.evaluate().isNotEmpty) {
    await tester.tap(
      find.descendant(
        of: segmented,
        matching: find.text(const {1: '주', 2: '월', 3: '일'}[identity]!),
      ),
    );
  } else {
    await tester.tap(
      find.byTooltip(const {1: '주간', 2: '월간', 3: '일간'}[identity]!),
    );
  }
}

List<SlideTransition> _slides(WidgetTester tester) => tester
    .widgetList<SlideTransition>(
      find.descendant(of: _switcher, matching: find.byType(SlideTransition)),
    )
    .where((slide) => slide.child?.key is ValueKey<int>)
    .toList();

double _offset(WidgetTester tester, int identity) => _slides(tester)
    .singleWhere((slide) => slide.child?.key == ValueKey<int>(identity))
    .position
    .value
    .dx;

void _assertToolbarOutsideMotion(WidgetTester tester, Rect original) {
  expect(find.descendant(of: _switcher, matching: _toolbar), findsNothing);
  final current = tester.getRect(_toolbar);
  expect(current.topLeft, original.topLeft);
  expect(current.width, original.width);
  if (find
      .byKey(const ValueKey('macos-calendar-toolbar'))
      .evaluate()
      .isNotEmpty) {
    expect(current, original);
  }
}

Future<void> _assertMoving(
  WidgetTester tester, {
  required int from,
  required int to,
  required int direction,
  required Rect toolbar,
  required Element switcherElement,
}) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
  expect(tester.element(_switcher), same(switcherElement));
  _assertToolbarOutsideMotion(tester, toolbar);
  final destinationToolbar = tester.getRect(_toolbar);
  final incoming = _offset(tester, to);
  final outgoing = _offset(tester, from);
  expect(incoming * direction, inExclusiveRange(0, 1));
  expect(outgoing * -direction, inExclusiveRange(0, 1));
  await tester.pump(const Duration(milliseconds: 45));
  expect(_offset(tester, to).abs(), lessThan(incoming.abs()));
  expect(_offset(tester, from).abs(), greaterThan(outgoing.abs()));
  expect(tester.getRect(_toolbar), destinationToolbar);
  await tester.pumpAndSettle();
  final settled = _slides(tester);
  expect(settled, hasLength(1));
  expect(settled.single.child?.key, ValueKey<int>(to));
  expect(settled.single.position.value, Offset.zero);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      '$platform timetable slides both ways with quick, week, month and day',
      (tester) async {
        final container = await _mount(tester, platform);
        final selectedDate = container.read(selectedDateProvider);
        final switcherElement = tester.element(_switcher);
        final toolbar = tester.getRect(_toolbar);
        final mobile =
            platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android;
        for (final other in [0, 1, 2, 3]) {
          await _choose(tester, other);
          await tester.pumpAndSettle();
          await _choose(tester, -1);
          await _assertMoving(
            tester,
            from: other,
            to: -1,
            direction: mobile ? 1 : -1,
            toolbar: toolbar,
            switcherElement: switcherElement,
          );
          expect(find.byType(TimetablePage), findsOneWidget);
          await _choose(tester, other);
          await _assertMoving(
            tester,
            from: -1,
            to: other,
            direction: mobile ? -1 : 1,
            toolbar: toolbar,
            switcherElement: switcherElement,
          );
          expect(find.byType(TimetablePage), findsNothing);
          expect(container.read(selectedDateProvider), selectedDate);
        }
        await _unmount(tester);
      },
    );
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    for (final profile in <AcademicProfile?>[
      null,
      const AcademicProfile(
        universityId: 'unsupported',
        universityName: '다른 대학교',
        schoolKind: 'fourYear',
      ),
    ]) {
      testWidgets('$platform academic gate slides in and out for $profile', (
        tester,
      ) async {
        await _mount(tester, platform, profile: profile);
        final switcherElement = tester.element(_switcher);
        final toolbar = tester.getRect(_toolbar);
        final direction = platform == TargetPlatform.iOS ? 1 : -1;
        await _choose(tester, -1);
        await _assertMoving(
          tester,
          from: 2,
          to: -1,
          direction: direction,
          toolbar: toolbar,
          switcherElement: switcherElement,
        );
        expect(
          find.byKey(const ValueKey('academic-profile-open')),
          findsOneWidget,
        );
        expect(find.byType(TimetablePage), findsNothing);
        await _choose(tester, 0);
        await _assertMoving(
          tester,
          from: -1,
          to: 0,
          direction: -direction,
          toolbar: toolbar,
          switcherElement: switcherElement,
        );
        expect(
          find.byKey(const ValueKey('academic-profile-open')),
          findsNothing,
        );
        await _unmount(tester);
      });
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform AI action animates timetable back to calendar', (
      tester,
    ) async {
      await _mount(tester, platform);
      await _choose(tester, -1);
      await tester.pumpAndSettle();
      final switcherElement = tester.element(_switcher);
      final toolbar = tester.getRect(_toolbar);
      await tester.tap(
        find.byTooltip(platform == TargetPlatform.android ? 'LLM' : 'Siri'),
      );
      await _assertMoving(
        tester,
        from: -1,
        to: 2,
        direction: -1,
        toolbar: toolbar,
        switcherElement: switcherElement,
      );
      expect(find.byTooltip('AI 입력 닫기'), findsOneWidget);
      expect(find.byType(TimetablePage), findsNothing);
      await _unmount(tester);
    });
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('$platform rapid reversal settles on a single timetable', (
      tester,
    ) async {
      await _mount(tester, platform);
      final switcherElement = tester.element(_switcher);
      final toolbar = tester.getRect(_toolbar);
      for (final identity in [-1, 0, -1, 3, -1]) {
        await _choose(tester, identity);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        expect(tester.element(_switcher), same(switcherElement));
        _assertToolbarOutsideMotion(tester, toolbar);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(_slides(tester), hasLength(1));
      expect(_slides(tester).single.child?.key, const ValueKey<int>(-1));
      expect(_slides(tester).single.position.value, Offset.zero);
      expect(find.byType(TimetablePage), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await _unmount(tester);
    });
  }

  testWidgets('resizing across toolbar layouts preserves timetable identity', (
    tester,
  ) async {
    await _mount(tester, TargetPlatform.android);
    await _choose(tester, -1);
    await tester.pumpAndSettle();
    final switcherElement = tester.element(_switcher);
    final timetableState = tester.state(find.byType(TimetablePage));
    for (final size in [const Size(1100, 800), const Size(393, 852)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.element(_switcher), same(switcherElement));
      expect(tester.state(find.byType(TimetablePage)), same(timetableState));
      expect(_slides(tester), hasLength(1));
      expect(_slides(tester).single.child?.key, const ValueKey<int>(-1));
      expect(_slides(tester).single.position.value, Offset.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    }
    final toolbar = tester.getRect(_toolbar);
    await _choose(tester, 0);
    await _assertMoving(
      tester,
      from: -1,
      to: 0,
      direction: -1,
      toolbar: toolbar,
      switcherElement: switcherElement,
    );
    await _unmount(tester);
  });
}
