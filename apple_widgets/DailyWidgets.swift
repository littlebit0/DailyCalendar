import SwiftUI
import WidgetKit
import AppIntents
#if os(iOS)
import UIKit
import ActivityKit
import AlarmKit
#elseif os(macOS)
import AppKit
#endif

#if os(macOS)
private let appGroup = "A6Y73X2ZLS.com.littlebit0.daily.widgets"
#else
private let appGroup = "group.com.littlebit0.daily.widgets"
#endif
private let snapshotFileName = "daily-widget-snapshot.json"
private let todoActionsFileName = "daily-widget-todo-actions.json"
private let todoActionsChangedNotification = dailySharedStoreNotificationName(
  "com.littlebit0.daily.widgetTodoActionsChanged"
)

// BEGIN DAILY SHARED STORE NAMESPACE
// The App Store and test builds share one App Group. Each build passes its own
// DailySharedStoreNamespace (empty for the App Store build, which keeps the
// group root) so snapshots, queues, locks and notifications never cross (#388).
private let dailySharedStoreNamespace =
  (Bundle.main.object(forInfoDictionaryKey: "DailySharedStoreNamespace") as? String)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

private func dailySharedStoreDirectory(_ groupURL: URL?) -> URL? {
  guard let groupURL else { return nil }
  guard !dailySharedStoreNamespace.isEmpty else { return groupURL }
  let directory = groupURL.appendingPathComponent(dailySharedStoreNamespace, isDirectory: true)
  try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

private func dailySharedStoreNotificationName(_ base: String) -> String {
  dailySharedStoreNamespace.isEmpty ? base : "\(base).\(dailySharedStoreNamespace)"
}
// END DAILY SHARED STORE NAMESPACE
// BEGIN WIDGET TEXT
/// Fixed widget wording in the app's four languages (#921). The language is
/// the one the app wrote the snapshot in (`localeTag`), so it matches the
/// titles and time labels Flutter already localized; without a tag it is the
/// device language.
struct DailyWidgetText {
  enum Language { case korean, english, japanese, traditionalChinese }

  let language: Language

  init(localeTag: String?) {
    language = DailyWidgetText.resolve(localeTag ?? Locale.preferredLanguages.first)
  }

  static var system: DailyWidgetText { DailyWidgetText(localeTag: nil) }

  static func resolve(_ identifier: String?) -> Language {
    guard let identifier else { return .english }
    let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    if normalized.hasPrefix("ko") { return .korean }
    if normalized.hasPrefix("ja") { return .japanese }
    if normalized.hasPrefix("zh") { return .traditionalChinese }  // the app has no Simplified Chinese
    return .english
  }

  private func localized(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
    switch language {
    case .korean: return ko
    case .english: return en
    case .japanese: return ja
    case .traditionalChinese: return zh
    }
  }

  /// Sunday-first one-letter weekday names from the system's own calendar data.
  var weekdayNames: [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: localized("ko", "en", "ja", "zh-Hant"))
    return calendar.veryShortStandaloneWeekdaySymbols
  }

  var todayEvents: String { localized("오늘 일정", "Today's Events", "今日の予定", "今日行程") }
  var noEventsToday: String { localized("오늘 일정이 없습니다", "No events today", "今日の予定はありません", "今天沒有行程") }
  var noEventsTodayShort: String { localized("오늘 일정 없음", "No events today", "今日の予定なし", "今天沒有行程") }
  var noRemainingEvents: String { localized("남은 일정이 없습니다", "No more events today", "残りの予定はありません", "沒有剩餘行程") }
  var events: String { localized("일정", "events", "予定", "行程") }
  var allDay: String { localized("종일", "All-day", "終日", "全天") }
  var inProgress: String { localized("진행 중", "Now", "進行中", "進行中") }
  var thisWeek: String { localized("이번 주 일정", "This Week", "今週の予定", "本週行程") }
  var noEventsThisWeek: String { localized("이번 주 일정이 없습니다", "No events this week", "今週の予定はありません", "本週沒有行程") }
  var noDdays: String { localized("표시할 D-day가 없습니다", "No D-days to show", "表示するD-dayはありません", "沒有可顯示的 D-day") }
  var refresh: String { localized("앱을 열어 일정을 갱신하세요", "Open the app to refresh events", "アプリを開いて予定を更新してください", "請開啟 App 以更新行程") }
  /// Short form for the single-line Lock Screen widget.
  var refreshShort: String { localized("앱을 열어 갱신", "Open app to refresh", "アプリで更新", "開啟 App 更新") }
  var markDone: String { localized("완료로 변경", "Mark as done", "完了にする", "標示為完成") }
  var markNotDone: String { localized("미완료로 변경", "Mark as not done", "未完了にする", "標示為未完成") }
  func moreEvents(_ count: Int) -> String {
    localized("외 \(count)개 일정", "+\(count) more events", "他\(count)件の予定", "另有 \(count) 個行程")
  }
  func more(_ count: Int) -> String {
    localized("외 \(count)개", "+\(count) more", "他\(count)件", "另有 \(count) 個")
  }

  var todayWidgetDescription: String { localized(
    "오늘의 일정을 시간순으로 확인합니다.", "See today's events in time order.",
    "今日の予定を時間順に確認します。", "依時間順序查看今天的行程。"
  ) }
  var calendarWidgetName: String { localized("주간 및 월간 캘린더", "Week and Month Calendar", "週間・月間カレンダー", "週曆與月曆") }
  var calendarWidgetDescription: String { localized(
    "중형에서는 이번 주 일정을, 대형에서는 월간 일정을 확인합니다.",
    "Medium shows this week's events; large shows the month.",
    "中サイズは今週の予定、大サイズは月間の予定を表示します。", "中型顯示本週行程，大型顯示整月行程。"
  ) }
  var ddayWidgetDescription: String { localized(
    "가까운 D-day 일정을 확인합니다.", "See your upcoming D-days.",
    "近づいているD-dayを確認します。", "查看即將到來的 D-day。"
  ) }

  var eventAlarm: String { localized("일정 알람", "Event Alarm", "予定のアラーム", "行程鬧鐘") }
  func snoozeAfter(_ minutes: Int) -> String {
    localized("\(minutes)분 후 다시 알림", "Snooze for \(minutes) min", "\(minutes)分後に再通知", "\(minutes) 分鐘後再次提醒")
  }
  func minutes(_ minutes: Int) -> String {
    localized("\(minutes)분", "\(minutes) min", "\(minutes)分", "\(minutes) 分鐘")
  }
}
// END WIDGET TEXT

