import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Eulji restores the partial catalog with every label affiliated',
    () async {
      final catalog = await UniversityCatalog.load();
      final datasets = catalog.where((d) => d.universityId == 'eulji').toList();
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'seongnam': 389, 'uijeongbu': 34},
      );

      final raw = <String>{};
      final orphans = <String>{};
      for (final dataset in datasets) {
        for (final course in dataset.courses) {
          expect(
            course.hasSchedulableMeetings,
            isTrue,
            reason: course.sourceId,
          );
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
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
    },
  );

  test('Eulji course names never carry the section column', () async {
    final catalog = await UniversityCatalog.load();
    var checked = 0;
    for (final dataset in catalog.where((d) => d.universityId == 'eulji')) {
      for (final course in dataset.courses) {
        checked++;
        expect(course.title.trim(), course.title, reason: course.sourceId);
        expect(
          course.title,
          isNot(matches(RegExp(r'\s{2,}'))),
          reason: course.sourceId,
        );
        if (course.section.isNotEmpty) {
          expect(
            course.title.endsWith(' ${course.section}'),
            isFalse,
            reason: course.sourceId,
          );
        }
      }
    }
    expect(checked, 423);
  });

  test('Eulji period slots include the following break', () {
    var checked = 0;
    for (final campus in ['seongnam', 'uijeongbu']) {
      final data =
          jsonDecode(
                File(
                  'assets/timetable/eulji-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final c in data['courses'] as List) {
        final src = c['sourceSchedule'] as String;
        for (final s in c['schedules'] as List) {
          final start = s['startMinute'] as int;
          final end = s['endMinute'] as int;
          if (src.contains('야')) {
            expect(start, 1080, reason: src);
            // 야1~3 = 18:00~20:25(3교시 뒤 10분 휴식 포함), 야1~2 = 18:00~19:30.
            expect(end, src.endsWith('3') ? 1225 : 1170, reason: src);
          } else {
            expect(start % 60, 0, reason: src);
            expect(end % 60, 0, reason: src);
          }
          checked++;
        }
      }
    }
    expect(checked, 423);
  });
}
