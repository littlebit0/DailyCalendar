import 'dart:convert';
import 'dart:io';

import 'package:daily/features/events/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Siri는 앱과 다른 프로세스에서 같은 DB 파일에 쓴다. 다른 프로세스가
// BEGIN IMMEDIATE로 쓰기 잠금을 잡고 있다가 잠시 뒤 커밋한다.
const _holdWriteLock = '''
import sqlite3, sys, time
db = sqlite3.connect(sys.argv[1], isolation_level=None)
db.execute("BEGIN IMMEDIATE")
db.execute("UPDATE event_records SET title = 'siri' WHERE 0")
print("locked", flush=True)
time.sleep(0.4)
db.execute("COMMIT")
print("committed", flush=True)
''';

void main() {
  late Directory directory;
  late File file;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily-busy-timeout');
    file = File(p.join(directory.path, 'daily.sqlite'));
    database = AppDatabase.forTesting(openAppDatabaseFile(file));
    // 첫 쿼리로 파일과 스키마를 만든다.
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('앱 DB 연결에 busy_timeout 5000ms가 설정된다', () async {
    final row = await database.customSelect('PRAGMA busy_timeout').getSingle();
    expect(row.data.values.single, 5000);
  });

  test('다른 프로세스가 BEGIN IMMEDIATE를 잡은 동안 앱 쓰기가 기다린 뒤 성공한다', () async {
    final Process writer;
    try {
      writer = await Process.start('python3', ['-c', _holdWriteLock, file.path]);
    } on ProcessException {
      markTestSkipped('python3 is required to hold a lock from another process');
      return;
    }
    final lines = writer.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final committed = lines.firstWhere((line) => line == 'committed');
    await lines.firstWhere((line) => line == 'locked');

    // 대기 없이 실패(SQLITE_BUSY)하지 않고, 상대가 커밋한 뒤에 끝난다.
    await database.customStatement(
      "UPDATE event_records SET title = 'app' WHERE 0",
    );
    await committed;
    expect(await writer.exitCode, 0);
  });
}
