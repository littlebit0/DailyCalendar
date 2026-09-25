import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/theme/event_completion_style.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/search/presentation/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('search completion uses its actual $brightness card surface', (
      tester,
    ) async {
      final event = CalendarEvent(
        id: 'yellow',
        title: 'Yellow completed event',
        startAt: DateTime(2026, 9, 1),
        endAt: DateTime(2026, 9, 2),
        allDay: true,
        completed: true,
        category: EventCategory.basic,
        colorValue: 0xffffff00,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(_SearchRepository(event)),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const SearchPage(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Yellow');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final titleFinder = find.text(event.title);
      final title = tester.widget<Text>(titleFinder);
      final material = tester.widget<Material>(
        find.ancestor(of: titleFinder, matching: find.byType(Material)).first,
      );
      expect(
        calendarEventContrast(title.style!.color!, material.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        calendarEventContrast(
          title.style!.decorationColor!,
          title.style!.color!,
        ),
        greaterThanOrEqualTo(3),
      );
      expect(
        calendarEventContrast(title.style!.decorationColor!, material.color!),
        greaterThanOrEqualTo(3),
      );
      expect(event.colorValue, 0xffffff00);
      expect(
        title.style!.decorationColor,
        calendarEventStrikeColor(const Color(0xffffff00), material.color!),
      );
      expect(title.style!.decoration, TextDecoration.lineThrough);
      expect(tester.takeException(), isNull);
    });
  }
}

class _SearchRepository implements EventRepository {
  _SearchRepository(this.event);
  final CalendarEvent event;
  @override
  Future<List<CalendarEvent>> search(String query) async => [event];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
