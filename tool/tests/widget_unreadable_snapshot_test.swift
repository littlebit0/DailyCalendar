import Foundation

@main
struct WidgetUnreadableSnapshotTest {
  static func main() throws {
    let url = testDirectory.appendingPathComponent(snapshotFileName)
    let now = Date()
    let today = DailyWidgetDateRollover.dateKey(now)

    // 1. No snapshot file yet: refresh state, never "no events".
    assert(DailyWidgetSnapshot.load(for: now).needsRefresh == true)

    // 2. Not JSON.
    try Data("{broken".utf8).write(to: url)
    assert(DailyWidgetSnapshot.load(for: now).needsRefresh == true)

    // 3. JSON, but not a snapshot.
    try JSONSerialization.data(withJSONObject: ["generatedAt": "x"]).write(to: url)
    assert(DailyWidgetSnapshot.load(for: now).needsRefresh == true)

    func snapshot(date: String) -> [String: Any] {
      [
        "generatedAt": 1, "themeMode": "dark", "monthTitle": "M", "weekStartsOnMonday": true,
        "monthDays": [], "todayTitle": "T", "todayEvents": [], "todayRemainingCount": 0,
        "ddays": [], "snapshotDate": date,
      ]
    }

    // 4. A snapshot that cannot cover today keeps the stored theme and asks for a refresh.
    try JSONSerialization.data(withJSONObject: snapshot(date: "2000-01-01")).write(to: url)
    let stale = DailyWidgetSnapshot.load(for: now)
    assert(stale.needsRefresh == true)
    assert(stale.themeMode == "dark")
    assert(stale.weekStartsOnMonday)
    // The header keeps the normal title; the body carries the refresh message.
    assert(stale.todayTitle == DailyWidgetSnapshot.empty.todayTitle)

    // 5. A readable snapshot for today is shown as is ("no events" is true here).
    try JSONSerialization.data(withJSONObject: snapshot(date: today)).write(to: url)
    let current = DailyWidgetSnapshot.load(for: now)
    assert(current.needsRefresh != true)
    assert(current.todayTitle == "T")

    // 6. An unreadable file (no permission) is a refresh state too.
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
    assert(DailyWidgetSnapshot.load(for: now).needsRefresh == true)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    print("widget unreadable snapshot checks passed")
  }
}
