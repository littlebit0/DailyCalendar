import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
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
  for (final (university, id, count, lastDay) in [
    ('snu', '0000019', 3744, DateTime(2026, 12, 14)),
    ('ajou', '0000146', 2237, DateTime(2026, 12, 21)),
  ]) {
    test(
      '$university loads its verified catalog and bounded semester',
      () async {
        final datasets = await UniversityCatalog.load(
          bundle: _Files(),
          university: university,
        );
        expect(datasets.length, 1);
        final data = datasets.single;
        expect(data.universityId, university);
        expect(data.campus, 'main');
        expect(data.courses.length, count);
        expect(data.courses.map((c) => c.sourceId).toSet().length, count);
        expect(
          data.courses.every(
            (c) => c.academicYear == 2026 && c.semester == '2',
          ),
          isTrue,
        );
        expect(
          data.courses
              .where((c) => c.scheduleStatus == 'unscheduled')
              .every((c) => c.meetings.isEmpty),
          isTrue,
        );
        expect(
          data.courses
              .where((c) => c.scheduleStatus == 'scheduled')
              .every(
                (c) =>
                    c.meetings.isNotEmpty &&
                    c.meetings.every((m) => m.endMinute > m.startMinute),
              ),
          isTrue,
        );
        final profile = AcademicProfile(
          universityId: 'institution:academyinfo:$id',
          universityName: university,
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, university);
        expect(profile.timetableCampus, 'main');
        expect(profile.academicSourceId, university);
        final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
        final period = defaults.periodFor(2026, '2', university: university)!;
        expect(period.start, DateTime(2026, 9, 1));
        expect(period.end, lastDay);
        expect(period.contains(DateTime(2026, 8, 31)), isFalse);
        expect(period.contains(lastDay.add(const Duration(days: 1))), isFalse);
        expect(defaults.periodsFor(university).length, 4);
      },
    );
  }
  test('published SNU restrictions and classrooms remain in search data', () {
    final data = UniversityDataset.fromJson(
      jsonDecode(
        File('assets/timetable/snu-main-2026-2.json').readAsStringSync(),
      ),
    );
    expect(data.courses.any((c) => c.remarks.isNotEmpty), isTrue);
    expect(data.courses.first.codeAndSection, 'C10.101-001');
    expect(data.courses.first.meetings.first.startMinute, 660);
    expect(data.courses.first.meetings.first.endMinute, 750);
    expect(data.courses.first.meetings.first.classroom, contains('14-203'));
  });
}
