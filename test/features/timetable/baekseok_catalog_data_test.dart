import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('BU major labels open as its official top-level faculties', () async {
    final data = (await UniversityCatalog.load(
      bundle: FileAssetBundle(),
      university: 'baekseok',
    )).single;
    expect(data.courses, hasLength(2571));
    final labels = <String>{};
    for (final c in data.courses) {
      for (final label in c.departments.where(c.isMajorForSourceDepartment)) {
        labels.add(label);
        // The official faculty list has no college above each 학부(과).
        expect(
          c.offeringOrganizations
              .where((o) => o.sourceLabel == label)
              .map((o) => (o.college, o.department)),
          [(label, null)],
        );
      }
    }
    expect(labels, hasLength(18));
  });
  test('BU maps its own timetable independently from calendar source ID', () {
    for (final id in [
      'institution:academyinfo:0000178',
      'academyinfo:0000178',
    ]) {
      final p = AcademicProfile(
        universityId: id,
        universityName: '백석대학교',
        schoolKind: 'fourYear',
      );
      expect(p.timetableUniversity, 'baekseok');
      expect(p.timetableCampus, 'unknown');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '백석대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'BU frozen two exact general offerings preserve their direct original clocks',
    () {
      final raw =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-s/bu-contract-scoped-clock-v2-20261009/baseline2571-current-asset.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final courses = UniversityDataset.fromJson(raw).courses;
      expect(courses, hasLength(2571));
      final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(approved.map((c) => c.codeAndSection).toSet(), {
        '08544-31',
        '30188-03',
      });
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(2407),
      );
      expect(approved.expand((c) => c.meetings), hasLength(26));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in approved) {
          expect(c.remarks, contains('계약학과'));
          expect(c.remarks, contains('1학년'));
          expect(c.remarks, contains('시험 시각'));
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          expect(saved.meetings, hasLength(13));
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
          for (final m in saved.meetings) {
            expect(m.weekday, 2);
            expect(m.teachingDate!.weekday, 2);
            expect(
              m.date,
              isNot(isIn(['2026-10-20', '2026-12-08', '2026-12-09'])),
            );
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-01'), lessThanOrEqualTo(0));
            expect(m.originalStartMinute, c.code == '08544' ? 540 : 840);
            expect(m.originalEndMinute, c.code == '08544' ? 650 : 950);
            expect(m.endMinute, c.code == '08544' ? 660 : 960);
            expect(m.classroom, c.code == '08544' ? '진리311' : '진리506');
            expect(saved.modeOn(m, m.teachingDate!), mode);
          }
        }
        final doc = TimetableSyncDocument.records(courses: values);
        expect(doc.schemaVersion, 2);
        final restore = TimetableSyncDocument.fromJson(doc.toJson());
        for (final key in values.keys) {
          expect(restore.courses[key]!.value, values[key]!.value);
        }
      }
    },
  );
  test('BU undergraduate periods use the booklet 60-minute slots from 09:00', () async {
    final data = (await UniversityCatalog.load(
      bundle: FileAssetBundle(),
      university: 'baekseok',
    )).single;
    final byStatus = <String?, int>{};
    for (final c in data.courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
    }
    expect(byStatus, {'scheduled': 2382, 'unscheduled': 189});
    // 비고 "13~15주차/백석연수원/집중이수": 수업 주차 현황의 13~15주차와 연수원 1박 2일만
    final ai = data.courses.singleWhere((c) => c.codeAndSection == '32065-01');
    expect(ai.meetings.map((m) => m.date), [
      '2026-09-11',
      '2026-09-12',
      '2026-11-24',
      '2026-12-01',
      '2026-12-15',
    ]);
    // 작업치료학과 3학년: 10월 26일부터 8주간 집중수업
    final ot = data.courses.singleWhere((c) => c.codeAndSection == '09502-01');
    expect(ot.meetings.map((m) => m.date).toSet(), {
      '2026-10-26',
      '2026-11-02',
      '2026-11-09',
      '2026-11-16',
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
      '2026-12-14',
    });
    expect(
      data.courses
          .where((c) => ['09957', '08956'].contains(c.code))
          .map((c) => c.scheduleStatus)
          .toSet(),
      {'unscheduled'},
    );
    // The schedule explanation reaches the displayed remarks, which prefer
    // department remarks over the top-level note.
    final emergency = data.courses.singleWhere(
      (c) => c.codeAndSection == '09957-01',
    );
    expect(emergency.remarks, contains('집중이수 주차 미공개'));
    expect(emergency.remarks, contains('응급구조학과'));
    for (final c in data.courses.where((c) => c.sourceRemarks.isNotEmpty)) {
      expect(c.remarks, contains(c.sourceRemarks.trim()), reason: c.sourceId);
    }
    // 목5,6 → 13:00~15:00 (5교시 13:00 시작, 60분 슬롯 두 개)
    final music = data.courses.singleWhere(
      (c) => c.codeAndSection == '07294-01',
    );
    expect(music.sourceSchedule, '목5,6');
    expect(
      music.meetings.map(
        (m) => (m.weekday, m.originalStartMinute, m.originalEndMinute),
      ),
      [(4, 780, 900)],
    );
    // 요일만 있고 교시가 빈 강좌는 시각을 만들지 않고 시간 미정
    for (final code in ['30035-01', '31438-01']) {
      final c = data.courses.singleWhere((c) => c.codeAndSection == code);
      expect(c.scheduleStatus, 'unscheduled');
      expect(c.meetings, isEmpty);
    }
    for (final c in data.courses.where((c) => c.sourceSchedule == '사')) {
      expect(c.scheduleStatus, 'unscheduled');
      expect(c.meetings, isEmpty);
    }
  });
}
