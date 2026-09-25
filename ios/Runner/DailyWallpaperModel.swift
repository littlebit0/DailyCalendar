import Foundation
import CoreGraphics

// Only explicit user confirmations advance setup. A share-sheet dismissal,
// generated image or Shortcuts callback is not proof of a visible wallpaper.
struct DailyWallpaperSetupProgress: Codable, Equatable {
  private(set) var photoReady = false
  private(set) var shortcutReady = false
  private(set) var visibleConfirmedAt: Date?
  private(set) var automationReady = false
  var stage: Int {
    !photoReady ? 0 : !shortcutReady ? 1 : visibleConfirmedAt == nil ? 2 : 3
  }
  mutating func confirmPhoto() { photoReady = true }
  mutating func confirmShortcut() { if photoReady { shortcutReady = true } }
  mutating func confirmVisible(now: Date = Date()) {
    if photoReady && shortcutReady { visibleConfirmedAt = now }
  }
  mutating func confirmAutomation() {
    if visibleConfirmedAt != nil { automationReady = true }
  }
  mutating func repeatFromPhoto() { self = Self() }
  mutating func replaceShortcut() {
    shortcutReady = false
    visibleConfirmedAt = nil
    // The OS automation itself is not deleted; its connection needs checking.
    automationReady = false
  }
}

struct DailyWallpaperAttempt: Codable, Equatable {
  enum Outcome: String, Codable {
    case waiting, systemReported, failed, cancelled, unconfirmed
  }
  enum Source: String, Codable { case app, shortcut }
  static let timeout: TimeInterval = 120
  let id: UUID
  let startedAt: Date
  let source: Source
  var outcome: Outcome = .waiting
  var finishedAt: Date?

  var statusDate: Date {
    // A URL success is deliberately weaker than an action receipt.
    source == .app && outcome == .unconfirmed ? startedAt : max(startedAt, finishedAt ?? startedAt)
  }

  func visibleOutcome(now: Date) -> Outcome {
    outcome == .waiting && now.timeIntervalSince(startedAt) >= Self.timeout ? .unconfirmed : outcome
  }
}

struct DailyWallpaperAttempts: Codable {
  private(set) var items: [DailyWallpaperAttempt] = []

  mutating func begin(source: DailyWallpaperAttempt.Source, now: Date = Date()) -> DailyWallpaperAttempt {
    let attempt = DailyWallpaperAttempt(id: UUID(), startedAt: now, source: source)
    items.append(attempt)
    return attempt
  }

  mutating func finish(id: UUID, outcome: DailyWallpaperAttempt.Outcome, now: Date = Date()) -> Bool {
    guard let index = items.firstIndex(where: { $0.id == id }), items[index].outcome == .waiting else { return false }
    items[index].outcome = outcome
    items[index].finishedAt = now
    return true
  }

  // A manual launch and its generated workflow have separate IDs. A generic
  // URL success must never overwrite the actual wallpaper-action receipt.
  var latest: DailyWallpaperAttempt? { items.max { $0.statusDate < $1.statusDate } }

  mutating func prune(now: Date) -> [UUID] {
    let expired = items.filter { now.timeIntervalSince($0.startedAt) > 86400 }.map(\.id)
    items.removeAll { expired.contains($0.id) }
    return expired
  }

  static func callback(_ url: URL) -> (UUID, DailyWallpaperAttempt.Outcome)? {
    guard url.scheme == "daily-wallpaper", url.host == "result",
          let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let rawID = parts.queryItems?.first(where: { $0.name == "id" })?.value,
          let id = UUID(uuidString: rawID) else { return nil }
    switch url.path {
    case "/error": return (id, .failed)
    case "/cancel": return (id, .cancelled)
    case "/success": return (id, .unconfirmed)
    default: return nil
    }
  }
}

struct DailyWallpaperSettings: Codable, Equatable, Sendable {
  var enabled = false
  var consentAccepted = false
  var appearance = "dark"
  var topFraction = 0.40

  mutating func normalize() {
    if !["dark", "light"].contains(appearance) { appearance = "dark" }
    topFraction = topFraction.isFinite ? min(0.52, max(0.34, topFraction)) : 0.40
  }
}

struct DailyWallpaperEvent: Codable, Sendable {
  let id: String
  let title: String
  let start: Date
  let end: Date
  let color: Int64
  let completed: Bool
  let holiday: Bool
}

// A wallpaper belongs to the built-in display, not the current app window.
// iPad uses one square image so a background App Intent need not guess which
// orientation the user will choose later on the Lock Screen.
struct DailyWallpaperCanvas: Codable, Equatable {
  enum Device: String, Codable { case phone, pad }
  static let rendererVersion = 3
  let device: Device
  let nativeWidth: Double
  let nativeHeight: Double

  init(device: Device, nativeSize: CGSize) {
    self.device = device
    nativeWidth = min(nativeSize.width, nativeSize.height)
    nativeHeight = max(nativeSize.width, nativeSize.height)
  }

  var size: CGSize {
    CGSize(width: device == .pad ? nativeHeight : nativeWidth, height: nativeHeight)
  }

  // These are centered, unzoomed crops of the PNG, not a readback of iPadOS's
  // wallpaper placement. System/user zoom and repositioning may differ.
  var portraitCrop: CGRect {
    CGRect(x: (size.width - nativeWidth) / 2, y: 0,
           width: nativeWidth, height: nativeHeight)
  }