private enum DailyWidgetKind {
  static let today = "DailyTodayWidget"
  static let calendar = "DailyMonthWidget"
  static let dday = "DailyDdayWidget"
}

private func reloadDailyWidgetTimelines() {
  WidgetCenter.shared.reloadAllTimelines()
}

struct DailyWidgetEvent: Codable, Identifiable {
  let id: String
  let eventId: String?
  let title: String
  let timeLabel: String
  let color: Int
  let startAt: Int64?
  let endAt: Int64?
  let allDay: Bool?
  let completed: Bool?

  var startDate: Date? { startAt.map { Date(timeIntervalSince1970: Double($0) / 1000) } }
  var endDate: Date? { endAt.map { Date(timeIntervalSince1970: Double($0) / 1000) } }
}

struct DailyWidgetMonthEvent: Codable, Identifiable {
  let id: String
  let eventId: String?
  let title: String
  let color: Int
  let completed: Bool?
}

private enum DailyWidgetTodoActionStore {
  static func append(eventId: String, completed: Bool, occurrenceId: String? = nil) throws {
    guard let containerURL = dailySharedStoreDirectory(FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    )) else {
      throw NSError(
        domain: "DailyWidgets",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "위젯 공유 저장소를 열 수 없습니다."]
      )
    }
    let actionsURL = containerURL.appendingPathComponent(todoActionsFileName)
    try withTodoActionsLock(in: containerURL) {
      var actions: [[String: Any]] = []
      if FileManager.default.fileExists(atPath: actionsURL.path) {
        let existing = try Data(contentsOf: actionsURL)
        if let decoded = try? JSONSerialization.jsonObject(with: existing) as? [[String: Any]] {
          actions = decoded
        } else {
          // Never replace an unreadable queue with an empty one: keep it aside.
          let aside = containerURL.appendingPathComponent(
            "daily-widget-todo-actions.corrupt-\(Int(Date().timeIntervalSince1970)).json"
          )
          try? FileManager.default.removeItem(at: aside)
          try FileManager.default.moveItem(at: actionsURL, to: aside)
        }
      }
      actions.append([
        "token": UUID().uuidString,
        "eventId": eventId,
        "completed": completed,
        "occurrenceId": occurrenceId ?? "",
      ])
      let data = try JSONSerialization.data(withJSONObject: actions)
      try data.write(to: actionsURL, options: .atomic)
      // Still under the lock the app takes for its own snapshot write, so this
      // read-modify-write can never put back a snapshot the app replaced (#920).
      try updateSnapshot(
        at: containerURL.appendingPathComponent(snapshotFileName),
        eventId: eventId,
        completed: completed,
        occurrenceId: occurrenceId
      )
    }
    notifyApp()
  }

  /// Serializes read-modify-write of the shared action queue across the app and
  /// widget processes. An in-process queue cannot protect another process.
  private static func withTodoActionsLock<T>(
    in containerURL: URL,
    _ body: () throws -> T
  ) throws -> T {
    let lockPath = containerURL.appendingPathComponent("daily-widget-todo-actions.lock").path
    let descriptor = open(lockPath, O_CREAT | O_RDWR, 0o600)
    guard descriptor >= 0 else {
      throw NSError(
        domain: "DailyWidgets",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "위젯 작업 잠금을 열 수 없습니다."]
      )
    }
    defer { close(descriptor) }
    var attempts = 0
    while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
      attempts += 1
      guard errno == EWOULDBLOCK, attempts <= 300 else {
        throw NSError(
          domain: "DailyWidgets",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: "위젯 작업 잠금을 얻지 못했습니다."]
        )
      }
      usleep(10_000)
    }
    defer { flock(descriptor, LOCK_UN) }
    return try body()
  }

  private static func updateSnapshot(at url: URL, eventId: String, completed: Bool, occurrenceId: String?) throws {
    guard let data = try? Data(contentsOf: url),
          var snapshot = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }
    for key in ["todayEvents", "scheduleEvents", "ddays"] {
      guard var events = snapshot[key] as? [[String: Any]] else { continue }
      update(&events, eventId: eventId, completed: completed, occurrenceId: occurrenceId)
      snapshot[key] = events
    }
    if var days = snapshot["monthDays"] as? [[String: Any]] {
      for index in days.indices {
        guard var events = days[index]["events"] as? [[String: Any]] else { continue }
        update(&events, eventId: eventId, completed: completed, occurrenceId: occurrenceId)
        days[index]["events"] = events
      }
      snapshot["monthDays"] = days
    }
    if var views = snapshot["dailyViews"] as? [[String: Any]] {
      for index in views.indices {
        for key in ["todayEvents", "ddays"] {
          guard var events = views[index][key] as? [[String: Any]] else { continue }
          update(&events, eventId: eventId, completed: completed, occurrenceId: occurrenceId)
          views[index][key] = events
        }
      }
      snapshot["dailyViews"] = views
    }
    snapshot["generatedAt"] = Int64(Date().timeIntervalSince1970 * 1000)
    let updated = try JSONSerialization.data(withJSONObject: snapshot)
    try updated.write(to: url, options: .atomic)
  }

  private static func update(
    _ events: inout [[String: Any]],
    eventId: String,
    completed: Bool,
    occurrenceId: String?
  ) {
    let target = occurrenceId.flatMap { $0.isEmpty ? nil : $0 } ?? eventId
    for index in events.indices where
      (events[index]["id"] as? String ?? events[index]["eventId"] as? String) == target {
      events[index]["completed"] = completed
    }
  }

  private static func notifyApp() {
    #if os(macOS)
    DistributedNotificationCenter.default().postNotificationName(
      Notification.Name(todoActionsChangedNotification),
      object: nil,
      deliverImmediately: true
    )
    #else
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(todoActionsChangedNotification as CFString),
      nil,
      nil,
      true
    )
    #endif
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DailyToggleTodoIntent: AppIntent {
  static var title: LocalizedStringResource = "일정 완료 상태 변경"
  static var description = IntentDescription("Daily 일정의 완료 상태를 변경합니다.")
  static var openAppWhenRun = false

  @Parameter(title: "일정 ID") var eventId: String
  @Parameter(title: "완료") var targetCompleted: Bool
  @Parameter(title: "반복 회차 ID") var occurrenceId: String?

  init() {}

  init(eventId: String, targetCompleted: Bool, occurrenceId: String? = nil) {
    self.eventId = eventId
    self.targetCompleted = targetCompleted
    self.occurrenceId = occurrenceId
  }

  func perform() async throws -> some IntentResult {
    try DailyWidgetTodoActionStore.append(
      eventId: eventId,
      completed: targetCompleted,
      occurrenceId: occurrenceId
    )
    reloadDailyWidgetTimelines()
    return .result()
  }
}

