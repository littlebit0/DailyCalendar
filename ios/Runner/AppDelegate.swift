import Flutter
import AuthenticationServices
import UIKit
import UserNotifications
import WidgetKit
import flutter_local_notifications
import AlarmKit
import SwiftUI
import CryptoKit
import EventKit
import AppIntents

private final class DailyAppleWidgets {
  static let channelName = "daily/apple_widgets"
  static let appGroup = "group.com.littlebit0.daily.widgets"
  static let snapshotFileName = "daily-widget-snapshot.json"
  static let todoActionsFileName = "daily-widget-todo-actions.json"
  static let todoActionsChangedNotification = "com.littlebit0.daily.widgetTodoActionsChanged"
  private static var channel: FlutterMethodChannel?
  private static var observesTodoActions = false
  private static let todoActionsCallback: CFNotificationCallback = {
    _, _, _, _, _ in
    DispatchQueue.main.async {
      DailyAppleWidgets.channel?.invokeMethod("todoActionsChanged", arguments: nil)
    }
  }

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel?.setMethodCallHandler { call, result in
      switch call.method {
      case "updateSnapshot":
        guard let snapshot = call.arguments as? [String: Any],
              JSONSerialization.isValidJSONObject(snapshot) else {
          result(FlutterError(code: "invalid_widget_snapshot", message: "위젯 데이터 형식이 올바르지 않습니다.", details: nil))
          return
        }
        do {
          try writeSnapshot(snapshot)
          reloadTimelines()
          if #available(iOS 18.0, *) {
            DailySiriSearchIndexer.scheduleRefresh()
          }
          result(nil)
        } catch {
          result(FlutterError(code: "widget_snapshot_failed", message: error.localizedDescription, details: nil))
        }
      case "pendingTodoActions":
        do {
          result(try loadTodoActions())
        } catch {
          result(FlutterError(code: "widget_todo_read_failed", message: error.localizedDescription, details: nil))
        }
      case "acknowledgeTodoActions":
        let arguments = call.arguments as? [String: Any]
        let tokens = Set(arguments?["tokens"] as? [String] ?? [])
        do {
          let remaining = try loadTodoActions().filter {
            guard let token = $0["token"] as? String else { return false }
            return !tokens.contains(token)
          }
          try writeTodoActions(remaining)
          result(nil)
        } catch {
          result(FlutterError(code: "widget_todo_ack_failed", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if !observesTodoActions {
      observesTodoActions = true
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        nil,
        todoActionsCallback,
        todoActionsChangedNotification as CFString,
        nil,
        .deliverImmediately
      )
    }
  }

  private static func reloadTimelines() {
    WidgetCenter.shared.reloadAllTimelines()
  }

  private static func containerURL() throws -> URL {
    guard let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else {
      throw NSError(
        domain: "DailyWidgets",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "위젯 공유 저장소를 열 수 없습니다."]
      )
    }
    return url
  }

  private static func writeSnapshot(_ snapshot: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: snapshot)
    try data.write(
      to: try containerURL().appendingPathComponent(snapshotFileName),
      options: .atomic
    )
  }

  private static func loadTodoActions() throws -> [[String: Any]] {
    let url = try containerURL().appendingPathComponent(todoActionsFileName)
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
  }

  private static func writeTodoActions(_ actions: [[String: Any]]) throws {
    let data = try JSONSerialization.data(withJSONObject: actions)
    try data.write(
      to: try containerURL().appendingPathComponent(todoActionsFileName),
      options: .atomic
    )
  }
}

