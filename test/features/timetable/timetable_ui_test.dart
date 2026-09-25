import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:daily/features/timetable/presentation/weekly_timetable_grid.dart';
import 'package:daily/features/timetable/presentation/timetable_schedule.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SettingsRepository> settings() async {
    SharedPreferences.setMockInitialValues({});
    return SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  }

  Widget app(
    SettingsRepository settings,
    Widget child, {
    bool dark = false,
    bool showNavigation = false,
  }) => ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      appSettingsProvider.overrideWith(
        (_) => settings.load().copyWith(
          academicProfile: const AcademicProfile(
            universityId: 'academyinfo:0000117',
            universityName: '상명대학교',
            schoolKind: 'fourYear',
            campus: '서울캠퍼스',
          ),
        ),
      ),
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
      theme: dark ? DailyTheme.dark() : DailyTheme.light(),
      home: Scaffold(
        body: child,
        bottomNavigationBar: showNavigation
            ? const SizedBox(
                height: 60,
                child: Text('일간 · 주간 · 시간표', key: ValueKey('main-navigation')),
              )
            : null,
      ),
    ),
  );
  testWidgets(
    'saved timetable picker connects to dated view and period editor',
    (tester) async {
      final repo = await settings();
      final store = repo.timetableStore;
      await store.save(
        TimetableClass(
          id: 'old',
          title: '지난 수업',
          academicYear: 2025,
          semester: '겨울',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await store.setTermPeriod(
        2025,
        '겨울',
        TimetablePeriod(start: DateTime(2026, 1, 5), end: DateTime(2026, 1, 5)),
      );
      await store.selectTerm(2026, '2');
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-term-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-term-2025-겨울')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-term-2025-겨울')));
      await tester.pumpAndSettle();
      expect(store.activeYear, 2025);
      expect(store.activeSemester, '겨울');
      WeeklyTimetableGrid grid() =>
          tester.widget(find.byType(WeeklyTimetableGrid));
      expect(grid().occurrences.single.course.id, 'old');
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      expect(grid().occurrences.single.date, DateTime(2026, 1, 5));
      await tester.tap(find.byTooltip('다음 주'));
      await tester.pumpAndSettle();
      expect(grid().occurrences, isEmpty);
      await tester.tap(find.byKey(const ValueKey('timetable-period')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timetable-settings-page')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('timetable-settings-period')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timetable-term-period')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('timetable-term-cancel')));
      await tester.pumpAndSettle();
      expect(store.activePeriod!.end, DateTime(2026, 1, 5));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(grid().days.first, DateTime(2026, 1, 12));
      await tester.tap(find.byKey(const ValueKey('timetable-term-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-picker-close')));
      await tester.pumpAndSettle();
      expect(grid().days.first, DateTime(2026, 1, 12));
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      expect(grid().occurrences.single.course.id, 'old');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown period keeps basic classes but excludes dated occurrences',
    (tester) async {
      final repo = await settings();
      final store = repo.timetableStore;
      await store.selectTerm(2030, '1');
      await store.save(
        TimetableClass(
          id: 'unknown',
          title: '기간 미정 수업',
          academicYear: 2030,
          semester: '1',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
          ],
        ),
      );
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('기간을 설정하면'), findsOneWidget);
      expect(
        tester
            .widget<WeeklyTimetableGrid>(find.byType(WeeklyTimetableGrid))
            .occurrences,
        hasLength(1),
      );
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeeklyTimetableGrid>(find.byType(WeeklyTimetableGrid))
            .occurrences,
        isEmpty,
      );
      expect(store.classes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manual class persists after leaving editor', (tester) async {
    final repo = await settings();
    await tester.pumpWidget(app(repo, const TimetablePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timetable-add')));
    await tester.pumpAndSettle();
    final popup = find.byKey(const ValueKey('class-editor-popup'));
    expect(popup, findsOneWidget);
    expect(ModalRoute.of(tester.element(popup)), isA<DialogRoute<void>>());
    expect(tester.getRect(popup), tester.getRect(find.byType(Navigator).first));
    expect(find.byTooltip('닫기'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('class-title')), '자료구조');
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('class-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('class-save')));
    await tester.pumpAndSettle();
    expect(repo.timetableStore.classes.single.title, '자료구조');
    expect(find.byKey(const ValueKey('timetable-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'class popup offers only half-hour times, accepts midnight and cancels without saving',
    (tester) async {
      final repo = await settings();
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-add')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('월 09:00 – 10:00'));
      await tester.tap(find.text('월 09:00 – 10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('class-meeting-start')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      final timeRows = tester.widgetList<ListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('class-meeting-time-picker')),
          matching: find.byType(ListTile),
        ),
      );
      for (final row in timeRows) {
        final value = int.parse(
          (row.key as ValueKey<String>).value.replaceFirst('class-time-', ''),
        );
        expect(value % 30, 0);
      }
      await tester.tap(find.byKey(const ValueKey('class-time-570')));
      await tester.pumpAndSettle();
      expect(find.text('시작 시간 09:30'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('class-meeting-end')));
      await tester.pumpAndSettle();
      final timeList = find.descendant(
        of: find.byKey(const ValueKey('class-meeting-time-picker')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('class-time-1440')),
        300,
        scrollable: timeList,
      );
      await tester.tap(find.byKey(const ValueKey('class-time-1440')));
      await tester.pumpAndSettle();
      expect(find.text('종료 시간 24:00'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('저장'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('월 09:30 – 24:00'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('class-editor-popup')), findsNothing);
      expect(repo.timetableStore.classes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing a classroom preserves original imported minute precision',
    (tester) async {
      final repo = await settings();
      final store = repo.timetableStore;
      await store.selectTerm(2026, '2');
      await store.save(
        TimetableClass(
          id: 'original',
          title: '원본 수업',
          academicYear: 2026,
          semester: '2',
          meetings: const [
            ClassMeeting(
              id: 'm',
              weekday: 1,
              startMinute: 540,
              endMinute: 590,
              classroom: 'A101',
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(repo, const TimetablePage(), dark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('원본 수업'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('class-details-edit')));
      await tester.pumpAndSettle();
      final popup = tester.widget<Dialog>(
        find.byKey(const ValueKey('class-editor-popup')),
      );
      final decoration =
          (popup.child! as DecoratedBox).decoration as BoxDecoration;
      expect(decoration.border!.top.width, 1.2);
      await tester.ensureVisible(find.text('월 09:00 – 10:00'));
      await tester.tap(find.text('월 09:00 – 10:00'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'A101'),
        'A102',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('저장'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('class-save')));
      await tester.tap(find.byKey(const ValueKey('class-save')));
      await tester.pumpAndSettle();
      final meeting = store.classes.single.meetings.single;
      expect(meeting.classroom, 'A102');
      expect(meeting.endMinute, 600);
      expect(meeting.originalEndMinute, 590);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty slot prefills weekday and time without saving a draft', (
    tester,
  ) async {
    final repo = await settings();
    await tester.pumpWidget(app(repo, const TimetablePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timetable-slot-3-600')));
    await tester.pumpAndSettle();
    expect(find.text('수 10:00 – 11:00'), findsOneWidget);
    expect(repo.timetableStore.classes, isEmpty);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(repo.timetableStore.classes, isEmpty);
  });
  testWidgets(
    'default timetable keeps regular mode and weekly view restores cancellation',
    (tester) async {
      final repo = await settings();
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
      final course = TimetableClass(
        id: 'mode',
        title: '기본 수업',
        academicYear: now.year,
        semester: now.month < 7 ? '1' : '2',
        meetings: const [
          ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 600),
        ],
      );
      await repo.timetableStore.save(course);
      await repo.timetableStore.setTermPeriod(
        course.academicYear,
        course.semester,
        TimetablePeriod(
          start: monday,
          end: monday.add(const Duration(days: 6)),
        ),
      );
      await repo.timetableStore.setOverride(
        'mode',
        'm',
        monday,
        LectureMode.cancelled,
      );
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeeklyTimetableGrid>(find.byType(WeeklyTimetableGrid))
            .occurrences
            .single
            .mode,
        LectureMode.inPerson,
      );
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      final grid = tester.widget<WeeklyTimetableGrid>(
        find.byType(WeeklyTimetableGrid),
      );
      expect(grid.occurrences.single.mode, LectureMode.cancelled);
      await tester.tap(
        find.byKey(
          ValueKey('timetable-occurrence-${grid.occurrences.single.id}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이번 수업 방식'), findsOneWidget);
      await tester.tap(find.text('이번 수업 방식'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기본값 사용 (대면 강의)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(repo.timetableStore.classes.single.overrides, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'overlapping class and personal event share lanes; cancelled class leaves schedule only',
    (tester) async {
      final repo = await settings();
      final store = repo.timetableStore;
      await store.selectTerm(2026, '2');
      final date = DateTime(2026, 9, 21);
      await store.setTermPeriod(
        2026,
        '2',
        TimetablePeriod(
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 12, 21),
        ),
      );
      await store.save(
        TimetableClass(
          id: 'class',
          title: '자료구조',
          academicYear: 2026,
          semester: '2',
          meetings: const [
            ClassMeeting(id: 'm', weekday: 1, startMinute: 540, endMinute: 615),
          ],
        ),
      );
      final event = CalendarEvent(
        id: 'personal',
        title: '개인 회의',
        startAt: DateTime(2026, 9, 21, 9),
        endAt: DateTime(2026, 9, 21, 10),
        allDay: false,
        category: EventCategory.basic,
        colorValue: 0xff2563eb,
        createdAt: date,
        updatedAt: date,
      );
      List<CalendarEvent> rendered = [];
      await tester.pumpWidget(
        app(
          repo,
          TimetableSchedule(
            days: [date],
            events: [event],
            builder: (events, actions) {
              rendered = events;
              return ScheduleTimelineView(
                days: [date],
                events: events,
                eventActions: actions,
                selectedDate: date,
                use24HourTime: true,
                showAllDayEvents: false,
                holidayBackgroundEnabled: false,
                holidayColorValue: 0xffef4444,
                onShowAllDayEventsChanged: (_) {},
                onDateSelected: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, hasLength(2));
      final blocks = tester
          .widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .where((w) => w.key.toString().contains('schedule-event-'))
          .toList();
      expect(blocks, hasLength(2));
      expect(blocks[0].left, isNot(blocks[1].left));
      final projected = rendered.singleWhere(
        (e) => e.id.startsWith('timetable/'),
      );
      expect(projected.readOnly, isTrue);
      expect(projected.systemEvent, isTrue);
      await store.setOverride('class', 'm', date, LectureMode.cancelled);
      await tester.pumpAndSettle();
      expect(rendered.map((e) => e.id), ['personal']);
      await store.setOverride('class', 'm', date, null);
      await tester.pumpAndSettle();
      expect(rendered, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real catalog search, explicit mode, add and duplicate prevention',
    (tester) async {
      final repo = await settings();
      await repo.timetableStore.selectTerm(2026, '2');
      await tester.pumpWidget(
        app(
          repo,
          UniversityCoursePage(
            store: repo.timetableStore,
            loadCatalog: () => UniversityCatalog.load(bundle: _FileBundle()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('course-search')),
        'HAAA6005',
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('smu/seoul/2026/2/HAAA6005/1'));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('시간표에 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시간표에 추가'));
      await tester.pumpAndSettle();
      expect(find.text('강의 방식을 직접 선택해 주세요.'), findsOneWidget);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<LectureMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<LectureMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실시간 비대면 강의').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('시간표에 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시간표에 추가'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('class-title')), findsNothing);
      expect(
        repo.timetableStore.classes.single.defaultMode,
        LectureMode.liveOnline,
      );
      expect(
        repo.timetableStore.classes.single.sourceId,
        'smu/seoul/2026/2/HAAA6005/1',
      );
      expect(tester.widget<ListTile>(row).onTap, isNotNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey('course-add-smu/seoul/2026/2/HAAA6005/1'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'bundled datasets validate every section and preserve cross-listed credits',
    () async {
      final datasets = await UniversityCatalog.load(bundle: _FileBundle());
      expect(
        {
          for (final dataset in datasets)
            '${dataset.universityId}/${dataset.campus}': dataset.courses.length,
        },
        {
          'smu/seoul': 1185,
          'smu/cheonan': 1008,
          'dku/jukjeon': 2722,
          'dku/cheonan': 2562,
          'jnu/gwangju': 3166,
          'jnu/yeosu': 696,
        },
      );
      for (final dataset in datasets) {
        for (final c in dataset.courses) {
          expect(
            c.toTimetable(id: 'test', mode: LectureMode.inPerson).isValid,
            c.hasSchedulableMeetings,
            reason: c.sourceId,
          );
          if (!c.hasSchedulableMeetings) {
            expect(c.scheduleStatus, isIn(['unscheduled', 'unrecognized']));
          }
        }
      }
      final differing = datasets.first.courses.singleWhere(
        (c) => c.code == 'HADA9238' && c.section == '1',
      );
      expect(differing.credits, isNull);
      expect(differing.departmentCredits.values.toSet(), {2, 3});
      final json =
          jsonDecode(
                File(
                  'assets/timetable/smu-seoul-2026-2.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(json['sourceRowCount'], 1359);
    },
  );
  testWidgets(
    'compact landscape with large text keeps actions and grid available',
    (tester) async {
      tester.view.physicalSize = const Size(852, 393);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await settings();
      await tester.pumpWidget(
        app(
          repo,
          const MediaQuery(
            data: MediaQueryData(
              size: Size(852, 393),
              textScaler: TextScaler.linear(2),
            ),
            child: TimetablePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('timetable-day-5')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'weekly changes remains scrollable in a short landscape app body',
    (tester) async {
      tester.view.physicalSize = const Size(852, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await settings();
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-week-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('timetable-search')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('timetable-search'))).bottom,
        lessThanOrEqualTo(240),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets('timetable compact layout ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['DAILY_TIMETABLE_AUDIT'] != null) {
        await tester.runAsync(() async {
          await (FontLoader('Apple SD Gothic Neo')..addFont(
                File(
                  '/System/Library/Fonts/AppleSDGothicNeo.ttc',
                ).readAsBytes().then((b) => ByteData.sublistView(b)),
              ))
              .load();
          await (FontLoader('MaterialIcons')..addFont(
                File(
                  '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes().then((b) => ByteData.sublistView(b)),
              ))
              .load();
        });
      }
      final repo = await settings();
      final now = DateTime.now();
      await repo.timetableStore.save(
        TimetableClass(
          id: 'a',
          title: '자료구조',
          academicYear: now.year,
          semester: now.month < 7 ? '1' : '2',
          defaultMode: LectureMode.liveOnline,
          meetings: const [
            ClassMeeting(
              id: 'a',
              weekday: 1,
              startMinute: 540,
              endMinute: 615,
              classroom: '한누리관 301',
            ),
          ],
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          repo,
          RepaintBoundary(
            key: key,
            child: const Material(child: TimetablePage()),
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final path = Platform.environment['DAILY_TIMETABLE_AUDIT'];
      if (path != null) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(path).create(recursive: true);
          await File(
            '$path/timetable-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets(
    'course opens read-only details before editing and timetable can be renamed',
    (tester) async {
      final repo = await settings();
      final now = DateTime.now();
      await repo.timetableStore.save(
        TimetableClass(
          id: 'details',
          title: '자료구조',
          academicYear: now.year,
          semester: now.month < 7 ? '1' : '2',
          professor: '담당 교수',
          meetings: const [
            ClassMeeting(
              id: 'm',
              weekday: 1,
              startMinute: 540,
              endMinute: 630,
              classroom: 'A301',
            ),
            ClassMeeting(
              id: 'n',
              weekday: 3,
              startMinute: 600,
              endMinute: 660,
              classroom: 'B201',
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(repo, const TimetablePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자료구조').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('class-details')), findsOneWidget);
      expect(find.byKey(const ValueKey('class-title')), findsNothing);
      expect(find.text('A301'), findsWidgets);
      expect(find.text('B201'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('class-details-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('class-title')), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timetable-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시간표 이름 변경'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('timetable-name-input')),
        '가을 수업 🌿',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(repo.timetableStore.activeName, '가을 수업 🌿');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('가을 수업 🌿'), findsOneWidget);
      expect(repo.timetableStore.classes.single.title, '자료구조');
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, dark) in [(393.0, false), (1000.0, true)]) {
    testWidgets(
      'course search opens a separate page and returns to the timetable at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = await settings();
        await repo.timetableStore.selectTerm(2026, '2');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: app(
              repo,
              TimetablePage(
                loadCatalog: () =>
                    UniversityCatalog.load(bundle: _FileBundle()),
              ),
              dark: dark,
              showNavigation: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);
        final reviewPath = Platform.environment['DAILY_TIMETABLE_AUDIT'];
        if (reviewPath != null) {
          await tester.tap(find.byKey(const ValueKey('timetable-term-picker')));
          await tester.pumpAndSettle();
          expect(find.text('25년도 1학기'), findsOneWidget);
          expect(find.byType(TextFormField), findsNothing);
          await tester.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$reviewPath/header-term-list-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
          await tester.tap(
            find.byKey(const ValueKey('timetable-picker-close')),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('timetable-search')));
        await tester.pumpAndSettle();
        final gridFinder = find.byType(WeeklyTimetableGrid);
        final panelFinder = find.byType(UniversityCoursePanel);
        final panelRect = tester.getRect(panelFinder);
        expect(gridFinder, findsNothing);
        expect(find.byKey(const ValueKey('main-navigation')), findsNothing);
        expect(find.byType(UniversityCoursePage), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(panelRect.top, greaterThanOrEqualTo(0));
        expect(panelRect.bottom, lessThanOrEqualTo(852));
        await tester.enterText(
          find.byKey(const ValueKey('course-search')),
          'HAAA6005',
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('smu/seoul/2026/2/HAAA6005/1'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(gridFinder, findsNothing);
        expect(repo.timetableStore.classes, isEmpty);
        final mode = find.byType(DropdownButtonFormField<LectureMode>);
        await tester.ensureVisible(mode);
        await tester.pumpAndSettle();
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('대면 강의').last);
        await tester.pumpAndSettle();
        final add = find.byKey(
          const ValueKey('course-add-smu/seoul/2026/2/HAAA6005/1'),
        );
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        final path = Platform.environment['DAILY_TIMETABLE_AUDIT'];
        if (path != null) {
          await tester.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$path/browser-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(repo.timetableStore.classes.single.title, isNotEmpty);
        expect(gridFinder, findsNothing);
        expect(find.byKey(const ValueKey('class-title')), findsNothing);
        expect(find.byType(UniversityCoursePanel), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(UniversityCoursePanel), findsNothing);
        expect(gridFinder, findsOneWidget);
        expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);
        expect(repo.timetableStore.classes, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
