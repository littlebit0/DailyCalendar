import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conditions are grouped in order within the length budget', () {
    final conditions = [for (var i = 0; i < 50; i++) "name = 'file-$i'"];
    final groups = splitDriveNameConditions(conditions, maxLength: 100);
    expect(groups.length, greaterThan(1));
    expect(groups.expand((group) => group).toList(), conditions);
    for (final group in groups) {
      expect(group.join(' or ').length, lessThanOrEqualTo(100));
    }
  });

  test('one over-long condition forms its own group and nothing is dropped', () {
    final long = "name = '${'a' * 200}'";
    final groups = splitDriveNameConditions([
      "name = 'a'",
      long,
      "name = 'b'",
    ], maxLength: 100);
    expect(groups, [
      ["name = 'a'"],
      [long],
      ["name = 'b'"],
    ]);
  });

  test('empty input yields no groups', () {
    expect(splitDriveNameConditions(const []), isEmpty);
  });
}
