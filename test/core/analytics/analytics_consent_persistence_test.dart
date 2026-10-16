import 'dart:async';
import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../../support/persistence_failure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PersistenceFailureStore store;
  late SharedPreferences prefs;
  PrivacyAnalyticsService create({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  }) {
    final result = PrivacyAnalyticsService(
      preferences: prefs,
      secureStorage: secureStorage,
      httpClient: client,
      endpoint: client == null ? null : Uri.parse('https://example.com/events'),
      environmentLoader: () async => const AnalyticsEnvironment(
        appVersion: '4.0.0',
        platform: 'ios',
        osMajor: 27,
      ),
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    store = PersistenceFailureStore();
    store.disk['flutter.anonymousAnalyticsEnabled'] = true;
    SharedPreferencesStorePlatform.instance = store;
    prefs = await SharedPreferences.getInstance();
  });
  for (final failure in ['false', 'exception', 'unwritten']) {
    test(
      'withdrawal $failure blocks now, survives reload, retries same OFF',
      () async {
        final service = create();
        await service.initialize();
        store.failureKey = 'flutter.anonymousAnalyticsEnabled';
        store.throws = failure == 'exception';
        store.silent = failure == 'unwritten';
        final operation = service.setEnabled(false);
        expect(service.enabled, isFalse);
        await expectLater(operation, throwsStateError);
        await service.record(AnalyticsRecord.appLoad(durationMs: 4));
        expect(service.pendingEventCount, 0);
        await prefs.reload();
        expect(prefs.getBool('anonymousAnalyticsEnabled'), isTrue);
        final cold = create();
        await cold.initialize();
        expect(cold.enabled, isFalse); // independent durable withdrawal record
        store.failureKey = null;
        await cold.setEnabled(false);
        await prefs.reload();
        expect(prefs.getBool('anonymousAnalyticsEnabled'), isFalse);
      },
    );
  }
  test('pending-data removal failure is reported and can be retried', () async {
    final service = create();
    await service.initialize();
    store.failureKey = 'flutter.anonymousAnalyticsQueueV1';
    await expectLater(service.setEnabled(false), throwsStateError);
    expect(service.enabled, isFalse);
    await expectLater(service.deletePendingData(), throwsStateError);
    store.failureKey = null;
    await service.deletePendingData();
  });
  test(
    'initial consent completion failure is not reported completed',
    () async {
      await prefs.remove('anonymousAnalyticsEnabled');
      final service = create();
      await service.initialize();
      store.failureKey = 'flutter.anonymousAnalyticsConsentPromptCompletedV1';
      await expectLater(
        service.completeConsentPrompt(enabled: false),
        throwsStateError,
      );
      expect(service.consentPromptCompleted, isFalse);
      store.failureKey = null;
      await service.completeConsentPrompt(enabled: false);
      expect(service.consentPromptCompleted, isTrue);
    },
  );
  test('late response after withdrawal cannot recreate pending data', () async {
    final response = Completer<http.Response>();
    var posts = 0;
    final service = create(
      client: MockClient((_) {
        posts++;
        return response.future;
      }),
    );
    await service.initialize();
    await service.record(AnalyticsRecord.appLoad(durationMs: 4));
    final flushing = service.flush();
    await Future<void>.delayed(Duration.zero);
    await service.setEnabled(false);
    response.complete(http.Response('', 503));
    await flushing;
    expect(posts, 1);
    expect(service.pendingEventCount, 0);
    await prefs.reload();
    expect(prefs.getString('anonymousAnalyticsQueueV1'), isNull);
  });
  test('unreadable secure consent never grants collection', () async {
    final secure = _SecureStore()..failRead = true;
    final service = create(secureStorage: secure);
    await service.initialize();
    expect(service.enabled, isFalse);
    await service.record(AnalyticsRecord.appLoad(durationMs: 4));
    expect(service.pendingEventCount, 0);
  });
  test(
    'secure write failure still persists OFF to preferences and reports failure',
    () async {
      final secure = _SecureStore()..failWrite = true;
      final service = create(secureStorage: secure);
      await service.initialize();
      await expectLater(service.setEnabled(false), throwsStateError);
      await prefs.reload();
      expect(prefs.getBool('anonymousAnalyticsEnabled'), isFalse);
      final cold = create(secureStorage: secure);
      await cold.initialize();
      expect(cold.enabled, isFalse);
    },
  );
  test(
    'both storage failures are reported; current session remains blocked',
    () async {
      final secure = _SecureStore()..failWrite = true;
      final service = create(secureStorage: secure);
      await service.initialize();
      store.failureKey = 'flutter.anonymousAnalyticsEnabled';
      await expectLater(service.setEnabled(false), throwsStateError);
      expect(service.enabled, isFalse);
      // Neither store accepted a write. Do not claim this intent survives power loss.
      expect(store.disk['flutter.anonymousAnalyticsEnabled'], isTrue);
      expect(secure.values, isEmpty);
      store.failureKey = null;
      secure.failWrite = false;
      await service.setEnabled(false);
      final cold = create(secureStorage: secure);
      await cold.initialize();
      expect(cold.enabled, isFalse);
    },
  );
  test('OFF then ON and ON then OFF honor final explicit choice', () async {
    final service = create();
    await service.initialize();
    await Future.wait([service.setEnabled(false), service.setEnabled(true)]);
    expect(service.enabled, isTrue);
    await Future.wait([service.setEnabled(true), service.setEnabled(false)]);
    expect(service.enabled, isFalse);
    final cold = create();
    await cold.initialize();
    expect(cold.enabled, isFalse);
  });
}

class _SecureStore extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw StateError('secure storage unavailable');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('secure storage unavailable');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
