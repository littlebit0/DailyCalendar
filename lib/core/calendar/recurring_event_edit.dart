import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_draft.dart';
import '../../features/events/domain/recurrence_rule.dart';
import 'calendar_event_movement.dart';

enum RecurringEditScope { onlyThis, future, all }

/// Translate an occurrence-based editor into a series-based storage operation.
/// The latest stored series owns exclusions; the editor cannot erase them.
CalendarEvent applyRecurringEventDraft({
  required CalendarEvent latest,
  required CalendarEvent occurrence,
  required EventDraft draft,
  required RecurringEditScope scope,
}) {
  final delta = calendarDayDifference(draft.startAt, occurrence.startAt);
  var start = draft.startAt;
  if (scope == RecurringEditScope.all) {
    final day = shiftCalendarDateByDays(latest.startAt, delta);
    start = DateTime(
      day.year,
      day.month,
      day.day,
      draft.startAt.hour,
      draft.startAt.minute,
      draft.startAt.second,
      draft.startAt.millisecond,
      draft.startAt.microsecond,
    );
  }
  final inherited = scope == RecurringEditScope.future
      ? recurrenceRuleForMovedFuture(
          base: latest,
          occurrence: occurrence,
          targetDate: draft.startAt,
        )
      : shiftRecurrenceRuleByDays(latest.recurrence, delta);
  final edited = draft.recurrence;
  final original = occurrence.recurrence;
  final frequency = edited.frequency == original.frequency
      ? latest.recurrence.frequency
      : edited.frequency;
  final rule =
      scope == RecurringEditScope.onlyThis ||
          frequency == RecurrenceFrequency.none
      ? const RecurrenceRule()
      : RecurrenceRule(
          frequency: frequency,
          interval: edited.interval == original.interval
              ? latest.recurrence.interval
              : edited.interval,
          count: draft.recurrenceCountChanged || edited.count != original.count
              ? edited.count
              : inherited.count,
          until: edited.until != original.until
              ? edited.until
              : inherited.until,
          excludedDates: inherited.excludedDates,
          anchorDay: frequency == latest.recurrence.frequency
              ? inherited.anchorDay
              : null,
        );
  return draft
      .applyTo(latest)
      .copyWith(
        startAt: start,
        endAt: start.add(draft.endAt.difference(draft.startAt)),
        recurrence: rule,
        category: draft.categoryChanged ? draft.category : latest.category,
        colorValue: draft.categoryChanged
            ? draft.colorValue ?? draft.category.colorValue
            : latest.colorValue,
      )
      .normalizeAllDayBounds();
}