private final class DailySiriLogsBridge {
  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "daily/siri_logs", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "listLogs":
        result(DailySiriLogStore.load().map { record in
          [
            "id": record.id,
            "occurredAt": Int64(record.occurredAt.timeIntervalSince1970 * 1000),
            "action": record.action,
            "summary": record.summary,
            "result": record.result,
            "success": record.success,
            "details": record.details ?? [:],
          ] as [String: Any]
        })
      case "clearLogs":
        DailySiriLogStore.clear()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class DailySiriEventChangesBridge {
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "daily/siri_event_changes",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pendingChanges":
        result(DailySiriEventChangeSignal.pending().map {
          [
            "token": $0.token,
            "eventId": $0.eventID,
            "action": $0.action,
            "reminderMinutesBefore": $0.reminderMinutesBefore,
          ]
        })
      case "acknowledgeChanges":
        let arguments = call.arguments as? [String: Any]
        DailySiriEventChangeSignal.acknowledge(tokens: arguments?["tokens"] as? [String] ?? [])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      { _, observer, _, _, _ in
        guard let observer else { return }
        let bridge = Unmanaged<DailySiriEventChangesBridge>
          .fromOpaque(observer)
          .takeUnretainedValue()
        DispatchQueue.main.async {
          bridge.channel.invokeMethod("eventsChanged", arguments: nil)
        }
      },
      DailySiriEventChangeSignal.notificationName as CFString,
      nil,
      .deliverImmediately
    )
  }

  deinit {
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(DailySiriEventChangeSignal.notificationName as CFString),
      nil
    )
  }
}

