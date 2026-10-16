import Cocoa
import FlutterMacOS
import LocalAuthentication
import UserNotifications
import WidgetKit
import WebKit
import StoreKit

private final class DailyAppleWidgets {
  static let channelName = "daily/apple_widgets"
  static let appGroup = "A6Y73X2ZLS.com.littlebit0.daily.widgets"
  static let snapshotFileName = "daily-widget-snapshot.json"
  static let todoActionsFileName = "daily-widget-todo-actions.json"
  static let todoActionsChangedNotification = Notification.Name(
    "com.littlebit0.daily.widgetTodoActionsChanged"
  )
  private static var channel: FlutterMethodChannel?
  private static var todoActionsObserver: NSObjectProtocol?

  static func register(with flutterViewController: FlutterViewController) {
    channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
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
          if #available(macOS 11.0, *) {
            reloadTimelines()
          }
          if #available(macOS 15.0, *) {
            DailySiriSearchIndexer.scheduleRefresh()
          }
          result(nil)
        } catch {
          NSLog("[DailyWidgets] Snapshot update failed: \(error.localizedDescription)")
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
          // Remove only the acknowledged tokens, re-reading under the lock so a
          // request the widget appended meanwhile stays queued.
          try withTodoActionsLock(in: try containerURL()) {
            let remaining = try loadTodoActions().filter {
              guard let token = $0["token"] as? String else { return false }
              return !tokens.contains(token)
            }
            try writeTodoActions(remaining)
          }
          result(nil)
        } catch {
          result(FlutterError(code: "widget_todo_ack_failed", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if todoActionsObserver == nil {
      todoActionsObserver = DistributedNotificationCenter.default().addObserver(
        forName: todoActionsChangedNotification,
        object: nil,
        queue: .main
      ) { _ in
        DailyAppleWidgets.channel?.invokeMethod("todoActionsChanged", arguments: nil)
      }
    }
  }

  @available(macOS 11.0, *)
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
  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "daily/siri_logs",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
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

  init(flutterViewController: FlutterViewController) {
    channel = FlutterMethodChannel(
      name: "daily/siri_event_changes",
      binaryMessenger: flutterViewController.engine.binaryMessenger
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

private final class DailyMacAlarms {
  static let channelName = "daily/alarm_kit"
  static let categoryIdentifier = "daily.event.alarm"
  static let snoozeActionIdentifier = "daily.event.alarm.snooze"
  static let stopActionIdentifier = "daily.event.alarm.stop"
  static let requestIdentifierPrefix = "daily-event-alarm-"

  private static let eventIdKey = "dailyAlarmEventId"
  private static let snoozeMinutesKey = "dailyAlarmSnoozeMinutes"

  static func register(with flutterViewController: FlutterViewController) {
    registerCategory()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "authorizationState":
        authorizationState(result)
      case "requestAuthorization":
        requestAuthorization(result)
      case "schedule", "reconcile":
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

  static func registerCategory() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { categories in
      let snooze = UNNotificationAction(
        identifier: snoozeActionIdentifier,
        title: "10분 후 다시 알림",
        options: []
      )
      let stop = UNNotificationAction(
        identifier: stopActionIdentifier,
        title: "중지",
        options: [.destructive]
      )
      let alarmCategory = UNNotificationCategory(
        identifier: categoryIdentifier,
        actions: [snooze, stop],
        intentIdentifiers: [],
        options: [.customDismissAction]
      )
      var updated = categories.filter { $0.identifier != categoryIdentifier }
      updated.insert(alarmCategory)
      center.setNotificationCategories(updated)
    }
  }

  static func handle(
    _ response: UNNotificationResponse,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard response.notification.request.content.categoryIdentifier == categoryIdentifier else {
      return false
    }

    let center = UNUserNotificationCenter.current()
    let identifier = response.notification.request.identifier
    switch response.actionIdentifier {
    case snoozeActionIdentifier:
      let content = response.notification.request.content.mutableCopy() as! UNMutableNotificationContent
      let rawMinutes = content.userInfo[snoozeMinutesKey] as? NSNumber
      let snoozeMinutes = max(rawMinutes?.intValue ?? 10, 1)
      let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(
          timeInterval: TimeInterval(snoozeMinutes * 60),
          repeats: false
        )
      )
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      center.removeDeliveredNotifications(withIdentifiers: [identifier])
      center.add(request) { error in
        if let error = error {
          NSLog("[DailyAlarm] Snooze failed: \(error.localizedDescription)")
        }
        completionHandler()
      }
    default:
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      center.removeDeliveredNotifications(withIdentifiers: [identifier])
      completionHandler()
    }
    return true
  }

  private static func authorizationState(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      finish(result, value: stateName(settings.authorizationStatus))
    }
  }

  private static func requestAuthorization(_ result: @escaping FlutterResult) {
    registerCategory()
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
      if let error = error {
        finish(result, error: error)
        return
      }
      authorizationState(result)
    }
  }

  private static func schedule(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let eventId = arguments["eventId"] as? String,
          !eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let title = arguments["title"] as? String,
          let fireAtMilliseconds = int64Value(arguments["fireAtMilliseconds"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid macOS alarm arguments", details: nil))
      return
    }

    let fireAt = Date(timeIntervalSince1970: TimeInterval(fireAtMilliseconds) / 1000.0)

    let snoozeMinutes = max(intValue(arguments["snoozeMinutes"]) ?? 10, 1)
    let memo = (arguments["memo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = memo.flatMap { $0.isEmpty ? nil : String($0.prefix(160)) }
      ?? "일정이 시작되었습니다."
    content.sound = .default
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "daily-event-alarms"
    let sourceData = (try? JSONSerialization.data(withJSONObject: [fireAtMilliseconds, title, memo ?? "", snoozeMinutes])) ?? Data()
    let sourceFingerprint = sourceData.base64EncodedString()
    content.userInfo = [
      eventIdKey: eventId,
      snoozeMinutesKey: snoozeMinutes,
      "dailyAlarmSource": sourceFingerprint,
    ]
    if #available(macOS 12.0, *) {
      content.interruptionLevel = .timeSensitive
    }

    let identifier = requestIdentifier(eventId)
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(
        timeInterval: max(fireAt.timeIntervalSinceNow, 1.0),
        repeats: false
      )
    )
    let center = UNUserNotificationCenter.current()
    let apply = {
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      center.removeDeliveredNotifications(withIdentifiers: [identifier])
      guard fireAt > Date() else { finish(result, value: false); return }
      center.add(request) { error in
        finish(result, error: error, value: true)
      }
    }
    guard call.method == "reconcile" else { apply(); return }
    let matches: (UNNotificationRequest) -> Bool = { existing in
      guard existing.identifier == identifier else { return false }
      let previous = existing.content.userInfo["dailyAlarmSource"] as? String
      return previous == sourceFingerprint || (previous == nil && fireAt <= Date())
    }
    center.getPendingNotificationRequests { pending in
      if pending.contains(where: matches) { finish(result, value: true); return }
      center.getDeliveredNotifications { delivered in
        if delivered.contains(where: { matches($0.request) }) { finish(result, value: true); return }
        apply()
      }
    }
  }

  private static func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let eventId = arguments["eventId"] as? String,
          !eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(FlutterError(code: "bad_arguments", message: "Invalid macOS alarm event id", details: nil))
      return
    }
    let identifiers = [requestIdentifier(eventId)]
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
    result(nil)
  }

  private static func cancelAll(_ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let pending = requests
        .map(\.identifier)
        .filter { $0.hasPrefix(requestIdentifierPrefix) }
      center.removePendingNotificationRequests(withIdentifiers: pending)
      center.getDeliveredNotifications { notifications in
        let delivered = notifications
          .map { $0.request.identifier }
          .filter { $0.hasPrefix(requestIdentifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
        finish(result)
      }
    }
  }

  private static func requestIdentifier(_ eventId: String) -> String {
    return requestIdentifierPrefix + eventId
  }

  private static func stateName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .authorized, .provisional:
      return "authorized"
    @unknown default:
      return "unsupported"
    }
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    return (value as? NSNumber)?.intValue
  }

  private static func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 {
      return value
    }
    if let value = value as? Int {
      return Int64(value)
    }
    return (value as? NSNumber)?.int64Value
  }

  private static func finish(
    _ result: @escaping FlutterResult,
    error: Error? = nil,
    value: Any? = nil
  ) {
    DispatchQueue.main.async {
      if let error = error {
        result(FlutterError(
          code: "macos_alarm_error",
          message: error.localizedDescription,
          details: "\(error)"
        ))
      } else {
        result(value)
      }
    }
  }
}

