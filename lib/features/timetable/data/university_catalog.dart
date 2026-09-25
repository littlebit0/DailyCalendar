import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/university_course.dart';

class UniversityDataset {
  UniversityDataset.fromJson(Map<String, dynamic> json)
    : universityId = json['universityId'] as String? ?? 'smu',
      campus = json['campus'] as String,
      publishedDate = json['publishedDate'] as String,
      sourceUrl = json['sourceUrl'] as String,
      courses = List.unmodifiable(
        (json['courses'] as List).map(
          (c) => UniversityCourse.fromJson(Map<String, dynamic>.from(c as Map)),
        ),
      ) {
    if (json['schemaVersion'] != 1 ||
        universityId.trim().isEmpty ||
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
  String get university => universityId;
  final List<UniversityCourse> courses;
}

class UniversityCatalog {
  static Future<List<UniversityDataset>> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final files =
        jsonDecode(await assets.loadString('assets/timetable/catalog.json'))
            as List;
    return Future.wait(
      files.map(
        (path) async => UniversityDataset.fromJson(
          jsonDecode(await assets.loadString(path as String))
              as Map<String, dynamic>,
        ),
      ),
    );
  }
}
