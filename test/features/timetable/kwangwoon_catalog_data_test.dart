import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

// 0교시 08:00~09:00(50분+쉬는 시간 10분), 별표1 주간 1~6교시 75분+쉬는 시간
// 15분(90분 슬롯), 야간 7~10교시 45분+5분(50분 슬롯), 11교시는 별표1 표기 그대로.
const _slotStarts = [
  480,
  540,
  630,
  720,
  810,
  900,
  990,
  1080,
  1130,
  1180,
  1230,
  1280,
];
const _slotEnds = [
  540,
  630,
  720,
  810,
  900,
  990,
  1080,
  1130,
  1180,
  1230,
  1280,
  1340,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'registered Kwangwoon keeps whole search and dated attendance on restore',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kwangwoon',
      )).single;
      expect(data.courses, hasLength(1261));
      expect(data.courses.map((c) => c.sourceId).toSet(), hasLength(1261));
      expect(
        data.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(945),
      );
      expect(
        data.courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(316),
      );
      for (final c in data.courses) {
        expect(c.campus, 'unknown');
        expect(c.sourceSchedule, isNotEmpty);
        if (!c.hasSchedulableMeetings) continue;
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.period?.toJson(), saved.period?.toJson());
        for (final m in restored.meetings) {
          expect(m.date, isNotNull);
          for (final other in restored.meetings) {
            if (identical(m, other) || m.date != other.date) continue;
            expect(
              m.startMinute < other.endMinute &&
                  other.startMinute < m.endMinute,
              isFalse,
              reason: '${c.codeAndSection} ${m.date}',
            );
          }
          expect(m.teachingDate!.weekday, m.weekday);
          if (m.classroom.isEmpty) {
            expect(c.sourceClassroom, isEmpty);
          } else {
            expect(
              c.sourceClassroom.split(RegExp(r'[;\n]')).map((s) => s.trim()),
              contains(m.classroom),
            );
          }
          // 수업 운영에 관한 규정 [4-3-32] 별표1(수업시간)의 교시 시작 시각과,
          // 사용자 결정에 따라 쉬는 시간을 포함한 교시 끝 시각(다음 교시 시작).
          // 0교시(08:00~09:00)는 별표1에 없고 학사안내 연강 표와 사용자 결정 근거.
          expect(
            m.originalStartMinute,
            isIn(_slotStarts),
            reason: '${c.codeAndSection} ${m.date}',
          );
          expect(
            m.originalEndMinute,
            isIn(_slotEnds),
            reason: '${c.codeAndSection} ${m.date}',
          );
          expect(restored.modeOn(m, m.teachingDate!), LectureMode.inPerson);
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 31),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 9, 26),
              DateTime(2026, 10, 3),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
              DateTime(2026, 12, 15),
              DateTime(2026, 12, 21),
              DateTime(2027, 1, 1),
            ],
          ),
          isEmpty,
        );
      }
    },
  );
  test('Kwangwoon 0교시 연강 0~2교시는 08:00~12:00 한 블록으로 저장한다', () async {
    final data = (await UniversityCatalog.load(
      bundle: _Files(),
      university: 'kwangwoon',
    )).single;
    final zero = data.courses.where(
      (c) => c.hasSchedulableMeetings && c.sourceSchedule.contains(' 0,1,2'),
    );
    expect(zero, hasLength(28));
    for (final c in zero) {
      final t = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
      for (final m in t.meetings) {
        expect(m.originalStartMinute, 480, reason: c.codeAndSection);
        expect(m.originalEndMinute, 720, reason: c.codeAndSection);
      }
    }
  });
  test(
    'Kwangwoon major offering labels all belong to an official college',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kwangwoon',
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final d in data) {
        for (final c in d.courses) {
          for (final l in c.departments) {
            if (c.isMajorForSourceDepartment(l) &&
                !c.offeringOrganizations.any((o) => o.sourceLabel == l)) {
              raw.add('${d.campus} $l');
            }
          }
          for (final o in c.offeringOrganizations) {
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                c.isMajorForOrganization(o)) {
              orphans.add('${d.campus} ${o.department}');
            }
          }
        }
      }
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
      // The workbook's 개설대학 column names the college behind 공통 majors.
      final course = data.single.courses.singleWhere(
        (c) => c.sourceId == 'kwangwoon/unknown/2026/2/I000-2-1186-01',
      );
      expect(
        course.offeringOrganizations.map((o) => (o.college, o.department)),
        [('인공지능융합대학', null)],
      );
    },
  );
  test(
    'Kwangwoon profile uses actual unknown course location and published term',
    () async {
      for (final id in [
        'institution:academyinfo:0000074',
        'academyinfo:0000074',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '광운대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'kwangwoon');
        expect(profile.timetableCampus, 'unknown');
      }
      const foreign = AcademicProfile(
        universityId: 'institution:academyinfo:0000074',
        universityName: '광운대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000200',
      );
      expect(foreign.timetableCampus, isNull);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final term = defaults.periodFor(2026, '2', university: 'kwangwoon');
      expect(term?.start, DateTime(2026, 9, 1));
      expect(term?.end, DateTime(2026, 12, 21));
    },
  );
}