private final class DailyNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = DailyNotificationCenterDelegate()

  static func install() {
    UNUserNotificationCenter.current().delegate = shared
    DailyMacAlarms.registerCategory()
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if DailyMacAlarms.handle(response, completionHandler: completionHandler) {
      return
    }
    completionHandler()
  }
}

private final class DailyNativeNotifications {
  static let channelName = "daily/native_notifications"

  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "initialize":
        initialize(result)
      case "checkPermissions":
        checkPermissions(result)
      case "show":
        show(call, result)
      case "schedule":
        schedule(call, result)
      case "cancel":
        cancel(call, result)
      case "cancelPending":
        cancelPending(call, result)
      case "pendingCount":
        pendingCount(result)
      case "deliveredCount":
        deliveredCount(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func initialize(_ result: @escaping FlutterResult) {
    DailyNotificationCenterDelegate.install()
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
      finish(result, error: error, value: granted)
    }
  }

  private static func checkPermissions(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value: [String: Any] = [
        "isEnabled": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
        "isSoundEnabled": settings.soundSetting == .enabled,
        "isAlertEnabled": settings.alertSetting == .enabled,
        "isBadgeEnabled": settings.badgeSetting == .enabled,
        "notificationCenterEnabled": settings.notificationCenterSetting == .enabled,
        "alertStyle": settings.alertStyle.rawValue,
        "scheduledDeliveryEnabled": scheduledDeliveryEnabled(settings),
      ]
      finish(result, value: value)
    }
  }

  private static func scheduledDeliveryEnabled(_ settings: UNNotificationSettings) -> Bool {
    if #available(macOS 12.0, *) {
      return settings.scheduledDeliverySetting == .enabled
    }
    return true
  }

  private static func show(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification arguments", details: nil))
      return
    }
    DailyNotificationCenterDelegate.install()
    addNotification(from: arguments, trigger: nil, result)
  }

  private static func schedule(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let scheduledAtMillis = int64Value(arguments["scheduledAtMillis"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification schedule arguments", details: nil))
      return
    }

    let scheduledDate = Date(timeIntervalSince1970: TimeInterval(scheduledAtMillis) / 1000.0)
    let repeatsDaily = arguments["repeatsDaily"] as? Bool == true
    let trigger: UNNotificationTrigger
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    if repeatsDaily {
      let components = calendar.dateComponents([.hour, .minute, .second, .timeZone], from: scheduledDate)
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    } else {
      trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: max(scheduledDate.timeIntervalSinceNow, 1.0),
        repeats: false
      )
    }
    DailyNotificationCenterDelegate.install()
    addNotification(from: arguments, trigger: trigger, result)
  }

  private static func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let id = intValue(arguments["id"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification id", details: nil))
      return
    }
    let identifiers = [String(id)]
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
    result(nil)
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

  private static func pendingCount(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      finish(result, value: requests.count)
    }
  }

  private static func deliveredCount(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      finish(result, value: notifications.count)
    }
  }

  private static func notificationRequest(
    from arguments: [String: Any],
    trigger: UNNotificationTrigger?,
    settings: UNNotificationSettings
  ) -> UNNotificationRequest? {
    guard let id = intValue(arguments["id"]) else {
      return nil
    }
    let content = UNMutableNotificationContent()
    content.title = arguments["title"] as? String ?? "Daily"
    content.body = arguments["body"] as? String ?? ""
    content.sound = .default
    content.userInfo = ["payload": arguments["payload"] as? String ?? ""]
    if #available(macOS 12.0, *) {
      content.interruptionLevel = .active
    }
    return UNNotificationRequest(
      identifier: String(id),
      content: content,
      trigger: trigger
    )
  }

  private static func addNotification(
    from arguments: [String: Any],
    trigger: UNNotificationTrigger?,
    _ result: @escaping FlutterResult
  ) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard let request = notificationRequest(from: arguments, trigger: trigger, settings: settings) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "bad_arguments",
            message: "Invalid notification request arguments",
            details: nil
          ))
        }
        return
      }
      add(request, result)
    }
  }

  private static func add(_ request: UNNotificationRequest, _ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
    center.add(request) { error in
      finish(result, error: error, value: nil)
    }
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

  private static func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 {
      return value
    }
    if let value = value as? Int {
      return Int64(value)
    }
    if let value = value as? NSNumber {
      return value.int64Value
    }
    return nil
  }

  private static func finish(
    _ result: @escaping FlutterResult,
    error: Error? = nil,
    value: Any?
  ) {
    DispatchQueue.main.async {
      if let error = error {
        result(FlutterError(
          code: "notification_error",
          message: error.localizedDescription,
          details: "\(error)"
        ))
        return
      }
      result(value)
    }
  }
}