struct DailyWidgetDay: Codable, Identifiable {
  let date: String
  let day: Int
  let inMonth: Bool
  let isToday: Bool
  let eventCount: Int
  let events: [DailyWidgetMonthEvent]?

  var id: String { date }
  var visibleEvents: [DailyWidgetMonthEvent] { events ?? [] }
}

private struct DailyWidgetEventSpan: Identifiable {
  let event: DailyWidgetMonthEvent
  let startIndex: Int
  let endIndex: Int

  var id: String { "\(event.id)-\(startIndex)-\(endIndex)" }
}

private func eventSpans(in days: [DailyWidgetDay]) -> [DailyWidgetEventSpan] {
  var orderedIDs: [String] = []
  var values: [String: (DailyWidgetMonthEvent, Int, Int)] = [:]
  for (dayIndex, day) in days.enumerated() {
    for event in day.visibleEvents {
      if let current = values[event.id] {
        values[event.id] = (current.0, current.1, dayIndex)
      } else {
        orderedIDs.append(event.id)
        values[event.id] = (event, dayIndex, dayIndex)
      }
    }
  }
  return orderedIDs.compactMap { id in
    guard let value = values[id], value.2 > value.1 else { return nil }
    return DailyWidgetEventSpan(
      event: value.0,
      startIndex: value.1,
      endIndex: value.2
    )
  }
}

private struct DailyMonthWeekRow: View {
  let days: [DailyWidgetDay]

  private let columnSpacing: CGFloat = 2
  private let eventRowHeight: CGFloat = 9
  private let maxEventRows = 2

  private var spans: [DailyWidgetEventSpan] { eventSpans(in: days) }
  private var spanningIDs: Set<String> { Set(spans.map { $0.event.id }) }

  var body: some View {
    GeometryReader { geometry in
      let columnWidth = (geometry.size.width - columnSpacing * 6) / 7
      let visibleSpans = Array(spans.prefix(maxEventRows))
      let singleRowCount = max(0, maxEventRows - visibleSpans.count)

      ZStack(alignment: .topLeading) {
        HStack(alignment: .top, spacing: columnSpacing) {
          ForEach(Array(days.enumerated()), id: \.element.id) { dayIndex, day in
            let singleEvents = day.visibleEvents.filter { !spanningIDs.contains($0.id) }
            let shownSingleCount = min(singleEvents.count, singleRowCount)
            let shownSpanCount = visibleSpans.filter {
              $0.startIndex <= dayIndex && dayIndex <= $0.endIndex
            }.count
            let hiddenCount = max(0, day.visibleEvents.count - shownSingleCount - shownSpanCount)
            VStack(alignment: .leading, spacing: 1) {
              HStack(spacing: 1) {
                Text("\(day.day)")
                  .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                  .foregroundStyle(day.inMonth ? Color.dailyText : Color.dailySecondary.opacity(0.45))
                  .frame(width: 16, height: 12)
                  .background(day.isToday ? Color.blue.opacity(0.18) : Color.clear)
                  .clipShape(Circle())
                Spacer(minLength: 0)
                if hiddenCount > 0 {
                  Text("+\(hiddenCount)")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(Color.dailySecondary)
                }
              }
              Spacer().frame(height: CGFloat(visibleSpans.count) * eventRowHeight)
              ForEach(Array(singleEvents.prefix(singleRowCount).enumerated()), id: \.element.id) { _, event in
                DailyWidgetEventLabel(event: event, height: eventRowHeight, fontSize: 8)
              }
            }
            .frame(width: columnWidth, alignment: .topLeading)
          }
        }

        ForEach(Array(visibleSpans.enumerated()), id: \.element.id) { lane, span in
          DailyWidgetEventLabel(event: span.event, height: eventRowHeight, fontSize: 8)
            .frame(
              width: columnWidth * CGFloat(span.endIndex - span.startIndex + 1)
                + columnSpacing * CGFloat(span.endIndex - span.startIndex),
              height: eventRowHeight
            )
            .offset(
              x: CGFloat(span.startIndex) * (columnWidth + columnSpacing),
              y: 13 + CGFloat(lane) * eventRowHeight
            )
        }
      }
    }
    .frame(height: 34)
  }
}

private struct DailyWidgetEventLabel: View {
  @Environment(\.colorScheme) private var colorScheme
  let event: DailyWidgetMonthEvent
  let height: CGFloat
  let fontSize: CGFloat

  var body: some View {
    let surface = colorScheme == .dark ? 0xff000000 : 0xffffffff
    let background = DailyEventPalette.blend(event.color, on: surface, alpha: 0.18)
    let colors = DailyEventPalette.resolve(category: event.color | 0xff000000, background: background)
    Text(event.title)
      .font(.system(size: fontSize, weight: .medium))
      .dailyTodoCompletion(
        event.completed == true,
        category: event.color, backgroundAlpha: 0.18, palette: colors
      )
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .privacySensitive()
      .padding(.horizontal, 2)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
      .background(Color.daily(argb: colors.background))
      .clipShape(RoundedRectangle(cornerRadius: 2.5))
  }
}

