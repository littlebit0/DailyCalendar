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
      'stores a newer release and stops asking until it is installed',
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

        // Known requirement: no more release lookups, even a day later.
        now = now.add(const Duration(days: 1));
        await controller.check();
        expect(lookups, 1);

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
        expect(lookups, 1);
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
}
