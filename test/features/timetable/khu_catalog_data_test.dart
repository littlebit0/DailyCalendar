import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test('KHU uses own integrated profile and rejects foreign campus IDs', () {
    for (final id in [
      'academyinfo:0000066',
      'institution:academyinfo:0000066',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '경희대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'khu');
      expect(profile.timetableCampus, 'seoul');
      expect(profile.academicSourceId, 'khu');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '경희대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });

  test(
    'Global campus current dated plans preserve native nested room and remote/exam boundaries',
    () {
      final data = UniversityDataset.fromJson(
        jsonDecode(
              fixtureFile(
                'assets/timetable/khu-global-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      expect(data.courses.where((c) => c.hasSchedulableMeetings).length, 1461);
      final nested = data.courses.singleWhere(
        (c) => c.codeAndSection == 'FR2012-00',
      );
      expect(
        nested.meetings.every((m) => m.classroom == '외408(김우화 강의실)'),
        isTrue,
      );
      for (final id in ['FR1012-00', 'AE253-02']) {
        final c = data.courses.singleWhere((c) => c.codeAndSection == id);
        final start = id == 'FR1012-00' ? '2026-10-06' : '2026-09-29';
        final end = id == 'FR1012-00' ? '2026-10-12' : '2026-10-05';
        expect(
          c.meetings.any(
            (m) => m.date!.compareTo(start) >= 0 && m.date!.compareTo(end) <= 0,
          ),
          isFalse,
        );
      }
      final spanish = data.courses.singleWhere(
        (c) => c.codeAndSection == 'ESP351-00',
      );
      expect(
        spanish.meetings.any(
          (m) =>
              m.date!.compareTo('2026-10-20') >= 0 &&
              m.date!.compareTo('2026-10-26') <= 0,
        ),
        isFalse,
      );
      expect(
        spanish.meetings.any((m) => m.date!.compareTo('2026-12-15') >= 0),
        isFalse,
      );
      expect(
        data.courses
            .singleWhere((c) => c.codeAndSection == 'AE354-01')
            .hasSchedulableMeetings,
        isFalse,
      );
    },
  );
  test(
    'published exam time and unresolved holiday-online times remain distinct',
    () {
      final d = UniversityDataset.fromJson(
        jsonDecode(
              fixtureFile(
                'assets/timetable/khu-seoul-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final c = d.courses.singleWhere((c) => c.codeAndSection == 'SOC1004-00');
      for (final date in ['2026-10-21', '2026-12-16']) {
        final m = c.meetings.singleWhere((m) => m.date == date);
        expect(m.weekday, 3);
        expect(m.originalStartMinute, 810);
        expect(m.originalEndMinute, 885);
        expect(m.classroom, isEmpty);
      }
      expect(
        d.courses
            .singleWhere((c) => c.codeAndSection == 'ECON2043-00')
            .hasSchedulableMeetings,
        isFalse,
      );
      expect(
        d.courses
            .singleWhere((c) => c.codeAndSection == 'TRADE4015-00')
            .hasSchedulableMeetings,
        isFalse,
      );
      expect(
        d.courses
            .singleWhere((c) => c.codeAndSection == 'TRADE3052-00')
            .remarks,
        contains('실시간 여부와 참석 시각은 확인되지 않아'),
      );
    },
  );
  test(
    'KHU whole educational scope and fifty individually reviewed plans and native weekly reservations preserve actual Drive values',
    () {
      final courses = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/khu-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
          ).courses,
      ];
      expect(courses.length, 4666);
      expect(courses.map((c) => c.sourceId).toSet().length, 4666);
      expect(courses.where((c) => c.hasSchedulableMeetings).length, 3161);
      expect(courses.expand((c) => c.meetings).length, 58991);
      for (final code in ['TRADE1016-00', 'TRADE2010-01']) {
        final c = courses.singleWhere((c) => c.codeAndSection == code);
        expect(c.remarks, contains('외국인 전용'));
        expect(
          c.meetings.any((m) => m.date!.compareTo('2026-12-08') >= 0),
          isFalse,
        );
      }
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == 'KMS4117-01')
            .hasSchedulableMeetings,
        isFalse,
      );
      final econ = courses.singleWhere(
        (c) => c.codeAndSection == 'ECON1001-00',
      );
      expect(econ.meetings.map((m) => m.date), ['2026-10-20', '2026-12-15']);
      expect(econ.remarks, contains('경제학과 수강 불가'));
      final icfi = courses.singleWhere(
        (c) => c.codeAndSection == 'ICFI4035-00',
      );
      expect(icfi.meetings.length, 5);
      expect(icfi.remarks, contains('타학과수강불가'));
      final society = courses.singleWhere(
        (c) => c.codeAndSection == 'SOC4040-00',
      );
      expect(society.meetings.every((m) => m.classroom == '구(한)310'), isTrue);
      final data = courses.singleWhere(
        (c) => c.codeAndSection == 'TRADE3057-00',
      );
      expect(data.meetings.any((m) => m.date == '2026-10-01'), isFalse);
      expect(data.meetings.any((m) => m.date == '2026-09-22'), isTrue);
      expect(data.meetings.any((m) => m.date == '2026-09-29'), isTrue);
      expect(data.remarks, contains('영어로 강의하는 수업'));
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == 'ECON2042-00')
            .meetings
            .any((m) => m.date!.compareTo('2026-12-15') >= 0),
        isFalse,
      );
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'TRADE1001-01').remarks,
        contains('외국인수강불가'),
      );
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'TRADE2056-00').remarks,
        contains('GTEP 20기'),
      );
      final alternate = courses.singleWhere(
        (c) => c.codeAndSection == 'ECON1001-00',
      );
      expect(alternate.titleAliases, contains('경제학원론(관광·엔터테인먼트학부)'));
      expect(alternate.matchesQuery('경제학원론(관광·엔터테인먼트학부)'), isTrue);
      expect(alternate.matchesQuery('관광·엔터테인먼트학부 최용석'), isTrue);
      expect(alternate.matchesQuery('ㄱㅈㅎㅇㄹ(ㄱㄱ·ㅇㅌㅌㅇㅁㅌㅎㅂ)'), isTrue);
      expect(alternate.queryRank('경제학원론(관광·엔터테인먼트학부)'), 0);
      expect(alternate.title, '경제학원론');
      final bad =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/khu-seoul-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final invalid = Map<String, dynamic>.from(
        (bad['courses'] as List).first as Map,
      )..['courseNameAliases'] = ['  '];
      expect(() => UniversityCourse.fromJson(invalid), throwsFormatException);
      expect(
        courses.every((c) => !c.sourceSchedule.toLowerCase().contains('<br')),
        isTrue,
      );
      final private = courses.singleWhere(
        (c) => c.codeAndSection == 'TRADE2003-00',
      );
      expect(
        private.meetings.any(
          (m) =>
              (m.date!.compareTo('2026-09-29') >= 0 &&
                  m.date!.compareTo('2026-10-19') <= 0) ||
              (m.date!.compareTo('2026-12-08') >= 0 &&
                  m.date!.compareTo('2026-12-14') <= 0),
        ),
        isFalse,
      );
      expect(private.remarks, contains('학생별 배정'));
      expect(private.remarks, contains('more than 10 times'));
      final global = courses.singleWhere(
        (c) => c.codeAndSection == 'TRADE4044-00',
      );
      expect(
        global.meetings.any(
          (m) =>
              (m.date!.compareTo('2026-10-20') >= 0 &&
                  m.date!.compareTo('2026-10-26') <= 0) ||
              m.date!.compareTo('2026-12-15') >= 0,
        ),
        isFalse,
      );
      expect(global.remarks, contains('recommended as prior coursework'));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, isTrue);
          expect(t.defaultMode, mode);
          for (final m in t.meetings) {
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-21'), lessThanOrEqualTo(0));
            // Only source-confirmed whole classes override this holiday.
            if (m.date == '2026-10-09') {
              const exactLive = {
                'khu/2026/2/global/GEC1102G38': [540, 705],
                'khu/2026/2/global/GEC1102G41': [720, 885],
                'khu/2026/2/global/GED11011G00': [540, 705],
                'khu/2026/2/global/AS302800': [630, 795],
                'khu/2026/2/global/AS302900': [810, 975],
                // Own whole AE353 plan explicitly includes this live date.
                'khu/2026/2/global/AE35300': [810, 975],
              };
              if (exactLive.containsKey(c.sourceId)) {
                expect(m.originalStartMinute, exactLive[c.sourceId]![0]);
                expect(m.originalEndMinute, exactLive[c.sourceId]![1]);
                expect(m.classroom, isEmpty);
                expect(t.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              } else {
                expect(c.sourceId, 'khu/2026/2/seoul/GLEE100800');
                expect(m.originalStartMinute, 720);
                expect(m.originalEndMinute, 885);
                expect(m.classroom, '구(한)210');
                final proof =
                    jsonDecode(
                          fixtureFile(
                            'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/packet008-independent-proof.json',
                          ).readAsStringSync(),
                        )['proofs']
                        as List;
                final courseProof = proof.singleWhere(
                  (p) => p['sourceId'] == c.sourceId,
                );
                expect(jsonEncode(courseProof), contains('2026-10-09'));
              }
            }
            if (m.date == '2026-10-03' || m.date == '2026-10-05') {
              expect(c.sourceId, 'khu/2026/2/seoul/GEE1635S02');
              expect(m.originalStartMinute, 540);
              expect(m.originalEndMinute, 1080);
              final proof =
                  jsonDecode(
                        fixtureFile(
                          'work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1/packet041b-seven-own-concentrated/proof.json',
                        ).readAsStringSync(),
                      )['proofs']
                      as List;
              final courseProof = proof.singleWhere(
                (p) => p['sourceId'] == c.sourceId,
              );
              expect(courseProof['ownExplicitHolidayDates'], contains(m.date));
              expect(courseProof['ownProfessorWholeProofs'], hasLength(2));
              expect(t.modeOn(m, m.teachingDate!), mode);
            } else {
              expect([
                '2026-09-24',
                '2026-09-25',
                '2026-09-26',
                '2026-10-03',
                '2026-10-05',
              ], isNot(contains(m.date)));
            }
            expect(m.teachingDate!.weekday, m.weekday);
          }
          if (c.codeAndSection == 'ECON1001-00' ||
              c.codeAndSection == 'ICFI4035-00') {
            expect(t.overrides.length, t.meetings.length);
            for (final meeting in t.meetings) {
              expect(
                t.overrides['${meeting.id}/${meeting.date}'],
                meeting.date == '2026-12-05'
                    ? LectureMode.liveOnline
                    : LectureMode.inPerson,
              );
              if (meeting.date == '2026-12-05' ||
                  meeting.endMinute == 1050 ||
                  c.codeAndSection == 'ECON1001-00') {
                expect(meeting.classroom, isEmpty);
              }
            }
          }
          final key = timetableCourseSyncKey(t);
          values[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'review',
          );
        }
        final doc = TimetableSyncDocument.records(courses: values);
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        for (final entry in values.entries) {
          expect(restored.courses[entry.key]!.value, entry.value.value);
        }
      }
    },
  );
}