private struct DailyTodoToggle: View {
  let event: DailyWidgetEvent
  let text: DailyWidgetText

  @ViewBuilder
  var body: some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      Button(
        intent: DailyToggleTodoIntent(
          eventId: event.eventId ?? event.id,
          targetCompleted: event.completed != true,
          occurrenceId: event.id
        )
      ) {
        Image(systemName: event.completed == true ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(event.completed == true ? Color.blue : Color.dailySecondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(event.completed == true ? text.markNotDone : text.markDone)
    } else {
      Image(systemName: event.completed == true ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(event.completed == true ? Color.blue : Color.dailySecondary)
    }
  }
}

struct DailyWidgetDday: Codable, Identifiable {
  let id: String
  let title: String
  let dateLabel: String
  let daysRemaining: Int
  let color: Int
  let completed: Bool?

  var counter: String {
    if daysRemaining == 0 { return "D-day" }
    return daysRemaining > 0 ? "D-\(daysRemaining)" : "D+\(-daysRemaining)"
  }
}

// BEGIN WIDGET ROLLOVER
/// Re-derives the "today" values of a stored snapshot for the device date.
///
/// Flutter computes todayTitle/todayEvents/weekTitle/isToday and the D-days for
/// `snapshotDate` and, for every day of the cached month grid, a `dailyViews`
/// entry with the same values for that day. When the date has moved on this
/// switches to the matching entry, so no date arithmetic or ranking happens here.
/// It returns nil when the snapshot cannot represent the situation (the date is
/// outside the cached grid, or the time zone changed since the day buckets were
/// built), so a widget never shows stale values as current (#103).
enum DailyWidgetDateRollover {
  /// yyyy-MM-dd in the Gregorian calendar and `timeZone`, whatever calendar the
  /// user's region prefers (Buddhist, Islamic, ...).
  static func dateKey(_ date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  static func rollForward(
    _ stored: [String: Any],
    today: String,
    timeZone: TimeZone = .current
  ) -> [String: Any]? {
    guard let snapshotDate = stored["snapshotDate"] as? String, !snapshotDate.isEmpty else {
      return stored  // Written before this contract: no base date to compare.
    }
    // The day buckets were built with one UTC offset. A different offset at that
    // same instant means the time zone changed, so a timed event may belong to
    // another day than the one it was filed under.
    if let built = (stored["utcOffsetMinutes"] as? NSNumber)?.intValue,
       let builtAt = (stored["utcOffsetAtMs"] as? NSNumber)?.int64Value {
      let now = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(builtAt) / 1000)) / 60
      if built != now { return nil }
    }
    if snapshotDate == today { return stored }
    guard let views = stored["dailyViews"] as? [[String: Any]],
          let view = views.first(where: { ($0["date"] as? String) == today }) else { return nil }
    var rolled = stored
    rolled["todayTitle"] = view["todayTitle"]
    rolled["weekTitle"] = view["weekTitle"]
    rolled["todayEvents"] = view["todayEvents"] ?? []
    rolled["todayRemainingCount"] = view["todayRemainingCount"] ?? 0
    rolled["ddays"] = view["ddays"] ?? []
    rolled["snapshotDate"] = today
    if var days = stored["monthDays"] as? [[String: Any]] {
      for index in days.indices {
        days[index]["isToday"] = (days[index]["date"] as? String) == today
      }
      rolled["monthDays"] = days
    }
    return rolled
  }
}
// END WIDGET ROLLOVER

// BEGIN WIDGET WEEKDAY COLUMNS
/// The weekday shown in a header column, 0 = Sunday ... 6 = Saturday.
func dailyWeekdayOfColumn(_ column: Int, weekStartsOnMonday: Bool) -> Int {
  weekStartsOnMonday ? (column + 1) % 7 : column
}

func dailyWeekdayLabels(weekStartsOnMonday: Bool,
  names: [String] = ["일", "월", "화", "수", "목", "금", "토"]
) -> [String] {
  return (0..<7).map { names[dailyWeekdayOfColumn($0, weekStartsOnMonday: weekStartsOnMonday)] }
}
// END WIDGET WEEKDAY COLUMNS

/// Sunday red, Saturday blue, weekdays secondary, whatever the week start.
func dailyWeekdayColor(column: Int, weekStartsOnMonday: Bool) -> Color {
  switch dailyWeekdayOfColumn(column, weekStartsOnMonday: weekStartsOnMonday) {
  case 0: return .red
  case 6: return .blue
  default: return .dailySecondary
  }
}

struct DailyWidgetSnapshot: Codable {
  let generatedAt: Int64
  let themeMode: String?
  let monthTitle: String
  let weekTitle: String?
  let weekStartsOnMonday: Bool
  let monthDays: [DailyWidgetDay]
  let todayTitle: String
  let todayEvents: [DailyWidgetEvent]
  let todayRemainingCount: Int
  let scheduleEvents: [DailyWidgetEvent]?
  let ddays: [DailyWidgetDday]
  // Present on snapshots written by newer app versions; only used for rollover.
  var snapshotDate: String? = nil
  /// Set on the placeholder shown when the cached data cannot cover today.
  var needsRefresh: Bool? = nil
  /// The app language the snapshot was written in; absent on older snapshots.
  var localeTag: String? = nil

  var text: DailyWidgetText { DailyWidgetText(localeTag: localeTag) }

  func events(on date: Date) -> [DailyWidgetEvent] {
    guard let scheduleEvents else { return todayEvents }
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
    return scheduleEvents.filter { event in
      guard let start = event.startDate, let end = event.endDate else { return false }
      return start < dayEnd && end > dayStart
    }
  }

  func remainingEvents(at date: Date) -> [DailyWidgetEvent] {
    events(on: date).filter { event in
      event.allDay == true || event.endDate.map { $0 > date } ?? true
    }
  }

