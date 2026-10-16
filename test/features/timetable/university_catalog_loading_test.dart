import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == 'assets/timetable/catalog.json') {
      return ByteData.sublistView(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode([
              'assets/timetable/dku-jukjeon-2026-2.json',
              'assets/timetable/jnu-gwangju-2026-2.json',
            ]),
          ),
        ),
      );
    }
    if (key.contains('/jnu-')) {
      throw const FormatException('Unrelated broken catalog');
    }
    return ByteData.sublistView(File(key).readAsBytesSync());
  }
}

void main() {
  test('worker propagates malformed JSON and organization mismatch', () async {
    for (final malformed in [true, false]) {
      await expectLater(
        UniversityCatalog.load(
          bundle: _InvalidBundle(malformed),
          university: 'smu',
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'one school loads independently from unrelated missing or corrupt data',
    () async {
      final bundle = _Bundle();
      final datasets = await UniversityCatalog.load(
        bundle: bundle,
        university: 'dku',
      );
      expect(datasets.single.university, 'dku');
      expect(datasets.single.courses.length, 2722);
      expect(bundle.loaded.any((key) => key.contains('/jnu-')), isFalse);
    },
  );
  test(
    'a school without catalog does not fall back to Sangmyung courses',
    () async {
      final bundle = _Bundle();
      expect(
        await UniversityCatalog.load(bundle: bundle, university: 'snu'),
        isEmpty,
      );
      expect(bundle.loaded, ['assets/timetable/catalog.json']);
    },
  );
}

class _InvalidBundle extends CachingAssetBundle {
  _InvalidBundle(this.malformed);
  final bool malformed;
  @override
  Future<ByteData> load(String key) async {
    final text = key.endsWith('catalog.json')
        ? '["assets/timetable/smu-seoul-2026-2.json"]'
        : key.contains('/organizations/')
        ? '{"schemaVersion":1,"university":"other","mappings":[],"courseOwners":[]}'
        : malformed
        ? '{invalid'
        : '{"universityId":"smu"}';
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}
