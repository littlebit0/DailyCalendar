import 'dart:io';

import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
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

  test('Sunmoon keeps the restored partial public dataset', () async {
    final datasets = await UniversityCatalog.load(
      bundle: _Files(),
      university: 'sunmoon',
    );
    expect(
      {for (final d in datasets) d.campus: d.courses.length},
      {'unknown': 10},
    );
    final courses = datasets.single.courses;
    expect(courses.where((c) => c.scheduleStatus == 'scheduled'), hasLength(7));
    // Recorded-only HUSS courses publish no weekday or period.
    final untimed = courses.where((c) => c.scheduleStatus == 'unscheduled');
    expect(untimed.map((c) => c.sourceSchedule).toSet(), {'비대면(동영상) 100'});
    expect(untimed, hasLength(3));

    final period = (await TimetablePeriodDefaults.load(
      bundle: _Files(),
    )).periodFor(2026, '2', university: 'sunmoon');
    expect(period?.start, DateTime(2026, 9, 1));
    expect(period?.end, DateTime(2026, 12, 14));
  });

  test(
    'Sunmoon leaves only the user-held HUSS label without an affiliation',
    () async {
      final catalog = await UniversityCatalog.load();
      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in catalog.where((d) => d.universityId == 'sunmoon')) {
        for (final course in dataset.courses) {
          for (final label in course.departments) {
            if (course.isMajorForSourceDepartment(label) &&
                !course.offeringOrganizations.any(
                  (o) => o.sourceLabel == label,
                )) {
              raw.add('${dataset.campus} $label');
            }
          }
          for (final o in course.offeringOrganizations) {
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                course.isMajorForOrganization(o)) {
              orphans.add('${dataset.campus} ${o.department}');
            }
          }
        }
      }
      // Needs a user decision: the consortium list marks these courses
      // 전공구분 "없음", and no official page names their offering unit.
      expect(raw, {'unknown HUSS 위험사회'});
      expect(orphans, isEmpty);
    },
  );
}
