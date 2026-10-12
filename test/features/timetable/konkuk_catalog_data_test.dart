import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/core/academic/konkuk_academic_source.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Current original Konkuk English PDF cells and direct clock image preserve partial weekly plans in all modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/konkuk/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(
                fixtureFile(
                  n ==
                          'konkuk-unknown-2026-2.current-public-english-first-week-partial-v1.json'
                      ? 'assets/timetable/konkuk-unknown-2026-2.json'
                      : '$root$n',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source = read(
        'konkuk-current-public-english-education-source-20261008.json',
      );
      final raw = read(
        'konkuk-unknown-2026-2.current-public-english-first-week-partial-v1.json',
      );
      final ds = UniversityDataset.fromJson(raw);
      final rows = source['nativeCourseRows'] as List;
      expect(rows, hasLength(206));
      final scope = source['undergraduateScopeProof']['ownCollegeNavigation'];
      expect(scope['nativeParentLabel'], '대학');
      expect(scope['nativeSeparateGraduateParentLabel'], '대학원');
      expect(
        (scope['nativeCollegeLinks'] as List).any(
          (r) => r['nativeLabel'] == '상허교양대학 / KU자유전공학부',
        ),
        true,
      );
      expect(
        (scope['nativeCollegeLinks'] as List).any(
          (r) => r['nativeLabel'] == '경영대학',
        ),
        true,
      );
      expect(
        (scope['nativeCollegeLinks'] as List).any(
          (r) => r['nativeLabel'] == '일반대학원',
        ),
        false,
      );
      expect(ds.courses, hasLength(206));
      expect(raw['termEndDate'], isNull);
      expect(raw['completionClaim'], false);
      expect(raw['publishedDateMeaning'], 'sourceSnapshotRetrievalDate');
      final calendar = KonkukAcademicSource.parseSeoul(
        fixtureFile(
          'work/university-research/calendar-a/konkuk-year.html',
        ).readAsStringSync(),
        2026,
      );
      expect(
        calendar.singleWhere((e) => e.title == '2026학년도 2학기 개강').start,
        DateTime(2026, 8, 31),
      );
      expect(calendar.any((e) => e.title.contains('종강')), false);
      expect(
        calendar.singleWhere((e) => e.title == '동계방학').start,
        DateTime(2026, 12, 19),
      );
      final clocks = (source['nativeClockImage']['rows'] as List)
          .cast<Map<String, dynamic>>();
      expect(clocks, hasLength(20));
      expect(clocks.first['nativeBegins'], '09:00');
      expect(clocks.last['nativeEnds'], '19:00');
      final native = {for (final r in rows) r['sourceId']: r};
      const weekdays = {'MON': 1, 'TUE': 2, 'WED': 3, 'THR': 4, 'FRI': 5};
      int minute(String text) {
        final v = text.split(':');
        return int.parse(v[0]) * 60 + int.parse(v[1]);
      }

      var eligibleCount = 0;
      var meetingCount = 0;
      for (final c in ds.courses) {
        final r = native[c.sourceId]!;
        String plain(String text) =>
            text.replaceAll(RegExp(r'\s+'), ' ').trim();
        expect(c.code, r['nativeCourseNumber']);
        expect(c.code, matches(RegExp(r'^\d{4}$')));
        expect(c.title, plain(r['nativeTitle'] as String));
        expect(c.professor, plain(r['nativeProfessor'] as String));
        expect(c.credits, double.parse(r['nativeCredits'] as String));
        expect(c.departments.single, plain(r['nativeOfferedBy'] as String));
        expect(c.section, isEmpty);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'unknown');
        final schedule = plain(r['nativeSchedule'] as String);
        expect(c.sourceSchedule, schedule);
        final scheduleMatches = RegExp(
          r'(MON|TUE|WED|THR|FRI)(\d{2})-(\d{2})\(([^()]*)\)',
        ).allMatches(schedule).toList();
        final eligible =
            r['nativeMethod'] == 'In Person' &&
            scheduleMatches.isNotEmpty &&
            scheduleMatches.every(
              (m) =>
                  int.parse(m[2]!) >= 1 &&
                  int.parse(m[3]!) <= 20 &&
                  int.parse(m[3]!) >= int.parse(m[2]!),
            );
        expect(c.hasSchedulableMeetings, eligible);
        if (!eligible) {
          expect(c.meetings, isEmpty);
          continue;
        }
        eligibleCount++;
        meetingCount += c.meetings.length;
        expect(c.meetings, hasLength(scheduleMatches.length));
        for (var i = 0; i < scheduleMatches.length; i++) {
          final n = scheduleMatches[i];
          final m = c.meetings[i];
          final weekday = weekdays[n[1]]!;
          final date = DateTime(
            2026,
            8,
            31,
          ).add(Duration(days: weekday - 1)).toIso8601String().substring(0, 10);
          expect(m.date, date);
          expect(m.weekday, weekday);
          expect(
            m.originalStartMinute,
            minute(clocks[int.parse(n[2]!) - 1]['nativeBegins'] as String),
          );
          expect(
            m.originalEndMinute,
            minute(clocks[int.parse(n[3]!) - 1]['nativeEnds'] as String),
          );
          expect(m.classroom, n[4]);
        }
      }
      expect(eligibleCount, 137);
      expect(meetingCount, 242);
      expect(
        ds.courses.singleWhere((c) => c.code == '3621').hasSchedulableMeetings,
        false,
      );
      expect(
        ds.courses.singleWhere((c) => c.code == '1574').hasSchedulableMeetings,
        false,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = ds.courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(137));
        final original = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            original[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 분반번호가 아닙니다'));
        }
      }
    },
  );
}
