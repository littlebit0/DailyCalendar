import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Separate native disk map from legacy SharedPreferences' optimistic cache.
class PersistenceFailureStore extends SharedPreferencesStorePlatform {
  final disk = <String, Object>{};
  String? failureKey;
  bool throws = false;
  bool silent = false;
  bool fails(String key) {
    if (key != failureKey) return false;
    if (throws) throw StateError('storage unavailable');
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(disk);
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fails(key)) return silent;
    disk[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (fails(key)) return silent;
    disk.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    disk.clear();
    return true;
  }
}