private final class DailyCalendarImport {
  static let channelName = "daily/calendar_import"
  private static let store = EKEventStore()

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "listCalendars":
        withAccess(result) { result(calendars()) }
      case "loadEvents":
        guard let arguments = call.arguments as? [String: Any],
              let calendarIds = arguments["calendarIds"] as? [String] else {
          result(FlutterError(code: "bad_arguments", message: "가져올 캘린더를 선택해 주세요.", details: nil))
          return
        }
        withAccess(result) { result(events(calendarIds: Set(calendarIds))) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func withAccess(
    _ result: @escaping FlutterResult,
    operation: @escaping () -> Void
  ) {
    let status = EKEventStore.authorizationStatus(for: .event)
    if status == .authorized {
      operation()
      return
    }
    if #available(iOS 17.0, *), status == .fullAccess {
      operation()
      return
    }
    let hasInsufficientAccess: Bool
    if #available(iOS 17.0, *) {
      hasInsufficientAccess = status == .denied || status == .restricted || status == .writeOnly
    } else {
      hasInsufficientAccess = status == .denied || status == .restricted
    }
    if hasInsufficientAccess {
      result(FlutterError(
        code: "calendar_permission_denied",
        message: "설정에서 Daily의 캘린더 전체 접근을 허용해 주세요.",
        details: nil
      ))
      return
    }
    if #available(iOS 17.0, *) {
      store.requestFullAccessToEvents { granted, error in
        DispatchQueue.main.async {
          finishAccess(granted: granted, error: error, result: result, operation: operation)
        }
      }
    } else {
      store.requestAccess(to: .event) { granted, error in
        DispatchQueue.main.async {
          finishAccess(granted: granted, error: error, result: result, operation: operation)
        }
      }
    }
  }

  private static func finishAccess(
    granted: Bool,
    error: Error?,
    result: @escaping FlutterResult,
    operation: @escaping () -> Void
  ) {
    if let error = error {
      result(FlutterError(code: "calendar_permission_failed", message: error.localizedDescription, details: nil))
    } else if granted {
      operation()
    } else {
      result(FlutterError(code: "calendar_permission_denied", message: "캘린더 접근이 허용되지 않았습니다.", details: nil))
    }
  }

  private static func calendars() -> [[String: Any]] {
    store.calendars(for: .event)
      .filter { calendar in
        calendar.type != .birthday && !isGoogleSource(calendar.source)
      }
      .map { calendar in
        [
          "id": calendar.calendarIdentifier,
          "title": calendar.title,
          "accountName": calendar.source.title,
          "colorValue": colorValue(calendar.cgColor),
        ]
      }
  }

  private static func events(calendarIds: Set<String>) -> [[String: Any]] {
    let selected = store.calendars(for: .event).filter {
      calendarIds.contains($0.calendarIdentifier) && !isGoogleSource($0.source)
    }
    guard !selected.isEmpty else { return [] }
    let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1970, month: 1, day: 1))!
    let end = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2101, month: 1, day: 1))!
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected)
    var seen = Set<String>()
    var values: [[String: Any]] = []
    for event in store.events(matching: predicate).sorted(by: { $0.startDate < $1.startDate }) {
      let sourceId = event.calendarItemIdentifier
      guard !sourceId.isEmpty, seen.insert(sourceId).inserted else { continue }
      var value: [String: Any] = [
        "sourceId": sourceId,
        "calendarId": event.calendar.calendarIdentifier,
        "title": event.title ?? "제목 없음",
        "startMilliseconds": Int64(event.startDate.timeIntervalSince1970 * 1000),
        "endMilliseconds": Int64(event.endDate.timeIntervalSince1970 * 1000),
        "allDay": event.isAllDay,
      ]
      if let notes = event.notes, !notes.isEmpty { value["memo"] = notes }
      if let location = event.location, !location.isEmpty { value["location"] = location }
      if let url = event.url?.absoluteString { value["url"] = url }
      if let rule = event.recurrenceRules?.first, let rrule = recurrenceValue(rule) {
        value["recurrenceRule"] = rrule
      }
      let reminderMinutes = Set((event.alarms ?? []).compactMap { alarm -> Int? in
        let secondsBefore: TimeInterval
        if let absoluteDate = alarm.absoluteDate {
          secondsBefore = event.startDate.timeIntervalSince(absoluteDate)
        } else {
          secondsBefore = -alarm.relativeOffset
        }
        guard secondsBefore >= 0 else { return nil }
        return Int((secondsBefore / 60).rounded())
      }).sorted()
      if !reminderMinutes.isEmpty {
        value["reminderMinutesBeforeList"] = reminderMinutes
      }
      values.append(value)
    }
    return values
  }

  private static func recurrenceValue(_ rule: EKRecurrenceRule) -> String? {
    let frequency: String
    switch rule.frequency {
    case .daily: frequency = "DAILY"
    case .weekly: frequency = "WEEKLY"
    case .monthly: frequency = "MONTHLY"
    case .yearly: frequency = "YEARLY"
    @unknown default: return nil
    }
    var fields = ["FREQ=\(frequency)", "INTERVAL=\(max(rule.interval, 1))"]
    if let count = rule.recurrenceEnd?.occurrenceCount, count > 0 {
      fields.append("COUNT=\(count)")
    } else if let date = rule.recurrenceEnd?.endDate {
      let formatter = DateFormatter()
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
      fields.append("UNTIL=\(formatter.string(from: date))")
    }
    return "RRULE:" + fields.joined(separator: ";")
  }

  private static func isGoogleSource(_ source: EKSource) -> Bool {
    let title = source.title.lowercased()
    return title.contains("google") || title.contains("gmail")
  }

  private static func colorValue(_ color: CGColor) -> Int64 {
    let uiColor = UIColor(cgColor: color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return Int64(0xff2563eb)
    }
    return Int64(round(alpha * 255)) << 24 |
      Int64(round(red * 255)) << 16 |
      Int64(round(green * 255)) << 8 |
      Int64(round(blue * 255))
  }
}

