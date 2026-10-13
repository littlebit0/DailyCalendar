import 'package:sqlite3/sqlite3.dart';

// Explicit historical table definitions, not a current database with its version
// number lowered. Version additions follow AppDatabase's recorded 1–9 upgrades.
void createHistoricalEventSchema(Database db, int version) {
  db.execute('''CREATE TABLE event_records (
    id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
    memo TEXT, location TEXT, start_at INTEGER NOT NULL, end_at INTEGER NOT NULL,
    all_day INTEGER NOT NULL DEFAULT 0 CHECK(all_day IN (0,1)),
    category TEXT NOT NULL DEFAULT 'basic', color_value INTEGER NOT NULL,
    reminder_minutes_before INTEGER,
    recurrence_frequency TEXT NOT NULL DEFAULT 'none',
    recurrence_interval INTEGER NOT NULL DEFAULT 1,
    recurrence_until INTEGER, recurrence_count INTEGER,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
    device_id TEXT NOT NULL DEFAULT '', sync_status TEXT NOT NULL DEFAULT 'pending'
    ${version < 6 ? ', sensitive INTEGER NOT NULL DEFAULT 0' : ''}
    ${version >= 2 ? ', show_dday INTEGER NOT NULL DEFAULT 0 CHECK(show_dday IN (0,1))' : ''}
    ${version >= 3 ? ", url TEXT, weather TEXT, recurrence_excluded_dates TEXT NOT NULL DEFAULT '[]'" : ''}
    ${version >= 4 ? ", reminder_minutes_before_list TEXT NOT NULL DEFAULT '[]'" : ''}
    ${version >= 5 ? ', alarm_enabled INTEGER NOT NULL DEFAULT 0 CHECK(alarm_enabled IN (0,1)), all_day_alarm_minutes INTEGER NOT NULL DEFAULT 540' : ''}
    ${version >= 7 ? ', completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1))' : ''}
    ${version >= 8 ? ', sync_timestamp_details TEXT' : ''}
    ${version >= 9 ? ', lms_metadata TEXT' : ''}
  )''');
  if (version >= 8) {
    db.execute('''CREATE TABLE sync_event_deletions (
      id TEXT NOT NULL PRIMARY KEY, deleted_at TEXT NOT NULL,
      pending INTEGER NOT NULL DEFAULT 1
      ${version >= 9 ? ', lms_owner_id TEXT' : ''}
    )''');
    db.execute(
      "INSERT INTO sync_event_deletions VALUES ('old-deletion', '2026-01-01T00:00:00Z', 1${version >= 9 ? ', NULL' : ''})",
    );
  }
  db.execute('''INSERT INTO event_records
    (id,title,memo,location,start_at,end_at,color_value,category,
     reminder_minutes_before,recurrence_frequency,recurrence_interval,
     created_at,updated_at,sync_status)
    VALUES ('kept','Stored','memo','room',1767225600,1767229200,
      4280640491,'personal',15,'weekly',2,1767139200,1767139200,'synced')''');
  if (version >= 4) {
    db.execute(
      "UPDATE event_records SET reminder_minutes_before_list='[15,30]'",
    );
  }
  if (version >= 5) {
    db.execute(
      'UPDATE event_records SET alarm_enabled=1,all_day_alarm_minutes=600',
    );
  }
  if (version >= 7) db.execute('UPDATE event_records SET completed=1');
  db.execute('PRAGMA user_version=$version');
}
