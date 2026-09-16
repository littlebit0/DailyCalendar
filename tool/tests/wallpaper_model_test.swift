import Foundation

@main
struct WallpaperModelTests {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      precondition(condition(), message)
      checks += 1
    }
    let utc = TimeZone(secondsFromGMT: 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
      calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    func event(_ id: String, _ start: Date, _ end: Date) -> DailyWallpaperEvent {
      DailyWallpaperEvent(id: id, title: id, start: start, end: end,
                          color: 0xFF3366CC, completed: false, holiday: false)
    }
    let month = DailyWallpaperMonth(now: date(2026, 9, 12), mondayFirst: false, timeZone: utc)
    check(month.start == date(2026, 9, 1), "Month begins at midnight")
    check(month.end == date(2026, 10, 1), "Month ends exclusively")
    check(month.gridStart == date(2026, 8, 30), "Sunday grid offset")
    check(month.rows == 5 && month.days.count == 35, "Five-week month")
    let monday = DailyWallpaperMonth(now: date(2026, 9, 12), mondayFirst: true, timeZone: utc)
    check(monday.gridStart == date(2026, 8, 31), "Monday grid offset")
    let six = DailyWallpaperMonth(now: date(2026, 8, 12), mondayFirst: false, timeZone: utc)
    check(six.rows == 6 && six.days.count == 42, "Six-week month")
    let leap = DailyWallpaperMonth(now: date(2028, 2, 29, hour: 12), mondayFirst: true, timeZone: utc)
    check(leap.today == date(2028, 2, 29), "Leap day normalized")
    check(leap.end == date(2028, 3, 1), "Leap month boundary")
    let year = DailyWallpaperMonth(now: date(2026, 12, 31), mondayFirst: false, timeZone: utc)
    check(year.end == date(2027, 1, 1), "Year rollover")

    let spanning = event("trip", date(2026, 8, 28), date(2026, 9, 10))
    let segments = month.segments(events: [spanning], row: 0)
    check(segments.count == 1, "Multi-day event stays one bar per row")
    check(segments[0].startColumn == 2 && segments[0].endColumn == 6, "Hidden adjacent days excluded")
    let following = month.segments(events: [spanning], row: 1)
    check(following[0].startColumn == 0 && following[0].endColumn == 3, "Exclusive end stops before midnight")
    check(month.segments(events: [spanning], row: 2).isEmpty, "No phantom continuation")
    check(month.segments(events: [spanning], row: -1).isEmpty, "Invalid row safe")
    let timed = event("meeting", date(2026, 9, 1, hour: 9), date(2026, 9, 1, hour: 10))
    let timedBar = month.segments(events: [timed], row: 0)[0]
    check(timedBar.startColumn == 2 && timedBar.endColumn == 2, "Timed event occupies its actual date")
    let old = event("old", date(2026, 8, 29), date(2026, 9, 1))
    check(month.segments(events: [old], row: 0).isEmpty, "Event ending at month start excluded")
    let next = event("next", date(2026, 10, 1), date(2026, 10, 2))
    check(month.segments(events: [next], row: 4).isEmpty, "Next month excluded")
    let dense = (0..<100).map { event("event-\($0)", date(2026, 9, 1), date(2026, 9, 3)) }
    let packed = month.segments(events: dense, row: 0)
    check(Set(packed.map(\.lane)).count == 100, "No overlapping dense event lanes")
    let separate = [timed, event("later", date(2026, 9, 3), date(2026, 9, 4))]
    check(month.segments(events: separate, row: 0).allSatisfy { $0.lane == 0 }, "Reuse nonoverlapping lanes")

    let zone = TimeZone(identifier: "America/New_York")!
    var local = calendar
    local.timeZone = zone
    let spring = local.date(from: DateComponents(year: 2026, month: 3, day: 8))!
    let dst = DailyWallpaperMonth(now: spring, mondayFirst: false, timeZone: zone)
    for pair in zip(dst.days, dst.days.dropFirst()) {
      check(local.dateComponents([.day], from: pair.0, to: pair.1).day == 1, "No missing or duplicated DST days")
    }
    for width in [750.0, 1170.0, 1206.0, 1290.0, 1320.0] {
      for position in [0.34, 0.4, 0.52] {
       for aspect in [1334.0 / 750.0, 2.16] {
        let height = width * aspect
        let rect = DailyWallpaperGeometry.contentRect(width: width, height: height, topFraction: position)
        check(rect.minY >= height * 0.34 && rect.maxY <= height * 0.85 + 0.001, "Reserved clock and bottom areas")
        check(rect.minX > 0 && rect.maxX < width && rect.height > 0, "Bounded wallpaper layout")
        let scale = width / 390
        let rowHeight = (rect.height - 58 * scale) / 6
        let row = DailyWallpaperGeometry.rowLayout(height: rowHeight, scale: scale)
        check(row.slots >= 1, "Even small iPhones have an event or overflow row")
        for required in [0, 1, 5, 100] {
          let visible = row.visibleLanes(required: required)
          let used = visible + (required > visible ? 1 : 0)
          check(row.eventTop + Double(used) * row.eventHeight <= rowHeight,
                "Dense event and overflow labels stay inside their week")
        }
       }
      }
    }
    var settings = DailyWallpaperSettings()
    check(!settings.enabled, "Opt in only")
    settings.appearance = "invalid"
    settings.topFraction = .infinity
    settings.normalize()
    check(settings.appearance == "dark" && settings.topFraction == 0.4, "Invalid configuration normalized")
    settings.topFraction = -20; settings.normalize()
    check(settings.topFraction == 0.34, "Position lower clamp")
    settings.topFraction = 20; settings.normalize()
    check(settings.topFraction == 0.52, "Position upper clamp")
    let decoded = try JSONDecoder().decode(DailyWallpaperSettings.self, from: JSONEncoder().encode(settings))
    check(decoded == settings, "Settings round trip")
    let now = date(2026, 9, 15, hour: 12)
    var setup = DailyWallpaperSetupProgress()
    check(setup.stage == 0, "Fresh setup starts with a photo, not automation")
    setup.confirmShortcut(); setup.confirmVisible(now: now); setup.confirmAutomation()
    check(setup.stage == 0 && !setup.automationReady, "Cannot skip photo or shortcut prerequisites")
    setup.confirmPhoto()
    check(setup.stage == 1, "Photo confirmation advances to shortcut")
    setup.confirmVisible(now: now)
    check(setup.visibleConfirmedAt == nil, "Photo saved does not verify shortcut application")
    setup.confirmShortcut()
    check(setup.stage == 2, "Shortcut confirmation requires explicit visible check next")
    setup.confirmAutomation()
    check(!setup.automationReady, "Automation is gated on actual visible confirmation")
    setup.confirmVisible(now: now)
    check(setup.stage == 3 && setup.visibleConfirmedAt == now, "User can confirm visible wallpaper")
    setup.confirmAutomation()
    check(setup.automationReady, "User can acknowledge automation after visible check")
    let restoredSetup = try JSONDecoder().decode(DailyWallpaperSetupProgress.self, from: JSONEncoder().encode(setup))
    check(restoredSetup == setup, "Setup confirmations survive restart")
    setup.replaceShortcut()
    check(setup.stage == 1 && setup.visibleConfirmedAt == nil && !setup.automationReady,
          "Replacing shortcut invalidates downstream checks, not the photo")
    setup.repeatFromPhoto()
    check(setup == DailyWallpaperSetupProgress(), "Setup reset does not leave false completion")
    var attempts = DailyWallpaperAttempts()
    let manual = attempts.begin(source: .app, now: now)
    let native = attempts.begin(source: .shortcut, now: now.addingTimeInterval(1))
    check(manual.id != native.id, "Every attempt has an independent token")
    check(attempts.latest?.id == native.id, "The action receipt wins over its earlier app launch")
    check(native.visibleOutcome(now: now.addingTimeInterval(120)) == .waiting, "Do not expire early")
    check(native.visibleOutcome(now: now.addingTimeInterval(121)) == .unconfirmed, "Timeout is unconfirmed, not failed")
    check(!attempts.finish(id: UUID(), outcome: .systemReported), "Unknown token cannot claim success")
    check(attempts.finish(id: native.id, outcome: .systemReported, now: now.addingTimeInterval(10)), "Real action records completion")
    check(attempts.finish(id: manual.id, outcome: .unconfirmed, now: now.addingTimeInterval(11)), "URL termination is not wallpaper success")
    check(attempts.latest?.outcome == .systemReported, "URL completion does not overwrite action receipt")
    check(!attempts.finish(id: native.id, outcome: .failed), "Ignore duplicate or replayed callbacks")
    let failed = attempts.begin(source: .shortcut, now: now.addingTimeInterval(2))
    check(attempts.finish(id: failed.id, outcome: .failed, now: now.addingTimeInterval(12)), "Record failure independently")
    let cancelled = attempts.begin(source: .app, now: now.addingTimeInterval(3))
    check(attempts.finish(id: cancelled.id, outcome: .cancelled, now: now.addingTimeInterval(13)), "Cancellation is distinct from failure")
    check(attempts.latest?.outcome == .cancelled, "Return errors are visible despite a later native start")
    let restored = try JSONDecoder().decode(DailyWallpaperAttempts.self, from: JSONEncoder().encode(attempts))
    check(restored.items == attempts.items, "Result survives process restart")
    for (path, outcome) in [("error", DailyWallpaperAttempt.Outcome.failed), ("cancel", .cancelled), ("success", .unconfirmed)] {
      let url = URL(string: "daily-wallpaper://result/\(path)?id=\(manual.id.uuidString)&errorMessage=ignored")!
      check(DailyWallpaperAttempts.callback(url)?.0 == manual.id, "Callback preserves token")
      check(DailyWallpaperAttempts.callback(url)?.1 == outcome, "Callback maps \(path) honestly")
    }
    for invalid in ["https://result/error", "daily-wallpaper://other/error", "daily-wallpaper://result/error?id=bad",
                    "daily-wallpaper://result/unknown?id=\(manual.id.uuidString)"] {
      check(DailyWallpaperAttempts.callback(URL(string: invalid)!) == nil, "Reject malformed callback")
    }
    check(attempts.prune(now: now.addingTimeInterval(86404)).count == 4, "Prune expired receipts and notification IDs")
    check(attempts.latest == nil, "No stale success after clearing history")
    check(!attempts.finish(id: native.id, outcome: .systemReported), "Late completion cannot recreate cleared status")
    for (key, values) in DailyWallpaperText.values {
      check(values.count == 4 && values.allSatisfy { !$0.isEmpty }, "Four translations for \(key)")
    }
    check(DailyWallpaperText.languageIndex(setting: "english", preferredLanguage: "ko") == 1, "App language overrides system")
    check(DailyWallpaperText.languageIndex(setting: "system", preferredLanguage: "zh-Hant-TW") == 3, "System Traditional Chinese")
    check(DailyWallpaperText.languageIndex(setting: nil, preferredLanguage: "ja-JP") == 2, "System Japanese")
    for language in 0..<4 {
      let guide = DailyWallpaperText.automationInstructions(appName: "Daily Test", language: language)
      check(guide.contains("Daily Test"), "Guide names the installed app")
      check(!guide.contains("{app}"), "Guide resolves app-name placeholder")
      check(guide.contains("DailyCalendar Wallpaper"), "Guide preserves the automation shortcut name")
      check(guide.contains("Setup"), "Guide distinguishes the helper from the automation")
      check(guide.contains("\n\n"), "Guide separates readable steps")
      let labels = ["showConnectionGuide", "testSetup", "closeHelper"].map { DailyWallpaperText.values[$0]![language] }
      check(Set(labels).count == labels.count, "Menu choices stay distinct in every language")
    }
    print("Wallpaper model: \(checks) checks passed")
  }
}
