import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/notifications/reminder_delivery_plan.dart';
import 'package:daily/core/notifications/notification_settings_change.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event(String type, {List<int> own = const []}) {
  final due = DateTime(2026, 12, 1, 23, 59);
  return CalendarEvent(
    id: 'lms:$type',
    title: 'x',
    startAt: due,
    endAt: due,
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    reminderMinutesBeforeList: own,
    lms: LmsEventMetadata(
      schoolId: 's',
      ownerId: 'o',
      lmsUserId: 'u',
      courseId: 'c',
      courseTitle: 't',
      activityType: type,
      activityId: 'a',
      sourceUrl: 'https://example.com',
    ),
    createdAt: due,
    updatedAt: due,
    deviceId: 'd',
  );
}

void main() {
  const on = LmsDueReminder(
    enabled: true,
    hoursBefore: 24,
    intervalHours: 8,
    count: 3,
  );

  test('시간·간격·횟수로 마감 전 알림 시각을 만든다', () {
    expect(on.minutesBefore, [480, 960, 1440]);
    expect(on.copyWith(count: 10).minutesBefore, [0, 480, 960, 1440]);
    expect(const LmsDueReminder().minutesBefore, isEmpty);
  });

  test('저장 값은 JSON으로 왕복하고 잘못된 값은 범위로 맞춘다', () {
    expect(LmsDueReminder.fromJson(on.toJson()), on);
    expect(LmsDueReminder.fromJson('broken'), const LmsDueReminder());
    expect(
      LmsDueReminder.fromJson({'enabled': true, 'count': 999}).count,
      LmsDueReminder.maxCount,
    );
  });

  test('LMS 과제에만 설정이 더해지고 다른 일정은 그대로다', () {
    final settings = AppSettings(lmsDueReminder: on);
    expect(
      effectiveReminderMinutes(_event('assignment', own: [10]), settings),
      [10, 480, 960, 1440],
    );
    expect(effectiveReminderMinutes(_event('quiz'), settings), isEmpty);
    expect(
      effectiveReminderMinutes(_event('assignment'), AppSettings()),
      isEmpty,
    );
  });

  test('설정이 바뀌면 일정 알림을 다시 잡는다', () {
    final base = AppSettings();
    expect(
      NotificationSettingsChange.between(
        base,
        base.copyWith(lmsDueReminder: on),
      ).eventReminders,
      isTrue,
    );
  });
}
