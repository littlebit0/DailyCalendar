import 'dart:convert';
import 'dart:io' as io;
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:flutter/services.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      io.File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(io.File(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('BU major labels open as its official top-level faculties', () async {
    final data = (await UniversityCatalog.load(
      bundle: _Files(),
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
}
