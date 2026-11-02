import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-f/ssu/weekly-reservations-v4-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
String hash(String path) =>
    sha256.convert(fixtureFile(path).readAsBytesSync()).toString();
String clean(String text) {
  for (final pattern in [
    r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',
    r'(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',
    r'https?://[^\s<>]+',
  ]) {
    text = text.replaceAll(RegExp(pattern), '[연락·접속 정보 제외]');
  }
  return text;
}

List<Map<String, dynamic>> sourceGeometry(String text, String professor) {
  final header = RegExp(
    r'([월화수목금토일](?:\s+[월화수목금토일])*)\s+(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(',
  );
  final result = <Map<String, dynamic>>[];
  final names = <String>{professor, ...professor.split(' ')}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final match in header.allMatches(text)) {
    var closing = match.end;
    var depth = 1;
    while (depth > 0 && closing < text.length) {
      if (text[closing] == '(') {
        depth++;
      }
      if (text[closing] == ')') {
        depth--;
      }
      closing++;
    }
    expect(depth, 0);
    final rawRoom = text.substring(match.end, closing - 1).trim();
    final name = names.firstWhere(
      (name) => name.isNotEmpty && rawRoom.endsWith('-$name'),
    );
    final room = rawRoom.substring(0, rawRoom.length - name.length - 1).trim();
    for (final day in match[1]!.split(RegExp(r'\s+'))) {
      final m = <String, dynamic>{
        'weekday': '월화수목금토일'.indexOf(day) + 1,
        'startMinute': int.parse(match[2]!) * 60 + int.parse(match[3]!),
        'endMinute': int.parse(match[4]!) * 60 + int.parse(match[5]!),
        'classroom': room,
      };
      if (!result.any((r) => jsonEncode(r) == jsonEncode(m))) {
        result.add(m);
      }
    }
  }
  return result;
}

