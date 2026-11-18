import Foundation

@main
struct WidgetTimelinePlanTest {
  static func main() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
      calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

    // Boundaries inside five minutes of a group's first one become one entry at the last.
    let merged = dailyWidgetTimelineDates(
      from: at(18, 9), until: at(19, 0),
      boundaries: [at(18, 8), at(18, 10), at(18, 10, 3), at(18, 10, 4), at(18, 10, 6), at(19, 0), at(19, 1)]
    )
    assert(merged == [at(18, 9), at(18, 10, 4), at(18, 10, 6)], "\(merged)")

    func event(_ id: String, _ start: Date, _ end: Date) -> [String: Any] {
      ["id": id, "eventId": id, "title": id, "timeLabel": "", "color": 0,
       "startAt": ms(start), "endAt": ms(end), "allDay": false]
    }
    func dday(_ remaining: Int) -> [String: Any] {
      ["id": "exam", "title": "exam", "dateLabel": "", "daysRemaining": remaining, "color": 0]
    }
    func view(_ date: String, _ title: String, _ events: [[String: Any]], _ remaining: Int) -> [String: Any] {
      ["date": date, "todayTitle": title, "weekTitle": "w", "todayEvents": events,
       "todayRemainingCount": 0, "ddays": [dday(remaining)]]
    }
    let morning = event("morning", at(18, 10), at(18, 11))
    let late = event("late", at(18, 23), at(19, 1))  // crosses midnight
    let next = event("next", at(19, 14), at(19, 15))
    let stored: [String: Any] = [
      "generatedAt": 1, "monthTitle": "M", "weekStartsOnMonday": false, "monthDays": [],
      "todayTitle": "Nov 18", "todayEvents": [morning, late], "todayRemainingCount": 0,
      "scheduleEvents": [morning, late, next], "ddays": [dday(2)],
      "snapshotDate": "2026-11-18",
      "dailyViews": [
        view("2026-11-18", "Nov 18", [morning, late], 2),
        view("2026-11-19", "Nov 19", [late, next], 1),
      ],
    ]
    try JSONSerialization.data(withJSONObject: stored)
      .write(to: testDirectory.appendingPathComponent(snapshotFileName))

    let now = at(18, 9)
    let plan = dailyWidgetTimelinePlan(now: now, calendar: calendar)
    let dates = plan.entries.map { $0.date }
    assert(dates == [
      now, at(18, 10), at(18, 11), at(18, 23),           // today's event boundaries
      at(19, 0), at(19, 1), at(19, 14), at(19, 15),      // next midnight and that day's boundaries
    ], "\(dates)")
    assert(plan.reload == at(19, 0))

    // An entry at an event's end no longer lists it as remaining.
    let afterMorning = plan.entries[2]
    assert(afterMorning.snapshot.remainingEvents(at: afterMorning.date).map { $0.id } == ["late"])

    // The midnight entry carries the next day's own values.
    let midnight = plan.entries[4]
    assert(midnight.snapshot.todayTitle == "Nov 19")
    assert(midnight.snapshot.todayEvents.map { $0.id } == ["late", "next"])
    assert(midnight.snapshot.ddays.map { $0.daysRemaining } == [1])
    assert(midnight.snapshot.needsRefresh != true)

    // A day outside the cached views is the refresh placeholder, not stale values.
    let lastCached = dailyWidgetTimelinePlan(now: at(19, 16), calendar: calendar)
    assert(lastCached.entries.first?.snapshot.todayTitle == "Nov 19")
    assert(lastCached.entries.last?.date == at(20, 0))
    assert(lastCached.entries.last?.snapshot.needsRefresh == true)
    print("widget timeline plan checks passed")
  }
}