  /// Stored snapshot re-derived for `date`; a themed placeholder when it cannot cover that date.
  static func load(for date: Date = .now) -> DailyWidgetSnapshot {
    let stored = loadStored()
    // No readable snapshot (never written, unreadable or not JSON) is not "no
    // events today": the widget cannot know, so it asks for a refresh (#926).
    guard let raw = storedJSON() else { return stored.refreshPlaceholder }
    guard let rolled = DailyWidgetDateRollover.rollForward(raw, today: DailyWidgetDateRollover.dateKey(date)),
          let data = try? JSONSerialization.data(withJSONObject: rolled),
          let snapshot = try? JSONDecoder().decode(DailyWidgetSnapshot.self, from: data) else {
      return stored.refreshPlaceholder
    }
    return snapshot
  }

  private var refreshPlaceholder: DailyWidgetSnapshot {
    DailyWidgetSnapshot(
      generatedAt: 0,
      themeMode: themeMode,
      monthTitle: "Daily",
      weekTitle: nil,
      weekStartsOnMonday: weekStartsOnMonday,
      monthDays: [],
      todayTitle: text.todayEvents,
      todayEvents: [],
      todayRemainingCount: 0,
      scheduleEvents: [],
      ddays: [],
      needsRefresh: true,
      localeTag: localeTag
    )
  }

  private static func storedJSON() -> [String: Any]? {
    guard let containerURL = dailySharedStoreDirectory(FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          )),
          let data = try? Data(contentsOf: containerURL.appendingPathComponent(snapshotFileName)) else {
      return nil
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  private static func loadStored() -> DailyWidgetSnapshot {
    guard let containerURL = dailySharedStoreDirectory(FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          )),
          let data = try? Data(
            contentsOf: containerURL.appendingPathComponent(snapshotFileName),
            options: .mappedIfSafe
          ),
          let snapshot = try? JSONDecoder().decode(DailyWidgetSnapshot.self, from: data) else {
      return .empty
    }
    return snapshot
  }

  static let empty = DailyWidgetSnapshot(
    generatedAt: 0,
    themeMode: nil,
    monthTitle: "Daily",
    weekTitle: nil,
    weekStartsOnMonday: false,
    monthDays: [],
    todayTitle: DailyWidgetText.system.todayEvents,
    todayEvents: [],
    todayRemainingCount: 0,
    scheduleEvents: [],
    ddays: []
  )
}

struct DailyWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: DailyWidgetSnapshot
}

struct DailyWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> DailyWidgetEntry {
    DailyWidgetEntry(date: .now, snapshot: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (DailyWidgetEntry) -> Void) {
    completion(DailyWidgetEntry(date: .now, snapshot: DailyWidgetSnapshot.load(for: .now)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DailyWidgetEntry>) -> Void) {
    let plan = dailyWidgetTimelinePlan(now: .now)
    completion(Timeline(
      entries: plan.entries.map { DailyWidgetEntry(date: $0.date, snapshot: $0.snapshot) },
      policy: .after(plan.reload)
    ))
  }
}

// BEGIN WIDGET TIMELINE PLAN
/// Entry dates between `start` and `end`: `start` itself, then every later
/// event start/end before `end`. Boundaries closer than `minimumGap` to the
/// first one of their group become one entry at the group's last boundary, so
/// back-to-back events do not produce entries seconds apart.
func dailyWidgetTimelineDates(
  from start: Date,
  until end: Date,
  boundaries: [Date],
  minimumGap: TimeInterval = 5 * 60
) -> [Date] {
  var dates = [start]
  var groupStart: Date?
  for boundary in boundaries.filter({ $0 > start && $0 < end }).sorted() {
    if let first = groupStart, boundary.timeIntervalSince(first) < minimumGap {
      dates[dates.count - 1] = boundary
    } else {
      groupStart = boundary
      dates.append(boundary)
    }
  }
  return dates
}

/// The timeline is built ahead instead of relying on WidgetKit calling back at
/// midnight: it already holds the entry for each event boundary of today, the
/// next midnight (rolled to that day's cached values, or the refresh
/// placeholder when the cache cannot cover it) and the day after it (#919).
/// The reload is asked for once, at the next midnight.
func dailyWidgetTimelinePlan(
  now: Date,
  calendar: Calendar = .current
) -> (entries: [(date: Date, snapshot: DailyWidgetSnapshot)], reload: Date) {
  var entries: [(date: Date, snapshot: DailyWidgetSnapshot)] = []
  var start = now
  var reload = now
  // shortcut: two days ahead only, extend if widgets are seen stale after a missed reload.
  for day in 0..<2 {
    let snapshot = DailyWidgetSnapshot.load(for: start)
    // Calendar arithmetic keeps the entry on local midnight across DST changes.
    let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))
      ?? start.addingTimeInterval(24 * 60 * 60)
    let boundaries = snapshot.events(on: start).flatMap { [$0.startDate, $0.endDate].compactMap { $0 } }
    for date in dailyWidgetTimelineDates(from: start, until: midnight, boundaries: boundaries) {
      entries.append((date: date, snapshot: snapshot))
    }
    if day == 0 { reload = midnight }
    start = midnight
  }
  return (entries, reload)
}
// END WIDGET TIMELINE PLAN

private struct DailyWidgetHeader: View {
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .foregroundStyle(Color(red: 0.15, green: 0.38, blue: 0.91))
      Text(title)
        .font(.headline)
        .foregroundStyle(Color.dailyText)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}

