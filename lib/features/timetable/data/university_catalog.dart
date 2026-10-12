import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/university_course.dart';
import 'course_organization_directory.dart';

class UniversityDataset {
  UniversityDataset.fromJson(
    Map<String, dynamic> json, {
    CourseOrganizationDirectory? organizationDirectory,
  }) : universityId = json['universityId'] as String? ?? 'smu',
       campus = json['campus'] as String,
       campusName = json['campusName'] as String?,
       publishedDate = json['publishedDate'] as String,
       sourceNotice = json['sourceNotice'] as String? ?? '',
       sourceUrl = json['sourceUrl'] as String,
       courses = List.unmodifiable(
         (json['courses'] as List).map(
           (c) => UniversityCourse.fromJson(
             organizationDirectory?.apply(
                   Map<String, dynamic>.from(c as Map),
                 ) ??
                 Map<String, dynamic>.from(c as Map),
           ),
         ),
       ) {
    if ((json['schemaVersion'] != 1 && json['schemaVersion'] != 2) ||
        (json['schemaVersion'] == 1 &&
            courses.any((c) => c.meetings.any((m) => m.date != null))) ||
        universityId.trim().isEmpty ||
        (campusName != null && campusName!.trim().isEmpty) ||
        courses.any(
          (c) =>
              c.campus != campus ||
              c.academicYear != json['academicYear'] ||
              c.semester != json['semester'],
        ) ||
        courses.map((c) => c.sourceId).toSet().length != courses.length) {
      throw const FormatException('Invalid university dataset');
    }
  }
  final String universityId, campus, publishedDate, sourceUrl;
  final String sourceNotice;
  final String? campusName;
  String get university => universityId;
  final List<UniversityCourse> courses;
}

class UniversityCatalog {
  static Future<List<UniversityDataset>> load({
    AssetBundle? bundle,
    String? university,
  }) async {
    final assets = bundle ?? rootBundle;
    final files =
        jsonDecode(await assets.loadString('assets/timetable/catalog.json'))
            as List;
    final datasets = <UniversityDataset>[];
    final organizations = <String, CourseOrganizationDirectory>{};
    for (final path in files.cast<String>()) {
      // Catalog filenames are university-campus-year-semester. Do not load
      // every school's courses when the user opens one school's search.
      if (university != null &&
          !path.split('/').last.startsWith('$university-')) {
        continue;
      }
      final json =
          jsonDecode(await assets.loadString(path)) as Map<String, dynamic>;
      final school = json['universityId'] as String? ?? 'smu';
      if (!organizations.containsKey(school)) {
        final directory = CourseOrganizationDirectory.fromJson(
          jsonDecode(
                await assets.loadString(
                  'assets/timetable/organizations/$school.json',
                ),
              )
              as Map<String, dynamic>,
        );
        if (directory.university != school) {
          throw const FormatException('Organization university mismatch');
        }
        organizations[school] = directory;
      }
      final dataset = UniversityDataset.fromJson(
        json,
        organizationDirectory: organizations[school],
      );
      if (university != null && dataset.university != university) {
        throw const FormatException(
          'Catalog university does not match its file',
        );
      }
      datasets.add(dataset);
    }
    return datasets;
  }
}