private final class DailyGoogleOAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
  static let channelName = "daily/google_oauth"

  private var session: ASWebAuthenticationSession?
  private var flutterResult: FlutterResult?
  private var fallbackPresentationWindow: UIWindow?

  func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "authorize":
        self?.authorize(call, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func authorize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard flutterResult == nil else {
      result(FlutterError(code: "busy", message: "Google 인증이 이미 진행 중입니다.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let urlValue = arguments["authorizationUrl"] as? String,
          let url = URL(string: urlValue),
          let callbackUrlScheme = arguments["callbackUrlScheme"] as? String,
          !callbackUrlScheme.isEmpty else {
      result(FlutterError(code: "bad_arguments", message: "Invalid Google OAuth arguments", details: nil))
      return
    }

    flutterResult = result
    startAuthorizationSession(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      allowPresentationRetry: true
    )
  }

  private func startAuthorizationSession(
    url: URL,
    callbackUrlScheme: String,
    allowPresentationRetry: Bool
  ) {
    let authSession = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: callbackUrlScheme
    ) { [weak self] callbackURL, error in
      guard let self = self else { return }
      if self.shouldRetryPresentation(error, allowPresentationRetry) {
        self.session = nil
        self.fallbackPresentationWindow?.isHidden = true
        self.fallbackPresentationWindow = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
          guard let self = self, self.flutterResult != nil else { return }
          self.startAuthorizationSession(
            url: url,
            callbackUrlScheme: callbackUrlScheme,
            allowPresentationRetry: false
          )
        }
        return
      }

      let pendingResult = self.flutterResult
      self.flutterResult = nil
      self.session = nil
      self.fallbackPresentationWindow?.isHidden = true
      self.fallbackPresentationWindow = nil

      if let callbackURL = callbackURL {
        pendingResult?(callbackURL.absoluteString)
        return
      }
      if let authError = error as? ASWebAuthenticationSessionError,
         authError.code == .canceledLogin {
        pendingResult?(FlutterError(code: "canceled", message: "Google Drive 연결이 취소되었습니다.", details: nil))
        return
      }
      pendingResult?(FlutterError(
        code: "failed",
        message: error?.localizedDescription ?? "Google 인증 창을 완료하지 못했습니다.",
        details: nil
      ))
    }
    authSession.presentationContextProvider = self
    authSession.prefersEphemeralWebBrowserSession = false
    session = authSession
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.session === authSession else { return }
      if authSession.start() {
        return
      }
      flutterResult = nil
      session = nil
      fallbackPresentationWindow?.isHidden = true
      fallbackPresentationWindow = nil
      let pendingResult = self.flutterResult
      self.flutterResult = nil
      pendingResult?(
        FlutterError(code: "failed", message: "Google 인증 창을 열 수 없습니다.", details: nil)
      )
    }
  }

  private func shouldRetryPresentation(_ error: Error?, _ allowPresentationRetry: Bool) -> Bool {
    guard allowPresentationRetry,
          let authError = error as? ASWebAuthenticationSessionError else {
      return false
    }
    return authError.code.rawValue == 3
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window = Self.activePresentationWindow() {
      return window
    }

    let foregroundScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { scene in
        scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
      }

    guard let windowScene = foregroundScenes.first else {
      return ASPresentationAnchor()
    }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UIViewController()
    window.windowLevel = .normal
    window.backgroundColor = .clear
    window.isHidden = false
    fallbackPresentationWindow = window
    return window
  }

  private static func activePresentationWindow() -> UIWindow? {
    let foregroundWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { scene in
        scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
      }
      .flatMap(\.windows)

    return foregroundWindows.first { $0.isKeyWindow }
      ?? foregroundWindows.first {
        !$0.isHidden && $0.alpha > 0 && $0.windowLevel == .normal
      }
      ?? foregroundWindows.first
  }
}