private final class DailyMapLauncher {
  static let channelName = "daily/map_launcher"

  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openLocation",
            let arguments = call.arguments as? [String: Any],
            let location = arguments["location"] as? String,
            !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "지도에서 열기"
        alert.informativeText = location
        alert.addButton(withTitle: "카카오맵")
        alert.addButton(withTitle: "네이버지도")
        alert.addButton(withTitle: "Apple 지도")
        alert.addButton(withTitle: "취소")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
          result("kakao")
        case .alertSecondButtonReturn:
          result("naver")
        case .alertThirdButtonReturn:
          result("apple")
        default:
          result("handled")
        }
      }
    }
  }
}

private final class DailyMacAuthentication {
  static let channelName = "daily/apple_authentication"

  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "isBiometricsOrCompanionAvailable" {
        let context = LAContext()
        var error: NSError?
        result(context.canEvaluatePolicy(companionPolicy, error: &error))
        return
      }
      guard call.method == "authenticateBiometricsOrCompanion" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let reason = arguments?["localizedReason"] as? String
        ?? "Daily 잠금을 해제하려면 인증이 필요합니다."
      authenticate(reason: reason, result: result)
    }
  }

  private static func authenticate(
    reason: String,
    result: @escaping FlutterResult
  ) {
    let context = LAContext()
    let policy = companionPolicy
    var error: NSError?
    guard context.canEvaluatePolicy(policy, error: &error) else {
      result(false)
      return
    }
    context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    }
  }

  private static var companionPolicy: LAPolicy {
    if #available(macOS 15.0, *) {
      return .deviceOwnerAuthenticationWithBiometricsOrCompanion
    } else {
      return .deviceOwnerAuthenticationWithBiometricsOrWatch
    }
  }
}

private final class DailyAppLockPrivacy {
  static let channelName = "daily/app_lock_privacy"
  private static var retainedInstance: DailyAppLockPrivacy?

  private weak var window: NSWindow?
  private var enabled = false
  private var method = "noPin"
  private var authenticationSuppressed = false
  private var overlay: NSView?
  private var resignObserver: NSObjectProtocol?
  private var activeObserver: NSObjectProtocol?

