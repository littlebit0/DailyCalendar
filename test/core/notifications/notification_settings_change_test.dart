import 'package:daily/core/notifications/notification_settings_change.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = AppSettings();

  test('identical settings need no notification follow-up', () {
    expect(NotificationSettingsChange.between(base, base).isEmpty, isTrue);
  });

  test('switching the briefing off or on is a briefing change', () {
    final off = base.copyWith(morningBriefingEnabled: false);
    expect(NotificationSettingsChange.between(base, off).briefing, isTrue);
    expect(NotificationSettingsChange.between(off, base).briefing, isTrue);
  });

  test('a new briefing time matters only while the briefing is on', () {
    final moved = base.copyWith(
      morningBriefingHour: base.morningBriefingHour + 1,
    );
    expect(NotificationSettingsChange.between(base, moved).briefing, isTrue);
    final off = base.copyWith(morningBriefingEnabled: false);
    final offMoved = off.copyWith(morningBriefingMinute: 30);
    expect(NotificationSettingsChange.between(off, offMoved).briefing, isFalse);
  });

  test('all-day time and D-day offsets rebuild event reminders', () {
    final later = base.copyWith(
      allDayReminderHour: base.allDayReminderHour + 1,
    );
    expect(
      NotificationSettingsChange.between(base, later).eventReminders,
      isTrue,
    );
    final none = base.copyWith(dDayReminderOffsets: const []);
    expect(
      NotificationSettingsChange.between(base, none).eventReminders,
      isTrue,
    );
    // Order alone is not a change.
    final reordered = base.copyWith(dDayReminderOffsets: const [0, -1, -3, -7]);
    expect(NotificationSettingsChange.between(base, reordered).isEmpty, isTrue);
  });
}
