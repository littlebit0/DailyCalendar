import 'package:flutter/foundation.dart';

/// Logs only fixed stage names and durations. Never records accounts or errors.
enum StartupStage {
  launch,
  settings,
  migration,
  database,
  localCalendar,
  accountRestore,
  drive,
  lms,
  academic,
  firstCalendarFrame,
}

class StartupTiming {
  static final _clock = Stopwatch()..start();
  static bool _firstFrameRecorded = false;

  static void mark(StartupStage stage, {int? durationUs, bool failed = false}) {
    if (kReleaseMode) return;
    debugPrint(
      'Daily.startup stage=${stage.name} '
      'elapsed_us=${_clock.elapsedMicroseconds} '
      'duration_us=${durationUs ?? 0} outcome=${failed ? "failed" : "ok"}',
    );
  }

  static Future<T> measure<T>(
    StartupStage stage,
    Future<T> Function() run,
  ) async {
    final clock = Stopwatch()..start();
    var failed = false;
    try {
      return await run();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      mark(stage, durationUs: clock.elapsedMicroseconds, failed: failed);
    }
  }

  static void firstCalendarFrame() {
    if (_firstFrameRecorded) return;
    _firstFrameRecorded = true;
    mark(StartupStage.firstCalendarFrame);
  }
}