  static func register(
    with flutterViewController: FlutterViewController,
    window: NSWindow
  ) {
    let instance = DailyAppLockPrivacy(window: window)
    retainedInstance = instance
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak instance] call, result in
      if call.method == "setAuthenticationSuppressed",
         let arguments = call.arguments as? [String: Any],
         let suppressed = arguments["suppressed"] as? Bool {
        DispatchQueue.main.async {
          instance?.authenticationSuppressed = suppressed
          if suppressed {
            instance?.hideOverlay()
          }
          result(nil)
        }
        return
      }
      guard call.method == "setEnabled",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        instance?.enabled = enabled
        if let method = arguments["method"] as? String {
          instance?.method = method
        }
        if enabled && !NSApp.isActive && instance?.authenticationSuppressed != true {
          instance?.showOverlay()
        } else if !enabled {
          instance?.hideOverlay()
        } else {
          instance?.updateOverlayText()
        }
        result(nil)
      }
    }
  }

  private init(window: NSWindow) {
    self.window = window
    resignObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      if self?.enabled == true && self?.authenticationSuppressed != true {
        self?.showOverlay()
      }
    }
    activeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.hideOverlay()
    }
  }

  deinit {
    if let resignObserver {
      NotificationCenter.default.removeObserver(resignObserver)
    }
    if let activeObserver {
      NotificationCenter.default.removeObserver(activeObserver)
    }
  }

  private func showOverlay() {
    guard overlay == nil, let contentView = window?.contentView else { return }
    let view = NSView(frame: contentView.bounds)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      imageView.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "잠금")
      imageView.contentTintColor = .secondaryLabelColor
    }

    let label = NSTextField(labelWithString: overlayText)
    label.identifier = NSUserInterfaceItemIdentifier("daily-lock-overlay-label")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.alignment = .center
    label.font = .systemFont(ofSize: 20, weight: .semibold)
    label.textColor = .labelColor

    view.addSubview(imageView)
    view.addSubview(label)
    contentView.addSubview(view, positioned: .above, relativeTo: nil)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      view.topAnchor.constraint(equalTo: contentView.topAnchor),
      view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -26),
      imageView.widthAnchor.constraint(equalToConstant: 32),
      imageView.heightAnchor.constraint(equalToConstant: 32),
      label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 14),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
    ])
    overlay = view
  }

  private func hideOverlay() {
    overlay?.removeFromSuperview()
    overlay = nil
  }

  private func updateOverlayText() {
    guard let label = overlay?.subviews.compactMap({ $0 as? NSTextField }).first else {
      return
    }
    label.stringValue = overlayText
  }

  private var overlayText: String {
    method == "noPin"
      ? "잠금 상태에서는 화면을 볼 수 없습니다."
      : "잠금 상태입니다."
  }
}

class MainFlutterWindow: NSWindow {
  private var siriEventChangesBridge: DailySiriEventChangesBridge?
  private var signalVoiceBridge: DailySignalVoiceBridge?
  private var passwordInputBridge: DailyPasswordInputBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 800, height: 600)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    passwordInputBridge = DailyPasswordInputBridge(
      messenger: flutterViewController.engine.binaryMessenger, window: self
    )
    DailyNativeNotifications.register(with: flutterViewController)
    DailyMacAlarms.register(with: flutterViewController)
    DailyMapLauncher.register(with: flutterViewController)
    DailyDotIntegration.register(with: flutterViewController)
    DailyAppleWidgets.register(with: flutterViewController)
    DailyLmsCookieStore.register(with: flutterViewController.engine.binaryMessenger)
    DailySiriLogsBridge.register(with: flutterViewController)
    siriEventChangesBridge = DailySiriEventChangesBridge(
      flutterViewController: flutterViewController
    )
    signalVoiceBridge = DailySignalVoiceBridge(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    DailyMacAuthentication.register(with: flutterViewController)
    DailyAppLockPrivacy.register(with: flutterViewController, window: self)
    DailyNotificationCenterDelegate.install()

    super.awakeFromNib()
  }
}

// Restricts only the focused Daily password editor, not global keyboard settings.
private final class DailyPasswordInputBridge {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var requested = false
  private var context: NSTextInputContext?
  private var previousLocales: [String]?
  private var previousSource: NSTextInputSourceIdentifier?
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    self.window = window
    channel = FlutterMethodChannel(name: "daily/password_input", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      guard call.method == "setEnglishInput" else {
        result(FlutterMethodNotImplemented); return
      }
      guard let enabled = call.arguments as? Bool else {
        result(FlutterError(code: "invalid_password_input_mode", message: nil, details: nil)); return
      }
      requested = enabled
      if enabled {
        result(apply())
      } else {
        restore()
        result(true)
      }
    }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
      self?.restore()
    })
    observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
      guard let self, requested else { return }
      _ = apply()
    })
    observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
      self?.requested = false
      self?.restore()
    })
  }

  private func apply() -> Bool {
    guard requested, let window, window.isKeyWindow,
          let editor = window.firstResponder as? NSTextView,
          let active = editor.inputContext else { return false }
    if context === active { return true }
    restore()
    context = active
    previousLocales = active.allowedInputSourceLocales
    previousSource = active.selectedKeyboardInputSource
    active.allowedInputSourceLocales = ["en"]
    // English layouts are selected from those offered by this input context.
    // The locale restriction remains active when a language-toggle key is used.
    if let source = active.keyboardInputSources?.first(where: {
      $0 == "com.apple.keylayout.ABC" || $0 == "com.apple.keylayout.US"
    }) {
      active.selectedKeyboardInputSource = source
    }
    return true
  }

  private func restore() {
    guard let active = context else { return }
    active.allowedInputSourceLocales = previousLocales
    if let source = previousSource { active.selectedKeyboardInputSource = source }
    context = nil
    previousLocales = nil
    previousSource = nil
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
    restore()
  }
}

