import '../settings/app_settings.dart';

/// Which scheduled notifications a settings change makes stale.
///
/// Settings can change without the settings screen (a Drive restore applies
/// them directly), so the follow-up is derived from the old and new values
/// rather than from the screen that edited them.
class NotificationSettingsChange {
  const NotificationSettingsChange({
    required this.briefing,
    required this.eventReminders,
  });

  /// The morning briefing was switched on/off or moved.
  final bool briefing;

  /// The all-day reminder time or the D-day offsets that existing event
  /// reminders were scheduled from changed.
  final bool eventReminders;

  bool get isEmpty => !briefing && !eventReminders;

  static NotificationSettingsChange between(
    AppSettings previous,
    AppSettings next,
  ) => NotificationSettingsChange(
    briefing:
        previous.morningBriefingEnabled != next.morningBriefingEnabled ||
        (next.morningBriefingEnabled &&
            (previous.morningBriefingHour != next.morningBriefingHour ||
                previous.morningBriefingMinute != next.morningBriefingMinute)),
    eventReminders:
        previous.allDayReminderHour != next.allDayReminderHour ||
        previous.allDayReminderMinute != next.allDayReminderMinute ||
        !_sameOffsets(previous.dDayReminderOffsets, next.dDayReminderOffsets),
  );

  static bool _sameOffsets(List<int> a, List<int> b) {
    final left = {...a}, right = {...b};
    return left.length == right.length && left.containsAll(right);
  }
}