struct DailyTodayWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyWidgetEntry

  var visibleCount: Int {
    switch family {
    case .systemSmall: return 3
    case .systemMedium: return 4
    default: return 7
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DailyWidgetHeader(title: entry.snapshot.todayTitle, systemImage: "calendar")
      if entry.snapshot.needsRefresh == true {
        Spacer()
        Text(entry.snapshot.text.refresh)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else if entry.snapshot.todayEvents.isEmpty {
        Spacer()
        Text(entry.snapshot.text.noEventsToday)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else {
        ForEach(entry.snapshot.todayEvents.prefix(visibleCount)) { event in
          HStack(spacing: 7) {
            DailyTodoToggle(event: event, text: entry.snapshot.text)
            Capsule()
              .fill(Color.daily(argb: event.color))
              .frame(width: 3, height: 20)
            Text(event.timeLabel)
              .font(.caption)
              .foregroundStyle(Color.dailySecondary)
              .frame(width: 38, alignment: .leading)
            Text(event.title)
              .font(.subheadline)
              .dailyTodoCompletion(
                event.completed == true,
                category: event.color
              )
              .lineLimit(1)
              .privacySensitive()
            Spacer(minLength: 0)
          }
        }
        let hiddenCount = max(
          0,
          entry.snapshot.todayEvents.count - visibleCount + entry.snapshot.todayRemainingCount
        )
        if hiddenCount > 0 {
          Text(entry.snapshot.text.moreEvents(hiddenCount))
            .font(.caption)
            .foregroundStyle(Color.dailySecondary)
        }
        Spacer(minLength: 0)
      }
    }
    .dailyWidgetBackground(themeMode: entry.snapshot.themeMode)
  }
}

#if os(iOS)
struct DailyLockScreenTodayView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyWidgetEntry

  private var events: [DailyWidgetEvent] {
    entry.snapshot.remainingEvents(at: entry.date)
  }

  private func timeLabel(for event: DailyWidgetEvent) -> String {
    if event.allDay == true { return entry.snapshot.text.allDay }
    if let start = event.startDate, let end = event.endDate,
       start <= entry.date, entry.date < end {
      return entry.snapshot.text.inProgress
    }
    return event.timeLabel
  }

  @ViewBuilder
  var body: some View {
    switch family {
    case .accessoryInline:
      if entry.snapshot.needsRefresh == true {
        Label(entry.snapshot.text.refreshShort, systemImage: "arrow.clockwise")
      } else if let next = events.first {
        HStack(spacing: 4) {
          Image(systemName: "calendar")
          Text(timeLabel(for: next))
          Text(next.title)
            .dailyTodoCompletion(
              next.completed == true,
              category: next.color, systemManaged: true
            )
            .privacySensitive()
        }
      } else {
        Label(entry.snapshot.text.noEventsTodayShort, systemImage: "calendar")
      }

    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        if entry.snapshot.needsRefresh == true {
          Image(systemName: "arrow.clockwise")
            .font(.title2.bold())
            .accessibilityLabel(entry.snapshot.text.refresh)
        } else {
          VStack(spacing: 0) {
            Text("\(events.count)")
              .font(.title2.bold())
              .monospacedDigit()
            Text(entry.snapshot.text.events)
              .font(.caption2)
          }
        }
      }

    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label(entry.snapshot.text.todayEvents, systemImage: "calendar")
          .font(.caption.bold())
        if entry.snapshot.needsRefresh == true {
          Text(entry.snapshot.text.refresh)
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if events.isEmpty {
          Text(entry.snapshot.text.noRemainingEvents)
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(events.prefix(2)) { event in
            HStack(spacing: 4) {
              DailyTodoToggle(event: event, text: entry.snapshot.text)
              Text(timeLabel(for: event))
                .font(.caption2)
                .frame(width: 36, alignment: .leading)
              Text(event.title)
                .font(.caption)
                .dailyTodoCompletion(
                  event.completed == true,
                  category: event.color, systemManaged: true
                )
                .lineLimit(1)
                .privacySensitive()
            }
          }
          if events.count > 2 {
            Text(entry.snapshot.text.more(events.count - 2))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

    default:
      EmptyView()
    }
  }
}
#endif

struct DailyTodayWidgetRootView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyWidgetEntry

  @ViewBuilder
  var body: some View {
    #if os(iOS)
    switch family {
    case .accessoryInline, .accessoryCircular, .accessoryRectangular:
      DailyLockScreenTodayView(entry: entry)
        .containerBackground(.clear, for: .widget)
    default:
      DailyTodayWidgetView(entry: entry)
    }
    #else
    DailyTodayWidgetView(entry: entry)
    #endif
  }
}

struct DailyMonthWidgetView: View {
  let entry: DailyWidgetEntry

  private var weekdayLabels: [String] {
    dailyWeekdayLabels(weekStartsOnMonday: entry.snapshot.weekStartsOnMonday,
      names: entry.snapshot.text.weekdayNames)
  }

  var body: some View {
    VStack(spacing: 7) {
      HStack(spacing: 6) {
        Image(systemName: "calendar.circle")
          .font(.body)
          .foregroundStyle(Color(red: 0.15, green: 0.38, blue: 0.91))
        Text(entry.snapshot.monthTitle)
          .font(.headline.weight(.semibold))
          .foregroundStyle(Color.dailyText)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .frame(height: 20)
      .layoutPriority(1)

      if entry.snapshot.needsRefresh == true {
        Spacer()
        Text(entry.snapshot.text.refresh)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
          .multilineTextAlignment(.center)
        Spacer()
      } else {
      HStack(spacing: 2) {
        ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
          Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(
              dailyWeekdayColor(column: index, weekStartsOnMonday: entry.snapshot.weekStartsOnMonday)
            )
            .frame(maxWidth: .infinity)
        }
      }

      ForEach(0..<6, id: \.self) { weekIndex in
        let startIndex = weekIndex * 7
        let weekDays = Array(entry.snapshot.monthDays.dropFirst(startIndex).prefix(7))
        DailyMonthWeekRow(days: weekDays)
          .frame(maxWidth: .infinity)
        if weekIndex < 5 {
          Spacer(minLength: 0)
        }
      }
      }
    }
    .dailyWidgetBackground(themeMode: entry.snapshot.themeMode)
  }
}

struct DailyWeekWidgetView: View {
  let entry: DailyWidgetEntry

  private let columnSpacing: CGFloat = 3
  private let eventRowHeight: CGFloat = 15
  private let maxEventRows = 3

  private var weekDays: [DailyWidgetDay] {
    guard !entry.snapshot.monthDays.isEmpty else { return [] }
    let todayIndex = entry.snapshot.monthDays.firstIndex(where: { $0.isToday }) ?? 0
    let weekStartIndex = (todayIndex / 7) * 7
    return Array(entry.snapshot.monthDays.dropFirst(weekStartIndex).prefix(7))
  }

  private var weekdayLabels: [String] {
    dailyWeekdayLabels(weekStartsOnMonday: entry.snapshot.weekStartsOnMonday,
      names: entry.snapshot.text.weekdayNames)
  }

  private var spans: [DailyWidgetEventSpan] { eventSpans(in: weekDays) }
  private var spanningIDs: Set<String> { Set(spans.map { $0.event.id }) }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      DailyWidgetHeader(
        title: entry.snapshot.weekTitle ?? entry.snapshot.text.thisWeek,
        systemImage: "calendar.badge.clock"
      )

      if entry.snapshot.needsRefresh == true {
        Spacer()
        Text(entry.snapshot.text.refresh)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else if weekDays.isEmpty {
        Spacer()
        Text(entry.snapshot.text.noEventsThisWeek)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else {
        GeometryReader { geometry in
          let columnWidth = (geometry.size.width - columnSpacing * 6) / 7
          let visibleSpans = Array(spans.prefix(maxEventRows))
          let singleRowCount = max(0, maxEventRows - visibleSpans.count)

          ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: columnSpacing) {
              ForEach(Array(weekDays.enumerated()), id: \.element.id) { index, day in
                let singleEvents = day.visibleEvents.filter { !spanningIDs.contains($0.id) }
                let shownSingleCount = min(singleEvents.count, singleRowCount)
                let shownSpanCount = visibleSpans.filter {
                  $0.startIndex <= index && index <= $0.endIndex
                }.count
                let hiddenCount = max(0, day.visibleEvents.count - shownSingleCount - shownSpanCount)
                VStack(alignment: .leading, spacing: 3) {
                  HStack(spacing: 2) {
                    Text(weekdayLabels[index])
                      .font(.system(size: 10, weight: .semibold))
                      .foregroundStyle(
                        dailyWeekdayColor(
                          column: index, weekStartsOnMonday: entry.snapshot.weekStartsOnMonday)
                      )
                    Text("\(day.day)")
                      .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                      .foregroundStyle(day.isToday ? Color.white : Color.dailyText)
                      .frame(minWidth: 17, minHeight: 17)
                      .background(day.isToday ? Color.blue : Color.clear)
                      .clipShape(Circle())
                    Spacer(minLength: 0)
                    if hiddenCount > 0 {
                      Text("+\(hiddenCount)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.dailySecondary)
                    }
                  }
                  Spacer().frame(height: CGFloat(visibleSpans.count) * eventRowHeight)
                  ForEach(Array(singleEvents.prefix(singleRowCount).enumerated()), id: \.element.id) { _, event in
                    DailyWidgetEventLabel(event: event, height: eventRowHeight, fontSize: 8)
                  }
                  Spacer(minLength: 0)
                }
                .frame(width: columnWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
              }
            }

            ForEach(Array(visibleSpans.enumerated()), id: \.element.id) { lane, span in
              DailyWidgetEventLabel(event: span.event, height: eventRowHeight, fontSize: 8)
                .frame(
                  width: columnWidth * CGFloat(span.endIndex - span.startIndex + 1)
                    + columnSpacing * CGFloat(span.endIndex - span.startIndex),
                  height: eventRowHeight
                )
                .offset(
                  x: CGFloat(span.startIndex) * (columnWidth + columnSpacing),
                  y: 22 + CGFloat(lane) * eventRowHeight
                )
            }
          }
        }
      }
    }
    .dailyWidgetBackground(themeMode: entry.snapshot.themeMode)
  }
}

struct DailyCalendarWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyWidgetEntry

  @ViewBuilder
  var body: some View {
    if family == .systemMedium {
      DailyWeekWidgetView(entry: entry)
    } else {
      DailyMonthWidgetView(entry: entry)
    }
  }
}

