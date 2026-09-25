import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SettingsRepository> settings({bool use24HourTime = true}) async {
    SharedPreferences.setMockInitialValues({'use24HourTime': use24HourTime});
    return SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  }

  TimetableClass course({String note = '', int start = 780, int end = 840}) =>
      TimetableClass(
        id: 'course',
        title: 'Computer Science',
        academicYear: 2026,
        semester: '2',
        professor: 'Professor Kim',
        note: note,
        meetings: [
          ClassMeeting(
            id: 'meeting',
            weekday: 1,
            startMinute: start,
            endMinute: end,
            classroom: 'Room 201',
          ),
        ],
      );

  Widget app(
    SettingsRepository settings,
    TimetableClass course, {
    double textScale = 1,
  }) => ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: DailyTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                key: const ValueKey('open-course'),
                onPressed: () => showTimetableClassDetails(
                  context,
                  settings.timetableStore,
                  course,
                ),
                child: const Text('Open course'),
              ),
              TextButton(
                key: const ValueKey('open-occurrence'),
                onPressed: () => showClassOccurrence(
                  context,
                  settings.timetableStore,
                  ClassOccurrence(
                    course,
                    course.meetings.single,
                    DateTime(2026, 9, 21),
                    LectureMode.inPerson,
                  ),
                ),
                child: const Text('Open occurrence'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  for (final use24HourTime in [false, true]) {
    testWidgets(
      'course and occurrence details follow the ${use24HourTime ? 24 : 12}-hour app setting',
      (tester) async {
        final repo = await settings(use24HourTime: use24HourTime);
        await tester.pumpWidget(app(repo, course()));
        await tester.pumpAndSettle();
        final expected = use24HourTime ? '13:00 – 14:00' : '1:00 PM – 2:00 PM';
        for (final action in ['open-course', 'open-occurrence']) {
          await tester.tap(find.byKey(ValueKey(action)));
          await tester.pumpAndSettle();
          expect(find.textContaining(expected), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(Scaffold))).pop();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('24-hour details retain midnight as the end of the same day', (
    tester,
  ) async {
    final repo = await settings();
    await tester.pumpWidget(app(repo, course(start: 1380, end: 1440)));
    await tester.pumpAndSettle();
    for (final action in ['open-course', 'open-occurrence']) {
      await tester.tap(find.byKey(ValueKey(action)));
      await tester.pumpAndSettle();
      expect(find.textContaining('23:00 – 24:00'), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('long occurrence notes scroll while actions stay reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = await settings();
    final note = List.filled(
      40,
      'Read the assigned chapter before class.',
    ).join('\n');
    await tester.pumpWidget(app(repo, course(note: note), textScale: 1.5));
    await tester.tap(find.byKey(const ValueKey('open-occurrence')));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    final close = find.widgetWithText(TextButton, 'Close');
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('long course notes keep edit reachable in a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = await settings();
    final note = List.filled(
      40,
      'Read the assigned chapter before class.',
    ).join('\n');
    await tester.pumpWidget(app(repo, course(note: note), textScale: 1.5));
    await tester.tap(find.byKey(const ValueKey('open-course')));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('class-details-edit'));
    await tester.scrollUntilVisible(
      edit,
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(edit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('class-title')), findsOneWidget);
  });
}
