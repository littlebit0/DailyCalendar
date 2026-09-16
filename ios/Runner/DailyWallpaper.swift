import AppIntents
import CryptoKit
import Flutter
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import Photos

@MainActor
enum DailyWallpaperUpdateMonitor {
  static let key = "daily.wallpaper.attempts.v1"
  nonisolated static let notificationPrefix = "daily.wallpaper.result."
  static let changed = Notification.Name("DailyWallpaperUpdateChanged")

  static var attempts: DailyWallpaperAttempts {
    guard let data = UserDefaults.standard.data(forKey: key),
          let value = try? JSONDecoder().decode(DailyWallpaperAttempts.self, from: data) else {
      return DailyWallpaperAttempts()
    }
    return value
  }

  private static func save(_ value: DailyWallpaperAttempts) throws {
    UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: key)
    NotificationCenter.default.post(name: changed, object: nil)
  }

  static func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    if await center.notificationSettings().authorizationStatus == .notDetermined {
      _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }
  }

  static func begin(source: DailyWallpaperAttempt.Source) async throws -> UUID {
    guard DailyWallpaperStore.settings.enabled && DailyWallpaperStore.settings.consentAccepted else {
      throw DailyWallpaperError.disabled
    }
    var state = attempts
    removeNotifications(state.prune(now: Date()))
    let attempt = state.begin(source: source)
    try save(state)
    await notify(id: attempt.id, outcome: .unconfirmed, delay: DailyWallpaperAttempt.timeout)
    // OFF/reset can happen while notification scheduling is suspended.
    guard attempts.items.contains(where: { $0.id == attempt.id && $0.outcome == .waiting }) else {
      removeNotifications([attempt.id])
      throw DailyWallpaperError.disabled
    }
    return attempt.id
  }

  static func finish(id: UUID, outcome: DailyWallpaperAttempt.Outcome, announce: Bool = false) async throws {
    var state = attempts
    guard state.finish(id: id, outcome: outcome) else { return }
    try save(state)
    removeNotifications([id])
    if announce { await notify(id: id, outcome: outcome, delay: 1) }
  }

  static func clear() {
    removeNotifications(attempts.items.map(\.id))
    UserDefaults.standard.removeObject(forKey: key)
    NotificationCenter.default.post(name: changed, object: nil)
  }

  private static func removeNotifications(_ ids: [UUID]) {
    let identifiers = ids.map { notificationPrefix + $0.uuidString }
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
  }

  private static func notify(id: UUID, outcome: DailyWallpaperAttempt.Outcome, delay: TimeInterval) async {
    let content = UNMutableNotificationContent()
    content.title = DailyWallpaperText.value("update_\(outcome.rawValue)")
    content.body = DailyWallpaperText.value("updateFailureHelp")
    content.sound = .default
    let request = UNNotificationRequest(identifier: notificationPrefix + id.uuidString, content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
    // Denied permission never blocks the update; persisted status is still shown in Daily.
    try? await UNUserNotificationCenter.current().add(request)
    if !attempts.items.contains(where: { $0.id == id }) { removeNotifications([id]) }
  }

  static func handleCallback(_ url: URL) -> Bool {
    guard url.scheme == "daily-wallpaper" else { return false }
    guard let (id, outcome) = DailyWallpaperAttempts.callback(url),
          let attempt = attempts.items.first(where: { $0.id == id && $0.source == .app }),
          attempt.outcome == .waiting else { return true }
    Task {
      let children = attempts.items.filter { $0.source == .shortcut && $0.startedAt >= attempt.startedAt }
      // x-success only confirms workflow termination, not wallpaper changes.
      try? await finish(id: id, outcome: outcome,
        announce: outcome != .unconfirmed || children.isEmpty)
    }
    return true
  }
}

@MainActor
enum DailyWallpaperStore {
  static let key = "daily.wallpaper.settings.v1"
  static let generatedKey = "daily.wallpaper.generatedAt"
  nonisolated static let shortcutName = "DailyCalendar Wallpaper"
  nonisolated static let setupShortcutName = "DailyCalendar Wallpaper Setup"
  nonisolated static let guideStepKey = "daily.wallpaper.guideStep"
  static let progressKey = "daily.wallpaper.setup.v2"
  nonisolated static let photoGuidePageKey = "daily.wallpaper.photoGuidePage.v2"
  nonisolated static let automationGuidePageKey = "daily.wallpaper.automationGuidePage.v2"
  private static var generation = 0

