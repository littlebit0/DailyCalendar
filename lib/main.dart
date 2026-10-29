import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/daily_bootstrap.dart';
import 'app/startup_gate.dart';
import 'core/diagnostics/startup_timing.dart';
import 'core/analytics/privacy_analytics_service.dart';
import 'core/di/app_providers.dart';
import 'core/settings/settings_repository.dart';
import 'core/update/app_update_service.dart';
import 'core/update/update_requirement.dart';

Future<void> main() async {
  StartupTiming.begin();
  WidgetsFlutterBinding.ensureInitialized();
  StartupTiming.mark(StartupStage.launch);
  runApp(StartupGate(initialize: _initializeApplication));
}

Future<Widget> _initializeApplication() async {
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

  final updates = AppUpdateService();
  final requirement = UpdateRequirementController(
    preferences: preferences,
    latestVersion: updates.latestReleaseVersion,
    // Release builds only: a debug or test build is routinely older than the feed.
    enabled: !kDebugMode,
    onDetected: updates.checkAndInstallIfAvailable,
  );
  await requirement.initialize();
  final app = ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepository),
      requiredUpdateVersionProvider.overrideWithValue(
        requirement.requiredVersion,
      ),
      updateRequirementControllerProvider.overrideWithValue(requirement),
      productAnalyticsProvider.overrideWithValue(analytics),
    ],
    child: const DailyBootstrap(),
  );
  unawaited(updates.checkAndInstallIfAvailable());
  requirement.start();
  return app;
}
