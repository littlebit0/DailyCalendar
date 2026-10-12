import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/daily_bootstrap.dart';
import 'core/diagnostics/startup_timing.dart';
import 'core/analytics/privacy_analytics_service.dart';
import 'core/di/app_providers.dart';
import 'core/settings/settings_repository.dart';
import 'core/update/app_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTiming.mark(StartupStage.launch);
  await Future.wait([
    initializeDateFormatting('ko'),
    initializeDateFormatting('en'),
    initializeDateFormatting('ja'),
    initializeDateFormatting('zh_TW'),
  ]);
  final preferences = await StartupTiming.measure(
    StartupStage.settings,
    SharedPreferences.getInstance,
  );
  final settingsRepository = SettingsRepository(preferences: preferences);
  final analytics = PrivacyAnalyticsService(preferences: preferences);
  await analytics.initialize();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        productAnalyticsProvider.overrideWithValue(analytics),
      ],
      child: const DailyBootstrap(),
    ),
  );
  unawaited(AppUpdateService().checkAndInstallIfAvailable());
}
