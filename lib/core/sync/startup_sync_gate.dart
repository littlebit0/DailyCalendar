import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../localization/app_localizations.dart';
import 'google_drive_auth_service.dart';
import 'google_drive_sync_service.dart';

/// Only gates this mount's startup. A timeout releases the UI, not the live
/// operation: retries join it instead of starting a second merge or upload.
class StartupSyncGate extends StatefulWidget {
  const StartupSyncGate({
    super.key,
    required this.requiredAtStartup,
    required this.synchronize,
    required this.onContinue,
    required this.child,
    this.timeout = const Duration(seconds: 20),
  });

  final bool requiredAtStartup;
  final Future<void> Function() synchronize;
  final VoidCallback onContinue;
  final Widget child;
  final Duration timeout;

  @override
  State<StartupSyncGate> createState() => _StartupSyncGateState();
}

class _StartupSyncGateState extends State<StartupSyncGate> {
  Future<void>? _operation;
  bool _ready = false;
  bool _slow = false;
  _StartupFailure? _failure;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _ready = !widget.requiredAtStartup;
    if (!_ready) unawaited(_run());
  }

  Future<void> _run() async {
    final attempt = ++_attempt;
    setState(() {
      _slow = false;
      _failure = null;
    });
    final operation = _operation ??= _startOperation();
    try {
      await operation.timeout(widget.timeout);
    } on TimeoutException {
      if (!mounted || _ready || attempt != _attempt) return;
      // A transport timeout completes the original operation with an error.
      // Only the UI deadline leaves an operation running in the background.
      if (identical(_operation, operation)) setState(() => _slow = true);
    } on Object {
      // The original future owns the failure, including errors after the UI
      // deadline. Never render exception text, which can include private data.
    }
  }

  Future<void> _startOperation() {
    final operation = Future<void>.sync(widget.synchronize);
    // Handle both outcomes on the original future, including a late failure
    // after timeout or after the user chose to enter the local calendar.
    unawaited(
      operation.then<void>(
        (_) {
          if (!identical(_operation, operation)) return;
          _operation = null;
          if (mounted && !_ready) _continue();
        },
        onError: (Object error, StackTrace stack) {
          if (!identical(_operation, operation)) return;
          _operation = null;
          final failure = _StartupFailure.fromError(error);
          debugPrint('StartupSyncGate.failure category=${failure.code}');
          if (!mounted || _ready) return;
          setState(() {
            _slow = false;
            _failure = failure;
          });
        },
      ),
    );
    return operation;
  }

  void _continue() {
    if (_ready) return;
    ++_attempt;
    setState(() => _ready = true);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final strings = AppLocalizations.of(context);
    final failure = _failure;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (failure == null) const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      strings.text(
                        failure != null
                            ? '최신 데이터를 확인하지 못했습니다.'
                            : _slow
                            ? '최신 데이터를 확인하는 데 시간이 걸리고 있습니다.'
                            : '최신 일정을 확인하고 있습니다.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_slow || failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      strings.text(
                        failure?.message ??
                            '동기화를 계속 진행하고 있습니다. 완료되면 캘린더가 자동으로 열립니다.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.text(
                        '기기에 저장된 데이터로 계속할 수 있습니다. 아직 다른 기기의 변경사항이 반영되지 않았을 수 있습니다.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _run,
                      icon: const Icon(Icons.refresh),
                      label: Text(strings.text(_slow ? '계속 기다리기' : '다시 시도')),
                    ),
                    TextButton(
                      onPressed: _continue,
                      child: Text(strings.text('기기에 저장된 데이터로 계속')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StartupFailure {
  network('network', '네트워크 연결을 확인한 뒤 다시 시도해 주세요.'),
  expiredAuth('expired_auth', 'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.'),
  permission('permission', 'Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.'),
  auth(
    'auth',
    'Google Drive 연결을 확인해야 합니다. 기기에 저장된 데이터로 계속한 뒤 설정에서 연결 상태를 확인해 주세요.',
  ),
  changedAccount('changed_account', '동기화 중 연결된 계정이 변경되었습니다. 다시 시도해 주세요.'),
  malformedData('malformed_data', '동기화 데이터의 형식을 확인하지 못했습니다. 다시 시도해 주세요.'),
  rateLimited('rate_limited', 'Google Drive 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.'),
  server('server', 'Google Drive 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.'),
  unknown('unknown', '요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.');

  const _StartupFailure(this.code, this.message);

  final String code;
  final String message;

  static _StartupFailure fromError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return network;
    }
    if (error is FormatException) return malformedData;
    // These exact messages originate in our auth/Drive adapters. Arbitrary
    // exception strings, API response bodies, account IDs and paths stay private.
    final message = switch (error) {
      GoogleDriveAuthException() => error.message,
      GoogleDriveSyncException() => error.message,
      _ => null,
    };
    return switch (message) {
      'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.' => expiredAuth,
      'Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.' => permission,
      '계정이 변경되었습니다.' || 'Google Drive 계정이 변경되었습니다.' => changedAccount,
      'Google 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.' ||
      'Google Drive 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.' => rateLimited,
      'Google Drive 연결 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.' ||
      'Google Drive 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.' => server,
      'Google Drive 연결 응답 시간이 초과되었습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.' => network,
      'Google Drive 일정 백업 데이터가 손상되었습니다.' ||
      'Google Drive 설정 백업 데이터가 손상되었습니다.' ||
      'Google Drive 시간표 데이터가 손상되었거나 지원하지 않는 형식입니다. 기존 데이터는 보존됩니다.' =>
        malformedData,
      _ => error is GoogleDriveAuthException ? auth : unknown,
    };
  }
}
