import 'dart:async';
import 'dart:io';

import 'package:daily/features/events/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late Database other;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily-busy-timeout');
    final file = File(p.join(directory.path, 'daily.sqlite'));
    database = AppDatabase.forTesting(openAppDatabaseFile(file));
    // 첫 쿼리로 파일과 스키마를 만든다.
    await database.customSelect('SELECT 1').get();
    other = sqlite3.open(file.path);
  });

  tearDown(() async {
    other.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('앱 DB 연결에 busy_timeout 5000ms가 설정된다', () async {
    final row = await database.customSelect('PRAGMA busy_timeout').getSingle();
    expect(row.data.values.single, 5000);
  });

  test('다른 연결이 BEGIN IMMEDIATE를 잡은 동안 앱 쓰기가 기다린 뒤 성공한다', () async {
    other.execute('BEGIN IMMEDIATE');
    other.execute("UPDATE event_records SET title = 'siri' WHERE 0");
    final stopwatch = Stopwatch()..start();
    Timer(const Duration(milliseconds: 400), () => other.execute('COMMIT'));

    await database.customStatement(
      "UPDATE event_records SET title = 'app' WHERE 0",
    );

    // 대기 없이 실패(SQLITE_BUSY)하지 않고, 상대 커밋 뒤에 끝난다.
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
  });
}
