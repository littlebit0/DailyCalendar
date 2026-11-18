import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBundle extends CachingAssetBundle {
  final cached = <String>[];

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (cache) cached.add(key);
    return super.loadString(key, cache: cache);
  }
}

void main() {
  test('catalog load keeps no school or organization text cached', () async {
    final bundle = _RecordingBundle();
    final datasets = await UniversityCatalog.load(
      bundle: bundle,
      university: 'smu',
    );
    expect(datasets, isNotEmpty);
    expect(datasets.every((d) => d.university == 'smu'), isTrue);
    expect(bundle.cached, ['assets/timetable/catalog.json']);
  });
}
