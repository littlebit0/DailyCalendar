import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
    final texts = <String>[];
    for (final path in files.cast<String>()) {
      if (university != null &&
          !path.split('/').last.startsWith('$university-')) {
        continue;
      }
      texts.add(await assets.loadString(path));
    }
    if (texts.isEmpty) return [];
    final decoded = await compute(_decodeDatasets, texts);
    final organizationTexts = <String, String>{};
    for (final json in decoded) {
      final school = json['universityId'] as String? ?? 'smu';
      if (!organizationTexts.containsKey(school)) {
        organizationTexts[school] = await assets.loadString(
          'assets/timetable/organizations/$school.json',
        );
      }
    }
    return compute(_buildDatasets, (decoded, organizationTexts, university));
  }
}

List<Map<String, dynamic>> _decodeDatasets(List<String> texts) => [
  for (final text in texts) jsonDecode(text) as Map<String, dynamic>,
];

List<UniversityDataset> _buildDatasets(
  (List<Map<String, dynamic>>, Map<String, String>, String?) input,
) {
  final (decoded, texts, university) = input;
  final organizations = <String, CourseOrganizationDirectory>{};
  for (final entry in texts.entries) {
    final directory = CourseOrganizationDirectory.fromJson(
      jsonDecode(entry.value) as Map<String, dynamic>,
    );
    if (directory.university != entry.key) {
      throw const FormatException('Organization university mismatch');
    }
    organizations[entry.key] = directory;
  }
  final datasets = <UniversityDataset>[];
  for (final json in decoded) {
    final school = json['universityId'] as String? ?? 'smu';
    final dataset = UniversityDataset.fromJson(
      json,
      organizationDirectory: organizations[school],
    );
    if (university != null && dataset.university != university) {
      throw const FormatException('Catalog university does not match its file');
    }
    datasets.add(dataset);
  }
  return datasets;
}
