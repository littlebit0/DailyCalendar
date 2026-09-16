import 'calendar_event.dart';
import '../data/recurrence_expander.dart';
import 'event_repository.dart';

class EventDeletion {
  const EventDeletion({
    required this.id,
    required this.deletedAt,
    this.pending = true,
  });
  final String id;
  final DateTime deletedAt;
  final bool pending;

  Map<String, Object?> toJson() => {
    'id': id,
    'deletedAt': deletedAt.toUtc().toIso8601String(),
  };

  factory EventDeletion.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? '');
    if (id == null || id.isEmpty || deletedAt == null) {
      throw const FormatException('Invalid deletion record');
    }
    return EventDeletion(id: id, deletedAt: deletedAt.toUtc(), pending: false);
  }
}

bool canCompactDeletedEvent(CalendarEvent event, DateTime now) {
  if (!event.isDeleted) return false;
  final today = DateTime(now.year, now.month, now.day);
  var end = event.endAt;
  if (event.recurrence.isRepeating) {
    final until = event.recurrence.until;
    final count = event.recurrence.count;
    // An unbounded deleted series still has future planned dates.
    if (until == null && count == null) return false;
    end = RecurrenceExpander().lastPlannedEnd(event);
  }
  // endAt is exclusive; an event ending at midnight is past on that date.
  return !end.isAfter(today);
}

abstract interface class EventSyncMaintenance {
  Future<List<EventRestoreMutation>> mergeSyncRecords(
    List<CalendarEvent> events,
    List<EventDeletion> deletions, {
    required RestoredEventResolver resolve,
  });
  Future<List<EventDeletion>> deletionRecords({bool pendingOnly = false});
  Future<void> mergeDeletionRecords(Iterable<EventDeletion> records);
  Future<void> compactDeletedEvents(DateTime now);
  Future<void> markDeletionSynced(EventDeletion deletion);
}
