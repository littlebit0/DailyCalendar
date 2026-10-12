import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-n';
Map<String, dynamic> read(String f) {
  final match = RegExp(
    r'^tuk-(first|unknown)-2026-2\.published-regular',
  ).firstMatch(f);
  final path = match == null
      ? '$directory/$f'
      : 'assets/timetable/tuk-${match[1]}-2026-2.json';
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('TUK integrated identity rejects another university campus', () {
    for (final id in [
      'institution:academyinfo:0000247',
      'academyinfo:0000247',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '한국공학대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'tuk');
      expect(profile.timetableCampus, 'first');
      expect(profile.academicSourceId, 'tuk');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국공학대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  final audit = read('tuk-published-regular-1346-v2-next-audit-20261008.json');
  final raw = [
    for (final e in audit['datasets'] as List)
      ...read(e['file'])['courses'] as List,
  ];
  final courses = [
    for (final e in audit['datasets'] as List)
      ...UniversityDataset.fromJson(read(e['file'])).courses,
  ];
  test(
    '1431 native education lossless with physical campus evidence separate',
    () {
      expect(courses, hasLength(1431));
      for (final e in audit['datasets'] as List) {
        expect(
          sha256
              .convert(File('$directory/${e['file']}').readAsBytesSync())
              .toString(),
          e['sha256'],
        );
      }
      for (final a
          in read('tuk-research-safe-snapshot-candidates.json')['courses']
              as List) {
        final b = raw.singleWhere((b) => b['sourceId'] == a['sourceId']) as Map;
        for (final k in a.keys) {
          if (![
            'campus',
            'researchOnly',
            'productionRegistered',
            'scheduleStatus',
            'schedules',
            'departmentRemarks',
          ].contains(k)) {
            expect(b[k], a[k]);
          }
        }
        expect(b['sourceSnapshotSchedules'], a['schedules']);
        expect(b['sourceDepartmentRemarks'], a['departmentRemarks']);
        expect(b['sourceCampusPreparationAlias'], 'main');
        for (final e in (a['departmentRemarks'] as Map).entries) {
          expect(b['departmentRemarks'][e.key], startsWith(e.value));
        }
      }
      expect(courses.where((c) => c.campus == 'first'), hasLength(824));
      expect(courses.where((c) => c.campus == 'unknown'), hasLength(607));
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('1346 dated school plans actual sync roundtrip $mode', () {
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in courses) {
        if (c.meetings.isEmpty) {
          continue;
        }
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        expect(saved.isValid, isTrue);
        expect(saved.period!.end, DateTime(2026, 12, 22));
        expect(saved.note, contains('통합정보시스템'));
        final source =
            raw.singleWhere((b) => b['sourceId'] == c.sourceId) as Map;
        final blocks = source['sourceSnapshotSchedules'] as List;
        final seen = <String>{};
        for (final m in saved.meetings) {
          count++;
          final date = m.date!;
          expect(
            date.compareTo('2026-09-01') >= 0 &&
                date.compareTo('2026-12-07') <= 0,
            isTrue,
          );
          expect(
            date.compareTo('2026-10-20') >= 0 &&
                date.compareTo('2026-10-26') <= 0,
            isFalse,
          );
          expect(
            [
              '2026-09-24',
              '2026-09-25',
              '2026-09-26',
              '2026-10-03',
              '2026-10-05',
              '2026-10-09',
            ].contains(date),
            isFalse,
          );
          expect(m.classroom.contains('온라인'), isFalse);
          final b = blocks.singleWhere(
            (b) =>
                b['weekday'] == m.weekday &&
                b['startMinute'] == m.originalStartMinute &&
                b['endMinute'] == m.originalEndMinute &&
                b['classroom'] == m.classroom,
          );
          expect(
            saved.modeOn(m, m.teachingDate!),
            b['deliveryMode'] == 'liveOnline' ? LectureMode.liveOnline : mode,
          );
          expect(
            seen.add(
              '$date/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            isTrue,
          );
        }
        values[timetableCourseSyncKey(saved)] = TimetableSyncValue(
          {...saved.toJson(), 'id': timetableCourseSyncKey(saved)},
          DateTime.utc(2026, 10, 8),
          'research',
        );
      }
      expect(values, hasLength(1346));
      expect(count, 20412);
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      for (final c in restored.materializeClasses()) {
        expect(c.isValid, isTrue);
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        expect(c.note, contains('최종 활성'));
      }
    });
  }
  test(
    'online uncertainty and source native labels survive in user-visible notes',
    () {
      final partial = audit['partialOnlineScope'] as List;
      expect(partial, hasLength(10));
      expect(partial.where((x) => x['physicalSubsetAvailable']), hasLength(7));
      for (final x in partial) {
        final c = courses.singleWhere((c) => c.sourceId == x['sourceId']);
        expect(c.remarks, contains('실시간/동영상'));
        expect(c.remarks, contains('휴강 확정이 아니'));
      }
      for (final c in courses) {
        expect(
          RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}').hasMatch(c.remarks),
          isFalse,
        );
      }
    },
  );
}
