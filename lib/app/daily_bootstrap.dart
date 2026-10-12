import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../core/analytics/product_analytics.dart';
import '../core/localization/app_localizations.dart';
import '../core/migration/todo_database_migration_service.dart';
import '../core/settings/app_settings.dart';
import 'daily_app.dart';
import '../core/diagnostics/startup_timing.dart';
import 'daily_theme.dart';

class DailyBootstrap extends ConsumerStatefulWidget {
  const DailyBootstrap({super.key});

  @override
  ConsumerState<DailyBootstrap> createState() => _DailyBootstrapState();
}

class _DailyBootstrapState extends ConsumerState<DailyBootstrap> {
  final Stopwatch _startupStopwatch = Stopwatch()..start();
  late final TodoDatabaseMigrationService _migrationService;
  TodoMigrationProgress? _progress;
  TodoMigrationException? _error;
  var _ready = false;
  var _running = false;

  @override
  void initState() {
    super.initState();
    _migrationService = ref.read(todoDatabaseMigrationServiceProvider);
    _progress = _migrationService.progress.value;
    _migrationService.progress.addListener(_onProgressChanged);
    unawaited(_runMigration());
  }

  @override
  void dispose() {
    _migrationService.progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (!mounted) return;
    setState(() => _progress = _migrationService.progress.value);
  }

  Future<void> _runMigration() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await StartupTiming.measure(
        StartupStage.migration,
        _migrationService.migrateIfNeeded,
      );
      if (!mounted) return;
      _startupStopwatch.stop();
      unawaited(
        ref
            .read(productAnalyticsProvider)
            .record(
              AnalyticsRecord.appLoad(
                durationMs: _startupStopwatch.elapsedMilliseconds,
              ),
            )
            .catchError((_) {}),
      );
      setState(() => _ready = true);
    } on TodoMigrationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const DailyApp();
    }

    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: localeForLanguage(settings.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: DailyTheme.light(),
      darkTheme: DailyTheme.dark(),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: _MigrationScreen(
        progress: _progress,
        error: _error,
        running: _running,
        onRetry: _runMigration,
      ),
    );
  }
}

class _MigrationScreen extends StatelessWidget {
  const _MigrationScreen({
    required this.progress,
    required this.error,
    required this.running,
    required this.onRetry,
  });

  final TodoMigrationProgress? progress;
  final TodoMigrationException? error;
  final bool running;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasError ? Icons.sync_problem_rounded : Icons.sync_rounded,
                    size: 48,
                    color: hasError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr(hasError ? '업데이트를 완료하지 못했습니다' : '업데이트 중입니다'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      error?.message ?? progress?.message ?? '업데이트 확인 중',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (running)
                    const CircularProgressIndicator()
                  else if (hasError)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('다시 시도')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
