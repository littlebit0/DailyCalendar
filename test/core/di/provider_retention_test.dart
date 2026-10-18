// ignore_for_file: depend_on_referenced_packages

import 'package:daily/core/di/provider_retention.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const retention = Duration(minutes: 2);

  test('unused family members are disposed after the retention period', () {
    fakeAsync((async) {
      final disposed = <int>[];
      final provider = Provider.autoDispose.family<int, int>((ref, key) {
        retainWhileRecentlyUsed(ref, retention);
        ref.onDispose(() => disposed.add(key));
        return key;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (var key = 0; key < 100; key++) {
        container.listen(provider(key), (_, _) {}).close();
      }
      async.elapse(retention - const Duration(seconds: 1));
      expect(disposed, isEmpty);

      async.elapse(const Duration(seconds: 2));
      expect(disposed, hasLength(100));
    });
  });

  test('a resubscribe inside the window keeps the state and restarts it', () {
    fakeAsync((async) {
      var builds = 0;
      final provider = Provider.autoDispose<int>((ref) {
        retainWhileRecentlyUsed(ref, retention);
        return ++builds;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.listen(provider, (_, _) {}).close();
      async.elapse(const Duration(minutes: 1));
      final again = container.listen(provider, (_, _) {});
      async.elapse(const Duration(minutes: 5));
      expect(builds, 1, reason: 'an active listener is never disposed');
      expect(again.read(), 1);

      again.close();
      async.elapse(const Duration(minutes: 1));
      container.listen(provider, (_, _) {}).close();
      expect(builds, 1, reason: 'retention restarts after the last listener');
      async.elapse(retention + const Duration(seconds: 1));
      container.listen(provider, (_, _) {}).close();
      expect(builds, 2);
    });
  });
}
