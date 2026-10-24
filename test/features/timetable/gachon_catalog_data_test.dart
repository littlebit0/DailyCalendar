import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Gachon integrated profile exposes both published campuses', () async {
    final datasets = await UniversityCatalog.load(
      bundle: _Files(),
      university: 'gachon',
    );
    expect(
      {for (final d in datasets) d.campus: d.courses.length},
      {'global': 3242, 'medical': 567},
    );
    for (final id in [
      'academyinfo:0000063',
      'institution:academyinfo:0000063',
    ]) {
      final profile = AcademicProfile.fromJson(
        AcademicProfile(
          universityId: id,
          universityName: '가천대학교',
          schoolKind: 'fourYear',
        ).toJson(),
      );
      expect(profile.timetableUniversity, 'gachon');
      expect(profile.timetableCampus, 'global');
    }
    expect(
      const AcademicProfile(
        universityId: 'institution:academyinfo:0000063',
        universityName: '가천대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000117',
      ).timetableSupported,
      isFalse,
    );
    final period = (await TimetablePeriodDefaults.load(
      bundle: _Files(),
    )).periodFor(2026, '2', university: 'gachon');
    expect(period?.start, DateTime(2026, 9, 1));
    expect(period?.end, DateTime(2026, 12, 21));
  });

  test(
    'Gachon dated public plans retain per-course bounds and Drive values',
    () {
      final courses = <UniversityCourse>[];
      for (final campus in ['global', 'medical']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/gachon-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(raw['currentFullOperatingAuditFinished'], isFalse);
        courses.addAll(UniversityDataset.fromJson(raw).courses);
      }
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3809));
      final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
      expect(approved, hasLength(3445));
      expect(approved.expand((c) => c.meetings), hasLength(58145));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final course in approved) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          expect(saved.note, course.remarks);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'test',
          );
          for (final m in saved.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
            expect(m.date!.compareTo('2026-12-21'), lessThanOrEqualTo(0));
            if (course.codeAndSection == '15290-025' &&
                m.date == '2026-10-05') {
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              continue;
            }
            if (course.codeAndSection == '05271-001' &&
                m.date == '2026-09-24') {
              expect(m.originalStartMinute, 660);
              expect(m.originalEndMinute, 780);
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              continue;
            }
            if (course.codeAndSection == '10130-001' &&
                m.date == '2026-10-05') {
              expect(m.originalStartMinute, 600);
              expect(m.originalEndMinute, 780);
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.inPerson);
              continue;
            }
            if (course.codeAndSection == '14478-002' &&
                m.date == '2026-10-09') {
              expect(m.originalStartMinute, 900);
              expect(m.originalEndMinute, 1080);
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              continue;
            }
            if (course.codeAndSection == '10275-001' &&
                m.date == '2026-10-09') {
              expect(m.originalStartMinute, 840);
              expect(m.originalEndMinute, 1020);
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              continue;
            }
            if (['M3757-002', 'M3757-003'].contains(course.codeAndSection) &&
                m.date == '2026-10-05') {
              expect(saved.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
              continue;
            }
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
          }
          expect(
            classOccurrences(
              [saved],
              [DateTime(2026, 8, 31), DateTime(2026, 12, 22)],
            ),
            isEmpty,
          );
        }
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final entry in restored.courses.entries) {
          expect(entry.value.value, values[entry.key]!.value);
        }
      }
      final orientation = approved.singleWhere(
        (c) => c.codeAndSection == '12718-001',
      );
      expect(orientation.meetings, hasLength(1));
      expect(orientation.meetings.single.date, '2026-09-01');
      expect(orientation.meetings.single.originalStartMinute, 780);
      expect(orientation.meetings.single.originalEndMinute, 840);
    },
  );

  test('Gachon period slots include the 10 minute break (60 minute slots)', () {
    // 교시 시작은 60분 간격(50분 수업+10분 쉬는 시간): 1교시 09:00, 2교시 10:00 ...
    // 근거: gachon-current-scope-clock-term-manifest.json clock50minPeriods
    // (https://www.gachon.ac.kr/bbs/kor/475/151337/download.do), 학교 규정 문서는 미확인.
    var checked = 0;
    var clockText = 0;
    for (final campus in ['global', 'medical']) {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/gachon-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final course in raw['courses'] as List) {
        final byDay = <String, List<Map>>{};
        for (final s in (course as Map)['schedules'] as List) {
          final start = s['startMinute'] as int;
          final end = s['endMinute'] as int;
          if (course['sourceId'] == 'gachon/20/2026/2/12718/001') {
            // 원문이 시각을 직접 적은 오리엔테이션(13:00~14:00)은 그대로 둔다.
            expect(end, 840);
            clockText++;
            continue;
          }
          expect(start % 60, 0, reason: course['sourceId']);
          expect(end % 60, 0, reason: course['sourceId']);
          checked++;
          byDay.putIfAbsent('${s['date']}|${s['classroom']}', () => []).add(s);
        }
        for (final list in byDay.values) {
          list.sort(
            (a, b) =>
                (a['startMinute'] as int).compareTo(b['startMinute'] as int),
          );
          for (var i = 1; i < list.length; i++) {
            expect(
              (list[i]['startMinute'] as int) -
                  (list[i - 1]['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: course['sourceId'],
            );
          }
        }
      }
    }
    expect(checked, 58144);
    expect(clockText, 1);
  });
}
