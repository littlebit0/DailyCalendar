import Cocoa
import FlutterMacOS
import LocalAuthentication
import UserNotifications
import WidgetKit
import WebKit

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
    guard fireAt > Date() else {
      result(nil)
      return
    }

    let snoozeMinutes = max(intValue(arguments["snoozeMinutes"]) ?? 10, 1)
    let memo = (arguments["memo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = memo.flatMap { $0.isEmpty ? nil : String($0.prefix(160)) }
      ?? "일정이 시작되었습니다."
    content.sound = .default
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "daily-event-alarms"
    content.userInfo = [
      eventIdKey: eventId,
      snoozeMinutesKey: snoozeMinutes,
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
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
    center.add(request) { error in
      finish(result, error: error)
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

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 800, height: 600)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    DailyNativeNotifications.register(with: flutterViewController)
    DailyMacAlarms.register(with: flutterViewController)
    DailyMapLauncher.register(with: flutterViewController)
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
      if call.method == "bind" {
        guard let marker = args["marker"] as? String, marker.count >= 32,
              marker.count <= 160 else {
          result(FlutterError(code: "invalid_marker", message: nil, details: nil)); return
        }
        let candidates = schoolViews(host: host)
        let group = DispatchGroup()
        var matches: [WKWebsiteDataStore] = []
        for view in candidates {
          group.enter()
          view.evaluateJavaScript("window.name") { name, error in
            if error == nil, name as? String == marker,
               view.url?.host == host, !view.configuration.websiteDataStore.isPersistent {
              matches.append(view.configuration.websiteDataStore)
            }
            group.leave()
          }
        }
        group.notify(queue: .main) {
          guard matches.count == 1, let store = matches.first else {
            result(FlutterError(code: "school_view_missing", message: nil, details: nil)); return
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
