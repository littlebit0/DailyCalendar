import 'dart:async';
import 'dart:convert';

import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/update/app_update_service.dart';
import 'package:daily/core/update/update_required_view.dart';
import 'package:daily/core/update/update_requirement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('UpdateRequirementController', () {
    test(
      'stores a newer release and keeps it across a restart',
      () async {
        final prefs = await _prefs();
        var lookups = 0;
        var detected = 0;
        var now = DateTime.utc(2026, 10, 27);
        final controller = UpdateRequirementController(
          preferences: prefs,
          latestVersion: () async {
            lookups++;
            return '4.1.0';
          },
          currentVersion: () async => '4.0.0',
          now: () => now,
          onDetected: () async => detected++,
        );
        await controller.initialize();
        expect(controller.requiredVersion.value, isNull);

        await controller.check();
        expect(controller.requiredVersion.value, '4.1.0');
        expect(
          prefs.getString(UpdateRequirementController.requiredVersionKey),
          '4.1.0',
        );
        expect((lookups, detected), (1, 1));

        // Still offered a day later: the restriction stays, no new detection.
        now = now.add(const Duration(days: 1));
        await controller.check();
        expect(controller.requiredVersion.value, '4.1.0');
        expect((lookups, detected), (2, 1));

        // A restart keeps the restriction without any network call.
        final restarted = UpdateRequirementController(
          preferences: prefs,
          latestVersion: () async {
            lookups++;
            return null;
          },
          currentVersion: () async => '4.0.0',
        );
        await restarted.initialize();
        expect(restarted.requiredVersion.value, '4.1.0');
        expect(lookups, 2);
      },
    );

    test(
      'clears the stored requirement once the build is new enough',
      () async {
        final prefs = await _prefs({
          UpdateRequirementController.requiredVersionKey: '4.1.0',
        });
        final controller = UpdateRequirementController(
          preferences: prefs,
          latestVersion: () async => '4.1.0',
          currentVersion: () async => '4.1.0',
        );
        await controller.initialize();
        expect(controller.requiredVersion.value, isNull);
        expect(
          prefs.getString(UpdateRequirementController.requiredVersionKey),
          isNull,
        );
      },
    );

    test(
      'does not poll inside the interval and ignores lookup failures',
      () async {
        final prefs = await _prefs();
        var lookups = 0;
        var now = DateTime.utc(2026, 10, 27, 9);
        String? answer = '4.0.0';
        final controller = UpdateRequirementController(
          preferences: prefs,
          latestVersion: () async {
            lookups++;
            return answer;
          },
          currentVersion: () async => '4.0.0',
          now: () => now,
        );
        await controller.check();
        await controller.check();
        expect(lookups, 1);
        expect(controller.requiredVersion.value, isNull);

        now = now.add(const Duration(hours: 6, minutes: 1));
        answer = null; // feed unreachable
        await controller.check();
        expect(lookups, 2);
        expect(controller.requiredVersion.value, isNull);

        now = now.add(const Duration(minutes: 6));
        answer = '4.0.1';
        await controller.check();
        expect(controller.requiredVersion.value, '4.0.1');
      },
    );

    test('an unreadable running version never restricts (#890)', () async {
      for (final current in ['', 'abc']) {
        final prefs = await _prefs();
        final controller = UpdateRequirementController(
          preferences: prefs,
          latestVersion: () async => '4.1.1',
          currentVersion: () async => current,
          now: () => DateTime.utc(2026, 11, 18),
        );
        await controller.initialize();
        await controller.check();
        expect(controller.requiredVersion.value, isNull);
        expect(
          prefs.getString(UpdateRequirementController.requiredVersionKey),
          isNull,
        );

        // A requirement stored earlier is not kept either.
        final stored = await _prefs({
          UpdateRequirementController.requiredVersionKey: '4.1.1',
        });
        final restarted = UpdateRequirementController(
          preferences: stored,
          latestVersion: () async => null,
          currentVersion: () async => current,
        );
        await restarted.initialize();
        expect(restarted.requiredVersion.value, isNull);
      }
    });

    test('does nothing when disabled', () async {
      final prefs = await _prefs({
        UpdateRequirementController.requiredVersionKey: '9.0.0',
      });
      var lookups = 0;
      final controller = UpdateRequirementController(
        preferences: prefs,
        enabled: false,
        latestVersion: () async {
          lookups++;
          return '9.0.0';
        },
        currentVersion: () async => '4.0.0',
      );
      await controller.initialize();
      await controller.check();
      expect(controller.requiredVersion.value, isNull);
      expect(lookups, 0);
    });

    testWidgets('periodic timer keeps checking an app left open', (
      tester,
    ) async {
      final prefs = await _prefs();
      var lookups = 0;
      var now = DateTime.utc(2026, 10, 27);
      final controller = UpdateRequirementController(
        preferences: prefs,
        interval: const Duration(hours: 6),
        latestVersion: () async => ++lookups >= 3 ? '4.1.0' : '4.0.0',
        currentVersion: () async => '4.0.0',
        now: () => now,
      );
      controller.start();
      await tester.pump();
      expect(lookups, 1);
      for (var i = 0; i < 2; i++) {
        now = now.add(const Duration(hours: 6, minutes: 1));
        await tester.pump(const Duration(hours: 6));
      }
      expect(lookups, 3);
      expect(controller.requiredVersion.value, '4.1.0');
      controller.dispose();
    });
  });

  group('check schedule', () {
    Future<(UpdateRequirementController, List<int>)> restartedAfter(
      Duration sinceLastCheck,
      DateTime Function() now,
    ) async {
      final prefs = await _prefs({
        UpdateRequirementController.lastCheckedKey: now()
            .subtract(sinceLastCheck)
            .millisecondsSinceEpoch,
      });
      final lookups = <int>[];
      final controller = UpdateRequirementController(
        preferences: prefs,
        interval: const Duration(hours: 6),
        latestVersion: () async {
          lookups.add(1);
          return '4.0.0';
        },
        currentVersion: () async => '4.0.0',
        now: now,
      );
      return (controller, lookups);
    }

    testWidgets('a restart keeps the time left since the last check', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 27, 14);
      final (controller, lookups) = await restartedAfter(
        const Duration(hours: 5),
        () => now,
      );
      controller.start();
      await tester.pump();
      expect(lookups, isEmpty);

      now = now.add(const Duration(minutes: 59));
      await tester.pump(const Duration(minutes: 59));
      expect(lookups, isEmpty);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(lookups, hasLength(1));
      controller.dispose();
    });

    testWidgets('a check on resume moves the next scheduled one', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 27, 9);
      final (controller, lookups) = await restartedAfter(
        const Duration(hours: 7),
        () => now,
      );
      controller.start();
      await tester.pump();
      expect(lookups, hasLength(1));

      // Nothing is due yet, so this resume leaves the 15:00 check in place.
      now = now.add(const Duration(hours: 3));
      await tester.pump(const Duration(hours: 3));
      await controller.check();
      await tester.pump();
      expect(lookups, hasLength(1));

      now = now.add(const Duration(hours: 3));
      await tester.pump(const Duration(hours: 3));
      expect(lookups, hasLength(2));

      // A resume past the due time answers, then the next waits a full interval.
      now = now.add(const Duration(hours: 5));
      await tester.pump(const Duration(hours: 5));
      expect(lookups, hasLength(2));
      now = now.add(const Duration(minutes: 59));
      await tester.pump(const Duration(minutes: 59));
      expect(lookups, hasLength(2));
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(lookups, hasLength(3));
      controller.dispose();
    });

    testWidgets('a failed lookup waits for the next interval', (tester) async {
      final prefs = await _prefs();
      var lookups = 0;
      var now = DateTime.utc(2026, 10, 27);
      final controller = UpdateRequirementController(
        preferences: prefs,
        interval: const Duration(hours: 6),
        latestVersion: () async {
          lookups++;
          return null;
        },
        currentVersion: () async => '4.0.0',
        now: () => now,
      );
      controller.start();
      await tester.pump();
      expect(lookups, 1);
      now = now.add(const Duration(hours: 5, minutes: 59));
      await tester.pump(const Duration(hours: 5, minutes: 59));
      expect(lookups, 1);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(lookups, 2);
      controller.dispose();
    });
  });

  test(
    'an unanswered release lookup ends and lets the next check run',
    () async {
      final prefs = await _prefs();
      var requests = 0;
      final service = AppUpdateService(
        enabled: false,
        releaseLookupTimeout: const Duration(milliseconds: 10),
        client: MockClient((_) {
          requests++;
          return Completer<http.Response>().future;
        }),
      );
      expect(await service.latestReleaseVersion(), isNull);

      var now = DateTime.utc(2026, 10, 27);
      final controller = UpdateRequirementController(
        preferences: prefs,
        latestVersion: service.latestReleaseVersion,
        currentVersion: () async => '4.0.0',
        now: () => now,
      );
      await controller.check();
      now = now.add(const Duration(minutes: 5));
      await controller.check();
      expect(requests, 3);
      expect(prefs.getInt(UpdateRequirementController.lastCheckedKey), isNull);
      controller.dispose();
    },
  );

  test('latestReleaseVersion reads only a plain release tag', () async {
    AppUpdateService service(http.Response Function() respond) =>
        AppUpdateService(
          enabled: false,
          client: MockClient((_) async => respond()),
        );
    expect(
      await service(
        () => http.Response(jsonEncode({'tag_name': 'v4.1.0'}), 200),
      ).latestReleaseVersion(),
      '4.1.0',
    );
    expect(
      await service(
        () => http.Response(jsonEncode({'tag_name': 'linux-apt'}), 200),
      ).latestReleaseVersion(),
      isNull,
    );
    expect(
      await service(() => http.Response('{}', 403)).latestReleaseVersion(),
      isNull,
    );
    expect(
      await service(
        () => http.Response('not json', 200),
      ).latestReleaseVersion(),
      isNull,
    );
  });

  group('UpdateRequiredGate', () {
    Widget app(ValueNotifier<String?> version, Widget child) => ProviderScope(
      overrides: [requiredUpdateVersionProvider.overrideWithValue(version)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

    testWidgets('shows the child until an update is required', (tester) async {
      final version = ValueNotifier<String?>(null);
      await tester.pumpWidget(
        app(version, const UpdateRequiredGate(child: Text('timetable'))),
      );
      expect(find.text('timetable'), findsOneWidget);
      version.value = '4.1.0';
      await tester.pump();
      expect(find.text('timetable'), findsNothing);
      expect(find.text('업데이트가 필요합니다'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('update-required-open')),
        findsOneWidget,
      );
      version.value = null;
      await tester.pump();
      expect(find.text('timetable'), findsOneWidget);
    });

    testWidgets('editing is refused with a dialog only while required', (
      tester,
    ) async {
      final version = ValueNotifier<String?>(null);
      late bool blocked;
      await tester.pumpWidget(
        app(
          version,
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => blocked = blockedByRequiredUpdate(context, ref),
              child: const Text('edit'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pump();
      expect(blocked, isFalse);
      expect(find.byType(AlertDialog), findsNothing);

      version.value = '4.1.0';
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      expect(blocked, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
  group('store-based requirements', () {
    test('drops a GitHub requirement stored by an older build', () async {
      final now = DateTime.utc(2026, 11, 17);
      final prefs = await _prefs({
        UpdateRequirementController.requiredVersionKey: '4.2.0',
        UpdateRequirementController.lastCheckedKey: now.millisecondsSinceEpoch,
      });
      var lookups = 0;
      final controller = UpdateRequirementController(
        preferences: prefs,
        source: UpdateSource.appStore,
        latestVersion: () async {
          lookups++;
          return '4.1.1';
        },
        currentVersion: () async => '4.1.1',
        now: () => now,
      );
      await controller.initialize();
      expect(controller.requiredVersion.value, isNull);
      expect(
        prefs.getString(UpdateRequirementController.requiredVersionKey),
        isNull,
      );

      // The App Store is asked right away, not after the stored interval.
      await controller.check();
      expect(lookups, 1);
      expect(controller.requiredVersion.value, isNull);
    });

    test('keeps a GitHub requirement on Windows and Linux builds', () async {
      final prefs = await _prefs({
        UpdateRequirementController.requiredVersionKey: '4.2.0',
      });
      final controller = UpdateRequirementController(
        preferences: prefs,
        latestVersion: () async => null,
        currentVersion: () async => '4.1.1',
      );
      await controller.initialize();
      expect(controller.requiredVersion.value, '4.2.0');
    });

    test(
      'restricts Android by versionCode and lifts it after update',
      () async {
        final prefs = await _prefs();
        var installed = '420';
        final controller = UpdateRequirementController(
          preferences: prefs,
          source: UpdateSource.play,
          latestVersion: () async => '430',
          currentVersion: () async => installed,
          isNewer: isNewerVersionCode,
          now: () => DateTime.utc(2026, 11, 17),
        );
        await controller.check();
        expect(controller.requiredVersion.value, '430');
        expect(
          prefs.getString(UpdateRequirementController.requiredSourceKey),
          'play',
        );

        installed = '430';
        await controller.initialize();
        expect(controller.requiredVersion.value, isNull);
        expect(
          prefs.getString(UpdateRequirementController.requiredSourceKey),
          isNull,
        );
      },
    );

    test('a store that cannot be reached never restricts', () async {
      final prefs = await _prefs();
      final controller = UpdateRequirementController(
        preferences: prefs,
        source: UpdateSource.play,
        latestVersion: () async => null,
        currentVersion: () async => '420',
        isNewer: isNewerVersionCode,
      );
      await controller.check();
      expect(controller.requiredVersion.value, isNull);
      expect(prefs.getInt(UpdateRequirementController.lastCheckedKey), isNull);
    });
  });

  group('re-checking while restricted (#851)', () {
    Future<UpdateRequirementController> restricted({
      required Future<String?> Function() latest,
      UpdateSource source = UpdateSource.github,
      String stored = '4.2.0',
      String current = '4.1.0',
      bool Function(String, String)? isNewer,
      required DateTime Function() now,
      Future<void> Function()? onDetected,
    }) async {
      final prefs = await _prefs({
        UpdateRequirementController.requiredVersionKey: stored,
        UpdateRequirementController.requiredSourceKey: source.name,
        // Checked just now: the interval alone would skip the next lookup.
        UpdateRequirementController.lastCheckedKey: now().millisecondsSinceEpoch,
      });
      final controller = UpdateRequirementController(
        preferences: prefs,
        source: source,
        latestVersion: latest,
        currentVersion: () async => current,
        isNewer: isNewer,
        now: now,
        onDetected: onDetected,
      );
      await controller.initialize();
      expect(controller.requiredVersion.value, stored);
      return controller;
    }

    for (final source in UpdateSource.values) {
      final play = source == UpdateSource.play;
      test('lifts a withdrawn release on ${source.name}', () async {
        final now = DateTime.utc(2026, 11, 19);
        final controller = await restricted(
          source: source,
          stored: play ? '430' : '4.2.0',
          current: play ? '420' : '4.1.0',
          isNewer: play ? isNewerVersionCode : null,
          latest: () async => play ? '420' : '4.1.0',
          now: () => now,
        );
        await controller.check();
        expect(controller.requiredVersion.value, isNull);
        await controller.initialize();
        expect(controller.requiredVersion.value, isNull);
      });
    }

    test('lifts when the feed falls below the running build', () async {
      final now = DateTime.utc(2026, 11, 19);
      final controller = await restricted(
        latest: () async => '4.0.9',
        now: () => now,
      );
      await controller.check();
      expect(controller.requiredVersion.value, isNull);
    });

    test('keeps the restriction for the same or a newer release', () async {
      var now = DateTime.utc(2026, 11, 19);
      var answer = '4.2.0';
      var detected = 0;
      final controller = await restricted(
        latest: () async => answer,
        now: () => now,
        onDetected: () async => detected++,
      );
      await controller.check();
      expect(controller.requiredVersion.value, '4.2.0');
      expect(detected, 0);

      now = now.add(const Duration(minutes: 5));
      answer = '4.3.0';
      await controller.check();
      expect(controller.requiredVersion.value, '4.3.0');
      expect(detected, 1);
      await controller.initialize();
      expect(controller.requiredVersion.value, '4.3.0');
    });

    test('a failed or unanswered lookup keeps the restriction', () async {
      var now = DateTime.utc(2026, 11, 19);
      var fail = false;
      final controller = await restricted(
        latest: () async => fail ? throw Exception('offline') : null,
        now: () => now,
      );
      await controller.check();
      expect(controller.requiredVersion.value, '4.2.0');
      now = now.add(const Duration(minutes: 5));
      fail = true;
      await controller.check();
      expect(controller.requiredVersion.value, '4.2.0');
      await controller.initialize();
      expect(controller.requiredVersion.value, '4.2.0');
    });

    test('resume re-checks at most once per five minutes', () async {
      var now = DateTime.utc(2026, 11, 19);
      var lookups = 0;
      final controller = await restricted(
        latest: () async {
          lookups++;
          return '4.2.0';
        },
        now: () => now,
      );
      await controller.check();
      now = now.add(const Duration(minutes: 4));
      await controller.check();
      expect(lookups, 1);
      now = now.add(const Duration(minutes: 1));
      await controller.check();
      expect(lookups, 2);
    });

    testWidgets('the open restriction screen re-checks every interval', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 11, 19);
      var lookups = 0;
      var answer = '4.2.0';
      final controller = await restricted(
        latest: () async {
          lookups++;
          return answer;
        },
        now: () => now,
      );
      controller.start();
      await tester.pump();
      expect(lookups, 1);

      now = now.add(const Duration(hours: 5, minutes: 59));
      await tester.pump(const Duration(hours: 5, minutes: 59));
      expect(lookups, 1);

      answer = '4.1.0';
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(lookups, 2);
      expect(controller.requiredVersion.value, isNull);
      controller.dispose();
    });
  });
}
