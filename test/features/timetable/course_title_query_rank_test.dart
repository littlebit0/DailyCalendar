import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  test('published names with a trailing space rank as exact matches', () async {
    final courses = [
      for (final dataset in await UniversityCatalog.load(
        bundle: _FileBundle(),
        university: 'cau',
      ))
        ...dataset.courses,
    ];
    // 36 CAU courses keep the trailing space they were published with.
    final spaced = courses.where((c) => c.title != c.title.trim()).toList();
    expect(spaced, hasLength(36));
    for (final course in spaced) {
      expect(course.queryRank(course.title.trim()), 0, reason: course.title);
    }
    // A longer, different name still ranks as a prefix match only.
    final course = spaced.first;
    expect(course.queryRank(course.title.trim().substring(0, 1)), 1);
  });
}
