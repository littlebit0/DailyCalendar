import Foundation

@main
struct WidgetDateRolloverTest {
  static func main() throws {
    func event(_ id: String) -> [String: Any] { ["id": id] }
    func dday(_ id: String, _ remaining: Int) -> [String: Any] { ["id": id, "daysRemaining": remaining] }
    func view(_ date: String, _ title: String, events: [[String: Any]] = [], ddays: [[String: Any]] = []) -> [String: Any] {
      ["date": date, "todayTitle": title, "weekTitle": "week \(date)", "todayEvents": events,
       "todayRemainingCount": 0, "ddays": ddays]
    }
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    let utc = TimeZone(identifier: "UTC")!
    let built: Int64 = 1_793_000_000_000  // 2026-10-26T07:33:20Z
    let stored: [String: Any] = [
      "snapshotDate": "2026-10-31",
      "utcOffsetMinutes": 540,
      "utcOffsetAtMs": built,
      "todayTitle": "Oct 31",
      "weekTitle": "week 2026-10-31",
      "todayEvents": [event("old")],
      "todayRemainingCount": 0,
      "ddays": [dday("exam", 10)],
      "monthDays": [["date": "2026-10-31", "isToday": true], ["date": "2026-11-01", "isToday": false]],
      "dailyViews": [
        view("2026-10-31", "Oct 31", events: [event("old")], ddays: [dday("exam", 10)]),
        view("2026-11-01", "Nov 1", events: [event("new")], ddays: [dday("exam", 9), dday("fresh", 3)]),
      ],
    ]

    // Same date and legacy snapshots are returned untouched.
    precondition((DailyWidgetDateRollover.rollForward(stored, today: "2026-10-31", timeZone: seoul)?["todayTitle"] as? String) == "Oct 31")
    var legacy = stored; legacy["snapshotDate"] = nil
    precondition((DailyWidgetDateRollover.rollForward(legacy, today: "2026-11-01", timeZone: seoul)?["todayTitle"] as? String) == "Oct 31")

    // Next day (month boundary) uses the precomputed view, including its D-days.
    let rolled = DailyWidgetDateRollover.rollForward(stored, today: "2026-11-01", timeZone: seoul)!
    precondition((rolled["todayTitle"] as? String) == "Nov 1")
    precondition((rolled["weekTitle"] as? String) == "week 2026-11-01")
    precondition(((rolled["todayEvents"] as? [[String: Any]])?.first?["id"] as? String) == "new")
    let days = rolled["monthDays"] as! [[String: Any]]
    precondition((days[0]["isToday"] as? Bool) == false && (days[1]["isToday"] as? Bool) == true)
    let ddays = rolled["ddays"] as! [[String: Any]]
    precondition(ddays.count == 2 && (ddays[0]["daysRemaining"] as? Int) == 9 && (ddays[1]["id"] as? String) == "fresh")

    // A date outside the cached grid cannot be shown as current.
    precondition(DailyWidgetDateRollover.rollForward(stored, today: "2026-12-25", timeZone: seoul) == nil)

    // A time-zone change invalidates the buckets, even on the same date.
    precondition(DailyWidgetDateRollover.rollForward(stored, today: "2026-10-31", timeZone: utc) == nil)
    precondition(DailyWidgetDateRollover.rollForward(stored, today: "2026-11-01", timeZone: utc) == nil)
    // Same zone, daylight-saving rules included, is not a change.
    let newYork = TimeZone(identifier: "America/New_York")!
    var us = stored
    us["utcOffsetMinutes"] = newYork.secondsFromGMT(for: Date(timeIntervalSince1970: Double(built) / 1000)) / 60
    precondition(DailyWidgetDateRollover.rollForward(us, today: "2026-10-31", timeZone: newYork) != nil)

    // The key is Gregorian in the device zone, not tied to the preferred calendar.
    let instant = ISO8601DateFormatter().date(from: "2026-10-31T16:30:00Z")!  // 01:30 on 11/01 in Seoul
    precondition(DailyWidgetDateRollover.dateKey(instant, timeZone: seoul) == "2026-11-01")
    precondition(DailyWidgetDateRollover.dateKey(instant, timeZone: utc) == "2026-10-31")
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = seoul
    precondition(buddhist.component(.year, from: instant) != 2026)  // the trap this guards against
    print("widget date rollover ok")
  }
}
