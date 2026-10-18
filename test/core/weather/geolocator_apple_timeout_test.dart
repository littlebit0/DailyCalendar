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
  final requestIds = <String?>[];

  tearDown(() {
    calls.clear();
    requestIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('timeout cancels the native one-time request', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      requestIds.add((call.arguments as Map?)?['requestId'] as String?);
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
    // The cancel names the request that timed out.
    expect(requestIds.first, isNotNull);
    expect(requestIds.last, requestIds.first);
  });

  test('overlapping lookups get different ids; each timeout cancels its own', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      requestIds.add((call.arguments as Map?)?['requestId'] as String?);
      if (call.method == 'getCurrentPosition') {
        return Completer<Object?>().future;
      }
      return null;
    });
    const settings = LocationSettings(timeLimit: Duration(milliseconds: 30));
    final first = GeolocatorApple().getCurrentPosition(locationSettings: settings);
    final second = GeolocatorApple().getCurrentPosition(locationSettings: settings);
    await expectLater(first, throwsA(isA<TimeoutException>()));
    await expectLater(second, throwsA(isA<TimeoutException>()));
    final starts = [
      for (var i = 0; i < calls.length; i++)
        if (calls[i] == 'getCurrentPosition') requestIds[i],
    ];
    final cancels = [
      for (var i = 0; i < calls.length; i++)
        if (calls[i] == 'cancelGetCurrentPosition') requestIds[i],
    ];
    expect(starts.toSet(), hasLength(2));
    expect(cancels.toSet(), starts.toSet());
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
