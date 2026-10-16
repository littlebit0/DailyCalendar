import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/siri/signal_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('daily/signal_voice');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('runs recognized text through the native Signal bridge', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'startListening' => '내일 일정 알려줘',
            'runSignal' => <String, Object?>{
              'message': '내일 일정이 없습니다.',
              'success': true,
            },
            'speak' => null,
            _ => throw PlatformException(code: 'unexpected_method'),
          };
        });

    final service = SignalVoiceService.instance;
    final transcript = await service.startListening();
    final result = await service.runSignal(transcript);
    await service.speak(result.message);

    expect(transcript, '내일 일정 알려줘');
    expect(result.success, isTrue);
    expect(result.message, '내일 일정이 없습니다.');
    expect(calls.map((call) => call.method), [
      'startListening',
      'runSignal',
      'speak',
    ]);
    expect(calls[1].arguments, {'command': '내일 일정 알려줘', 'confirmed': false});
  });

  test('separates finishing an utterance from cancelling it', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return null;
        });

    final service = SignalVoiceService.instance;
    await service.finishListening();
    await service.cancelListening();

    expect(methods, ['finishListening', 'cancelListening']);
  });
  test(
    'cancelled request cannot deliver transcript or clear its replacement',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final pending = <int, Completer<String>>{};
      final service = SignalVoiceService.instance;
      final transcripts = <String>[];
      var starts = 0;
      service.setHandlers(
        onTranscriptChanged: transcripts.add,
        onListeningStarted: () => starts++,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'startListening') {
          final id = (call.arguments as Map)['requestId'] as int;
          return (pending[id] = Completer<String>()).future;
        }
        return null;
      });
      Future<void> event(String method, int id, [String? transcript]) async {
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, {'requestId': id, 'transcript': transcript}),
          ),
          (_) {},
        );
      }

      final old = service.startListening();
      final oldFailure = expectLater(
        old,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'listening_cancelled',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final oldId = pending.keys.single;
      await expectLater(
        service.startListening(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'already_listening',
          ),
        ),
      );
      await service.cancelListening();
      final current = service.startListening();
      await Future<void>.delayed(Duration.zero);
      final currentId = pending.keys.last;
      await event('transcriptChanged', oldId, 'old');
      await event('listeningStarted', oldId);
      pending[oldId]!.complete('old final');
      await oldFailure;
      await event('listeningStarted', currentId);
      await event('transcriptChanged', currentId, 'new');
      expect(transcripts, ['new']);
      expect(starts, 1);
      pending[currentId]!.complete('new final');
      expect(await current, 'new final');
      await event('transcriptChanged', currentId, 'late');
      expect(transcripts, ['new']);
      service.setHandlers();
    },
  );
}
