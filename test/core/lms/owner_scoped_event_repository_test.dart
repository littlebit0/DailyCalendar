import 'dart:async';

import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/features/events/data/owner_scoped_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedRepository extends Fake implements EventRepository {
  final response = Completer<List<CalendarEvent>>();
  final changes = StreamController<List<CalendarEvent>>();
  @override
  Future<List<CalendarEvent>> search(String query) => response.future;
  @override
  Future<List<CalendarEvent>> allEventsForSync() => response.future;
  @override
  Future<CalendarEvent?> findById(String id) async =>
      (await response.future).where((event) => event.id == id).firstOrNull;
  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime start,
    DateTime end,
  ) => changes.stream;
}

void main() {
  test(
    'account changes while reads are pending filter search, widgets and completion lookup',
    () async {
      var owner = 'first@example.com';
      final data = _DelayedRepository();
      final scoped = OwnerScopedEventRepository(data, () => owner);
      final now = DateTime(2026, 9, 26);
      CalendarEvent event(String id, {String? account}) => CalendarEvent(
        id: id,
        title: id,
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
        lms: account == null
            ? null
            : LmsEventMetadata(
                schoolId: 'smu',
                ownerId: account,
                lmsUserId: '1',
                courseId: '2',
                courseTitle: '수업',
                activityType: 'assignment',
                activityId: '3',
                sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=3',
              ),
      );
      final rows = [
        event('personal'),
        event('first', account: owner),
        event('second', account: 'second@example.com'),
        event('lms:missing-owner'),
      ];
      final search = scoped.search('');
      final widgetRows = scoped.allEventsForSync();
      final completed = scoped.findById('first');
      owner = 'SECOND@example.com';
      data.response.complete(rows);
      expect((await search).map((event) => event.id), ['personal', 'second']);
      expect((await widgetRows).map((event) => event.id), [
        'personal',
        'second',
      ]);
      expect(await completed, isNull);

      final output = <List<String>>[];
      final subscription = scoped
          .watchEventsInRange(now, now.add(const Duration(days: 1)))
          .listen(
            (events) => output.add(events.map((event) => event.id).toList()),
          );
      data.changes.add(rows);
      await Future<void>.delayed(Duration.zero);
      owner = '';
      data.changes.add(rows);
      await Future<void>.delayed(Duration.zero);
      expect(output, [
        ['personal', 'second'],
        ['personal'],
      ]);
      await subscription.cancel();
      await data.changes.close();
    },
  );
}
