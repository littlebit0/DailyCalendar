import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

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
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _ready = !widget.requiredAtStartup;
    if (!_ready) unawaited(_run());
  }

  Future<void> _run() async {
    final attempt = ++_attempt;
    setState(() => _failed = false);
    final operation = _operation ??= Future.sync(widget.synchronize);
    // Handle both outcomes on the original future, including a late failure
    // after timeout or after the user chose to enter the local calendar.
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_operation, operation)) _operation = null;
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_operation, operation)) _operation = null;
        },
      ),
    );
    try {
      await operation.timeout(widget.timeout);
      if (!mounted || attempt != _attempt) return;
      _continue();
    } on Object {
      if (!mounted || attempt != _attempt) return;
      setState(() => _failed = true);
    }
  }

  void _continue() {
    ++_attempt;
    setState(() => _ready = true);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final strings = AppLocalizations.of(context);
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
                  if (!_failed) const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      strings.text(
                        _failed ? '최신 데이터를 확인하지 못했습니다.' : '최신 일정을 확인하고 있습니다.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_failed) ...[
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
                      label: Text(strings.text('다시 시도')),
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
