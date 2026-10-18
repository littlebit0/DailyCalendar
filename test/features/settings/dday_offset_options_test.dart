import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored custom offsets are shown next to the presets, sorted once', () {
    expect(ddayOffsetOptions(const []), [-30, -14, -7, -3, -1, 0]);
    expect(ddayOffsetOptions(const [-2, -10, 5, -7]), [
      -30,
      -14,
      -10,
      -7,
      -3,
      -2,
      -1,
      0,
      5,
    ]);
  });

  test('switching off every shown offset leaves nothing hidden', () {
    final stored = {-7, -3, -2, -1, 0};
    // Each option is deselectable: removing all shown ones empties the set.
    for (final shown in ddayOffsetOptions(stored)) {
      stored.remove(shown);
    }
    expect(stored, isEmpty);
  });
}
