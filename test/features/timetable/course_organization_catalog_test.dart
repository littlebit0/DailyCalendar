import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/course_organization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'published organization overlay preserves every original course and campus',
    () {
      final paths =
          (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
                  as List)
              .cast<String>();
      final directories = <String, CourseOrganizationDirectory>{};
      final selected =
          (Platform.environment['DAILY_ORGANIZATION_RECHECK'] ?? '')
              .split(',')
              .where((school) => school.isNotEmpty)
              .toSet();
      final withPublishedUnits = <String>{};
      var withOrganizations = 0;
      for (final path in paths) {
        final source =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        final school = source['universityId'] as String? ?? 'smu';
        if (selected.isNotEmpty && !selected.contains(school)) continue;
        final directory = directories.putIfAbsent(
          school,
          () => CourseOrganizationDirectory.fromJson(
            jsonDecode(
                  File(
                    'assets/timetable/organizations/$school.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
          ),
        );
        expect(directory.university, school, reason: path);
        final dataset = UniversityDataset.fromJson(
          source,
          organizationDirectory: directory,
        );
        final original = (source['courses'] as List)
            .cast<Map<String, dynamic>>();
        expect(dataset.courses.length, original.length, reason: path);
        for (var i = 0; i < original.length; i++) {
          final raw = original[i];
          final converted = directory.apply(raw);
          final restored = Map<String, dynamic>.from(converted)
            ..remove('offeringOrganizations');
          expect(restored, raw, reason: '$path: ${raw['sourceId']}');
          final course = dataset.courses[i];
          expect(course.sourceId, raw['sourceId']);
          expect(course.campus, source['campus']);
          if (course.offeringOrganizations.isNotEmpty) {
            withOrganizations++;
            withPublishedUnits.add(school);
          }
          for (final unit in course.offeringOrganizations) {
            expect(unit.college, isNot('대학(전체)'));
            if (unit.department != null && unit.college != null) {
              final ancestor = CourseOrganization(
                college: unit.college,
                department: null,
                sourceLabel: unit.college!,
              );
              if (!course.offeringOrganizations.any(
                (u) => u.isCollegeHosted && u.college == unit.college,
              )) {
                expect(
                  course.matchesOrganization(ancestor),
                  isFalse,
                  reason: course.sourceId,
                );
              }
            }
          }
        }
      }
      expect(directories.length, selected.isEmpty ? 96 : selected.length);
      if (selected.isNotEmpty) {
        expect(withPublishedUnits, containsAll(selected));
      }
      expect(withOrganizations, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
