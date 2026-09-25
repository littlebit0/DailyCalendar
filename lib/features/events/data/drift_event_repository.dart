import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'event_mapper.dart';
import 'recurrence_expander.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_repository.dart';
import '../domain/event_deletion.dart';
import '../../../core/sync/sync_version.dart';
import '../../../core/lms/lms_models.dart';

class DriftEventRepository implements EventRepository, EventSyncMaintenance {
  DriftEventRepository(this._database, {RecurrenceExpander? expander})
    : _expander = expander ?? RecurrenceExpander();

  final AppDatabase _database;
  final RecurrenceExpander _expander;

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final query = _database.select(_database.eventRecords)
      ..where(
        (table) =>
            table.deletedAt.isNull() &
            (table.recurrenceFrequency.equals('none').not() |
                (table.startAt.isSmallerThanValue(rangeEnd) &
                    (table.endAt.isBiggerThanValue(rangeStart) |
                        (table.lmsMetadata.isNotNull() &
                            table.endAt.equalsExp(table.startAt) &
                            table.startAt.isBiggerOrEqualValue(rangeStart))))),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.startAt)]);

    return query.watch().map((records) {
      final events =
          records
              .expand(
                (record) =>
                    _expander.expand(record.toDomain(), rangeStart, rangeEnd),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return events;
    });
  }

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final rows =
        await (_database.select(_database.eventRecords)
              ..where(
                (table) =>
                    table.deletedAt.isNull() &
                    (table.recurrenceFrequency.equals('none').not() |
                        (table.startAt.isSmallerThanValue(rangeEnd) &
                            (table.endAt.isBiggerThanValue(rangeStart) |
                                (table.lmsMetadata.isNotNull() &
                                    table.endAt.equalsExp(table.startAt) &
                                    table.startAt.isBiggerOrEqualValue(
                                      rangeStart,
                                    ))))),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.startAt)]))
            .get();
    final events =
        rows
            .expand(
              (record) =>
                  _expander.expand(record.toDomain(), rangeStart, rangeEnd),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return events;
  }

  @override
  Future<List<CalendarEvent>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.eventRecords)
              ..where(
                (table) =>
                    table.deletedAt.isNull() &
                    (table.title.contains(normalized) |
                        table.memo.contains(normalized) |
                        table.location.contains(normalized) |
                        table.url.contains(normalized) |
                        table.weather.contains(normalized) |
                        table.category.contains(normalized)),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.startAt)]))
            .get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<CalendarEvent?> findById(String id) async {
    final row = await (_database.select(
      _database.eventRecords,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async {
    final rows = await (_database.select(
      _database.eventRecords,
    )..where((table) => table.syncStatus.equals('synced').not())).get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async {
    final rows = await (_database.select(
      _database.eventRecords,
    )..orderBy([(table) => OrderingTerm.asc(table.updatedAt)])).get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<void> save(CalendarEvent event) {
    final normalized = event.normalizeAllDayBounds();
    return _database
        .into(_database.eventRecords)
        .insertOnConflictUpdate(_companion(normalized));
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    final normalized = events
        .map((event) => event.normalizeAllDayBounds())
        .toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }
    await _database.transaction(() async {
      for (final event in normalized) {
        await _database
            .into(_database.eventRecords)
            .insertOnConflictUpdate(_companion(event));
      }
    });
  }

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) {
    return _database.transaction(() async {
      final rows = await _database.select(_database.eventRecords).get();
      final localById = {for (final row in rows) row.id: row.toDomain()};
      final mutations = <EventRestoreMutation>[];
      for (final remote in remoteEvents) {
        final normalizedRemote = remote.normalizeAllDayBounds();
        final previous = localById[normalizedRemote.id];
        final current = resolve(
          previous,
          normalizedRemote,
        ).normalizeAllDayBounds();
        if (!identical(previous, current)) {
          await _database
              .into(_database.eventRecords)
              .insertOnConflictUpdate(_companion(current));
          localById[current.id] = current;
          mutations.add(
            EventRestoreMutation(previous: previous, current: current),
          );
        }
      }
      return mutations;
    });
  }

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    final previousStoredValues = {
      previous.id,
      previous.label,
    }.where((value) => value.trim().isNotEmpty).toList();
    if (previousStoredValues.isEmpty) {
      return const [];
    }

    final affectedRows =
        await (_database.select(_database.eventRecords)..where(
              (table) =>
                  table.deletedAt.isNull() &
                  table.category.isIn(previousStoredValues),
            ))
            .get();
    if (affectedRows.isEmpty) {
      return const [];
    }

    final affected = affectedRows
        .map((record) {
          final event = record.toDomain();
          return event.copyWith(
            category: updated,
            colorValue: updated.colorValue,
            updatedAt: updatedAt,
            syncStatus: 'pending',
            holiday: updated.id == EventCategory.holiday.id,
          );
        })
        .toList(growable: false);

    await _database.batch((batch) {
      for (final event in affected) {
        final normalized = event.normalizeAllDayBounds();
        batch.update(
          _database.eventRecords,
          EventRecordsCompanion(
            category: Value(_storedCategoryValue(normalized)),
            colorValue: Value(normalized.colorValue),
            updatedAt: Value(normalized.updatedAt),
            syncTimestampDetails: Value(encodeSyncTimestamps(normalized)),
            syncStatus: const Value('pending'),
          ),
          where: (table) => table.id.equals(normalized.id),
        );
      }
    });
    return affected;
  }

  @override
  Future<void> markSynced(String eventId) {
    return (_database.update(_database.eventRecords)
          ..where((table) => table.id.equals(eventId)))
        .write(const EventRecordsCompanion(syncStatus: Value('synced')));
  }

  @override
  Future<void> delete(String eventId) => _database.transaction(() async {
    final event = await findById(eventId);
    if (event != null) {
      await save(
        event.copyWith(
          deletedAt: DateTime.now().toUtc(),
          syncStatus: 'pending_delete',
        ),
      );
    }
  });

  @override
  Future<void> hardDelete(String eventId) {
    return (_database.delete(
      _database.eventRecords,
    )..where((table) => table.id.equals(eventId))).go();
  }

  @override
  Future<void> clearAll() {
    return _database.transaction(() async {
      await _database.customStatement('DELETE FROM sync_event_deletions');
      await _database.delete(_database.eventRecords).go();
    });
  }

  @override
  Future<List<EventDeletion>> deletionRecords({
    bool pendingOnly = false,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT id, deleted_at, pending, lms_owner_id FROM sync_event_deletions'
          '${pendingOnly ? ' WHERE pending = 1' : ''}',
        )
        .get();
    return rows
        .map(
          (row) => EventDeletion(
            id: row.read<String>('id'),
            deletedAt: DateTime.parse(row.read<String>('deleted_at')).toUtc(),
            pending: row.read<int>('pending') != 0,
            lmsOwnerId: row.readNullable<String>('lms_owner_id'),
          ),
        )
        .toList();
  }

  @override
  Future<List<EventRestoreMutation>> mergeSyncRecords(
    List<CalendarEvent> events,
    List<EventDeletion> deletions, {
    required RestoredEventResolver resolve,
  }) => _database.transaction(() async {
    await mergeDeletionRecords(deletions);
    final markers = {
      for (final record in await deletionRecords()) record.id: record,
    };
    for (final deletion in deletions) {
      final local = await findById(deletion.id);
      if (local != null &&
          local.lms?.ownerId == deletion.lmsOwnerId &&
          eventChangedAt(local).isAfter(deletion.deletedAt)) {
        await save(local.copyWith(syncStatus: 'pending'));
      }
      if (markers[deletion.id]?.deletedAt.isAfter(deletion.deletedAt) ??
          false) {
        await _queueDeletionRepair(deletion.id);
      }
    }
    for (final event in events) {
      final marker = markers[event.id];
      if (marker != null &&
          marker.lmsOwnerId == event.lms?.ownerId &&
          !eventChangedAt(event).isAfter(marker.deletedAt)) {
        await _queueDeletionRepair(event.id);
      }
    }
    return mergeRestoredEventsAtomically(
      events.where((event) {
        final marker = markers[event.id];
        return marker == null ||
            marker.lmsOwnerId != event.lms?.ownerId ||
            eventChangedAt(event).isAfter(marker.deletedAt);
      }),
      resolve: resolve,
    );
  });

  Future<void> _queueDeletionRepair(String id) => _database.customStatement(
    'UPDATE sync_event_deletions SET pending = 1 WHERE id = ?',
    [id],
  );

  @override
  Future<void> mergeDeletionRecords(
    Iterable<EventDeletion> records,
  ) => _database.transaction(() async {
    for (final deletion in records) {
      final current = await findById(deletion.id);
      final old = await _database
          .customSelect(
            'SELECT deleted_at, lms_owner_id FROM sync_event_deletions WHERE id = ?',
            variables: [Variable.withString(deletion.id)],
          )
          .getSingleOrNull();
      final oldOwner = old?.readNullable<String>('lms_owner_id');
      final knownOwner = current?.lms?.ownerId ?? oldOwner;
      // Older clients can lose extension fields. Keep the known owner rather
      // than turning a scoped deletion into an account-independent marker.
      final owner = deletion.lmsOwnerId == null
          ? knownOwner
          : normalizeLmsOwner(deletion.lmsOwnerId!);
      if (knownOwner != null && owner != knownOwner) continue;
      if (current != null && current.lms == null && owner != null) continue;
      if (deletion.id.startsWith('lms:') && owner == null) continue;
      final oldDate = old == null
          ? null
          : DateTime.parse(old.read<String>('deleted_at'));
      if (oldDate == null ||
          oldDate.isBefore(deletion.deletedAt) ||
          oldDate.isAtSameMomentAs(deletion.deletedAt) && oldOwner != owner) {
        await _database.customStatement(
          'INSERT OR REPLACE INTO sync_event_deletions (id, deleted_at, pending, lms_owner_id) VALUES (?, ?, ?, ?)',
          [
            deletion.id,
            deletion.deletedAt.toUtc().toIso8601String(),
            deletion.pending ? 1 : 0,
            owner,
          ],
        );
      } else if (deletion.pending &&
          oldDate.isAtSameMomentAs(deletion.deletedAt)) {
        await _queueDeletionRepair(deletion.id);
      }
      final effectiveDate =
          oldDate != null && oldDate.isAfter(deletion.deletedAt)
          ? oldDate
          : deletion.deletedAt;
      if (current != null && !eventChangedAt(current).isAfter(effectiveDate)) {
        await hardDelete(current.id);
      }
    }
  });

  @override
  Future<void> compactDeletedEvents(DateTime now) =>
      _database.transaction(() async {
        final rows = await (_database.select(
          _database.eventRecords,
        )..where((table) => table.deletedAt.isNotNull())).get();
        for (final row in rows) {
          final event = row.toDomain();
          if (!canCompactDeletedEvent(event, now)) continue;
          await mergeDeletionRecords([
            EventDeletion(
              id: event.id,
              deletedAt: eventChangedAt(event),
              lmsOwnerId: event.lms?.ownerId,
            ),
          ]);
        }
      });

  @override
  Future<void> markDeletionSynced(
    EventDeletion deletion,
  ) => _database.customStatement(
    'UPDATE sync_event_deletions SET pending = 0 WHERE id = ? AND deleted_at = ? AND lms_owner_id IS ?',
    [
      deletion.id,
      deletion.deletedAt.toUtc().toIso8601String(),
      deletion.lmsOwnerId == null
          ? null
          : normalizeLmsOwner(deletion.lmsOwnerId!),
    ],
  );

  String _storedCategoryValue(CalendarEvent event) {
    if (event.category.id == 'basic' || event.category.id == 'holiday') {
      return event.category.id;
    }
    return event.category.label;
  }

  EventRecordsCompanion _companion(CalendarEvent event) {
    return EventRecordsCompanion(
      id: Value(event.id),
      title: Value(event.title),
      memo: Value(event.memo),
      location: Value(event.location),
      url: Value(event.url),
      weather: Value(event.weather),
      lmsMetadata: Value(
        event.lms == null ? null : jsonEncode(event.lms!.toJson()),
      ),
      startAt: Value(event.startAt),
      endAt: Value(event.endAt),
      allDay: Value(event.allDay),
      category: Value(_storedCategoryValue(event)),
      colorValue: Value(event.colorValue),
      reminderMinutesBefore: Value(event.reminderMinutesBefore),
      reminderMinutesBeforeList: Value(
        jsonEncode(event.reminderMinutesBeforeList),
      ),
      recurrenceFrequency: Value(event.recurrence.frequency.name),
      recurrenceInterval: Value(event.recurrence.interval),
      recurrenceUntil: Value(event.recurrence.until),
      recurrenceCount: Value(event.recurrence.count),
      recurrenceExcludedDates: Value(
        jsonEncode(
          event.recurrence.excludedDates
              .map((date) => DateTime(date.year, date.month, date.day))
              .map((date) => date.toIso8601String())
              .toList(),
        ),
      ),
      createdAt: Value(event.createdAt),
      updatedAt: Value(event.updatedAt),
      deletedAt: Value(event.deletedAt),
      syncTimestampDetails: Value(encodeSyncTimestamps(event)),
      deviceId: Value(event.deviceId),
      syncStatus: Value(event.syncStatus),
      showDday: Value(event.showDday),
      completed: Value(event.completed),
      alarmEnabled: Value(event.alarmEnabled),
      allDayAlarmMinutes: Value(event.allDayAlarmMinutes),
    );
  }
}
