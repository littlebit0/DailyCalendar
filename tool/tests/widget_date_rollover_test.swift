import Foundation

@main
struct WidgetDateRolloverTest {
  static func main() throws {
    func view(_ date: String, _ title: String, _ events: [[String: Any]] = []) -> [String: Any] {
      ["date": date, "todayTitle": title, "weekTitle": "week \(date)", "todayEvents": events, "todayRemainingCount": 0]
    }
    let stored: [String: Any] = [
      "snapshotDate": "2026-10-31",
      "todayTitle": "Oct 31",
      "weekTitle": "week 2026-10-31",
      "todayEvents": [["id": "old"]],
      "todayRemainingCount": 0,
      "monthDays": [["date": "2026-10-31", "isToday": true], ["date": "2026-11-01", "isToday": false]],
      "dailyViews": [view("2026-10-31", "Oct 31", [["id": "old"]]), view("2026-11-01", "Nov 1", [["id": "new"]])],
      "ddays": [["targetDate": "2026-11-10", "daysRemaining": 10]],
    ]

    // Same date and legacy snapshots are returned untouched.
    precondition((DailyWidgetDateRollover.rollForward(stored, today: "2026-10-31")?["todayTitle"] as? String) == "Oct 31")
    var legacy = stored; legacy["snapshotDate"] = nil
    precondition((DailyWidgetDateRollover.rollForward(legacy, today: "2026-11-01")?["todayTitle"] as? String) == "Oct 31")

    // Next day (month boundary) uses the precomputed view.
    let rolled = DailyWidgetDateRollover.rollForward(stored, today: "2026-11-01")!
    precondition((rolled["todayTitle"] as? String) == "Nov 1")
    precondition((rolled["weekTitle"] as? String) == "week 2026-11-01")
    precondition(((rolled["todayEvents"] as? [[String: Any]])?.first?["id"] as? String) == "new")
    let days = rolled["monthDays"] as! [[String: Any]]
    precondition((days[0]["isToday"] as? Bool) == false && (days[1]["isToday"] as? Bool) == true)
    precondition(((rolled["ddays"] as! [[String: Any]])[0]["daysRemaining"] as? Int) == 9)

    // A date outside the cached grid cannot be shown as current.
    precondition(DailyWidgetDateRollover.rollForward(stored, today: "2026-12-25") == nil)

    // Day counts across month, year and leap boundaries.
    precondition(DailyWidgetDateRollover.daysBetween("2026-12-31", "2027-01-01") == 1)
    precondition(DailyWidgetDateRollover.daysBetween("2028-02-28", "2028-03-01") == 2)
    precondition(DailyWidgetDateRollover.daysBetween("2026-03-08", "2026-03-09") == 1)
    precondition(DailyWidgetDateRollover.daysBetween("2026-11-10", "2026-10-31") == -10)
    precondition(DailyWidgetDateRollover.daysBetween("bad", "2026-10-31") == nil)

    // dateKey follows the supplied calendar's day, not UTC.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let instant = ISO8601DateFormatter().date(from: "2026-10-31T16:30:00Z")! // 01:30 on 11/01 in Seoul
    precondition(DailyWidgetDateRollover.dateKey(instant, calendar: calendar) == "2026-11-01")
    print("widget date rollover ok")
  }
}
