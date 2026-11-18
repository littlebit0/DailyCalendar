import 'dart:convert';
import 'dart:io';

import 'package:daily/core/calendar/recurring_event_edit.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

String _stamp(DateTime value) => value.toIso8601String().substring(0, 19);
String _day(DateTime value) => value.toIso8601String().substring(0, 10);

/// The Siri "entire series" edit reads the same fixture in
/// tool/tests/siri_occurrence_mutation_test.swift (#930).
void main() {
  final cases =
      jsonDecode(
            File(
              'test/fixtures/recurrence_series_edit_cases.json',
            ).readAsStringSync(),
          )
          as List;
  for (final item in cases) {
    test('shared series edit fixture ${item['name']}', () {
      final start = DateTime.parse(item['start']);
      final latest = CalendarEvent(
        id: 'series',
        title: 'series',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: 1,
        createdAt: start,
        updatedAt: start,
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.values.byName(item['frequency']),
          interval: item['interval'],
          until: item['until'] == null ? null : DateTime.parse(item['until']),
          anchorDay: item['anchorDay'],
          byDay: List<String>.from(item['byDay'] ?? const []),
          byMonth: List<int>.from(item['byMonth'] ?? const []),
          weekStart: item['weekStart'] == null
              ? null
              : RecurrenceRule.weekdayCodes.indexOf(item['weekStart']) + 1,
          excludedDates: [
            for (final day in item['excluded'] ?? []) DateTime.parse(day),
          ],
        ),
      );
      final occurrenceStart = DateTime.parse(item['occurrence']);
      final edited = applyRecurringEventDraft(
        latest: latest,
        occurrence: latest.copyWith(
          startAt: occurrenceStart,
          endAt: occurrenceStart.add(const Duration(hours: 1)),
        ),
        draft: EventDraft(
          title: 'series',
          startAt: DateTime.parse(item['newStart']),
          endAt: DateTime.parse(item['newEnd']),
          category: EventCategory.basic,
          categoryChanged: false,
          recurrence: latest.recurrence,
        ),
        scope: RecurringEditScope.all,
      );
      final rule = edited.recurrence;
      expect(rule.frequency, latest.recurrence.frequency);
      expect({
        'start': _stamp(edited.startAt),
        'end': _stamp(edited.endAt),
        if (rule.until != null) 'until': _day(rule.until!),
        if (rule.anchorDay != null) 'anchorDay': rule.anchorDay,
        if (rule.excludedDates.isNotEmpty)
          'excluded': rule.excludedDates.map(_day).toList()..sort(),
        if (rule.byDay.isNotEmpty) 'byDay': rule.byDay,
        if (rule.byMonthDay.isNotEmpty) 'byMonthDay': rule.byMonthDay,
        if (rule.byMonth.isNotEmpty) 'byMonth': rule.byMonth,
        if (rule.bySetPos.isNotEmpty) 'bySetPos': rule.bySetPos,
        if (rule.weekStart != null && rule.hasDetails)
          'weekStart': RecurrenceRule.weekdayCodes[rule.weekStart! - 1],
      }, item['expected']);
    });
  }
}
