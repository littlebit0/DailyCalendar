import Foundation
import SQLite3
let dailySQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
let testURL = URL(fileURLWithPath: CommandLine.arguments[1])
struct DailySiriCategory { let id: String; let colorValue: Int64 }
enum DailySiriError: Error { case databaseUnavailable, eventNotFound, ambiguousEvent, invalidTime, lmsOriginalReadOnly, updateRequired }
enum DailySiriUpdateRequirement { static var isActive = false }
enum DailySiriText {
  static func recurrenceScope(title: String, start: Date, entireSeries: Bool) -> String { "scope" }
}
enum DailyKoreanHolidayService {
  static func events(from: Date, to: Date) -> [DailySiriEvent] { [] }
  static func search(_ text: String, from: Date, to: Date) -> [DailySiriEvent] { [] }
}
enum DailySiriSearchIndexer { static func scheduleRefresh() {} }
enum DailySiriEventChangeSignal {
  static var changes: [(String, String)] = []
  static func post(eventID: String, action: String, reminderMinutesBefore: [Int]) { changes.append((eventID, action)) }
}
func sql(_ text: String) throws {
  var db: OpaquePointer?
  assert(sqlite3_open(testURL.path, &db) == SQLITE_OK)
  defer { sqlite3_close(db) }
  guard sqlite3_exec(db, text, nil, nil, nil) == SQLITE_OK else {
    fatalError(String(cString: sqlite3_errmsg(db)))
  }
}
func verify(_ condition: @autoclosure () throws -> Bool) {
  do { let value = try condition(); assert(value) } catch { fatalError("unexpected error: \(error)") }
}
func rejected(_ operation: () throws -> Void) {
  do { try operation(); fatalError("mutation must fail") } catch {}
}
try sql("""
CREATE TABLE event_records (
 id TEXT PRIMARY KEY, title TEXT, memo TEXT, location TEXT, url TEXT, weather TEXT,
 lms_metadata TEXT, start_at INTEGER, end_at INTEGER, all_day INTEGER,
 category TEXT, color_value INTEGER, reminder_minutes_before INTEGER,
 reminder_minutes_before_list TEXT DEFAULT '[]', recurrence_frequency TEXT DEFAULT 'none',
 recurrence_interval INTEGER DEFAULT 1, recurrence_until INTEGER, recurrence_count INTEGER,
 recurrence_excluded_dates TEXT DEFAULT '[]', created_at INTEGER, updated_at INTEGER,
 deleted_at INTEGER, sync_timestamp_details TEXT, device_id TEXT, sync_status TEXT,
 show_dday INTEGER DEFAULT 0, completed INTEGER DEFAULT 0, alarm_enabled INTEGER DEFAULT 0,
 all_day_alarm_minutes INTEGER DEFAULT 540
);
""")
let start = Date(timeIntervalSince1970: 1792195200)
let base = try DailySiriDatabase.add(title: "same title", startAt: start, endAt: start.addingTimeInterval(3600),
  allDay: false, category: DailySiriCategory(id: "basic", colorValue: 1), location: "room", memo: "keep")
