import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnnouncementFeature { wallpaper, weather, academicCalendar }

class FeatureAnnouncement {
  const FeatureAnnouncement(
    this.id,
    this.version,
    this.feature, {
    this.platforms,
  });
  final String id;
  final String version;
  final AnnouncementFeature feature;
  final Set<TargetPlatform>? platforms;
}

const featureAnnouncements = [
  FeatureAnnouncement(
    'lockscreen-calendar-v1',
    '3.4.0',
    AnnouncementFeature.wallpaper,
    platforms: {TargetPlatform.iOS},
  ),
  FeatureAnnouncement(
    'weather-forecast-v1',
    '3.4.0',
    AnnouncementFeature.weather,
  ),
  FeatureAnnouncement(
    'university-academic-calendar-v1',
    '3.4.0',
    AnnouncementFeature.academicCalendar,
  ),
];

class FeatureAnnouncementStore {
  FeatureAnnouncementStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'seenFeatureAnnouncements.v1';

  List<FeatureAnnouncement> pending(String version, TargetPlatform platform) {
    final seen = preferences.getStringList(key) ?? [];
    return featureAnnouncements
        .where(
          (item) =>
              !seen.contains(item.id) &&
              (item.platforms == null || item.platforms!.contains(platform)) &&
              _atLeast(version, item.version),
        )
        .toList();
  }

  Future<void> acknowledge(Iterable<String> ids) async {
    final seen = {...?preferences.getStringList(key), ...ids};
    if (!await preferences.setStringList(key, seen.toList())) {
      throw StateError('Could not save announcement acknowledgement');
    }
  }

  static bool _atLeast(String current, String minimum) {
    List<int> parts(String value) => value
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(current), b = parts(minimum);
    for (var i = 0; i < 3; i++) {
      final difference = (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0);
      if (difference != 0) return difference > 0;
    }
    return true;
  }
}