struct DailyDdayWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyWidgetEntry

  var visibleCount: Int { family == .systemSmall ? 2 : 4 }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DailyWidgetHeader(title: "D-day", systemImage: "flag")
      if entry.snapshot.needsRefresh == true {
        Spacer()
        Text(entry.snapshot.text.refresh)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else if entry.snapshot.ddays.isEmpty {
        Spacer()
        Text(entry.snapshot.text.noDdays)
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else {
        ForEach(entry.snapshot.ddays.prefix(visibleCount)) { item in
          HStack(spacing: 7) {
            Circle().fill(Color.daily(argb: item.color)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
              Text(item.title)
                .font(.subheadline)
                .dailyTodoCompletion(
                  item.completed == true,
                  category: item.color
                )
                .lineLimit(1)
                .privacySensitive()
              Text(item.dateLabel)
                .font(.caption2)
                .foregroundStyle(Color.dailySecondary)
            }
            Spacer(minLength: 4)
            Text(item.counter)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Color.daily(argb: item.color))
          }
        }
        Spacer(minLength: 0)
      }
    }
    .dailyWidgetBackground(themeMode: entry.snapshot.themeMode)
  }
}

private struct DailyWidgetBackgroundModifier: ViewModifier {
  @Environment(\.colorScheme) private var systemColorScheme
  let themeMode: String?

  private var resolvedColorScheme: ColorScheme {
    switch themeMode {
    case "light":
      return .light
    case "dark":
      return .dark
    default:
      return systemColorScheme
    }
  }

  private var themeIdentity: String {
    resolvedColorScheme == .dark ? "daily-widget-dark" : "daily-widget-light"
  }

  func body(content: Content) -> some View {
    let colorScheme = resolvedColorScheme
    let background = colorScheme == .dark ? Color.black : Color.white
    content
      .environment(\.colorScheme, colorScheme)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .containerBackground(background, for: .widget)
      .id(themeIdentity)
  }
}