// The school browser uses a nonpersistent WKWebsiteDataStore. This channel is
// callable only by Daily, never exposed as a JavaScript message handler.
private final class DailyLmsCookieStore {
  private static var stores: [String: WKWebsiteDataStore] = [:]
  // BEGIN LMS COOKIE READ POLICY
  private static let hosts: Set<String> = ["ecampus.smu.ac.kr", "sel.jnu.ac.kr"]
  private static func sessionName(_ name: String) -> Bool {
    name == "MoodleSession" || name.hasPrefix("MoodleSession_")
  }
  static func permitsSessionCookie(_ cookie: HTTPCookie, host: String) -> Bool {
    // Issuance flags are not authentication evidence: the official school can
    // omit Secure/HttpOnly on a valid session. Only read the bound private store.
    hosts.contains(host) && sessionName(cookie.name) &&
      cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == host
  }
  // END LMS COOKIE READ POLICY
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "daily/lms_cookie_store", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
            let host = args["host"] as? String, hosts.contains(host) else {
        result(FlutterError(code: "invalid_school", message: nil, details: nil)); return
      }
      if call.method == "canStartHeadless" {
        // flutter_inappwebview 1.1.2 attaches a new headless wrapper to this
        // exact parent. Its registry is internal, so an unattached view cannot
        // be safely found by a public API. Defer without activating a window.
        result(NSApplication.shared.mainWindow?.contentView != nil)
        return
      }
      if call.method == "bind" {
        guard let marker = args["marker"] as? String, marker.count >= 32,
              marker.count <= 160 else {
          result(FlutterError(code: "invalid_marker", message: nil, details: nil)); return
        }
        let candidates = schoolViews(host: host)
        guard !candidates.isEmpty else {
          result(FlutterError(code: "school_view_missing", message: nil, details: nil)); return
        }
        let group = DispatchGroup()
        var matches: [WKWebsiteDataStore] = []
        var scriptFailures = 0
        for view in candidates {
          group.enter()
          view.evaluateJavaScript("window.name") { name, error in
            if error != nil { scriptFailures += 1 }
            if error == nil, name as? String == marker,
               view.url?.host == host, !view.configuration.websiteDataStore.isPersistent {
              matches.append(view.configuration.websiteDataStore)
            }
            group.leave()
          }
        }
        group.notify(queue: .main) {
          guard matches.count == 1, let store = matches.first else {
            let code = matches.count > 1 ? "school_view_ambiguous"
              : scriptFailures > 0 ? "school_script_unavailable" : "school_marker_missing"
            result(FlutterError(code: code, message: nil, details: nil)); return
          }
          stores[host] = store
          result(true)
        }
        return
      }
      guard let store = stores[host], !store.isPersistent else {
        if call.method == "clear" { result(true) }
        else { result(FlutterError(code: "school_view_missing", message: nil, details: nil)) }
        return
      }
      switch call.method {
      case "read":
        store.httpCookieStore.getAllCookies { cookies in
          result(cookies.filter { cookie in
            permitsSessionCookie(cookie, host: host)
          }.map { cookie -> [String: Any] in
            var value: [String: Any] = ["name": cookie.name, "value": cookie.value]
            if let expiry = cookie.expiresDate {
              value["expires"] = Int64(expiry.timeIntervalSince1970 * 1000)
            }
            return value
          })
        }
      case "write":
        guard let values = args["cookies"] as? [[String: Any]], values.count <= 16 else {
          result(FlutterError(code: "invalid_cookies", message: nil, details: nil)); return
        }
        var cookies: [HTTPCookie] = []
        for value in values {
          guard let name = value["name"] as? String, sessionName(name),
                let content = value["value"] as? String, content.utf8.count <= 8192 else {
            result(FlutterError(code: "invalid_cookies", message: nil, details: nil)); return
          }
          var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name, .value: content, .domain: host, .path: "/",
            .secure: "TRUE", HTTPCookiePropertyKey("HttpOnly"): "TRUE"
          ]
          if let milliseconds = value["expires"] as? NSNumber {
            let expiry = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
            if expiry <= Date() { continue }
            properties[.expires] = expiry
          }
          guard let cookie = HTTPCookie(properties: properties) else {
            result(FlutterError(code: "invalid_cookies", message: nil, details: nil)); return
          }
          cookies.append(cookie)
        }
        let group = DispatchGroup()
        for cookie in cookies {
          group.enter()
          store.httpCookieStore.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { result(true) }
      case "clear":
        stores.removeValue(forKey: host)
        // This store belongs exclusively to the bound private school WebView.
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: .distantPast) { result(true) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private static func schoolViews(host: String) -> [WKWebView] {
    func walk(_ view: NSView) -> [WKWebView] {
      var result = view.subviews.flatMap(walk)
      if let web = view as? WKWebView, web.url?.host == host,
         !web.configuration.websiteDataStore.isPersistent { result.append(web) }
      return result
    }
    return NSApplication.shared.windows.compactMap(\.contentView).flatMap(walk)
  }
}

@MainActor
private enum DailyDotIntegration {

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "daily/dot_integration",
      binaryMessenger: controller.engine.binaryMessenger
    )
    // Keep every app entry point closed while direct Dot tool access is unresolved.
    // Do not initialize purchases, export folders, or status watchers.
    channel.setMethodCallHandler { _, result in
      result(FlutterError(code: "integration_disabled", message: "Dot integration is suspended.", details: nil))
    }
  }
}

