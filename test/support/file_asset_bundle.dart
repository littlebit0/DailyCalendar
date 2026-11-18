import 'dart:io';

import 'package:flutter/services.dart';

/// Serves repository files as Flutter assets, for tests that load shipped
/// catalogs through an [AssetBundle].
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}
