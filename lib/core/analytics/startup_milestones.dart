import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/app_providers.dart';
import '../diagnostics/startup_timing.dart';
import 'product_analytics.dart';

/// Reports a startup milestone once per process; never affects startup.
void recordStartupMilestone(
  WidgetRef ref,
  StartupStage stage,
  AnalyticsStartupMilestone milestone,
) {
  if (!StartupTiming.claim(stage)) return;
  unawaited(
    ref
        .read(productAnalyticsProvider)
        .record(
          AnalyticsRecord.startupMilestone(
            milestone,
            durationMs: StartupTiming.sinceLaunchMs,
          ),
        )
        .catchError((_) {}),
  );
}

/// Whether [context]'s render object is on screen rather than inside an
/// `Offstage(offstage: true)` (which is how the app lock hides the calendar).
bool isShownOnScreen(BuildContext context) {
  RenderObject? node = context.findRenderObject();
  if (node == null || !node.attached) return false;
  while (node != null) {
    if (node is RenderOffstage && node.offstage) return false;
    node = node.parent;
  }
  return true;
}

/// Measures the first frame of the calendar itself, from the calendar's own
/// mount: not the loading/announcement screens in front of it, and not a
/// locked start. When the calendar is first built hidden behind the app lock,
/// the milestone is skipped for this run (the time would measure the person
/// typing a PIN), so the dataset never mixes in that case.
void recordFirstCalendarFrame(BuildContext context, WidgetRef ref) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    StartupTiming.firstCalendarFrame();
    if (!isShownOnScreen(context)) {
      StartupTiming.claim(StartupStage.firstCalendarFrame);
      return;
    }
    recordStartupMilestone(
      ref,
      StartupStage.firstCalendarFrame,
      AnalyticsStartupMilestone.firstCalendarFrame,
    );
  });
}