@available(macOS 12.0, *)
@MainActor
private final class DailyDotPurchases {
  // Non-consumable. Registration and KRW 1,000 pricing belong in App Store Connect.
  private let productID = "com.littlebit0.daily.dot.unlock"
  private let channel: FlutterMethodChannel
  private var updates: Task<Void, Never>?
  private var purchasing = false
  private var exportDirectory: URL?
  private var scopedDirectory: URL?
  private var statusWatcher: DispatchSourceFileSystemObject?

  private func watchStatus(in root: URL) {
    guard statusWatcher == nil else { return }
    let directory = root.appendingPathComponent("status", isDirectory: true)
    let descriptor = open(directory.path, O_EVTONLY)
    guard descriptor >= 0 else { return }
    let watcher = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
    watcher.setEventHandler { [weak self, weak watcher] in
      Task { @MainActor in
        guard let self, let watcher else { return }
        if watcher.data.contains(.delete) || watcher.data.contains(.rename) {
          self.statusWatcher?.cancel()
          self.statusWatcher = nil
        }
        self.channel.invokeMethod("setupChanged", arguments: nil)
      }
    }
    watcher.setCancelHandler { close(descriptor) }
    statusWatcher = watcher
    watcher.resume()
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    updates = Task { [weak self] in
      for await verification in StoreKit.Transaction.updates {
        guard let self else { return }
        switch verification {
        case .verified(let transaction):
          guard transaction.productID == self.productID else { continue }
          await transaction.finish()
          self.channel.invokeMethod("purchaseChanged", arguments: nil)
        case .unverified(let transaction, _):
          if transaction.productID == self.productID {
            self.channel.invokeMethod("purchaseChanged", arguments: nil)
          }
        }
      }
    }
  }

  deinit {
    updates?.cancel()
    statusWatcher?.cancel()
    scopedDirectory?.stopAccessingSecurityScopedResource()
  }

  private func exportRoot(in directory: URL) throws -> URL {
    let path = directory.resolvingSymlinksInPath().path
    guard !path.contains("/Library/Containers/"), !path.contains("/Library/Group Containers/"),
          !path.hasSuffix("/Library/Containers"), !path.hasSuffix("/Library/Group Containers") else {
      throw PurchaseError.protectedFolder
    }
    let root = directory.appendingPathComponent("DailyCalendar Dot-\(getuid())", isDirectory: true)
    let manager = FileManager.default
    if !manager.fileExists(atPath: root.path) {
      try manager.createDirectory(at: root, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700])
    }
    let attributes = try manager.attributesOfItem(atPath: root.path)
    guard attributes[.type] as? FileAttributeType == .typeDirectory,
          (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
          root.resolvingSymlinksInPath().standardizedFileURL.path == root.standardizedFileURL.path else {
      throw PurchaseError.protectedFolder
    }
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    return root
  }

