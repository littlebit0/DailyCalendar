import 'dart:convert';

import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_colors.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TimetableClass course(
  String id, {
  LectureMode mode = LectureMode.inPerson,
  String? sourceId,
  int year = 2026,
  String semester = '2',
  int color = 0xff2563eb,
}) => TimetableClass(
  id: id,
  title: '자료구조',
  academicYear: year,
  semester: semester,
  colorValue: color,
  sourceId: sourceId,
  defaultMode: mode,
  meetings: const [
    ClassMeeting(id: 'mon', weekday: 1, startMinute: 540, endMinute: 615),
    ClassMeeting(id: 'mon2', weekday: 1, startMinute: 780, endMinute: 840),
    ClassMeeting(id: 'wed', weekday: 3, startMinute: 540, endMinute: 615),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('existing version 1 payload needs no timetable names', () async {
    final original = course('legacy').withOverride(
      course('legacy').meetings.first,
      DateTime(2026, 9, 21),
      LectureMode.cancelled,
    );
    SharedPreferences.setMockInitialValues({
      TimetableStore.storageKey: jsonEncode({
        'version': 1,
        'activeYear': 2026,
        'activeSemester': '2',
        'classes': [original.toJson()],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs);
    expect(store.loadError, isNull);
    expect(store.activeName, isNull);
    expect(store.classes.single.toJson(), original.toJson());

    await store.renameActive('  나의 가을 학기  ');
    final restored = TimetableStore(prefs);
    expect(restored.activeName, '나의 가을 학기');
    expect(restored.classes.single.toJson(), original.toJson());
  });
  test('names persist independently by year and semester', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs);
    await store.selectTerm(2026, '2');
    await store.renameActive('가을 학기');
    await store.selectTerm(2026, '계절/겨울');
    expect(store.activeName, isNull);
    await store.renameActive('겨울 계절학기');
    await store.selectTerm(2027, '2');
    expect(store.activeName, isNull);
    await store.renameActive('다음 가을');

    final restored = TimetableStore(prefs);
    expect(restored.activeName, '다음 가을');
    await restored.selectTerm(2026, '계절/겨울');
    expect(restored.activeName, '겨울 계절학기');
    await restored.selectTerm(2026, '2');
    expect(restored.activeName, '가을 학기');
  });
  test(
    'queued term, name, course and reset edits retain all metadata',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      await Future.wait([
        store.selectTerm(2026, '2'),
        store.renameActive('이번 학기'),
        store.save(course('fall')),
        store.selectTerm(2027, '1'),
        store.renameActive('다음 학기'),
        store.save(course('spring', year: 2027, semester: '1')),
        store.renameActive('다음 봄 학기'),
      ]);
      expect(store.activeName, '다음 봄 학기');
      expect(store.classes, hasLength(2));
      await store.clearActive();
      expect(store.activeName, '다음 봄 학기');
      expect(store.activeClasses, isEmpty);
      final restored = TimetableStore(prefs);
      expect(restored.activeName, '다음 봄 학기');
      expect(restored.classes.single.id, 'fall');
      await restored.selectTerm(2026, '2');
      expect(restored.activeName, '이번 학기');
      expect(restored.activeClasses.single.id, 'fall');
    },
  );
  test('invalid names leave persisted classes and name untouched', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs);
    await store.selectTerm(2026, '2');
    await store.save(course('a'));
    await store.renameActive('a' * 60);
    final before = prefs.getString(TimetableStore.storageKey);
    for (final invalid in ['', '   ', 'a' * 61]) {
      expect(() => store.renameActive(invalid), throwsArgumentError);
    }
    expect(prefs.getString(TimetableStore.storageKey), before);
    expect(store.classes.single.id, 'a');
    expect(store.activeName, 'a' * 60);
  });
  test('name limit counts user-visible characters, including emoji', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs);
    await store.selectTerm(2026, '2');
    final name = '👩🏽‍💻' * 59 + '각';
    await store.renameActive(name);
    expect(store.activeName, name);
    expect(TimetableStore(prefs).activeName, name);
    expect(() => store.renameActive('$name🌟'), throwsArgumentError);
  });
  for (final invalid in [
    null,
    [],
    {
      '02026': {'2': '이름'},
    },
    {
      '1899': {'2': '이름'},
    },
    {
      '2026': {'': '이름'},
    },
    {
      '2026': {'2': '   '},
    },
    {
      '2026': {'2': ' 공백 '},
    },
    {
      '2026': {'2': 42},
    },
    {
      '2026': {'2': 'a' * 61},
    },
  ]) {
    test('corrupt timetable names fail closed: $invalid', () async {
      final raw = jsonEncode({
        'version': 1,
        'activeYear': 2026,
        'activeSemester': '2',
        'classes': [course('preserved').toJson()],
        'termNames': invalid,
      });
      SharedPreferences.setMockInitialValues({TimetableStore.storageKey: raw});
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      expect(store.loadError, isNotNull);
      expect(store.classes, isEmpty);
      expect(store.activeName, isNull);
      await expectLater(store.renameActive('새 이름'), throwsStateError);
      await expectLater(store.save(course('new')), throwsStateError);
      expect(prefs.getString(TimetableStore.storageKey), raw);
    });
  }
  test('new course colors balance usage in stable palette order', () {
    expect(selectNewCourseColor([]), timetableCourseColors.first);
    expect(
      selectNewCourseColor([course('a'), course('custom', color: 0xff123456)]),
      timetableCourseColors[1],
    );
    final oneOfEach = [
      for (final color in timetableCourseColors) course('$color', color: color),
    ];
    expect(selectNewCourseColor(oneOfEach), timetableCourseColors.first);
    expect(
      selectNewCourseColor([...oneOfEach, course('extra')]),
      timetableCourseColors[1],
    );
  });
  test(
    'concurrent saves survive reload and term switching preserves all classes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      await store.selectTerm(2026, '2');
      await Future.wait([store.save(course('a')), store.save(course('b'))]);
      await store.selectTerm(2027, '1');
      expect(store.activeClasses, isEmpty);
      final restored = TimetableStore(prefs);
      expect(restored.classes, hasLength(2));
      await restored.selectTerm(2026, '2');
      expect(restored.activeClasses, hasLength(2));
      await restored.clearActive();
      expect(TimetableStore(prefs).classes, isEmpty);
    },
  );
  test(
    'each date and meeting has an independent override; reset restores default',
    () async {
      final store = TimetableStore(await SharedPreferences.getInstance());
      await store.save(course('a'));
      final monday = DateTime(2026, 9, 21);
      await store.setOverride('a', 'mon', monday, LectureMode.cancelled);
      expect(classOccurrences(store.classes, [monday]), hasLength(1));
      expect(
        classOccurrences(store.classes, [DateTime(2026, 9, 28)]),
        hasLength(2),
      );
      await store.setOverride('a', 'mon', monday, LectureMode.video);
      expect(classOccurrences(store.classes, [monday]), hasLength(1));
      expect(
        classOccurrences(store.classes, [monday], includeUnscheduled: true),
        hasLength(2),
      );
      await store.setOverride('a', 'mon', monday, LectureMode.liveOnline);
      expect(classOccurrences(store.classes, [monday]), hasLength(2));
      await store.setOverride('a', 'mon', monday, null);
      expect(store.classes.single.overrides, isEmpty);
      expect(
        classOccurrences(store.classes, [monday]).first.mode,
        LectureMode.inPerson,
      );
    },
  );
  test(
    'video default is absent from schedule but per-date live class returns',
    () async {
      final store = TimetableStore(await SharedPreferences.getInstance());
      await store.save(course('a', mode: LectureMode.video));
      final date = DateTime(2026, 9, 21);
      expect(classOccurrences(store.classes, [date]), isEmpty);
      await store.setOverride('a', 'mon', date, LectureMode.liveOnline);
      final occurrence = classOccurrences(store.classes, [date]).single;
      expect(occurrence.start, DateTime(2026, 9, 21, 9));
      expect(occurrence.end, DateTime(2026, 9, 21, 10, 30));
    },
  );
  test(
    'duplicate section refused but manual edits retain source identity',
    () async {
      final store = TimetableStore(await SharedPreferences.getInstance());
      await store.save(course('a', sourceId: 'smu/seoul/2026/2/ABC/01'));
      await expectLater(
        store.save(course('b', sourceId: 'smu/seoul/2026/2/ABC/01')),
        throwsStateError,
      );
      await store.save(
        course(
          'a',
          sourceId: 'smu/seoul/2026/2/ABC/01',
          mode: LectureMode.liveOnline,
        ),
      );
      expect(store.classes, hasLength(1));
      expect(store.classes.single.defaultMode, LectureMode.liveOnline);
    },
  );
  test('corrupt existing data is never silently overwritten', () async {
    SharedPreferences.setMockInitialValues({
      TimetableStore.storageKey: 'broken',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TimetableStore(prefs);
    expect(store.loadError, isNotNull);
    await expectLater(store.save(course('a')), throwsStateError);
    expect(prefs.getString(TimetableStore.storageKey), 'broken');
  });
  for (final invalid in [
    42,
    '{"version":1,"classes":[],"activeYear":0,"activeSemester":"2"}',
  ]) {
    test('invalid persisted type or term fails closed: $invalid', () async {
      SharedPreferences.setMockInitialValues({
        TimetableStore.storageKey: invalid,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      expect(store.loadError, isNotNull);
      expect(store.classes, isEmpty);
      await expectLater(store.save(course('a')), throwsStateError);
      expect(prefs.get(TimetableStore.storageKey), invalid);
    });
  }
}