private extension View {
  func dailyTodoCompletion(_ completed: Bool, category: Int,
                           backgroundAlpha: Double = 0, systemManaged: Bool = false,
                           palette: DailyEventPalette.Palette? = nil) -> some View {
    modifier(DailyCompletionModifier(completed: completed, category: category,
      backgroundAlpha: backgroundAlpha, systemManaged: systemManaged, palette: palette))
  }

  func dailyWidgetBackground(themeMode: String?) -> some View {
    modifier(DailyWidgetBackgroundModifier(themeMode: themeMode))
  }
}

private struct DailyCompletionModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric(relativeTo: .subheadline) private var strikeThickness: CGFloat = 1.25
  let completed: Bool
  let category: Int
  let backgroundAlpha: Double
  let systemManaged: Bool
  /// Palette the caller already resolved for the same category, alpha and appearance.
  let palette: DailyEventPalette.Palette?

  @ViewBuilder
  func body(content: Content) -> some View {
    if systemManaged {
      // Accessory widgets are composited/tinted by the Lock Screen. Its actual
      // wallpaper is unavailable, so use the OS foreground and native line.
      content.foregroundStyle(.primary).strikethrough(completed, color: colorScheme == .dark ? .white : .black)
    } else {
      let colors = palette ?? {
        let surface = colorScheme == .dark ? 0xff000000 : 0xffffffff
        let background = DailyEventPalette.blend(category, on: surface, alpha: backgroundAlpha)
        return DailyEventPalette.resolve(category: category | 0xff000000, background: background)
      }()
      content.foregroundStyle(Color.daily(argb: colors.foreground))
        .background(Color.daily(argb: colors.background))
        // Keep a visible line in both appearances and at small month-label sizes.
        // Apply it before the caller's padding/frame expansion.
        .overlay {
          if completed {
            Rectangle()
              .fill(colorScheme == .dark ? Color.white : Color.black)
              .frame(height: strikeThickness)
              .allowsHitTesting(false)
              .accessibilityHidden(true)
          }
        }
    }
  }
}

private extension Color {
  static let dailyText = Color.primary
  static let dailySecondary = Color.secondary

  static func daily(argb: Int) -> Color {
    let red = Double((argb >> 16) & 0xff) / 255.0
    let green = Double((argb >> 8) & 0xff) / 255.0
    let blue = Double(argb & 0xff) / 255.0
    return Color(red: red, green: green, blue: blue)
  }

}

struct DailyTodayWidget: Widget {
  let kind = DailyWidgetKind.today

  private var supportedFamilies: [WidgetFamily] {
    #if os(iOS)
    return [
      .systemSmall,
      .systemLarge,
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
    ]
    #else
    return [.systemSmall, .systemLarge]
    #endif
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
      DailyTodayWidgetRootView(entry: entry)
    }
    .configurationDisplayName(DailyWidgetText.system.todayEvents)
    .description(DailyWidgetText.system.todayWidgetDescription)
    .supportedFamilies(supportedFamilies)
  }
}

struct DailyMonthWidget: Widget {
  let kind = DailyWidgetKind.calendar

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
      DailyCalendarWidgetView(entry: entry)
    }
    .configurationDisplayName(DailyWidgetText.system.calendarWidgetName)
    .description(DailyWidgetText.system.calendarWidgetDescription)
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct DailyDdayWidget: Widget {
  let kind = DailyWidgetKind.dday

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
      DailyDdayWidgetView(entry: entry)
    }
    .configurationDisplayName("D-day")
    .description(DailyWidgetText.system.ddayWidgetDescription)
    .supportedFamilies([.systemSmall])
  }
}

#if os(iOS)
@available(iOS 26.0, *)
private struct DailyAlarmActivityContent: View {
  let title: String
  let memo: String?
  let snoozeLabel: String
  let compact: Bool

  var body: some View {
    HStack(spacing: compact ? 5 : 10) {
      Image(systemName: "alarm.fill")
        .foregroundStyle(.blue)
      if compact {
        Text(title)
          .font(.caption.bold())
          .lineLimit(1)
      } else {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
            .lineLimit(1)
          if let memo, !memo.isEmpty {
            Text(memo)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          } else {
            Text(snoozeLabel)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

@available(iOS 26.0, *)
struct DailyAlarmLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AlarmAttributes<DailyAlarmMetadata>.self) { context in
      let text = DailyWidgetText(localeTag: context.attributes.metadata?.localeTag)
      DailyAlarmActivityContent(
        title: context.attributes.metadata?.title ?? text.eventAlarm,
        memo: context.attributes.metadata?.memo,
        snoozeLabel: text.snoozeAfter(context.attributes.metadata?.snoozeMinutes ?? 10),
        compact: false
      )
      .padding()
      .activityBackgroundTint(Color(red: 0.96, green: 0.98, blue: 1.0))
      .activitySystemActionForegroundColor(.blue)
    } dynamicIsland: { context in
      let text = DailyWidgetText(localeTag: context.attributes.metadata?.localeTag)
      let title = context.attributes.metadata?.title ?? text.eventAlarm
      // Alarms scheduled before the metadata carried it used ten minutes.
      let snoozeMinutes = context.attributes.metadata?.snoozeMinutes ?? 10
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "alarm.fill")
            .foregroundStyle(.blue)
        }
        DynamicIslandExpandedRegion(.center) {
          DailyAlarmActivityContent(
            title: title,
            memo: context.attributes.metadata?.memo,
            snoozeLabel: text.snoozeAfter(snoozeMinutes),
            compact: false
          )
        }
      } compactLeading: {
        Image(systemName: "alarm.fill")
          .foregroundStyle(.blue)
      } compactTrailing: {
        Text(text.minutes(snoozeMinutes))
          .font(.caption2.bold())
      } minimal: {
        Image(systemName: "alarm.fill")
          .foregroundStyle(.blue)
      }
    }
  }
}
#endif

@main
struct DailyWidgetBundle: WidgetBundle {
  var body: some Widget {
    DailyTodayWidget()
    DailyMonthWidget()
    DailyDdayWidget()
    #if os(iOS)
    if #available(iOS 26.0, *) {
      DailyAlarmLiveActivity()
    }
    #endif
  }
}
