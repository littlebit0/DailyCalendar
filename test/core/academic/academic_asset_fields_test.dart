import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('university regions use the short province spelling (#975)', () {
    final rows =
        (jsonDecode(
                  File('assets/academic/universities.json').readAsStringSync(),
                )
                as Map)['universities']
            as List;
    // Short forms such as 서울·경기 are the convention; full administrative
    // names split one province into two subtitles.
    final fullName = RegExp(
      r'(특별시|광역시|특별자치시|특별자치도|통합특별시)$|^(경기|강원|충청[남북]|전라[남북]|경상[남북]|제주)도$',
    );
    final offenders = [
      for (final row in rows)
        if (row['region'] is String && fullName.hasMatch(row['region']))
          '${row['id']}: ${row['region']}',
    ];
    expect(offenders, isEmpty);
  });

  test('logo source URLs have well-formed hosts (#975)', () {
    final text = File(
      'assets/academic/university_logo_sources.json',
    ).readAsStringSync();
    final hosts = RegExp(
      r'https?://([^/"]+)',
    ).allMatches(text).map((m) => m.group(1)!);
    expect(hosts, isNotEmpty);
    expect(hosts.where((h) => RegExp(r'^w{4,}\.').hasMatch(h)), isEmpty);
  });
}