  static var progress: DailyWallpaperSetupProgress {
    guard let data = UserDefaults.standard.data(forKey: progressKey),
          let value = try? JSONDecoder().decode(DailyWallpaperSetupProgress.self, from: data) else {
      return DailyWallpaperSetupProgress()
    }
    return value
  }

  static func saveProgress(_ value: DailyWallpaperSetupProgress) throws {
    UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: progressKey)
  }

  @available(iOS 16.0, *)
  static func savePhoto() async throws {
    guard settings.enabled && settings.consentAccepted else { throw DailyWallpaperError.disabled }
    let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard authorization == .authorized else { throw DailyWallpaperError.photoPermission }
    let data = try await image()
    guard settings.enabled && settings.consentAccepted, !Task.isCancelled else { throw CancellationError() }
    try await PHPhotoLibrary.shared().performChanges {
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = "DailyCalendar-Wallpaper.png"
      PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: options)
    }
  }

  static var settings: DailyWallpaperSettings {
    guard let data = UserDefaults.standard.data(forKey: key),
          var value = try? JSONDecoder().decode(DailyWallpaperSettings.self, from: data) else {
      return DailyWallpaperSettings()
    }
    value.normalize()
    return value
  }

  static func save(_ value: DailyWallpaperSettings) throws {
    var value = value
    value.normalize()
    UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: key)
    if !value.enabled || !value.consentAccepted { DailyWallpaperUpdateMonitor.clear() }
    generation += 1
  }

  static var directory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("DailyWallpaper", isDirectory: true)
  }

  static func clear() throws {
    // Disable first, even if cleanup fails: a surviving automation must stop.
    UserDefaults.standard.removeObject(forKey: key)
    UserDefaults.standard.removeObject(forKey: generatedKey)
    UserDefaults.standard.removeObject(forKey: guideStepKey)
    UserDefaults.standard.removeObject(forKey: progressKey)
    UserDefaults.standard.removeObject(forKey: photoGuidePageKey)
    UserDefaults.standard.removeObject(forKey: automationGuidePageKey)
    DailyWallpaperUpdateMonitor.clear()
    generation += 1
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }

  @available(iOS 16.0, *)
  static func image(preview: Bool = false) async throws -> Data {
    let settings = settings
    let revision = generation
    guard preview || (settings.enabled && settings.consentAccepted) else { throw DailyWallpaperError.disabled }
    guard UIDevice.current.userInterfaceIdiom == .phone else { throw DailyWallpaperError.unsupported }
    let defaults = UserDefaults.standard
    let month = DailyWallpaperMonth(now: Date(), mondayFirst: defaults.bool(forKey: "flutter.weekStartsOnMonday"))
    let start = month.start
    let end = month.end
    let events = try await Task.detached(priority: .userInitiated) {
      try DailyWallpaperDataSource.events(from: start, to: end)
    }.value
    guard revision == generation, !Task.isCancelled else { throw CancellationError() }
    let size = UIScreen.main.nativeBounds.size
    let portrait = CGSize(width: min(size.width, size.height), height: max(size.width, size.height))
    let locale = DailyWallpaperText.locale
    let centered = defaults.string(forKey: "flutter.calendarEventTitleAlignment") == "center"
    struct CacheInput: Encodable {
      let settings: DailyWallpaperSettings
      let events: [DailyWallpaperEvent]
      let today: Date
      let monday: Bool
      let width: Double
      let height: Double
      let locale: String
      let centered: Bool
      let renderer = 1
    }
    let input = CacheInput(settings: settings, events: events, today: month.today,
                           monday: month.calendar.firstWeekday == 2,
                           width: portrait.width, height: portrait.height,
                           locale: locale.identifier, centered: centered)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let digest = SHA256.hash(data: try encoder.encode(input)).map { String(format: "%02x", $0) }.joined()
    let cached = directory.appendingPathComponent("\(digest).png")
    if let data = try? Data(contentsOf: cached) {
      if !preview { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: generatedKey) }
      return data
    }
    let data = DailyWallpaperRenderer.render(month: month, events: events, settings: settings,
                                            size: portrait, locale: locale, centered: centered)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: cached, options: [.atomic, .completeFileProtection])
    var excludedDirectory = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try excludedDirectory.setResourceValues(values)
    for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
      where file.pathExtension == "png" && file != cached {
      try? FileManager.default.removeItem(at: file)
    }
    if !preview { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: generatedKey) }
    return data
  }
}