try sql("UPDATE event_records SET recurrence_frequency='daily', recurrence_count=5, completed=1 WHERE id='\(base.id)'")
let second = Calendar.current.date(byAdding: .day, value: 1, to: start)!
let third = Calendar.current.date(byAdding: .day, value: 2, to: start)!
let secondID = DailySiriOccurrenceIdentity.make(sourceID: base.id, start: second)
let thirdID = DailySiriOccurrenceIdentity.make(sourceID: base.id, start: third)
assert(secondID != thirdID)
verify(try DailySiriDatabase.events(withIDs: [secondID]).first!.startAt == second)
let allEdited = try DailySiriDatabase.update(id: secondID, newTitle: "same title", newStartAt: nil, newEndAt: nil, entireSeries: true)
assert(allEdited.startAt == start)
verify(try DailySiriDatabase.events(withIDs: [base.id]).first!.startAt == start)
let updated = try DailySiriDatabase.update(id: secondID, newTitle: "detached", newStartAt: second.addingTimeInterval(1800), newEndAt: nil)
assert(updated.id != base.id && updated.recurrenceFrequency == "none")
verify(try DailySiriDatabase.events(withIDs: [secondID]).isEmpty)
verify(try DailySiriDatabase.events(withIDs: [thirdID]).count == 1)
verify(try DailySiriDatabase.events(withIDs: [base.id]).first!.title == "same title")
verify(try DailySiriDatabase.events(withIDs: [updated.id]).first!.memo == "keep")
rejected { _ = try DailySiriDatabase.delete(id: secondID) }
let countBefore = DailySiriEventChangeSignal.changes.count
try sql("CREATE TRIGGER fail_clone BEFORE INSERT ON event_records BEGIN SELECT RAISE(ABORT, 'fail clone'); END")
rejected { _ = try DailySiriDatabase.update(id: thirdID, newTitle: "failed", newStartAt: nil, newEndAt: nil) }
verify(try DailySiriDatabase.events(withIDs: [thirdID]).count == 1)
assert(DailySiriEventChangeSignal.changes.count == countBefore)
try sql("DROP TRIGGER fail_clone")
_ = try DailySiriDatabase.delete(id: thirdID)
verify(try DailySiriDatabase.events(withIDs: [thirdID]).isEmpty)
verify(try DailySiriDatabase.events(withIDs: [base.id]).count == 1)
_ = try DailySiriDatabase.delete(id: base.id, entireSeries: true)
verify(try DailySiriDatabase.events(withIDs: [base.id]).isEmpty)
verify(try DailySiriDatabase.events(withIDs: [updated.id]).count == 1)
assert(DailySiriOccurrenceIdentity.parse("daily-occurrence:bad:not-a-number") == nil)
print("Siri occurrence mutation checks passed")

try sql("ALTER TABLE event_records ADD COLUMN recurrence_anchor_day INTEGER")
let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [[String: Any]]
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.dateFormat = "yyyy-MM-dd"
func fixtureDate(_ value: String) -> Date { Calendar.current.date(byAdding: .hour, value: 9, to: formatter.date(from: value)!)! }
for item in fixtures {
  let name = item["name"] as! String
  let date = fixtureDate(item["start"] as! String)
  let event = try DailySiriDatabase.add(title: name, startAt: date, endAt: date.addingTimeInterval(3600), allDay: false, category: DailySiriCategory(id: "basic", colorValue: 1), location: nil, memo: nil)
  let until = (item["until"] as? String).map { String(Int64(fixtureDate($0).timeIntervalSince1970)) } ?? "NULL"
  let anchor = (item["anchorDay"] as? Int).map(String.init) ?? "NULL"
  let exclusions = String(data: try JSONSerialization.data(withJSONObject: item["excluded"] as? [String] ?? []), encoding: .utf8)!
  try sql("UPDATE event_records SET recurrence_frequency='\(item["frequency"]!)', recurrence_interval=\(item["interval"]!), recurrence_count=\(item["count"]!), recurrence_until=\(until), recurrence_anchor_day=\(anchor), recurrence_excluded_dates='\(exclusions)' WHERE id='\(event.id)'")
  let from = Calendar.current.startOfDay(for: fixtureDate(item["rangeStart"] as? String ?? item["start"] as! String))
  let to = fixtureDate(item["rangeEnd"] as? String ?? "2030-01-01")
  let actual = try DailySiriDatabase.events(from: from, to: to).filter { DailySiriOccurrenceIdentity.parse($0.id)?.sourceID == event.id || $0.id == event.id }.map { formatter.string(from: $0.startAt) }
  assert(actual == item["expected"] as! [String], "fixture \(name): \(actual)")
  if name == "split" {
    _ = try DailySiriDatabase.update(id: event.id, newTitle: nil, newStartAt: fixtureDate("2025-02-27"), newEndAt: nil, entireSeries: true)
    verify(try DailySiriDatabase.events(withIDs: [event.id]).first!.recurrenceAnchorDay == nil)
  }
}
print("Shared recurrence anchor fixtures passed")

