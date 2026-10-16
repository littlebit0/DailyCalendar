import 'package:daily/features/chat/application/rule_based_schedule_parser.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleBasedScheduleParser', () {
    final parser = RuleBasedScheduleParser();
    final baseDate = DateTime(2026, 5, 11);

    test('parses a simple timed event with the default reminder', () async {
      final result = await parser.parse(
        '내일 오후 3시 병원',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '병원');
      expect(draft.startAt, DateTime(2026, 5, 12, 15));
      expect(draft.endAt, DateTime(2026, 5, 12, 16));
      expect(draft.reminderMinutesBefore, 60);
      expect(draft.category, EventCategory.health);
    });

    test('applies every selected default reminder', () async {
      final result = await parser.parse(
        '내일 오후 3시 회의',
        baseDate: baseDate,
        defaultReminderMinutes: 10,
        defaultReminderMinutesList: const [10, 30, 60],
      );

      expect(result.draft!.reminderMinutesBeforeList, [10, 30, 60]);
    });

    test('an explicit reminder replaces the selected defaults', () async {
      final result = await parser.parse(
        '내일 오후 3시 20분 전 회의',
        baseDate: baseDate,
        defaultReminderMinutes: 10,
        defaultReminderMinutesList: const [10, 30, 60],
      );

      expect(result.draft!.reminderMinutesBeforeList, [20]);
    });

    test('uses a selected date when no date is typed', () async {
      final result = await parser.parse(
        '오전 9시 회의',
        baseDate: baseDate,
        selectedDate: DateTime(2026, 5, 20),
        defaultReminderMinutes: 60,
      );

      expect(result.draft!.startAt, DateTime(2026, 5, 20, 9));
    });

    test('parses recurring events', () async {
      final result = await parser.parse(
        '매주 월요일 오후 7시 운동',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      expect(result.draft!.recurrence.frequency, RecurrenceFrequency.weekly);
    });

    test('parses an all-day multi-day event', () async {
      final result = await parser.parse(
        '5월 20일부터 5월 22일까지 부산 여행',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '부산 여행');
      expect(draft.startAt, DateTime(2026, 5, 20));
      expect(draft.endAt, DateTime(2026, 5, 23));
      expect(draft.allDay, isTrue);
      expect(draft.reminderMinutesBefore, isNull);
    });

    test('parses a timed multi-day event', () async {
      final result = await parser.parse(
        '5월 20일 오후 2시부터 5월 22일 오전 10시까지 출장',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '출장');
      expect(draft.startAt, DateTime(2026, 5, 20, 14));
      expect(draft.endAt, DateTime(2026, 5, 22, 10));
      expect(draft.allDay, isFalse);
    });

    test('parses a duration-based multi-day event', () async {
      final result = await parser.parse(
        '내일부터 3일간 워크숍',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '워크숍');
      expect(draft.startAt, DateTime(2026, 5, 12));
      expect(draft.endAt, DateTime(2026, 5, 15));
      expect(draft.allDay, isTrue);
    });

    Future<dynamic> parse(String text, {DateTime? at}) => parser.parse(
      text,
      baseDate: at ?? baseDate,
      defaultReminderMinutes: 60,
    );

    test('a reminder never becomes a start or end time', () async {
      for (final entry in {
        '내일 오전 9시 회의 2시간 전 알림': (DateTime(2026, 5, 12, 9), 120),
        '내일 오전 9시 회의 30분 전 알림': (DateTime(2026, 5, 12, 9), 30),
        '내일 오후 3시 회의 1시간 전 알림': (DateTime(2026, 5, 12, 15), 60),
        '내일 오후 3시 20분 전 회의': (DateTime(2026, 5, 12, 15), 20),
        '1시간 전 알림 내일 오후 3시 회의': (DateTime(2026, 5, 12, 15), 60),
      }.entries) {
        final draft = (await parse(entry.key)).draft!;
        expect(draft.startAt, entry.value.$1, reason: entry.key);
        expect(
          draft.endAt,
          entry.value.$1.add(const Duration(hours: 1)),
          reason: entry.key,
        );
        expect(draft.allDay, isFalse, reason: entry.key);
        expect(draft.reminderMinutesBeforeList, [entry.value.$2]);
        expect(draft.title, '회의', reason: entry.key);
      }
    });

    test('real start and end times and minutes are kept', () async {
      var draft = (await parse('내일 오후 3시 20분 회의')).draft!;
      expect(draft.startAt, DateTime(2026, 5, 12, 15, 20));
      draft = (await parse('내일 오전 9시부터 오전 10시까지 회의 1시간 전 알림')).draft!;
      expect(draft.startAt, DateTime(2026, 5, 12, 9));
      expect(draft.endAt, DateTime(2026, 5, 12, 10));
      expect(draft.reminderMinutesBeforeList, [60]);
    });

    test(
      'dates that do not exist ask instead of moving to another day',
      () async {
        for (final text in ['2월 30일 회의', '4월 31일 회의', '13월 1일 회의']) {
          final result = await parse(text, at: DateTime(2026, 1, 1));
          expect(result.draft, isNull, reason: text);
          expect(result.question, contains('올바른 날짜가 아닙니다'), reason: text);
        }
        final range = await parse(
          '2월 27일부터 2월 30일까지 출장',
          at: DateTime(2026, 1, 1),
        );
        expect(range.draft, isNull);
        expect(range.question, contains('2월 30일'));
      },
    );

    test('real month ends and leap days still parse', () async {
      var draft = (await parse('2월 28일 회의', at: DateTime(2026, 1, 1))).draft!;
      expect(draft.startAt, DateTime(2026, 2, 28));
      draft = (await parse('2월 29일 회의', at: DateTime(2026, 1, 1))).draft!;
      expect(draft.startAt, DateTime(2028, 2, 29));
    });

    test(
      'invalid clock times ask instead of becoming an all-day event',
      () async {
        for (final text in ['내일 25시 회의', '내일 9시 75분 회의']) {
          final result = await parse(text);
          expect(result.draft, isNull, reason: text);
          expect(result.question, contains('올바른 시각이 아닙니다'), reason: text);
        }
        final draft = (await parse('내일 회의')).draft!;
        expect(draft.allDay, isTrue);
      },
    );
  });
}
