import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Timetable datasets of universities whose search is suspended are kept out of
/// the app's `assets/` bundle (they only add package size) and stored here.
const suspendedAssetRoot = 'test/fixtures/suspended_assets';

/// Reads the real `assets/` tree plus the suspended datasets, so tests see the
/// same catalog the app would ship once support resumes.
///
/// To resume support for a university: `git mv` its dataset files from
/// `test/fixtures/suspended_assets/timetable/` back to `assets/timetable/`,
/// append their paths to `assets/timetable/catalog.json`, delete the
/// university's `<university>.catalog.json` there, and take the university off
/// `UniversitySupportPolicy.suspendedTimetableUniversities`.
class SuspendedAssetBundle extends CachingAssetBundle {
  /// One `<university>.catalog.json` per suspended university, so the pull
  /// requests that suspend different universities never edit the same file.
  List<String> get _suspendedPaths => [
    for (final file in Directory(
      '$suspendedAssetRoot/timetable',
    ).listSync().whereType<File>())
      if (file.path.endsWith('.catalog.json'))
        ...(jsonDecode(file.readAsStringSync()) as List).cast<String>(),
  ];

  File? _suspendedFile(String key) {
    if (!key.startsWith('assets/timetable/')) return null;
    final file = File('$suspendedAssetRoot/${key.substring('assets/'.length)}');
    return _suspendedPaths.contains(key) && file.existsSync() ? file : null;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/timetable/catalog.json') {
      final shipped = (jsonDecode(File(key).readAsStringSync()) as List)
          .cast<String>();
      return jsonEncode([...shipped, ..._suspendedPaths]);
    }
    return (_suspendedFile(key) ?? File(key)).readAsStringSync();
  }

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    (_suspendedFile(key) ?? File(key)).readAsBytesSync(),
  );
}
