import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherSettings {
  const WeatherSettings({
    this.enabled = false,
    this.automaticLocation = false,
    this.regionId,
  });
  final bool enabled;
  final bool automaticLocation;
  final String? regionId;
  WeatherSettings copyWith({
    bool? enabled,
    bool? automaticLocation,
    String? regionId,
  }) => WeatherSettings(
    enabled: enabled ?? this.enabled,
    automaticLocation: automaticLocation ?? this.automaticLocation,
    regionId: regionId ?? this.regionId,
  );
}

class WeatherStore extends ChangeNotifier {
  WeatherStore(this._preferences);
  final SharedPreferences _preferences;
  static const settingsKey = 'weather.settings.v1';
  static const cacheKey = 'weather.cache.v1';
  Future<void> _writes = Future.value();

  Map<String, dynamic> _read(String key) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(_preferences.getString(key) ?? '{}') as Map,
      );
    } on Object {
      return {};
    }
  }

  WeatherSettings load() {
    final json = _read(settingsKey);
    return WeatherSettings(
      enabled: json['enabled'] == true,
      automaticLocation: json['automatic'] == true,
      regionId: json['region'] is String ? json['region'] as String : null,
    );
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> save(WeatherSettings settings) => _enqueue(() async {
    if (!await _preferences.setString(
      settingsKey,
      jsonEncode({
        'enabled': settings.enabled,
        'automatic': settings.automaticLocation,
        'region': settings.regionId,
      }),
    )) {
      throw StateError('Weather settings write failed');
    }
  });

  ({String xml, DateTime fetchedAt})? cached(String grid) {
    try {
      final data = _read(cacheKey)[grid] as Map;
      return (
        xml: data['xml'] as String,
        fetchedAt: DateTime.parse(data['fetchedAt'] as String),
      );
    } on Object {
      return null;
    }
  }

  Future<void> cache(String grid, String xml, DateTime now) =>
      _enqueue(() async {
        final data = _read(cacheKey)..remove(grid);
        while (data.length >= 4) {
          data.remove(data.keys.first);
        }
        data[grid] = {'xml': xml, 'fetchedAt': now.toUtc().toIso8601String()};
        if (!await _preferences.setString(cacheKey, jsonEncode(data))) {
          throw StateError('Weather cache write failed');
        }
      });

  Future<void> clear() {
    // Notify synchronously so in-flight location/network results are invalidated.
    notifyListeners();
    return _enqueue(() async {
      await _preferences.remove(settingsKey);
      await _preferences.remove(cacheKey);
    });
  }
}
