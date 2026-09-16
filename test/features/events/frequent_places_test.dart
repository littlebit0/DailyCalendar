import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/frequent_places.dart';
import 'package:daily/features/events/presentation/frequent_places_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FrequentPlaces store;
  final now = DateTime(2026, 9, 16);
  CalendarEvent event(String id, String place, {bool deleted = false}) =>
      CalendarEvent(
        id: id,
        title: id,
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.values.first,
        colorValue: 0xff123456,
        createdAt: now,
        updatedAt: now,
        location: place,
        deletedAt: deleted ? now : null,
      );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FrequentPlaces(await SharedPreferences.getInstance());
  });
  test(
    'pins first, frequency next, normalize whitespace, exclude deletions',
    () async {
      await store.update(pinned: [' Home ', 'Home']);
      expect(
        store.recommend([
          event('1', 'Office'),
          event('2', ' Office '),
          event('3', 'Cafe'),
          event('4', 'Deleted', deleted: true),
        ]),
        ['Home', 'Office', 'Cafe'],
      );
    },
  );
  test(
    'disable automation retains pins; hidden recommendations stay hidden',
    () async {
      await store.update(pinned: ['Home'], hidden: ['Office']);
      expect(store.recommend([event('1', 'Office')]), ['Home']);
      await store.update(automatic: false);
      expect(store.recommend([event('2', 'Cafe')]), ['Home']);
      await store.clear();
      expect(store.pinned, isEmpty);
    },
  );
  test('duplicate recurring source does not multiply recommendation count', () {
    expect(
      store.recommend([
        event('1', 'Office'),
        event('1', 'Office'),
        event('2', 'Cafe'),
        event('3', 'Cafe'),
      ]).first,
      'Cafe',
    );
  });
  testWidgets('tap recommendation fills field without editing saved events', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final saved = event('1', 'Office');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FrequentPlacesField(
            store: store,
            loadEvents: () async => [saved],
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office'));
    expect(controller.text, 'Office');
    expect(saved.location, 'Office');
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
