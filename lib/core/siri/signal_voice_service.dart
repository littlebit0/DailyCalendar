import 'package:flutter/services.dart';

class SignalVoiceResult {
  const SignalVoiceResult({required this.message, required this.success});

  final String message;
  final bool success;
}

class SignalVoiceService {
  SignalVoiceService._();

  static final SignalVoiceService instance = SignalVoiceService._();
  static const MethodChannel _channel = MethodChannel('daily/signal_voice');

  int _nextRequestId = 0;
  int? _activeRequestId;

  void Function(String transcript)? _onTranscriptChanged;
  void Function()? _onListeningStarted;

  void setHandlers({
    void Function(String transcript)? onTranscriptChanged,
    void Function()? onListeningStarted,
  }) {
    _onTranscriptChanged = onTranscriptChanged;
    _onListeningStarted = onListeningStarted;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (arguments is! Map ||
          _activeRequestId == null ||
          arguments['requestId'] != _activeRequestId) {
        return;
      }
      if (call.method == 'transcriptChanged') {
        _onTranscriptChanged?.call(arguments['transcript'] as String? ?? '');
      } else if (call.method == 'listeningStarted') {
        _onListeningStarted?.call();
      }
    });
  }

  Future<String> startListening() async {
    if (_activeRequestId != null) {
      throw PlatformException(code: 'already_listening');
    }
    final id = ++_nextRequestId;
    _activeRequestId = id;
    try {
      final transcript = await _channel.invokeMethod<String>('startListening', {
        'requestId': id,
      });
      if (_activeRequestId != id) {
        throw PlatformException(code: 'listening_cancelled');
      }
      return transcript ?? '';
    } finally {
      if (_activeRequestId == id) _activeRequestId = null;
    }
  }

  Future<void> finishListening() => _channel.invokeMethod<void>(
    'finishListening',
    {'requestId': _activeRequestId},
  );

  Future<void> cancelListening() {
    final id = _activeRequestId;
    _activeRequestId = null;
    return _channel.invokeMethod<void>('cancelListening', {'requestId': id});
  }

  Future<SignalVoiceResult> runSignal(
    String command, {
    bool confirmed = false,
  }) async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'runSignal',
      {'command': command, 'confirmed': confirmed},
    );
    return SignalVoiceResult(
      message: response?['message'] as String? ?? '',
      success: response?['success'] as bool? ?? false,
    );
  }

  Future<void> speak(String message) =>
      _channel.invokeMethod<void>('speak', {'message': message});
}
