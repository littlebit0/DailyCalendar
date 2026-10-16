import 'package:drift/drift.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'merge reads only target rows, preserves duplicate order and rollback',
    () async {
      final counter = _MergeReads();
      final database = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final now = DateTime(2026, 10, 16);
      final local = List.generate(
        1201,
        (i) => _event(id: 'event-$i', startAt: now),
      );
      await repository.saveAllAtomically(local);
      counter.reset();
      final seen = <String>[];
      final mutations = await repository.mergeRestoredEventsAtomically(
        [local.first, local.first.copyWith(title: 'second')],
        resolve: (previous, incoming) {
          seen.add(previous!.title);
          return incoming.copyWith(
            title: incoming.title == 'second' ? 'second' : 'first',
          );
        },
      );
      expect(counter.rows, 1);
      expect(counter.queries, 1);
      expect(seen, ['event-0', 'first']);
      expect(mutations.length, 2);
      counter.reset();
      await repository.mergeRestoredEventsAtomically(
        local,
        resolve: (previous, incoming) => previous!,
      );
      expect(counter.rows, 1201);
      expect(counter.queries, 3);
      expect(counter.maxBindings, lessThanOrEqualTo(500));
      counter.reset();
      expect(
        await repository.mergeRestoredEventsAtomically(
          [],
          resolve: (_, incoming) => incoming,
        ),
        isEmpty,
      );
      expect(counter.queries, 0);
      await expectLater(
        repository.mergeRestoredEventsAtomically(
          [local.first.copyWith(title: 'must roll back'), local[1]],
          resolve: (_, incoming) {
            if (incoming.id == 'event-1') throw StateError('fixture');
            return incoming;
          },
        ),
        throwsStateError,
      );
      expect((await repository.findById('event-0'))!.title, 'second');
    },
  );

  test('range queries do not map unrelated one-time events', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final expander = _CountingRecurrenceExpander();
    final repository = DriftEventRepository(database, expander: expander);

    for (var index = 0; index < 120; index++) {
      await repository.save(
        _event(
          id: 'historical-$index',
          startAt: DateTime(2020, 1, 1).add(Duration(days: index)),
        ),
      );
    }
    await repository.save(
      _event(id: 'visible', startAt: DateTime(2026, 7, 15, 9)),
    );
    await repository.save(
      _event(
        id: 'recurring',
        startAt: DateTime(2020, 1, 6, 9),
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      ),
    );

    final rangeStart = DateTime(2026, 7, 1);
    final rangeEnd = DateTime(2026, 8, 1);
    final events = await repository.eventsInRange(rangeStart, rangeEnd);

    expect(expander.calls, 2);
    expect(events.any((event) => event.id == 'visible'), isTrue);
    expect(events.any((event) => event.id == 'recurring'), isTrue);

    expander.calls = 0;
    await repository.watchEventsInRange(rangeStart, rangeEnd).first;
    expect(expander.calls, 2);
  });
}

CalendarEvent _event({
  required String id,
  required DateTime startAt,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) {
  return CalendarEvent(
    id: id,
    title: id,
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: recurrence,
    createdAt: startAt,
    updatedAt: startAt,
  );
}

class _CountingRecurrenceExpander extends RecurrenceExpander {
  var calls = 0;

  @override
  List<CalendarEvent> expand(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    calls += 1;
    return super.expand(event, rangeStart, rangeEnd);
  }
}

class _MergeReads extends QueryInterceptor {
  int rows = 0, queries = 0, maxBindings = 0;
  void reset() {
    rows = 0;
    queries = 0;
    maxBindings = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (statement.contains('FROM "event_records"')) {
      queries++;
      rows += result.length;
      if (args.length > maxBindings) maxBindings = args.length;
    }
    return result;
  }
}