  // A deep link does not grant ChatGPT access to this app's protected container.
  // Use a user-selected folder, and keep all request/receipt paths there too.
  private func integrationRoot(allowSelection: Bool = false) async throws -> URL {
    if let directory = exportDirectory { return directory }
    let key = "daily.dot.exportBookmark"
    if let bookmark = UserDefaults.standard.data(forKey: key) {
      var stale = false
      if let directory = try? URL(resolvingBookmarkData: bookmark,
          options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale),
         directory.startAccessingSecurityScopedResource() {
        if FileManager.default.fileExists(atPath: directory.path) {
          let root: URL
          do { root = try exportRoot(in: directory) }
          catch { directory.stopAccessingSecurityScopedResource(); throw error }
          scopedDirectory = directory
          exportDirectory = root
          if stale, let refreshed = try? directory.bookmarkData(options: [.withSecurityScope],
              includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: key)
          }
          return root
        }
        directory.stopAccessingSecurityScopedResource()
      }
    }
    guard allowSelection else { throw PurchaseError.folderRequired }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.directoryURL = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
    panel.message = NSLocalizedString("DailyCalendar와 ChatGPT가 함께 사용할 연결 폴더를 선택하세요. 앱 보호 폴더는 사용할 수 없습니다.", comment: "Dot export folder")
    panel.prompt = NSLocalizedString("연결 폴더 선택", comment: "Dot export folder")
    let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
      panel.begin { continuation.resume(returning: $0) }
    }
    guard response == .OK, let directory = panel.url else { throw PurchaseError.folderCancelled }
    guard directory.startAccessingSecurityScopedResource() else { throw PurchaseError.folderRequired }
    do {
      let bookmark = try directory.bookmarkData(options: [.withSecurityScope],
        includingResourceValuesForKeys: nil, relativeTo: nil)
      let root = try exportRoot(in: directory)
      UserDefaults.standard.set(bookmark, forKey: key)
      scopedDirectory = directory
      exportDirectory = root
      return root
    } catch {
      directory.stopAccessingSecurityScopedResource()
      throw error
    }
  }

  private var testAccess: Bool {
    Bundle.main.bundleIdentifier == "com.littlebit0.daily.test"
  }

  private func canUseDot() async throws -> Bool {
    if testAccess { return true }
    return try await unlocked()
  }

  private func unlocked() async throws -> Bool {
    for await verification in StoreKit.Transaction.currentEntitlements {
      switch verification {
      case .verified(let transaction):
        if transaction.productID == productID,
           transaction.productType == .nonConsumable,
           transaction.revocationDate == nil,
           !transaction.isUpgraded { return true }
      case .unverified(let transaction, _):
        if transaction.productID == productID {
          throw PurchaseError.unverified
        }
      }
    }
    return false
  }

  private func product() async throws -> Product? {
    try await Product.products(for: [productID]).first {
      $0.id == productID && $0.type == .nonConsumable &&
      $0.priceFormatStyle.currencyCode == "KRW" && $0.price == Decimal(1000)
    }
  }

  private func status() async throws -> [String: Any] {
    if testAccess {
      return ["unlocked": false, "testAccess": true, "available": false,
              "price": "", "productID": productID]
    }
    let owned = try await unlocked()
    // A store outage must not discard an independently verified entitlement.
    let item = try? await product()
    return ["unlocked": owned, "available": item != nil,
            "price": item?.displayPrice ?? "", "productID": productID]
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    do {
      switch call.method {
      case "requestSetup":
        guard try await canUseDot() else { throw PurchaseError.locked }
        guard let action = call.arguments as? String,
              ["connect", "check", "read"].contains(action),
              let nonce = UserDefaults.standard.string(forKey: "daily.dot.statusNonce") else {
          throw PurchaseError.unavailable
        }
        let directory = try await integrationRoot().appendingPathComponent("status", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
          attributes: [.posixPermissions: 0o700])
        if let root = exportDirectory { watchStatus(in: root) }
        let identifier = UUID().uuidString
        let request: [String: Any] = ["nonce": nonce, "id": identifier,
          "action": action, "createdAt": Date().timeIntervalSince1970]
        let file = directory.appendingPathComponent("request.json")
        try JSONSerialization.data(withJSONObject: request).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        result(identifier)
      case "openGoogle":
        let directory = try await integrationRoot().appendingPathComponent("status", isDirectory: true)
        let data = try Data(contentsOf: directory.appendingPathComponent("connection.json"))
        guard let state = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              state["nonce"] as? String == UserDefaults.standard.string(forKey: "daily.dot.statusNonce"),
              let address = state["authURL"] as? String, let url = URL(string: address),
              url.scheme == "http", url.host == "127.0.0.1", url.port != nil,
              url.path.hasPrefix("/connect/"), NSWorkspace.shared.open(url) else {
          throw PurchaseError.unavailable
        }
        result(nil)
      case "setupStatus":
        guard let root = try? await integrationRoot() else { result([:]); return }
        watchStatus(in: root)
        let prepared = filesPrepared(in: root)
        let file = root.appendingPathComponent("status/connection.json")
        if let data = try? Data(contentsOf: file),
           let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nonce = UserDefaults.standard.string(forKey: "daily.dot.statusNonce"),
           state["nonce"] as? String == nonce,
           state["pluginVersion"] as? String == "0.1.3",
           let checked = state["checkedAt"] as? Double,
           Date().timeIntervalSince1970 - checked >= 0 {
          let now = Date().timeIntervalSince1970
          let googleChecked = state["googleCheckedAt"] as? Double ?? 0
          let queried = state["lastQuery"] as? Double ?? 0
          result(["filesPrepared": prepared, "pluginReady": state["pluginReady"] as? Bool ?? false,
                  "googleConnected": (state["googleConnected"] as? Bool == true) &&
                    now - googleChecked >= 0,
                  "lastQuery": now - queried >= 0 && now - queried < 300 ? queried as Any : NSNull(),
                  "requestAction": state["requestAction"] ?? NSNull(),
                  "queryPhase": state["queryPhase"] ?? NSNull(),
                  "filesRead": state["filesRead"] ?? 0,
                  "filesTotal": state["filesTotal"] ?? 0,
                  "requestCreatedAt": state["requestCreatedAt"] ?? NSNull(),
                  "errorCode": state["errorCode"] ?? NSNull(),
                  "requestID": state["requestID"] ?? NSNull(),
                  "requestState": state["requestState"] ?? NSNull(),
                  "hasAuthURL": state["authURL"] is String])
        } else {
          result(["filesPrepared": prepared])
        }
      case "preparePlugin":
        guard try await canUseDot() else { throw PurchaseError.locked }
        guard let payload = call.arguments as? FlutterStandardTypedData,
              payload.data.count >= 4, payload.data.count <= 4 * 1024 * 1024,
              payload.data.prefix(4) == Data([0x50, 0x4b, 0x03, 0x04]) else {
          throw PurchaseError.unavailable
        }
        try await preparePlugin(payload.data)
        result(nil)
      case "openPlugin":
        guard try await canUseDot() else { throw PurchaseError.locked }
        try await openPlugin()
        result(nil)
      case "openDot":
        guard let url = URL(string: "codex://dots"), NSWorkspace.shared.open(url) else {
          throw PurchaseError.chatgptUnavailable
        }
        result(nil)
      case "purchaseStatus":
        result(try await status())
      case "restorePurchases":
        guard !purchasing else { throw PurchaseError.busy }
        purchasing = true
        defer { purchasing = false }
        try await AppStore.sync()
        result(try await status())
      case "purchase":
        guard !purchasing else { throw PurchaseError.busy }
        purchasing = true
        defer { purchasing = false }
        if try await unlocked() { result("purchased"); return }
        guard let item = try await product() else { throw PurchaseError.unavailable }
        switch try await item.purchase() {
        case .success(let verification):
          guard case .verified(let transaction) = verification,
                transaction.productID == productID,
                transaction.productType == .nonConsumable,
                transaction.revocationDate == nil else { throw PurchaseError.unverified }
          await transaction.finish()
          result("purchased")
        case .pending: result("pending")
        case .userCancelled: result("cancelled")
        @unknown default: throw PurchaseError.unavailable
        }
      default: result(FlutterMethodNotImplemented)
      }
    } catch let error as PurchaseError {
      result(FlutterError(code: error.rawValue, message: nil, details: nil))
    } catch {
      result(FlutterError(code: "store_unavailable", message: nil, details: nil))
    }
  }

  private func filesPrepared(in root: URL) -> Bool {
    let required = [".agents/plugins/marketplace.json", "dailycalendar-awareness/plugin.json",
                    "dailycalendar-awareness/mcp.json", "dailycalendar-awareness/mcp_server.py",
                    "dailycalendar-awareness/drive_reader.py", "dailycalendar-awareness/keychain_store.py",
                    "dailycalendar-awareness/SKILL.md", "dailycalendar-awareness/drive-data.md"]
    return required.allSatisfy { FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0).path) }
  }

  private func preparePlugin(_ data: Data) async throws {
    let root = try await integrationRoot(allowSelection: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let archive = root.appendingPathComponent("dailycalendar.zip")
    try data.write(to: archive, options: .atomic)
    // Only the app-bundled archive is supplied by the Flutter settings page.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", archive.path, root.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.global().async { process.waitUntilExit(); continuation.resume() }
    }
    guard process.terminationStatus == 0 else { throw PurchaseError.unavailable }
    // Remove obsolete app-generated helpers; credentials live in Keychain, not these files.
    for name in ["keychain", "keychain.swift"] {
      let old = root.appendingPathComponent("dailycalendar-awareness/" + name)
      if FileManager.default.fileExists(atPath: old.path) {
        try FileManager.default.removeItem(at: old)
      }
    }
    let nonce = UUID().uuidString
    UserDefaults.standard.set(nonce, forKey: "daily.dot.statusNonce")
    let mcpURL = root.appendingPathComponent("dailycalendar-awareness/mcp.json")
    var mcp = try JSONSerialization.jsonObject(with: Data(contentsOf: mcpURL)) as? [String: Any] ?? [:]
    var servers = mcp["mcpServers"] as? [String: [String: Any]] ?? [:]
    guard var server = servers["dailycalendar"] else { throw PurchaseError.unavailable }
    server["env"] = ["DAILY_DOT_STATUS_FILE": root.appendingPathComponent("status/connection.json").path,
                     "DAILY_DOT_STATUS_NONCE": nonce]
    servers["dailycalendar"] = server
    mcp["mcpServers"] = servers
    try JSONSerialization.data(withJSONObject: mcp).write(to: mcpURL, options: .atomic)
    let directory = root.appendingPathComponent(".agents/plugins", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let catalog = directory.appendingPathComponent("marketplace.json")
    let metadata: [String: Any] = ["name": "dailycalendar-local",
      "interface": ["displayName": "DailyCalendar"],
      "plugins": [["name": "dailycalendar",
        "source": ["source": "local", "path": "./dailycalendar-awareness"],
        "policy": ["installation": "AVAILABLE", "authentication": "ON_INSTALL"],
        "category": "Productivity"]]]
    try JSONSerialization.data(withJSONObject: metadata).write(to: catalog, options: .atomic)
    guard filesPrepared(in: root) else { throw PurchaseError.filesRequired }
  }

  private func openPlugin() async throws {
    guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") != nil else {
      throw PurchaseError.chatgptUnavailable
    }
    let root = try await integrationRoot()
    guard filesPrepared(in: root) else { throw PurchaseError.filesRequired }
    let catalog = root.appendingPathComponent(".agents/plugins/marketplace.json")
    var link = URLComponents()
    link.scheme = "codex"
    link.host = "plugins"
    link.path = "/dailycalendar"
    link.queryItems = [URLQueryItem(name: "marketplacePath", value: catalog.path)]
    guard let url = link.url, NSWorkspace.shared.open(url) else {
      throw PurchaseError.chatgptUnavailable
    }
    // Opening the installation screen is not an installation or Dot-access receipt.
  }

  private enum PurchaseError: String, Error {
    case busy, unavailable, unverified, locked, chatgptUnavailable
    case folderRequired, folderCancelled, protectedFolder, filesRequired
  }
}