void main() {
  final audit = read('$directory/weekly-reservation-audit-v4.json');
  final raw = read('assets/timetable/ssu-main-2026-2.json');
  final base = read(audit['baseFile']);
  final source = read(audit['sourceRawFile']);
  final courses = (raw['courses'] as List).cast<Map<String, dynamic>>();
  final model = UniversityDataset.fromJson(raw);
  final classification =
      jsonDecode(
            fixtureFile(
              '$directory/all2219-classification-v4.json',
            ).readAsStringSync(),
          )
          as List;
  final added = classification
      .where((r) => r['status'] == 'ordinaryNativeWeeklyReservation')
      .map((r) => r['nativeCourseId'])
      .toSet();
  test(
    'whole2219 and5561 whitelisted native rows independent;17 and175 untouched',
    () {
      expect(
        hash('$directory/${audit['candidateFile']}'),
        audit['candidateSHA256'],
      );
      expect(
        hash(audit['baseFile']),
        'a4ee705c1c46c0cb2cd87a002337a541495821b439c9d0c798a4b3b2f96b2e5f',
      );
      expect(hash(audit['sourceRawFile']), audit['sourceRawSHA256']);
      expect(courses, hasLength(2219));
      expect(added, hasLength(2027));
      expect(
        model.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(2044),
      );
      expect(model.courses.expand((c) => c.meetings), hasLength(56624));
      const allowed = [
        '이수구분(주전공)',
        '이수구분(다전공)',
        '공학인증',
        '과목번호',
        '과목명',
        '수강유의사항',
        '강좌유형정보',
        '분반',
        '교수명',
        '개설학과',
        '시간/학점(설계)',
        '강의시간(강의실)',
        '수강대상',
        '교과영역',
      ];
      var rowCount = 0;
      var existing = 0;
      var held = 0;
      for (var i = 0; i < courses.length; i++) {
        final c = courses[i];
        final before = base['courses'][i];
        final cid = c['sourceEducation']['nativeTenDigitCourseId'];
        final educational = <Map<String, dynamic>>[];
        for (final row in source['recordsByCode'][cid]) {
          educational.add({
            for (final key in allowed)
              if (row.containsKey(key)) key: clean(row[key]),
          });
          rowCount++;
        }
        expect(c['sourceEducation']['allPublicQueryEducation'], educational);
        expect('${c['courseCode']}${c['section']}', cid);
        for (final field in [
          'sourceId',
          'campus',
          'courseCode',
          'section',
          'courseName',
          'professor',
          'credits',
          'classification',
          'departmentClassifications',
          'departmentCredits',
          'sourceSchedule',
          'sourceClassroom',
          'sourceEducation',
        ]) {
          expect(c[field], before[field]);
        }
        if (!added.contains(cid)) {
          expect(jsonEncode(c), jsonEncode(before));
          if ((c['schedules'] as List).isEmpty) {
            held++;
          } else {
            existing++;
          }
        } else {
          expect(
            c['reservationEvidence']['dateMeaning'],
            'derivedRegularWeeklyReservationNotSourcePublishedAttendance',
          );
          expect(c['reservationEvidence']['sourceWeekIndexUsed'], false);
          expect(
            c['reservationEvidence']['sourcePublishedIndividualDatesClaim'],
            false,
          );
          expect(c['remarks'], contains('실제출석 날짜가 아닙니다'));
        }
      }
      expect(rowCount, 5561);
      expect(existing, 17);
      expect(held, 175);
    },
  );
  test(
    'actual native day groups nested rooms and exact independent reservations',
    () {
      final calendar = read('$directory/${audit['calendarSourceFile']}');
      expect(
        hash('$directory/${audit['calendarSourceFile']}'),
        audit['calendarSourceSHA256'],
      );
      expect(calendar['startDate'], '2026-09-01');
      expect(calendar['endDate'], '2026-12-21');
      expect(calendar['officialExamPeriod'], {
        'startDate': '2026-12-08',
        'endDate': '2026-12-14',
      });
      expect(calendar['officialMakeupPeriod'], {
        'startDate': '2026-12-15',
        'endDate': '2026-12-21',
      });
      final excluded = <String>{
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (var day = 8; day <= 21; day++) {
        excluded.add('2026-12-${day.toString().padLeft(2, '0')}');
      }
      expect(audit['globalExcludedDates'], excluded.toList()..sort());
      var count = 0;
      for (final c in courses.where(
        (c) => added.contains(c['sourceEducation']['nativeTenDigitCourseId']),
      )) {
        final cid = c['sourceEducation']['nativeTenDigitCourseId'];
        final row = source['recordsByCode'][cid][0];
        final geometry = sourceGeometry(clean(row['강의시간(강의실)']), row['교수명']);
        final expected = <Map<String, dynamic>>[];
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 21));
          date = date.add(const Duration(days: 1))
        ) {
          final key = timetableDateKey(date);
          if (excluded.contains(key)) {
            continue;
          }
          for (final m in geometry) {
            if (m['weekday'] == date.weekday) {
              expected.add({...m, 'date': key});
            }
          }
        }
        expect(c['schedules'], expected);
        expect(c['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-12-21',
        });
        count += expected.length;
        for (final m in c['schedules']) {
          expect(m.containsKey('deliveryMode'), false);
        }
      }
      expect(count, 56503);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('actual2044 classes56624 meetings full Drive ${mode.name}', () {
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in model.courses.where((c) => c.hasSchedulableMeetings)) {
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        expect(saved.isValid, true);
        expect(
          TimetableClass.fromJson(saved.toJson()).toJson(),
          saved.toJson(),
        );
        final sourceCourse = courses.singleWhere(
          (r) => r['sourceId'] == c.sourceId,
        );
        final meetings = sourceCourse['schedules'] as List;
        expect(saved.meetings, hasLength(meetings.length));
        for (var i = 0; i < meetings.length; i++) {
          final m = saved.meetings[i];
          final r = meetings[i];
          expect(m.date, r['date']);
          expect(m.weekday, r['weekday']);
          expect(m.originalStartMinute, r['startMinute']);
          expect(m.originalEndMinute, r['endMinute']);
          expect(m.classroom, r['classroom']);
          expect(saved.period!.contains(m.teachingDate!), true);
          if (added.contains(
            sourceCourse['sourceEducation']['nativeTenDigitCourseId'],
          )) {
            expect(saved.modeOn(m, m.teachingDate!), mode);
          } else if (r['deliveryMode'] != null) {
            expect(saved.modeOn(m, m.teachingDate!).name, r['deliveryMode']);
          }
          count++;
        }
        if (added.contains(
          sourceCourse['sourceEducation']['nativeTenDigitCourseId'],
        )) {
          final first = saved.meetings.first.teachingDate!;
          final expectedOnFirst = (sourceCourse['schedules'] as List)
              .where((r) => r['date'] == timetableDateKey(first))
              .length;
          expect(
            classOccurrences([saved], [first]),
            hasLength(mode == LectureMode.video ? 0 : expectedOnFirst),
          );
        }
        final key = timetableCourseSyncKey(saved);
        expect(values.containsKey(key), false);
        values[key] = TimetableSyncValue(
          {...saved.toJson(), 'id': key},
          DateTime.utc(2026, 10, 8),
          'research',
        );
      }
      expect(count, 56624);
      expect(values, hasLength(2044));
      final json =
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(json);
      expect(restored.materializeClasses(), hasLength(2044));
      for (final c in restored.materializeClasses()) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
      }
    });
  }
}