// #100: weekday / month-position conditions, from the same fixture the Dart tests use.
try sql("ALTER TABLE event_records ADD COLUMN recurrence_details TEXT")
let detailFixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))) as! [[String: Any]]
for item in detailFixtures {
  let name = item["name"] as! String
  let date = fixtureDate(item["start"] as! String)
  let event = try DailySiriDatabase.add(title: name, startAt: date, endAt: date.addingTimeInterval(3600), allDay: false, category: DailySiriCategory(id: "basic", colorValue: 1), location: nil, memo: nil)
  let until = (item["until"] as? String).map { String(Int64(fixtureDate($0).timeIntervalSince1970)) } ?? "NULL"
  let count = (item["count"] as? Int).map(String.init) ?? "NULL"
  var details: [String: Any] = [:]
  for key in ["byDay", "byMonthDay", "byMonth", "bySetPos"] where item[key] != nil { details[key] = item[key] }
  let detailsJSON = String(data: try JSONSerialization.data(withJSONObject: details), encoding: .utf8)!
  let exclusions = String(data: try JSONSerialization.data(withJSONObject: item["excluded"] as? [String] ?? []), encoding: .utf8)!
  try sql("UPDATE event_records SET recurrence_frequency='\(item["frequency"]!)', recurrence_interval=\(item["interval"]!), recurrence_count=\(count), recurrence_until=\(until), recurrence_details='\(detailsJSON)', recurrence_excluded_dates='\(exclusions)' WHERE id='\(event.id)'")
  let from = Calendar.current.startOfDay(for: fixtureDate(item["rangeStart"] as! String))
  let to = fixtureDate(item["rangeEnd"] as! String)
  let actual = try DailySiriDatabase.events(from: from, to: to)
    .filter { DailySiriOccurrenceIdentity.parse($0.id)?.sourceID == event.id || $0.id == event.id }
    .map { formatter.string(from: $0.startAt) }
  if actual != item["expected"] as! [String] { fatalError("detail fixture \(name): expected \(item["expected"]!), got \(actual)") }
}
print("Siri recurrence detail fixtures passed")

// #123: the until day is inclusive and a last occurrence may run past it.
func localDate(_ day: Int, _ hour: Int) -> Date {
  Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
}
func addUntilSeries(_ id: String, hours: Int) throws {
  let first = localDate(24, 9)
  try sql("""
  INSERT INTO event_records (id, title, start_at, end_at, all_day, category, color_value, recurrence_frequency,
    recurrence_interval, recurrence_until, created_at, updated_at)
  VALUES ('\(id)', '\(id)', \(Int64(first.timeIntervalSince1970)), \(Int64(first.addingTimeInterval(Double(hours) * 3600).timeIntervalSince1970)),
    0, 'basic', 1, 'daily', 1, \(Int64(localDate(26, 0).timeIntervalSince1970)), 0, 0)
  """)
}
func untilStarts(_ id: String, _ from: Date, _ to: Date) throws -> [Int] {
  try DailySiriDatabase.events(from: from, to: to)
    .filter { DailySiriOccurrenceIdentity.parse($0.id)?.sourceID == id || $0.id == id }
    .map { Calendar.current.component(.day, from: $0.startAt) }
}
func expectDays(_ id: String, _ from: Date, _ to: Date, _ expected: [Int]) throws {
  let actual = try untilStarts(id, from, to)
  if actual != expected { fatalError("\(id) \(from)...\(to): expected \(expected), got \(actual)") }
}
try addUntilSeries("until-short", hours: 1)
try expectDays("until-short", localDate(26, 8), localDate(26, 18), [26])
try expectDays("until-short", localDate(24, 0), localDate(30, 0), [24, 25, 26])
try expectDays("until-short", localDate(27, 8), localDate(27, 18), [])
try addUntilSeries("until-long", hours: 48)
// 48h occurrences: the 25th and the last one (26th, the until day) still run on the 27th.
try expectDays("until-long", localDate(27, 0), localDate(27, 12), [25, 26])
try expectDays("until-long", localDate(29, 0), localDate(29, 12), [])
print("Siri until-day inclusion checks passed")

