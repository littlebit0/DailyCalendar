import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/geolocator_apple');
  final calls = <String>[];

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('timeout cancels the native one-time request', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      if (call.method == 'getCurrentPosition') {
        return Completer<Object?>().future; // never answers
      }
      return null;
    });

    await expectLater(
      GeolocatorApple().getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, ['getCurrentPosition', 'cancelGetCurrentPosition']);
  });

  test('timeout is still reported when the native cancel fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      if (call.method == 'getCurrentPosition') {
        return Completer<Object?>().future;
      }
      throw PlatformException(code: 'fail');
    });

    await expectLater(
      GeolocatorApple().getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, contains('cancelGetCurrentPosition'));
  });
}
