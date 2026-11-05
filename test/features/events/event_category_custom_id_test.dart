import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy hashed ids stay unchanged without a collision', () {
    final a = EventCategory.custom(label: 'a~', colorValue: 1);
    final b = EventCategory.custom(label: 'b_', colorValue: 1);
    expect(a.id, 'custom_19470');
    expect(b.id, 'custom_19470');
    expect(EventCategory.fromJson({'label': 'a~'}).id, 'custom_19470');
    expect(EventCategory.fromName('a~').id, 'custom_19470');
  });

  test('a different name with the same hash gets its own id', () {
    final a = EventCategory.custom(label: 'a~', colorValue: 1);
    final b = EventCategory.custom(
      label: 'b_',
      colorValue: 2,
      existing: [EventCategory.basic, EventCategory.holiday, a],
    );
    expect(b.id, 'custom_19470_2');
    expect(b.id, isNot(a.id));

    final c = EventCategory.custom(label: 'c?', colorValue: 3);
    final third = EventCategory.custom(
      label: c.label,
      colorValue: 3,
      existing: [
        EventCategory(id: c.id, label: 'x', colorValue: 1),
        EventCategory(id: '${c.id}_2', label: 'y', colorValue: 1),
      ],
    );
    expect(third.id, '${c.id}_3');
  });

  test('the same name still reuses the existing id', () {
    final a = EventCategory.custom(label: 'a~', colorValue: 1);
    final b = EventCategory.custom(label: 'b_', colorValue: 2, existing: [a]);
    expect(
      EventCategory.custom(label: ' A~ ', colorValue: 9, existing: [a, b]).id,
      a.id,
    );
    expect(
      EventCategory.custom(label: 'B_', colorValue: 9, existing: [a, b]).id,
      b.id,
    );
  });

  test('suffixed ids survive a json round trip', () {
    final b = EventCategory.custom(
      label: 'b_',
      colorValue: 2,
      existing: [EventCategory.custom(label: 'a~', colorValue: 1)],
    );
    final restored = EventCategory.fromJson(b.toJson());
    expect(restored.id, b.id);
    expect(restored.label, 'b_');
  });
}
