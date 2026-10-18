import '../../features/events/data/recurrence_expander.dart';
import '../../features/events/domain/calendar_event.dart';

enum ReminderDeliveryType { none, immediate, scheduled }

class ReminderDeliveryPlan {
  const ReminderDeliveryPlan._(this.type, this.deliverAt);

  const ReminderDeliveryPlan.none() : this._(ReminderDeliveryType.none, null);

  const ReminderDeliveryPlan.immediate(DateTime deliverAt)
    : this._(ReminderDeliveryType.immediate, deliverAt);

  const ReminderDeliveryPlan.scheduled(DateTime deliverAt)
    : this._(ReminderDeliveryType.scheduled, deliverAt);

  final ReminderDeliveryType type;
  final DateTime? deliverAt;
}

ReminderDeliveryPlan resolveReminderDeliveryPlan({
  required DateTime reminderAt,
  required DateTime fallbackAt,
  required DateTime eventEndAt,
  required DateTime now,
  required bool allowImmediate,
  Duration dueGrace = const Duration(minutes: 2),
}) {
  if (reminderAt.isAfter(now)) {
    return ReminderDeliveryPlan.scheduled(reminderAt);
  }

  if (allowImmediate && eventEndAt.isAfter(now)) {
    return ReminderDeliveryPlan.immediate(reminderAt);
  }

  if (fallbackAt.isAfter(now)) {
    return ReminderDeliveryPlan.scheduled(fallbackAt);
  }

  if (allowImmediate && now.difference(fallbackAt) <= dueGrace) {
    return ReminderDeliveryPlan.immediate(fallbackAt);
  }

  return const ReminderDeliveryPlan.none();
}

/// Upcoming reminders kept scheduled per repeating event and reminder offset.
///
/// Notification requests are single shots (Windows has no repeating trigger and
/// an OS trigger cannot honour count, until or excluded dates), and iOS keeps
/// only 64 pending requests, so a repeating event keeps its next few
/// occurrences. They are refilled whenever the app starts, the event changes or
/// a sync restores it.
const recurringReminderSlotsPerOffset = 8;

class RecurringReminderRequest {
  const RecurringReminderRequest({
    required this.slot,
    required this.occurrence,
    required this.base,
    required this.plan,
  });

  /// 0-based position among the upcoming requests; keys the notification id.
  final int slot;
  final CalendarEvent occurrence;

  /// Start of the occurrence (or the all-day reminder time) the offset counts from.
  final DateTime base;
  final ReminderDeliveryPlan plan;
}

/// The next reminders of a repeating [event] for one [reminderMinutes] offset.
///
/// Occurrences come from the same expander the calendar uses, so count, until,
/// excluded dates and month-end rules match what the user sees.
List<RecurringReminderRequest> planRecurringReminders({
  required CalendarEvent event,
  required int reminderMinutes,
  required DateTime Function(CalendarEvent occurrence) baseTime,
  required DateTime now,
  required bool allowImmediate,
  Duration dueGrace = const Duration(minutes: 2),
  int slots = recurringReminderSlotsPerOffset,
}) {
  final requests = <RecurringReminderRequest>[];
  if (slots <= 0) return requests;
  // Widen the search until a valid reminder exists, so a series whose next
  // occurrence is years away (yearly, multi-year interval) keeps its reminder.
  var occurrences = <CalendarEvent>[];
  for (final days in const [800, 3700, 36600]) {
    occurrences = RecurrenceExpander().expand(
      event,
      now.subtract(event.duration + const Duration(days: 2)),
      now.add(Duration(days: days)),
    )..sort((a, b) => a.startAt.compareTo(b.startAt));
    final hasUpcoming = occurrences.any(
      (o) =>
          baseTime(o).isAfter(now.subtract(dueGrace)) || o.endAt.isAfter(now),
    );
    if (hasUpcoming) break;
  }
  for (final occurrence in occurrences) {
    final base = baseTime(occurrence);
    final plan = resolveReminderDeliveryPlan(
      reminderAt: base.subtract(Duration(minutes: reminderMinutes)),
      fallbackAt: base,
      eventEndAt: occurrence.endAt,
      now: now,
      allowImmediate: allowImmediate,
      dueGrace: dueGrace,
    );
    if (plan.type == ReminderDeliveryType.none) continue;
    requests.add(
      RecurringReminderRequest(
        slot: requests.length,
        occurrence: occurrence,
        base: base,
        plan: plan,
      ),
    );
    if (requests.length >= slots) break;
  }
  return requests;
}