enum DailyWallpaperError: Error, LocalizedError {
  case disabled, unsupported, installUnavailable, databaseUnavailable, photoPermission, invalidUpdateID
  var errorDescription: String? {
    switch self {
    case .disabled: DailyWallpaperText.value("disabled")
    case .unsupported: DailyWallpaperText.value("unsupported")
    case .installUnavailable: DailyWallpaperText.value("installError")
    case .databaseUnavailable: DailyWallpaperText.value("dataError")
    case .photoPermission: DailyWallpaperText.value("photoPermission")
    case .invalidUpdateID: DailyWallpaperText.value("replaceBrokenShortcut")
    }
  }
}

@MainActor
enum DailyWallpaperRenderer {
  static func render(month: DailyWallpaperMonth, events: [DailyWallpaperEvent],
                     settings: DailyWallpaperSettings, size: CGSize, locale: Locale,
                     centered: Bool) -> Data {
    let scale = size.width / 390
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
      let dark = settings.appearance == "dark"
      let background = dark ? UIColor.black : UIColor.white
      let foreground = dark ? UIColor.white : UIColor.black
      let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
      let red = UIColor.systemRed.resolvedColor(with: traits)
      let blue = UIColor.systemBlue.resolvedColor(with: traits)
      background.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      let rect = DailyWallpaperGeometry.contentRect(width: size.width, height: size.height,
                                                    topFraction: settings.topFraction)
      func text(_ value: String, _ frame: CGRect, _ font: CGFloat, _ color: UIColor,
                weight: UIFont.Weight = .regular, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: frame, withAttributes: [
          .font: UIFont.systemFont(ofSize: font * scale, weight: weight),
          .foregroundColor: color, .paragraphStyle: paragraph,
        ])
      }
      let formatter = DateFormatter()
      formatter.locale = locale
      formatter.calendar = month.calendar
      formatter.timeZone = month.calendar.timeZone
      formatter.setLocalizedDateFormatFromTemplate("yMMMM")
      text(formatter.string(from: month.start), CGRect(x: rect.minX, y: rect.minY,
          width: rect.width, height: 35 * scale), 25, foreground, weight: .bold)
      let gridY = rect.minY + 58 * scale
      let rowHeight = (rect.maxY - gridY) / CGFloat(month.rows)
      let columnWidth = rect.width / 7
      let rowLayout = DailyWallpaperGeometry.rowLayout(height: rowHeight, scale: scale)
      let labelHeight = CGFloat(rowLayout.dateHeight)
      let eventHeight = CGFloat(rowLayout.eventHeight)
      let symbols = formatter.veryShortStandaloneWeekdaySymbols!
      for column in 0..<7 {
        let weekday = (month.calendar.firstWeekday - 1 + column) % 7
        let color = weekday == 0 ? red : weekday == 6 ? blue : foreground.withAlphaComponent(0.65)
        text(symbols[weekday], CGRect(x: rect.minX + CGFloat(column) * columnWidth, y: gridY - 20 * scale,
             width: columnWidth, height: 16 * scale), 10, color, weight: .semibold, alignment: .center)
      }
      for row in 0..<month.rows {
        let top = gridY + CGFloat(row) * rowHeight
        for column in 0..<7 {
          let date = month.days[row * 7 + column]
          guard date >= month.start && date < month.end else { continue }
          let x = rect.minX + CGFloat(column) * columnWidth
          let weekday = month.calendar.component(.weekday, from: date)
          let holiday = events.contains { $0.holiday && $0.start <= date && $0.end > date }
          let today = month.calendar.isDate(date, inSameDayAs: month.today)
          let color = holiday || weekday == 1 ? red : weekday == 7 ? blue : foreground
          if today {
            blue.setFill()
            let diameter = min(19 * scale, labelHeight + 2 * scale)
            UIBezierPath(ovalIn: CGRect(x: x + (columnWidth - diameter) / 2, y: top - scale,
                                       width: diameter, height: diameter)).fill()
          }
          text("\(month.calendar.component(.day, from: date))", CGRect(x: x, y: top, width: columnWidth,
               height: labelHeight), min(12, labelHeight * 0.8 / scale),
               today ? .white : color, weight: .semibold, alignment: .center)
        }
        let segments = month.segments(events: events, row: row)
        let required = segments.map { $0.lane + 1 }.max() ?? 0
        let laneCount = rowLayout.visibleLanes(required: required)
        for segment in segments where segment.lane < laneCount {
          let frame = CGRect(x: rect.minX + CGFloat(segment.startColumn) * columnWidth + scale,
            y: top + rowLayout.eventTop + CGFloat(segment.lane) * eventHeight,
            width: CGFloat(segment.endColumn - segment.startColumn + 1) * columnWidth - 2 * scale,
            height: eventHeight - 2 * scale)
          let raw = segment.event.color
          var color = UIColor(red: CGFloat((raw >> 16) & 255) / 255,
                              green: CGFloat((raw >> 8) & 255) / 255,
                              blue: CGFloat(raw & 255) / 255, alpha: 1)
          color = color.readableWallpaperColor(onDark: dark)
          color.withAlphaComponent(dark ? 0.22 : 0.12).setFill()
          UIBezierPath(roundedRect: frame, cornerRadius: 2.5 * scale).fill()
          text(segment.event.title, frame.insetBy(dx: 2 * scale, dy: 0), 8.5, color,
               weight: .medium, alignment: centered ? .center : .left)
          if segment.event.completed {
            color.wallpaperCompletionColor(onDark: dark).setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: frame.minX + 2 * scale, y: frame.midY))
            line.addLine(to: CGPoint(x: frame.maxX - 2 * scale, y: frame.midY))
            line.lineWidth = scale
            line.stroke()
          }
        }
        for column in 0..<7 {
          let extra = segments.filter { $0.lane >= laneCount && $0.startColumn <= column && $0.endColumn >= column }.count
          if extra > 0 && rowLayout.slots > 0 {
            text("+\(extra)", CGRect(x: rect.minX + CGFloat(column) * columnWidth,
                 y: top + rowLayout.eventTop + CGFloat(laneCount) * eventHeight,
                 width: columnWidth, height: eventHeight), 8, foreground.withAlphaComponent(0.65), alignment: .center)
          }
        }
      }
    }
  }
}

