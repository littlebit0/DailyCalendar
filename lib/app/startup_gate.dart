import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_localizations.dart';
import 'daily_theme.dart';

/// Does not create repositories or expose calendar content until initialization
/// succeeds. Failed preferences reads are never replaced with default settings.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.initialize});

  final Future<Widget> Function() initialize;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _application;
  bool _running = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
    });
    try {
      final application = await widget.initialize();
      if (!mounted) return;
      setState(() => _application = application);
    } catch (_) {
      // Do not log preferences contents or display raw file/account exceptions.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_application != null) return _application!;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: DailyTheme.light(),
      darkTheme: DailyTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_failed) ...[
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('앱을 시작하지 못했습니다'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            '저장된 설정을 불러오거나 앱을 준비하지 못했습니다. 기존 설정과 일정은 초기화하지 않았습니다. 문제가 계속되면 지원을 요청해 주세요.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _initialize,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr('다시 시도')),
                        ),
                      ] else
                        const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
