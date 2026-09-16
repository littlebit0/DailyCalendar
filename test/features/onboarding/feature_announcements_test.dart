import 'package:daily/features/onboarding/feature_announcements.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FeatureAnnouncementStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FeatureAnnouncementStore(await SharedPreferences.getInstance());
  });
  test('version and platform filter announcements', () {
    expect(store.pending('3.3.9', TargetPlatform.iOS), isEmpty);
    expect(store.pending('3.4.0', TargetPlatform.iOS), hasLength(3));
    expect(store.pending('3.4.0', TargetPlatform.android), hasLength(2));
  });
  test('acknowledgements survive recreation and hotfixes', () async {
    await store.acknowledge([
      'weather-forecast-v1',
      'university-academic-calendar-v1',
    ]);
    final restored = FeatureAnnouncementStore(
      await SharedPreferences.getInstance(),
    );
    expect(restored.pending('3.4.1', TargetPlatform.android), isEmpty);
    expect(
      restored.pending('3.4.1', TargetPlatform.iOS).single.id,
      'lockscreen-calendar-v1',
    );
  });
  test('fresh install baseline avoids update onboarding duplication', () async {
    await store.acknowledge(featureAnnouncements.map((item) => item.id));
    expect(store.pending('4.0.0', TargetPlatform.iOS), isEmpty);
  });
  test(
    'existing users receive only the new feature at the same app version',
    () async {
      await store.acknowledge([
        'lockscreen-calendar-v1',
        'weather-forecast-v1',
      ]);
      for (final platform in TargetPlatform.values) {
        expect(store.pending('3.4.0', platform).map((item) => item.id), [
          'university-academic-calendar-v1',
        ]);
      }
      await store.acknowledge(['university-academic-calendar-v1']);
      expect(store.pending('3.4.0', TargetPlatform.iOS), isEmpty);
    },
  );
  test(
    'catalog has unique identities and covers every announcement feature',
    () {
      expect(
        featureAnnouncements.map((item) => item.id).toSet().length,
        featureAnnouncements.length,
      );
      expect(
        featureAnnouncements.map((item) => item.feature).toSet(),
        AnnouncementFeature.values.toSet(),
      );
    },
  );
}