private extension UIColor {
  func wallpaperCompletionColor(onDark: Bool) -> UIColor {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    let rgb = [Double(r), Double(g), Double(b)]
    let alpha = onDark ? 0.22 : 0.12
    let surface = onDark ? 0.0 : 1.0
    func luminance(_ values: [Double]) -> Double {
      let linear = values.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
      return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722 + 0.05
    }
    let ink = luminance(rgb)
    let background = luminance(rgb.map { $0 * alpha + surface * (1 - alpha) })
    let midpoint = sqrt(ink * background) - 0.05
    let encoded = midpoint <= 0.0031308 ? midpoint * 12.92 : 1.055 * pow(midpoint, 1 / 2.4) - 0.055
    let c = Int((encoded * 255).rounded())
    func score(_ value: Int) -> Double {
      let l = luminance(Array(repeating: Double(value) / 255, count: 3))
      return min(max(l, ink) / min(l, ink), max(l, background) / min(l, background))
    }
    let best = [0, 255, c, max(0, c - 1), min(255, c + 1)]
      .max { score($0) < score($1) } ?? 0
    return UIColor(white: CGFloat(best) / 255, alpha: 1)
  }

  func readableWallpaperColor(onDark: Bool) -> UIColor {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func luminance(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat {
      func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
      return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
    for _ in 0..<24 {
      let lum = luminance(red, green, blue)
      let opacity: CGFloat = onDark ? 0.22 : 0.12
      let base: CGFloat = onDark ? 0 : 1
      let barLum = luminance(base * (1 - opacity) + red * opacity,
                             base * (1 - opacity) + green * opacity,
                             base * (1 - opacity) + blue * opacity)
      if (max(lum, barLum) + 0.05) / (min(lum, barLum) + 0.05) >= 4.5 { break }
      red = onDark ? red + (1 - red) * 0.12 : red * 0.88
      green = onDark ? green + (1 - green) * 0.12 : green * 0.88
      blue = onDark ? blue + (1 - blue) * 0.12 : blue * 0.88
    }
    return UIColor(red: red, green: green, blue: blue, alpha: 1)
  }
}

@available(iOS 16.0, *)
struct DailyWallpaperEnabledIntent: AppIntent {
  static var title = LocalizedStringResource("Daily Wallpaper Enabled", table: "WallpaperIntents")
  static var description = IntentDescription(LocalizedStringResource(
    "Returns whether Daily may generate a Lock Screen calendar.", table: "WallpaperIntents"))
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    .result(value: DailyWallpaperStore.settings.enabled && DailyWallpaperStore.settings.consentAccepted)
  }
}

@available(iOS 16.0, *)
struct DailyWallpaperSetupIntent: AppIntent {
  static var title = LocalizedStringResource("Daily Wallpaper Setup", table: "WallpaperIntents")
  static var description = IntentDescription(LocalizedStringResource(
    "Shows setup guidance in Shortcuts and asks before testing wallpaper updates.", table: "WallpaperIntents"))
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: LocalizedStringResource("Setup choice", table: "WallpaperIntents"))
  var choice: String?