// #127: a failed read is an error, never an empty or "column missing" result.
let probeStart = Date(timeIntervalSince1970: 1900000000)
let probe = try DailySiriDatabase.add(title: "read failure probe", startAt: probeStart, endAt: probeStart.addingTimeInterval(3600),
  allDay: false, category: DailySiriCategory(id: "basic", colorValue: 1), location: nil, memo: nil)
let probeFrom = probeStart.addingTimeInterval(-3600)
let probeTo = probeStart.addingTimeInterval(7200)
verify(try DailySiriDatabase.events(withIDs: [probe.id]).count == 1)
func blockedByUpdate(_ operation: () throws -> Void) {
  do {
    try operation()
    fatalError("a mutation ran during a required update")
  } catch DailySiriError.updateRequired {
  } catch {
    fatalError("unexpected error: \(error)")
  }
}
DailySiriUpdateRequirement.isActive = true
let changesBeforeBlock = DailySiriEventChangeSignal.changes.count
blockedByUpdate {
  _ = try DailySiriDatabase.add(title: "blocked", startAt: probeStart, endAt: probeStart.addingTimeInterval(3600),
    allDay: false, category: DailySiriCategory(id: "basic", colorValue: 1), location: nil, memo: nil)
}
blockedByUpdate { try DailySiriDatabase.requireEditable(id: probe.id) }
blockedByUpdate { _ = try DailySiriDatabase.update(id: probe.id, newTitle: "blocked", newStartAt: nil, newEndAt: nil) }
blockedByUpdate { _ = try DailySiriDatabase.delete(id: probe.id) }
verify(try DailySiriDatabase.events(withIDs: [probe.id]).first!.title == probe.title)
verify(try DailySiriDatabase.search("blocked").isEmpty)
assert(DailySiriEventChangeSignal.changes.count == changesBeforeBlock)
DailySiriUpdateRequirement.isActive = false
print("Siri update requirement checks passed")
var lockHolder: OpaquePointer?
assert(sqlite3_open(testURL.path, &lockHolder) == SQLITE_OK)
assert(sqlite3_exec(lockHolder, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK)
rejected { _ = try DailySiriDatabase.events(from: probeFrom, to: probeTo) }
rejected { _ = try DailySiriDatabase.events(withIDs: [probe.id]) }
sqlite3_exec(lockHolder, "ROLLBACK", nil, nil, nil)
sqlite3_close(lockHolder)
verify(try DailySiriDatabase.events(withIDs: [probe.id]).count == 1)
verify(try DailySiriDatabase.events(from: probeFrom, to: probeTo).contains { $0.id == probe.id })
// The schema page is intact, so preparing succeeds and only stepping reports the
// damaged table page: that must be an error, not "no events".
var rootPage: Int32 = 0
var pageSize: Int32 = 0
var inspector: OpaquePointer?
assert(sqlite3_open(testURL.path, &inspector) == SQLITE_OK)
var inspect: OpaquePointer?
sqlite3_prepare_v2(inspector, "SELECT (SELECT rootpage FROM sqlite_master WHERE name='event_records'), (SELECT page_size FROM pragma_page_size)", -1, &inspect, nil)
assert(sqlite3_step(inspect) == SQLITE_ROW)
rootPage = sqlite3_column_int(inspect, 0)
pageSize = sqlite3_column_int(inspect, 1)
sqlite3_finalize(inspect)
sqlite3_close(inspector)
let handle = try FileHandle(forUpdating: testURL)
try handle.seek(toOffset: UInt64(rootPage - 1) * UInt64(pageSize))
handle.write(Data(repeating: 0xFF, count: 8))
try handle.close()
rejected { _ = try DailySiriDatabase.events(from: probeFrom, to: probeTo) }
print("Siri read failure checks passed")