private final class DailyNativeNotifications {
  static let channelName = "daily/native_notifications"

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "cancelPending":
        cancelPending(call, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func cancelPending(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let id = intValue(arguments["id"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification id", details: nil))
      return
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [String(id)])
    result(nil)
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }
}

private final class DailyAlarmKit {
  static let channelName = "daily/alarm_kit"

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "authorizationState":
        result(authorizationStateName())
      case "requestAuthorization":
        requestAuthorization(result)
      case "schedule":
        schedule(call, result)
      case "cancel":
        cancel(call, result)
      case "cancelAll":
        cancelAll(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func authorizationStateName() -> String {
    guard #available(iOS 26.0, *) else { return "unsupported" }
    return stateName(AlarmManager.shared.authorizationState)
  }

  private static func requestAuthorization(_ result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result("unsupported")
      return
    }
    let current = AlarmManager.shared.authorizationState
    guard current == .notDetermined else {
      result(stateName(current))
      return
    }
    Task { @MainActor in
      do {
        result(stateName(try await AlarmManager.shared.requestAuthorization()))
      } catch {
        result(FlutterError(code: "alarm_authorization_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func schedule(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(FlutterError(code: "unsupported", message: "이 iOS 버전에서는 일정 알람을 사용할 수 없습니다.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let eventID = arguments["eventId"] as? String,
          !eventID.isEmpty,
          let title = arguments["title"] as? String,
          let fireAtMilliseconds = int64Value(arguments["fireAtMilliseconds"]),
          let snoozeMinutes = intValue(arguments["snoozeMinutes"]) else {
      result(FlutterError(code: "bad_arguments", message: "일정 알람 정보가 올바르지 않습니다.", details: nil))
      return
    }
    let id = alarmID(for: eventID)
    guard AlarmManager.shared.authorizationState == .authorized else {
      result(FlutterError(code: "alarm_permission_denied", message: "Daily의 알람 권한이 허용되지 않았습니다.", details: nil))
      return
    }

    let memo = (arguments["memo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let visibleMemo = memo.flatMap { $0.isEmpty ? nil : String($0.prefix(80)) }
    let displayTitle = visibleMemo.map { "\(title)\n\($0)" } ?? title
    let fireDate = Date(timeIntervalSince1970: Double(fireAtMilliseconds) / 1000)
    guard fireDate > Date() else {
      result(nil)
      return
    }

    Task { @MainActor in
      do {
        try? AlarmManager.shared.cancel(id: id)
        let secondaryButton = AlarmButton(
          text: "\(snoozeMinutes)분 후 다시 알림",
          textColor: .white,
          systemImageName: "clock.arrow.circlepath"
        )
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
          alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: displayTitle),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: .countdown
          )
        } else {
          let stopButton = AlarmButton(
            text: "중지",
            textColor: .white,
            systemImageName: "stop.circle"
          )
          alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: displayTitle),
            stopButton: stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: .countdown
          )
        }
        let countdown = AlarmPresentation.Countdown(
          title: "다시 알림까지",
          pauseButton: nil
        )
        let metadata = DailyAlarmMetadata(title: title, memo: visibleMemo)
        let attributes = AlarmAttributes(
          presentation: AlarmPresentation(alert: alert, countdown: countdown),
          metadata: metadata,
          tintColor: Color(red: 0.15, green: 0.39, blue: 0.92)
        )
        let configuration = AlarmManager.AlarmConfiguration(
          countdownDuration: Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: TimeInterval(snoozeMinutes * 60)
          ),
          schedule: .fixed(fireDate),
          attributes: attributes,
          sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        result(nil)
      } catch {
        result(FlutterError(code: "alarm_schedule_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(nil)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let eventID = arguments["eventId"] as? String,
          !eventID.isEmpty else {
      result(FlutterError(code: "bad_arguments", message: "일정 알람 ID가 올바르지 않습니다.", details: nil))
      return
    }
    let id = alarmID(for: eventID)
    do {
      try AlarmManager.shared.cancel(id: id)
      result(nil)
    } catch {
      // AlarmKit removes completed one-shot alarms, so an absent ID is already cancelled.
      result(nil)
    }
  }

  private static func cancelAll(_ result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(nil)
      return
    }
    do {
      for alarm in try AlarmManager.shared.alarms {
        try? AlarmManager.shared.cancel(id: alarm.id)
      }
      result(nil)
    } catch {
      result(FlutterError(code: "alarm_cancel_failed", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 26.0, *)
  private static func stateName(_ state: AlarmManager.AuthorizationState) -> String {
    switch state {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unsupported"
    }
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    return nil
  }

  private static func alarmID(for eventID: String) -> UUID {
    if let id = UUID(uuidString: eventID) {
      return id
    }
    var bytes = Array(SHA256.hash(data: Data(eventID.utf8)).prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x50
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }

  private static func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    return nil
  }
}

private final class DailyMapLauncher {
  static let channelName = "daily/map_launcher"

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "openLocation",
            let arguments = call.arguments as? [String: Any],
            let location = arguments["location"] as? String,
            !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        open(location: location, result: result)
      }
    }
  }

  private static func open(location: String, result: @escaping FlutterResult) {
    let candidates = installedCandidates(for: location)
    if candidates.count == 1, let candidate = candidates.first {
      open(candidate.url, fallbackLocation: location, result: result)
      return
    }
    guard candidates.count > 1, let presenter = topViewController() else {
      UIApplication.shared.open(webFallback(for: location), options: [:]) { _ in result("handled") }
      return
    }

    let alert = UIAlertController(title: "지도에서 열기", message: location, preferredStyle: .actionSheet)
    for candidate in candidates {
      alert.addAction(UIAlertAction(title: candidate.title, style: .default) { _ in
        open(candidate.url, fallbackLocation: location, result: result)
      })
    }
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in result("handled") })
    if let popover = alert.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    presenter.present(alert, animated: true)
  }

  private static func open(_ url: URL, fallbackLocation: String, result: @escaping FlutterResult) {
    UIApplication.shared.open(url, options: [:]) { success in
      guard !success else {
        result("handled")
        return
      }
      UIApplication.shared.open(webFallback(for: fallbackLocation), options: [:]) { _ in
        result("handled")
      }
    }
  }

  private static func installedCandidates(for location: String) -> [(title: String, url: URL)] {
    [
      ("카카오맵", url("kakaomap", host: "search", queryName: "q", location: location)),
      ("네이버지도", naverURL(for: location)),
      ("Apple 지도", url("maps", host: "", queryName: "q", location: location)),
    ].compactMap { title, url in
      guard let url = url, UIApplication.shared.canOpenURL(url) else { return nil }
      return (title, url)
    }
  }

  private static func url(_ scheme: String, host: String, queryName: String, location: String) -> URL? {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.queryItems = [URLQueryItem(name: queryName, value: location)]
    return components.url
  }

  private static func naverURL(for location: String) -> URL? {
    var components = URLComponents()
    components.scheme = "nmap"
    components.host = "search"
    components.queryItems = [
      URLQueryItem(name: "query", value: location),
      URLQueryItem(name: "appname", value: "com.littlebit0.daily"),
    ]
    return components.url
  }

  private static func webFallback(for location: String) -> URL {
    var components = URLComponents(string: "https://maps.apple.com/")!
    components.queryItems = [URLQueryItem(name: "q", value: location)]
    return components.url!
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let googleOAuthSession = DailyGoogleOAuthSession()
  private var siriEventChangesBridge: DailySiriEventChangesBridge?
  private var signalVoiceBridge: DailySignalVoiceBridge?
  private var wallpaperBridge: DailyWallpaperBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    if #available(iOS 16.0, *) {
      DailyAppShortcuts.updateAppShortcutParameters()
    }
    if #available(iOS 18.0, *) {
      DailySiriSearchIndexer.scheduleRefresh()
    }
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let registrar = registrar(forPlugin: "DailyNativeNotifications") {
      DailyNativeNotifications.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyAlarmKit") {
      DailyAlarmKit.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyGoogleOAuthSession") {
      googleOAuthSession.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyMapLauncher") {
      DailyMapLauncher.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyAppleWidgets") {
      DailyAppleWidgets.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyWallpaper") {
      let bridge = DailyWallpaperBridge(binaryMessenger: registrar.messenger())
      wallpaperBridge = bridge
      registrar.addSceneDelegate(bridge)
    }
    if let registrar = registrar(forPlugin: "DailyCalendarImport") {
      DailyCalendarImport.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailySiriLogsBridge") {
      DailySiriLogsBridge.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailySiriEventChangesBridge") {
      siriEventChangesBridge = DailySiriEventChangesBridge(
        binaryMessenger: registrar.messenger()
      )
    }
    if let registrar = registrar(forPlugin: "DailySignalVoiceBridge") {
      signalVoiceBridge = DailySignalVoiceBridge(
        binaryMessenger: registrar.messenger()
      )
    }
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.identifier.hasPrefix(DailyWallpaperUpdateMonitor.notificationPrefix) {
      completionHandler([.banner, .list, .sound])
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }
}