  @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    let t = DailyWallpaperText.value
    // This interactive intent belongs only to the setup shortcut, never automation.
    let selected = try await $choice.requestDisambiguation(
      among: [t("showConnectionGuide"), t("testSetup"), t("closeHelper")],
      dialog: IntentDialog(stringLiteral: t("helperPrompt")))
    if selected == t("showConnectionGuide") {
      let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Daily"
      try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral:
        DailyWallpaperText.automationInstructions(appName: appName))))
      return .result(value: false)
    }
    guard selected == t("testSetup") else { return .result(value: false) }
    guard DailyWallpaperStore.settings.enabled && DailyWallpaperStore.settings.consentAccepted else {
      try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: t("helperDisabled"))))
      return .result(value: false)
    }
    try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: t("helperTestWarning"))))
    // Recheck after the user prompt; OFF/reset may have occurred while it was open.
    return .result(value: DailyWallpaperStore.settings.enabled && DailyWallpaperStore.settings.consentAccepted)
  }
}

@available(iOS 16.0, *)
struct GenerateDailyWallpaperIntent: AppIntent {
  static var title = LocalizedStringResource("Generate Daily Calendar Wallpaper", table: "WallpaperIntents")
  static var description = IntentDescription(LocalizedStringResource(
    "Creates a current-month calendar image. Does not change wallpaper by itself.", table: "WallpaperIntents"))
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: LocalizedStringResource("Update ID", table: "WallpaperIntents"))
  var updateID: String?

  @MainActor func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
    do {
      let data = try await DailyWallpaperStore.image()
      return .result(value: IntentFile(data: data, filename: "DailyCalendar-Wallpaper.png", type: .png))
    } catch {
      if let updateID, let id = UUID(uuidString: updateID) {
        try? await DailyWallpaperUpdateMonitor.finish(id: id, outcome: .failed, announce: true)
      }
      throw error
    }
  }
}

@available(iOS 16.0, *)
struct BeginDailyWallpaperUpdateIntent: AppIntent {
  static var title = LocalizedStringResource("Begin Daily Wallpaper Update", table: "WallpaperIntents")
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
    .result(value: try await DailyWallpaperUpdateMonitor.begin(source: .shortcut).uuidString)
  }
}

@available(iOS 16.0, *)
struct CompleteDailyWallpaperUpdateIntent: AppIntent {
  static var title = LocalizedStringResource("Record Wallpaper Action Completion", table: "WallpaperIntents")
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @Parameter(title: LocalizedStringResource("Update ID", table: "WallpaperIntents"))
  var updateID: String?
  @MainActor func perform() async throws -> some IntentResult {
    guard DailyWallpaperStore.settings.enabled && DailyWallpaperStore.settings.consentAccepted else {
      throw DailyWallpaperError.disabled
    }
    guard let updateID, let id = UUID(uuidString: updateID),
          DailyWallpaperUpdateMonitor.attempts.items.contains(where: {
            $0.id == id && $0.source == .shortcut && $0.outcome == .waiting
          }) else { throw DailyWallpaperError.invalidUpdateID }
    try await DailyWallpaperUpdateMonitor.finish(id: id, outcome: .systemReported)
    return .result()
  }
}

@MainActor
final class DailyWallpaperBridge: NSObject, @preconcurrency FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "daily/wallpaper", binaryMessenger: binaryMessenger)
    super.init()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reset":
        do { try DailyWallpaperStore.clear(); result(nil) }
        catch { result(FlutterError(code: "wallpaper_reset", message: error.localizedDescription, details: nil)) }
      case "openSettings":
        guard #available(iOS 16.0, *), UIDevice.current.userInterfaceIdiom == .phone,
              let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows }).first(where: \.isKeyWindow)?.rootViewController else {
          result(FlutterError(code: "wallpaper_unsupported", message: DailyWallpaperText.value("unsupported"), details: nil))
          return
        }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        let controller = UIHostingController(rootView: DailyWallpaperSettingsView())
        controller.modalPresentationStyle = .fullScreen
        presenter.present(controller, animated: true)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    handleURLs(connectionOptions?.urlContexts ?? [])
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    handleURLs(URLContexts)
  }

  private func handleURLs(_ contexts: Set<UIOpenURLContext>) -> Bool {
    contexts.reduce(false) { DailyWallpaperUpdateMonitor.handleCallback($1.url) || $0 }
  }
}
