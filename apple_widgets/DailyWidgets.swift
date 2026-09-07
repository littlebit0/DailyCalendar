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
private let todoActionsChangedNotification = "com.littlebit0.daily.widgetTodoActionsChanged"
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
  static func append(eventId: String, completed: Bool) throws {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else {
      throw NSError(
        domain: "DailyWidgets",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "위젯 공유 저장소를 열 수 없습니다."]
      )
    }
    let actionsURL = containerURL.appendingPathComponent(todoActionsFileName)
    var actions: [[String: Any]] = []
    if let data = try? Data(contentsOf: actionsURL),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      actions = decoded
    }
    actions.append([
      "token": UUID().uuidString,
      "eventId": eventId,
      "completed": completed,
    ])
    let data = try JSONSerialization.data(withJSONObject: actions)
    try data.write(to: actionsURL, options: .atomic)
    try updateSnapshot(
      at: containerURL.appendingPathComponent(snapshotFileName),
      eventId: eventId,
      completed: completed
    )
    notifyApp()
  }

  private static func updateSnapshot(at url: URL, eventId: String, completed: Bool) throws {
    guard let data = try? Data(contentsOf: url),
          var snapshot = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }
    for key in ["todayEvents", "scheduleEvents", "ddays"] {
      guard var events = snapshot[key] as? [[String: Any]] else { continue }
      update(&events, eventId: eventId, completed: completed)
      snapshot[key] = events
    }
    if var days = snapshot["monthDays"] as? [[String: Any]] {
      for index in days.indices {
        guard var events = days[index]["events"] as? [[String: Any]] else { continue }
        update(&events, eventId: eventId, completed: completed)
        days[index]["events"] = events
      }
      snapshot["monthDays"] = days
    }
    snapshot["generatedAt"] = Int64(Date().timeIntervalSince1970 * 1000)
    let updated = try JSONSerialization.data(withJSONObject: snapshot)
    try updated.write(to: url, options: .atomic)
  }

  private static func update(
    _ events: inout [[String: Any]],
    eventId: String,
    completed: Bool
  ) {
    for index in events.indices where
      (events[index]["eventId"] as? String ?? events[index]["id"] as? String) == eventId {
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

  init() {}

  init(eventId: String, targetCompleted: Bool) {
    self.eventId = eventId
    self.targetCompleted = targetCompleted
  }

  func perform() async throws -> some IntentResult {
    try DailyWidgetTodoActionStore.append(
      eventId: eventId,
      completed: targetCompleted
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
  let event: DailyWidgetMonthEvent
  let height: CGFloat
  let fontSize: CGFloat

  var body: some View {
    Text(event.title)
      .font(.system(size: fontSize, weight: .medium))
      .dailyTodoCompletion(
        event.completed == true,
        eventColor: Color.daily(argb: event.color)
      )
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 2)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
      .background(Color.daily(argb: event.color).opacity(0.18))
      .clipShape(RoundedRectangle(cornerRadius: 2.5))
  }
}

private struct DailyTodoToggle: View {
  let event: DailyWidgetEvent

  @ViewBuilder
  var body: some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      Button(
        intent: DailyToggleTodoIntent(
          eventId: event.eventId ?? event.id,
          targetCompleted: event.completed != true
        )
      ) {
        Image(systemName: event.completed == true ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(event.completed == true ? Color.blue : Color.dailySecondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(event.completed == true ? "미완료로 변경" : "완료로 변경")
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

  static func load() -> DailyWidgetSnapshot {
    guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
          ),
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
    todayTitle: "오늘 일정",
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
    completion(DailyWidgetEntry(date: .now, snapshot: DailyWidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DailyWidgetEntry>) -> Void) {
    let now = Date.now
    let snapshot = DailyWidgetSnapshot.load()
    let entry = DailyWidgetEntry(date: now, snapshot: snapshot)
    let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
    let eventBoundaries = (snapshot.scheduleEvents ?? []).flatMap { event in
      [event.startDate, event.endDate].compactMap { $0 }.filter { $0 > now }
    }
    let nextRefresh = ([midnight] + eventBoundaries).min() ?? now.addingTimeInterval(3600)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }
}

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
      if entry.snapshot.todayEvents.isEmpty {
        Spacer()
        Text("오늘 일정이 없습니다")
          .font(.subheadline)
          .foregroundStyle(Color.dailySecondary)
        Spacer()
      } else {
        ForEach(entry.snapshot.todayEvents.prefix(visibleCount)) { event in
          HStack(spacing: 7) {
            DailyTodoToggle(event: event)
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
                eventColor: Color.daily(argb: event.color)
              )
              .lineLimit(1)
            Spacer(minLength: 0)
          }
        }
        let hiddenCount = max(
          0,
          entry.snapshot.todayEvents.count - visibleCount + entry.snapshot.todayRemainingCount
        )
        if hiddenCount > 0 {
          Text("외 \(hiddenCount)개 일정")
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
    if event.allDay == true { return "종일" }
    if let start = event.startDate, let end = event.endDate,
       start <= entry.date, entry.date < end {
      return "진행 중"
    }
    return event.timeLabel
  }

  @ViewBuilder
  var body: some View {
    switch family {
    case .accessoryInline:
      if let next = events.first {
        HStack(spacing: 4) {
          Image(systemName: "calendar")
          Text(timeLabel(for: next))
          Text(next.title)
            .dailyTodoCompletion(
              next.completed == true,
              eventColor: Color.daily(argb: next.color)
            )
            .privacySensitive()
        }
      } else {
        Label("오늘 일정 없음", systemImage: "calendar")
      }

    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Text("\(events.count)")
            .font(.title2.bold())
            .monospacedDigit()
          Text("일정")
            .font(.caption2)
        }
      }

    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("오늘 일정", systemImage: "calendar")
          .font(.caption.bold())
        if events.isEmpty {
          Text("남은 일정이 없습니다")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(events.prefix(2)) { event in
            HStack(spacing: 4) {
              DailyTodoToggle(event: event)
              Text(timeLabel(for: event))
                .font(.caption2)
                .frame(width: 36, alignment: .leading)
              Text(event.title)
                .font(.caption)
                .dailyTodoCompletion(
                  event.completed == true,
                  eventColor: Color.daily(argb: event.color)
                )
                .lineLimit(1)
                .privacySensitive()
            }
          }
          if events.count > 2 {
            Text("외 \(events.count - 2)개")
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
    entry.snapshot.weekStartsOnMonday
      ? ["월", "화", "수", "목", "금", "토", "일"]
      : ["일", "월", "화", "수", "목", "금", "토"]
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

      HStack(spacing: 2) {
        ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
          Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(
              index == 0 ? Color.red : (index == 6 ? Color.blue : Color.dailySecondary)
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
    entry.snapshot.weekStartsOnMonday
      ? ["월", "화", "수", "목", "금", "토", "일"]
      : ["일", "월", "화", "수", "목", "금", "토"]
  }

  private var spans: [DailyWidgetEventSpan] { eventSpans(in: weekDays) }
  private var spanningIDs: Set<String> { Set(spans.map { $0.event.id }) }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      DailyWidgetHeader(
        title: entry.snapshot.weekTitle ?? "이번 주 일정",
        systemImage: "calendar.badge.clock"
      )

      if weekDays.isEmpty {
        Spacer()
        Text("이번 주 일정이 없습니다")
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
                        index == 0 ? Color.red : (index == 6 ? Color.blue : Color.dailySecondary)
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
      if entry.snapshot.ddays.isEmpty {
        Spacer()
        Text("표시할 D-day가 없습니다")
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
                  eventColor: Color.daily(argb: item.color)
                )
                .lineLimit(1)
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
  @ViewBuilder
  func dailyTodoCompletion(_ completed: Bool, eventColor: Color) -> some View {
    if completed {
      self
        .foregroundStyle(eventColor)
        .strikethrough(true, color: Color.primary.opacity(0.78))
    } else {
      self.foregroundStyle(eventColor)
    }
  }

  func dailyWidgetBackground(themeMode: String?) -> some View {
    modifier(DailyWidgetBackgroundModifier(themeMode: themeMode))
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
    .configurationDisplayName("오늘 일정")
    .description("오늘의 일정을 시간순으로 확인합니다.")
    .supportedFamilies(supportedFamilies)
  }
}

struct DailyMonthWidget: Widget {
  let kind = DailyWidgetKind.calendar

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
      DailyCalendarWidgetView(entry: entry)
    }
    .configurationDisplayName("주간 및 월간 캘린더")
    .description("중형에서는 이번 주 일정을, 대형에서는 월간 일정을 확인합니다.")
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
    .description("가까운 D-day 일정을 확인합니다.")
    .supportedFamilies([.systemSmall])
  }
}

#if os(iOS)
@available(iOS 26.0, *)
private struct DailyAlarmActivityContent: View {
  let title: String
  let memo: String?
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
            Text("10분 후 다시 알림")
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
      DailyAlarmActivityContent(
        title: context.attributes.metadata?.title ?? "일정 알람",
        memo: context.attributes.metadata?.memo,
        compact: false
      )
      .padding()
      .activityBackgroundTint(Color(red: 0.96, green: 0.98, blue: 1.0))
      .activitySystemActionForegroundColor(.blue)
    } dynamicIsland: { context in
      let title = context.attributes.metadata?.title ?? "일정 알람"
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "alarm.fill")
            .foregroundStyle(.blue)
        }
        DynamicIslandExpandedRegion(.center) {
          DailyAlarmActivityContent(
            title: title,
            memo: context.attributes.metadata?.memo,
            compact: false
          )
        }
      } compactLeading: {
        Image(systemName: "alarm.fill")
          .foregroundStyle(.blue)
      } compactTrailing: {
        Text("10분")
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
