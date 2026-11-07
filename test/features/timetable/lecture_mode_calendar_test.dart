import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/presentation/timetable_schedule.dart';
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

final _today = DateUtils.dateOnly(DateTime.now());

Future<SettingsRepository> _settings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsRepository(preferences: await SharedPreferences.getInstance());
}

/// A term around today with one weekly class meeting on today's weekday.
Future<TimetableStore> _seed(
  SettingsRepository settings, {
  LectureMode defaultMode = LectureMode.inPerson,
}) async {
  final store = settings.timetableStore;
  await store.selectTerm(_today.year, '2');
  await store.setTermPeriod(
    _today.year,
    '2',
    TimetablePeriod(
      start: _today.subtract(const Duration(days: 60)),
      end: _today.add(const Duration(days: 60)),
    ),
  );
  await store.save(
    TimetableClass(
      id: 'class',
      title: '자료구조',
      academicYear: _today.year,
      semester: '2',
      defaultMode: defaultMode,
      meetings: [
        ClassMeeting(
          id: 'm',
          weekday: _today.weekday,
          startMinute: 540,
          endMinute: 615,
        ),
      ],
    ),
  );
  return store;
}

Widget _localized(Widget home, {bool dark = false}) => MaterialApp(
  locale: const Locale('ko'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: dark ? DailyTheme.dark() : DailyTheme.light(),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only meetings whose mode differs from the default are changes, '
      'and only inside the term', () async {
    final settings = await _settings();
    final store = await _seed(settings, defaultMode: LectureMode.video);
    expect(lectureModeChangeOccurrences(store, [_today]), isEmpty);
    // Same as the default: not a change.
    await store.setOverride('class', 'm', _today, LectureMode.video);
    expect(lectureModeChangeOccurrences(store, [_today]), isEmpty);
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.cancelled,
    ]) {
      await store.setOverride('class', 'm', _today, mode);
      expect(lectureModeChangeOccurrences(store, [_today]).single.mode, mode);
    }
    await store.setTermPeriod(
      _today.year,
      '2',
      TimetablePeriod(
        start: _today.add(const Duration(days: 1)),
        end: _today.add(const Duration(days: 60)),
      ),
    );
    expect(lectureModeChangeOccurrences(store, [_today]), isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'day panel lists a lecture-mode change, opens the occurrence and '
      'drops it on revert or delete (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final settings = await _settings();
        final store = await _seed(settings);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              timetableStoreProvider.overrideWithValue(store),
              eventsInRangeProvider.overrideWith(
                (_, _) => Stream.value(const <CalendarEvent>[]),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: _localized(
                Scaffold(
                  body: EventDetailsPanel(date: _today, events: const []),
                ),
                dark: dark,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('자료구조'), findsNothing);

        for (final (mode, title) in [
          (LectureMode.video, '자료구조 영상 강의'),
          (LectureMode.cancelled, '자료구조 휴강'),
          (LectureMode.liveOnline, '자료구조 실시간 비대면 강의'),
        ]) {
          await store.setOverride('class', 'm', _today, mode);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('자료구조 실시간 비대면 강의'));
        await tester.pumpAndSettle();
        expect(find.text('이번 수업 방식'), findsOneWidget);
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(EventDetailsPanel)),
        );
        container.read(calendarSearchQueryProvider.notifier).state = '자료';
        await tester.pumpAndSettle();
        expect(find.textContaining('자료구조'), findsNothing);
        container.read(calendarSearchQueryProvider.notifier).state = '';
        await tester.pumpAndSettle();
        expect(find.text('자료구조 실시간 비대면 강의'), findsOneWidget);

        await store.setOverride('class', 'm', _today, null);
        await tester.pumpAndSettle();
        expect(find.textContaining('자료구조'), findsNothing);

        await store.setOverride('class', 'm', _today, LectureMode.video);
        await tester.pumpAndSettle();
        expect(find.text('자료구조 영상 강의'), findsOneWidget);
        await store.remove('class');
        await tester.pumpAndSettle();
        expect(find.textContaining('자료구조'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('projections are read-only, unmovable and replace stale copies', (
    tester,
  ) async {
    final settings = await _settings();
    final store = await _seed(settings);
    await store.setOverride('class', 'm', _today, LectureMode.cancelled);
    late List<CalendarEvent> shown;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetableStoreProvider.overrideWithValue(store),
        ],
        child: _localized(
          Builder(
            builder: (context) {
              final first = withLectureModeChanges(context, store, [
                _today,
              ], const []);
              shown = withLectureModeChanges(context, store, [_today], first);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final event = shown.single;
    expect(event.title, '자료구조 휴강');
    expect(event.readOnly && event.systemEvent, isTrue);
    expect(isTimetableProjection(event), isTrue);
    expect(calendarEventCanMove(event), isFalse);
    expect(event.reminderMinutesBeforeList, isEmpty);
  });

  testWidgets('schedule layouts keep plain class blocks while changes are '
      'hidden by search or D-day only', (tester) async {
    final settings = await _settings();
    final store = await _seed(settings);
    await store.setOverride('class', 'm', _today, LectureMode.liveOnline);
    late List<CalendarEvent> rendered;
    Future<void> pump(bool show) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          timetableStoreProvider.overrideWithValue(store),
        ],
        child: _localized(
          TimetableSchedule(
            days: [_today],
            events: const [],
            showLectureModeChanges: show,
            builder: (events, _) {
              rendered = events;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await pump(false);
    expect(rendered.single.title, '자료구조');
    await store.setOverride('class', 'm', _today, LectureMode.cancelled);
    await tester.pump();
    expect(rendered, isEmpty);
    await pump(true);
    expect(rendered.single.title, '자료구조 휴강');
  });

  for (final (platform, size) in [
    (TargetPlatform.iOS, const Size(393, 852)),
    (TargetPlatform.macOS, const Size(1000, 800)),
  ]) {
    testWidgets('month, week and day views show the change in list and '
        'schedule layouts without duplicating the class block '
        '(${platform.name})', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      PackageInfo.setMockInitialValues(
        appName: 'Daily',
        packageName: 'daily.test',
        version: '3.5.2',
        buildNumber: '352',
        buildSignature: '',
      );
      final settings = await _settings();
      final store = await _seed(settings);
      await store.setOverride('class', 'm', _today, LectureMode.video);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            appSettingsProvider.overrideWith(
              (_) => settings.load().copyWith(
                weekDayLayoutMode: WeekDayLayoutMode.list,
              ),
            ),
            timetableStoreProvider.overrideWithValue(store),
            eventsInRangeProvider.overrideWith(
              (_, _) => Stream.value(const <CalendarEvent>[]),
            ),
            googleDriveAuthServiceProvider.overrideWithValue(_SilentAuth()),
          ],
          child: _localized(const MonthCalendarPage()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MonthCalendarPage)),
      );
      const title = '자료구조 영상 강의';

      Future<void> show(CalendarViewMode mode, WeekDayLayoutMode layout) async {
        container.read(calendarViewModeProvider.notifier).state = mode;
        final notifier = container.read(appSettingsProvider.notifier);
        notifier.state = notifier.state.copyWith(weekDayLayoutMode: layout);
        await tester.pumpAndSettle();
      }

      await show(CalendarViewMode.month, WeekDayLayoutMode.list);
      expect(find.textContaining(title), findsWidgets);
      for (final mode in [CalendarViewMode.week, CalendarViewMode.day]) {
        await show(mode, WeekDayLayoutMode.list);
        expect(find.textContaining(title), findsWidgets, reason: '$mode list');
        await show(mode, WeekDayLayoutMode.schedule);
        // One block: the changed class keeps its schedule slot (#771).
        // Wide layouts also list the day in a side panel; count the timeline.
        final timeline = find.byType(ScheduleTimelineView);
        expect(
          find.descendant(of: timeline, matching: find.textContaining(title)),
          findsOneWidget,
          reason: '$mode schedule',
        );
        expect(
          find.descendant(
            of: timeline,
            matching: find.textContaining(RegExp(r'^자료구조($|\n)')),
          ),
          findsNothing,
        );
      }

      await store.setOverride('class', 'm', _today, null);
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      await show(CalendarViewMode.month, WeekDayLayoutMode.list);
      expect(find.text(title), findsNothing);
      expect(find.textContaining('자료구조'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
