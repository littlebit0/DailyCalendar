import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_repository.dart';

/// Personal calendars retain their existing shared local behavior. LMS rows are
/// always scoped to their Google owner, including search, widgets and reminders.
class OwnerScopedEventRepository implements EventRepository {
  OwnerScopedEventRepository(this.delegate, this.readOwner);
  final EventRepository delegate;
  final String? Function() readOwner;
  List<CalendarEvent> _visible(List<CalendarEvent> events) =>
      events.where((event) => event.isVisibleToOwner(readOwner())).toList();

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime start,
    DateTime end,
  ) => delegate.watchEventsInRange(start, end).map(_visible);
  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime start,
    DateTime end,
  ) async => _visible(await delegate.eventsInRange(start, end));
  @override
  Future<List<CalendarEvent>> search(String query) async =>
      _visible(await delegate.search(query));
  @override
  Future<CalendarEvent?> findById(String id) async {
    final event = await delegate.findById(id);
    return event?.isVisibleToOwner(readOwner()) == true ? event : null;
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async =>
      _visible(await delegate.pendingSyncEvents());
  @override
  Future<List<CalendarEvent>> allEventsForSync() async =>
      _visible(await delegate.allEventsForSync());
  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) => delegate.updateCategoryReferences(
    previous: previous,
    updated: updated,
    updatedAt: updatedAt,
  );
  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) => delegate.mergeRestoredEventsAtomically(remoteEvents, resolve: resolve);
  @override
  Future<void> save(CalendarEvent event) => delegate.save(event);
  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) =>
      delegate.saveAllAtomically(events);
  @override
  Future<void> markSynced(String id) => delegate.markSynced(id);
  @override
  Future<void> delete(String id) => delegate.delete(id);
  @override
  Future<void> hardDelete(String id) => delegate.hardDelete(id);
  @override
  Future<void> clearAll() => delegate.clearAll();
}
