import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Sangmyung real sources keep general education out of department major filters',
    () {
      final paths =
          (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
                  as List)
              .cast<String>();
      final directories = <String, CourseOrganizationDirectory>{};
      var majorAssociations = 0;
      var generalAssociations = 0;
      for (final path in paths) {
        final raw =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        final school = raw['universityId'] as String? ?? 'smu';
        if (school != 'smu') continue;
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
        final dataset = UniversityDataset.fromJson(
          raw,
          organizationDirectory: directory,
        );
        for (final course in dataset.courses) {
          for (final unit in course.offeringOrganizations.where(
            (unit) => unit.department != null,
          )) {
            final majors = course.majorClassificationLabelsForOrganization(
              unit,
            );
            expect(
              course.isMajorForOrganization(unit),
              majors.isNotEmpty,
              reason: '${course.sourceId}/${unit.sourceLabel}',
            );
            for (final label in majors) {
              expect(
                label.contains('교양') ||
                    label == '교필' ||
                    label == '교선' ||
                    label.contains('교직'),
                isFalse,
                reason: '${course.sourceId}: $label',
              );
            }
            if (majors.isNotEmpty) majorAssociations++;
            final all = course.classificationLabelsForOrganization(unit);
            if (all.isNotEmpty &&
                all.every(
                  (label) => label == '교필' || label == '교선' || label == '교양',
                )) {
              generalAssociations++;
              expect(
                course.isMajorForOrganization(unit),
                isFalse,
                reason: course.sourceId,
              );
            }
            if (unit.group != null) {
              expect(unit.group!.trim(), isNotEmpty);
            }
          }
        }
      }
      expect(directories.keys, ['smu']);
      expect(majorAssociations, greaterThan(0));
      expect(generalAssociations, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