  var landscapeCrop: CGRect {
    CGRect(x: 0, y: (size.height - nativeWidth) / 2,
           width: nativeHeight, height: nativeWidth)
  }
}

struct DailyWallpaperMonth {
  struct Segment {
    let event: DailyWallpaperEvent
    let startColumn: Int
    let endColumn: Int
    let lane: Int
  }

  let calendar: Calendar
  let start: Date
  let end: Date
  let gridStart: Date
  let days: [Date]
  let today: Date
  let rows: Int

  init(now: Date, mondayFirst: Bool, timeZone: TimeZone = .current) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = mondayFirst ? 2 : 1
    self.calendar = calendar
    today = calendar.startOfDay(for: now)
    start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    end = calendar.date(byAdding: .month, value: 1, to: start)!
    let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
    gridStart = calendar.date(byAdding: .day, value: -offset, to: start)!
    let count = calendar.range(of: .day, in: .month, for: start)!.count
    rows = (offset + count + 6) / 7
    let first = gridStart
    days = (0..<(rows * 7)).map { calendar.date(byAdding: .day, value: $0, to: first)! }
  }

  func segments(events: [DailyWallpaperEvent], row: Int) -> [Segment] {
    guard row >= 0 && row < rows else { return [] }
    let first = days[row * 7]
    let afterLast = calendar.date(byAdding: .day, value: 7, to: first)!
    let matching = events.filter { $0.start < min(afterLast, end) && $0.end > max(first, start) }
      .sorted {
        if $0.start != $1.start { return $0.start < $1.start }
        if $0.end != $1.end { return $0.end > $1.end }
        return $0.id < $1.id
      }
    var lanes: [Int] = []
    return matching.compactMap { event in
      let visibleStart = max(first, max(start, calendar.startOfDay(for: event.start)))
      let visibleEnd = min(afterLast, min(end, event.end))
      guard visibleEnd > visibleStart else { return nil }
      let column = calendar.dateComponents([.day], from: first, to: visibleStart).day!
      let lastDay = calendar.startOfDay(for: visibleEnd.addingTimeInterval(-0.001))
      let lastColumn = calendar.dateComponents([.day], from: first, to: lastDay).day!
      let lane = lanes.firstIndex(where: { $0 < column }) ?? lanes.count
      if lane == lanes.count { lanes.append(lastColumn) } else { lanes[lane] = lastColumn }
      return Segment(event: event, startColumn: column, endColumn: lastColumn, lane: lane)
    }
  }
}

enum DailyWallpaperGeometry {
  struct Layout {
    let content: CGRect
    let scale: Double
    let gridTop: Double
    let rowHeight: Double
  }

  static func layout(canvas: DailyWallpaperCanvas, topFraction: Double, rows: Int) -> Layout {
    let content: CGRect
    let scale: Double
    let rowCount = max(1, rows)
    if canvas.device == .pad {
      let portrait = canvas.portraitCrop
      let landscape = canvas.landscapeCrop
      let position = topFraction.isFinite ? min(0.52, max(0.34, topFraction)) : 0.40
      let safeTop = 0.32 + (position - 0.34) * (2.0 / 3.0)
      // Reserve clock/date space in both orientations and the usual left-side
      // landscape widgets. Enlarged clocks/widgets still need a visual check.
      let portraitSafe = CGRect(x: portrait.minX + portrait.width * 0.055,
        y: portrait.height * safeTop, width: portrait.width * 0.89,
        height: portrait.height * (0.90 - safeTop))
      let landscapeSafe = CGRect(x: landscape.width * 0.25,
        y: landscape.minY + landscape.height * safeTop,
        width: landscape.width * 0.695, height: landscape.height * (0.91 - safeTop))
      content = portraitSafe.intersection(landscapeSafe)
      // More title room per day than a phone. At the lowest calendar position,
      // retain at least one event plus its overflow count in a six-week month.
      let twoSlotHeight = 16.0 + 2 + 13 * 2 + 2
      scale = min(canvas.nativeWidth / 650,
                  content.height / (58 + Double(rowCount) * twoSlotHeight + 1))
    } else {
      content = contentRect(width: canvas.size.width, height: canvas.size.height,
                            topFraction: topFraction)
      scale = canvas.size.width / 390
    }
    let gridTop = content.minY + 58 * scale
    return Layout(content: content, scale: scale, gridTop: gridTop,
                  rowHeight: (content.maxY - gridTop) / Double(rowCount))
  }

  struct RowLayout {
    let dateHeight: Double
    let eventHeight: Double
    let eventTop: Double
    let slots: Int

    func visibleLanes(required: Int) -> Int {
      required > slots ? max(0, slots - 1) : required
    }
  }

  static func rowLayout(height: Double, scale: Double) -> RowLayout {
    let dateHeight = min(16 * scale, height * 0.38)
    let eventHeight = 13 * scale
    let eventTop = dateHeight + 2 * scale
    let slots = max(0, Int((height - eventTop - 2 * scale) / eventHeight))
    return RowLayout(dateHeight: dateHeight, eventHeight: eventHeight,
                     eventTop: eventTop, slots: slots)
  }

  // Keep content below the normal clock/widgets and above the bottom controls.
  static func contentRect(width: Double, height: Double, topFraction: Double) -> CGRect {
    let top = min(0.52, max(0.34, topFraction)) * height
    let contentHeight: Double = max(1.0, height * 0.85 - top)
    return CGRect(x: CGFloat(width * 0.055), y: CGFloat(top),
                  width: CGFloat(width * 0.89), height: CGFloat(contentHeight))
  }
}
