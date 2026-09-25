import AppIntents
import AVFoundation
import CoreSpotlight
import Foundation
import FoundationModels
import LocalAuthentication
import SQLite3
import Speech
import SwiftUI
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

private let dailySQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// BEGIN LMS VISIBILITY POLICY
// A stored LMS row alone is never permission to expose school data. The app
// grants visibility only after checking the active account and source session.
struct DailySiriLmsVisibility: Equatable {
  let ownerID: String?
  let checkedAt: Double?
  let eventIDs: Set<String>

  init(ownerID: String?, snapshot: [String: Any]?, now: Date = Date()) {
    let owner = Self.normalizedOwner(ownerID)
    self.ownerID = owner
    guard let owner,
          let grant = snapshot?["lmsVisibility"] as? [String: Any],
          Self.normalizedOwner(grant["ownerId"] as? String) == owner,
          let checked = grant["checkedAt"] as? Double,
          checked.isFinite,
          checked > 0,
          now.timeIntervalSince1970 * 1000 >= checked,
          now.timeIntervalSince1970 * 1000 - checked <= 300_000,
          let ids = grant["eventIds"] as? [String] else {
      checkedAt = nil
      eventIDs = []
      return
    }
    checkedAt = checked
    eventIDs = Set(ids)
  }

  static func normalizedOwner(_ value: String?) -> String? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
  }

  static func isLms(id: String, metadata: String?) -> Bool {
    id.hasPrefix("lms:") || metadata != nil
  }

  func allows(id: String, metadata: String?) -> Bool {
    guard Self.isLms(id: id, metadata: metadata) else { return true }
    guard let ownerID, checkedAt != nil, eventIDs.contains(id),
          let data = metadata?.data(using: .utf8),
          let source = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          source["provider"] as? String == "coursemos",
          Self.normalizedOwner(source["ownerId"] as? String) == ownerID,
          let school = source["schoolId"] as? String, !school.isEmpty,
          let principal = source["lmsUserId"] as? String, !principal.isEmpty else {
      return false
    }
    return true
  }
}
// END LMS VISIBILITY POLICY

struct DailySiriLogRecord: Codable, Sendable {
  let id: String
  let occurredAt: Date
  let action: String
  let summary: String
  let result: String
  let success: Bool
  let details: [String: String]?
}

enum DailySiriLogStore {
  #if os(macOS)
  static let appGroup = "A6Y73X2ZLS.com.littlebit0.daily.widgets"
  #else
  static let appGroup = "group.com.littlebit0.daily.widgets"
  #endif
  static let fileName = "daily-siri-action-logs.json"
  private static let lock = NSLock()

  static func load() -> [DailySiriLogRecord] {
    lock.lock()
    defer { lock.unlock() }
    return loadUnlocked()
  }

  static func clear() {
    lock.lock()
    defer { lock.unlock() }
    guard let url = fileURL() else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private static func loadUnlocked() -> [DailySiriLogRecord] {
    guard let url = fileURL(),
          let data = try? Data(contentsOf: url),
          let records = try? JSONDecoder().decode([DailySiriLogRecord].self, from: data) else {
      return []
    }
    return records.sorted { $0.occurredAt > $1.occurredAt }
  }

  static func append(
    action: String,
    summary: String,
    result: String,
    success: Bool,
    details: [String: String]? = nil
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard let url = fileURL() else { return }
    var records = loadUnlocked()
    records.insert(
      DailySiriLogRecord(
        id: UUID().uuidString,
        occurredAt: Date(),
        action: action,
        summary: summary,
        result: result,
        success: success,
        details: details
      ),
      at: 0
    )
    if records.count > 1000 {
      records.removeSubrange(1000...)
    }
    if let data = try? JSONEncoder().encode(records) {
      try? data.write(to: url, options: .atomic)
    }
  }

  private static func fileURL() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    )?.appendingPathComponent(fileName)
  }
}

final class DailySignalVoiceBridge: NSObject {
  static let channelName = "daily/signal_voice"

  private let channel: FlutterMethodChannel
  private let audioEngine = AVAudioEngine()
  private let synthesizer = AVSpeechSynthesizer()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var silenceTimer: Timer?
  private var maximumTimer: Timer?
  private var pendingResult: FlutterResult?
  private var latestTranscript = ""
  private var inputTapInstalled = false

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "voice_unavailable", message: DailySiriText.voiceUnavailable, details: nil))
        return
      }
      switch call.method {
      case "startListening":
        self.requestPermissionsAndStart(result: result)
      case "finishListening":
        self.finishListening(cancelled: false)
        result(nil)
      case "cancelListening", "stopListening":
        self.finishListening(cancelled: true)
        result(nil)
      case "runSignal":
        guard let arguments = call.arguments as? [String: Any],
              let command = arguments["command"] as? String,
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "empty_command", message: DailySiriText.emptyCommand, details: nil))
          return
        }
        let confirmed = arguments["confirmed"] as? Bool ?? false
        self.runSignal(command: command, confirmed: confirmed, result: result)
      case "speak":
        guard let arguments = call.arguments as? [String: Any],
              let message = arguments["message"] as? String else {
          result(FlutterError(code: "empty_response", message: DailySiriText.emptyResponse, details: nil))
          return
        }
        self.speak(message)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestPermissionsAndStart(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "already_listening", message: DailySiriText.alreadyListening, details: nil))
      return
    }
    SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
      guard let self else { return }
      guard speechStatus == .authorized else {
        DispatchQueue.main.async {
          result(FlutterError(code: "speech_denied", message: DailySiriText.speechPermissionRequired, details: nil))
        }
        return
      }
      self.requestMicrophonePermission { granted in
        DispatchQueue.main.async {
          guard granted else {
            result(FlutterError(code: "microphone_denied", message: DailySiriText.microphonePermissionRequired, details: nil))
            return
          }
          self.startListening(result: result)
        }
      }
    }
  }

  private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
    #if os(iOS)
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: completion)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(completion)
    }
    #else
    AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    #endif
  }

  private func startListening(result: @escaping FlutterResult) {
    stopAudioSession()
    synthesizer.stopSpeaking(at: .immediate)
    guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
      result(FlutterError(code: "recognizer_unavailable", message: DailySiriText.recognizerUnavailable, details: nil))
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    recognitionRequest = request
    pendingResult = result
    latestTranscript = ""

    #if os(iOS)
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .record,
        mode: .measurement,
        options: [.duckOthers, .allowBluetooth]
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      finishListening(error: error)
      return
    }
    #endif

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    inputTapInstalled = true

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let recognitionResult {
          self.latestTranscript = recognitionResult.bestTranscription.formattedString
          self.channel.invokeMethod("transcriptChanged", arguments: self.latestTranscript)
          self.scheduleSilenceFinish()
          if recognitionResult.isFinal {
            self.finishListening(cancelled: false)
          }
        } else if let error {
          self.finishListening(error: error)
        }
      }
    }

    do {
      audioEngine.prepare()
      try audioEngine.start()
      channel.invokeMethod("listeningStarted", arguments: nil)
      maximumTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
        self?.finishListening(cancelled: false)
      }
    } catch {
      finishListening(error: error)
    }
  }

  private func scheduleSilenceFinish() {
    silenceTimer?.invalidate()
    silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
      self?.finishListening(cancelled: false)
    }
  }

  private func finishListening(cancelled: Bool) {
    let result = pendingResult
    let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    stopAudioSession()
    guard let result else { return }
    pendingResult = nil
    if cancelled {
      result(FlutterError(code: "listening_cancelled", message: DailySiriText.listeningCancelled, details: nil))
    } else if transcript.isEmpty {
      result(FlutterError(code: "no_speech", message: DailySiriText.noSpeech, details: nil))
    } else {
      result(transcript)
    }
  }

  private func finishListening(error: Error) {
    let result = pendingResult
    stopAudioSession()
    pendingResult = nil
    result?(FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil))
  }

  private func stopAudioSession() {
    silenceTimer?.invalidate()
    maximumTimer?.invalidate()
    silenceTimer = nil
    maximumTimer = nil
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    if inputTapInstalled {
      audioEngine.inputNode.removeTap(onBus: 0)
      inputTapInstalled = false
    }
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil
    #if os(iOS)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    #endif
  }

  private func runSignal(
    command: String,
    confirmed: Bool,
    result: @escaping FlutterResult
  ) {
    #if os(iOS)
    guard #available(iOS 17.0, *) else {
      result(FlutterError(code: "signal_unavailable", message: DailySiriText.signalUnavailable, details: nil))
      return
    }
    #else
    guard #available(macOS 14.0, *) else {
      result(FlutterError(code: "signal_unavailable", message: DailySiriText.signalUnavailable, details: nil))
      return
    }
    #endif
    Task { @MainActor in
      self.runAvailableSignal(command: command, confirmed: confirmed, result: result)
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  @MainActor
  private func runAvailableSignal(
    command: String,
    confirmed: Bool,
    result: @escaping FlutterResult
  ) {
    Task { @MainActor in
      let startedAt = Date()
      var intent = DailySignalCommandIntent()
      intent.spokenCommand = command
      intent.isBridgeExecution = true
      intent.confirmedInApp = confirmed
      do {
        _ = try await intent.perform()
        guard let record = DailySiriLogStore.load().first,
              record.occurredAt >= startedAt.addingTimeInterval(-0.5) else {
          result(FlutterError(code: "signal_result_missing", message: DailySiriText.signalResultMissing, details: nil))
          return
        }
        let message = self.responseMessage(for: record)
        result(["message": message, "success": record.success])
      } catch {
        if error is DailySignalConfirmationRequired {
          result(FlutterError(code: "signal_confirmation_required", message: DailySiriText.commandConfirmation, details: nil))
          return
        }
        if let localAuthenticationError = error as? LAError {
          let cancelledCodes: Set<LAError.Code> = [
            .appCancel, .systemCancel, .userCancel, .userFallback,
          ]
          let code = cancelledCodes.contains(localAuthenticationError.code)
            ? "signal_auth_cancelled"
            : "signal_auth_failed"
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
          return
        }
        if let record = DailySiriLogStore.load().first,
           record.occurredAt >= startedAt.addingTimeInterval(-0.5),
           !record.success {
          let code = record.result == "cancelled"
            ? "signal_cancelled"
            : "signal_execution_failed"
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
          return
        }
        result(FlutterError(code: "signal_needs_input", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func responseMessage(for record: DailySiriLogRecord) -> String {
    switch record.action.replacingOccurrences(of: "signal-", with: "") {
    case "add": return DailySiriText.added(record.summary)
    case "update": return DailySiriText.updated(record.result)
    case "delete": return DailySiriText.deleted(record.summary)
    default: return record.result
    }
  }

  private func speak(_ message: String) {
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: message)
    utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first)
    synthesizer.speak(utterance)
  }
}

struct DailySpokenTemporalValues: Sendable {
  let startAt: Date
  let endAt: Date?
  let allDay: Bool?
}

enum DailySpokenTemporalParser {
  static func parse(_ value: String?) -> DailySpokenTemporalValues? {
    guard let value else { return nil }
    let calendar = Calendar.current
    let explicitRange = explicitDateRange(in: value, calendar: calendar)
    let baseDate: Date
    if let start = explicitRange?.start {
      baseDate = start
    } else {
      let dayOffset: Int
      if value.contains("모레") {
        dayOffset = 2
      } else if value.contains("내일") {
        dayOffset = 1
      } else if value.contains("오늘") {
        dayOffset = 0
      } else {
        return nil
      }
      baseDate = calendar.date(
        byAdding: .day,
        value: dayOffset,
        to: calendar.startOfDay(for: Date())
      )!
    }
    let hasClockTime = firstMatch(#"(?:오전|오후)\s*\d{1,2}|\d{1,2}\s*시"#, in: value) != nil
    if (value.contains("종일") || explicitRange?.end != nil) && !hasClockTime {
      return DailySpokenTemporalValues(
        startAt: calendar.startOfDay(for: baseDate),
        endAt: explicitRange?.end ?? calendar.date(byAdding: .day, value: 1, to: baseDate),
        allDay: true
      )
    }
    let rangePattern = #"(?:(오전|오후)\s*)?(\d{1,2})(?:\s*시)?(?:\s*(\d{1,2})\s*분)?\s*(?:~|〜|–|—|-|부터)\s*(?:(오전|오후)\s*)?(\d{1,2})(?:\s*시)?(?:\s*(\d{1,2})\s*분)?"#
    if let match = firstMatch(rangePattern, in: value),
       let start = date(
         on: baseDate,
         period: group(1, match: match, source: value),
         hour: group(2, match: match, source: value),
         minute: group(3, match: match, source: value),
         calendar: calendar
       ),
       var end = date(
         on: baseDate,
         period: group(4, match: match, source: value) ??
           group(1, match: match, source: value),
         hour: group(5, match: match, source: value),
         minute: group(6, match: match, source: value),
         calendar: calendar
       ) {
      if end <= start {
        end = calendar.date(byAdding: .day, value: 1, to: end)!
      }
      return DailySpokenTemporalValues(startAt: start, endAt: end, allDay: false)
    }

    let singlePattern = #"(?:(오전|오후)\s*)?(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"#
    if let match = firstMatch(singlePattern, in: value),
       let start = date(
            on: baseDate,
            period: group(1, match: match, source: value),
            hour: group(2, match: match, source: value),
            minute: group(3, match: match, source: value),
            calendar: calendar
          ) {
      return DailySpokenTemporalValues(startAt: start, endAt: nil, allDay: false)
    }

    guard value.contains("종일") || explicitRange?.end != nil else { return nil }
    return DailySpokenTemporalValues(
      startAt: calendar.startOfDay(for: baseDate),
      endAt: explicitRange?.end ?? calendar.date(byAdding: .day, value: 1, to: baseDate),
      allDay: true
    )
  }

  private static func explicitDateRange(
    in value: String,
    calendar: Calendar
  ) -> (start: Date, end: Date?)? {
    let pattern = #"(?:(\d{2,4})년\s*)?(\d{1,2})월\s*(\d{1,2})일(?:\s*(?:부터|~|〜|–|—|-)\s*(?:(\d{2,4})년\s*)?(?:(\d{1,2})월\s*)?(\d{1,2})일)?"#
    guard let match = firstMatch(pattern, in: value),
          let startMonth = group(2, match: match, source: value).flatMap(Int.init),
          let startDay = group(3, match: match, source: value).flatMap(Int.init) else {
      return nil
    }
    let nowYear = calendar.component(.year, from: Date())
    let startYear = normalizedYear(group(1, match: match, source: value).flatMap(Int.init)) ?? nowYear
    guard let start = calendar.date(from: DateComponents(
      timeZone: .current,
      year: startYear,
      month: startMonth,
      day: startDay
    )) else { return nil }
    guard let endDay = group(6, match: match, source: value).flatMap(Int.init) else {
      return (calendar.startOfDay(for: start), nil)
    }
    let endYear = normalizedYear(group(4, match: match, source: value).flatMap(Int.init)) ?? startYear
    let endMonth = group(5, match: match, source: value).flatMap(Int.init) ?? startMonth
    guard let inclusiveEnd = calendar.date(from: DateComponents(
      timeZone: .current,
      year: endYear,
      month: endMonth,
      day: endDay
    )), inclusiveEnd >= start else {
      return (calendar.startOfDay(for: start), nil)
    }
    return (
      calendar.startOfDay(for: start),
      calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: inclusiveEnd))
    )
  }

  private static func normalizedYear(_ value: Int?) -> Int? {
    guard let value else { return nil }
    return value < 100 ? 2000 + value : value
  }

  private static func firstMatch(
    _ pattern: String,
    in value: String
  ) -> NSTextCheckingResult? {
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }
    return expression.firstMatch(
      in: value,
      range: NSRange(value.startIndex..., in: value)
    )
  }

  private static func group(
    _ index: Int,
    match: NSTextCheckingResult,
    source: String
  ) -> String? {
    let range = match.range(at: index)
    guard range.location != NSNotFound,
          let swiftRange = Range(range, in: source) else {
      return nil
    }
    return String(source[swiftRange])
  }

  private static func date(
    on baseDate: Date,
    period: String?,
    hour: String?,
    minute: String?,
    calendar: Calendar
  ) -> Date? {
    guard var hour = hour.flatMap(Int.init), (0...23).contains(hour) else {
      return nil
    }
    let minute = minute.flatMap(Int.init) ?? 0
    guard (0...59).contains(minute) else { return nil }
    if period == "오전" {
      guard hour <= 12 else { return nil }
      if hour == 12 { hour = 0 }
    } else if period == "오후" {
      guard hour <= 12 else { return nil }
      if hour < 12 { hour += 12 }
    }
    return calendar.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: baseDate
    )
  }
}

enum DailySiriLanguage: Equatable, Sendable {
  case korean
  case english
  case japanese
  case traditionalChinese

  static var system: DailySiriLanguage {
    resolve(Locale.preferredLanguages.first)
  }

  static func resolve(_ identifier: String?) -> DailySiriLanguage {
    guard let identifier else { return .english }
    let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    if normalized.hasPrefix("ko") { return .korean }
    if normalized.hasPrefix("ja") { return .japanese }
    if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") ||
        normalized.hasPrefix("zh-hk") || normalized.hasPrefix("zh-mo") {
      return .traditionalChinese
    }
    return .english
  }

  var locale: Locale {
    switch self {
    case .korean: Locale(identifier: "ko_KR")
    case .english: Locale(identifier: "en_US")
    case .japanese: Locale(identifier: "ja_JP")
    case .traditionalChinese: Locale(identifier: "zh_Hant_TW")
    }
  }
}

private struct DailySiriCategory: Sendable {
  let id: String
  let label: String
  let colorValue: Int64
}

private enum DailySiriPreferences {
  static var uses24HourTime: Bool {
    let defaults = UserDefaults.standard
    let key = "flutter.use24HourTime"
    return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
  }

  static var categories: [DailySiriCategory] {
    let fallback = [
      DailySiriCategory(id: "basic", label: "기본", colorValue: 0xff2563eb),
      DailySiriCategory(id: "holiday", label: "공휴일", colorValue: 0xffef4444),
    ]
    guard let raw = UserDefaults.standard.string(forKey: "flutter.eventCategories"),
          let data = raw.data(using: .utf8),
          let values = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return fallback
    }
    let decoded = values.compactMap { value -> DailySiriCategory? in
      guard let id = value["id"] as? String, !id.isEmpty else { return nil }
      let label = (value["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let color = (value["colorValue"] as? NSNumber)?.int64Value ?? 0xff2563eb
      return DailySiriCategory(id: id, label: label?.isEmpty == false ? label! : id, colorValue: color)
    }
    return decoded.isEmpty ? fallback : decoded
  }

  static func category(matching value: String) -> DailySiriCategory? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let aliases: [String: Set<String>] = [
      "basic": ["basic", "기본", "default", "標準", "基本"],
      "holiday": ["holiday", "holidays", "공휴일", "祝日", "國定假日"],
    ]
    return categories.first { category in
      let candidates = [category.id, category.label] + Array(aliases[category.id] ?? [])
      return candidates.contains {
        $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalized
      }
    }
  }
}

private enum DailySiriText {
  private static var language: DailySiriLanguage { .system }

  private static func localized(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
    switch language {
    case .korean: ko
    case .english: en
    case .japanese: ja
    case .traditionalChinese: zh
    }
  }

  static var voiceUnavailable: String { localized(
    "음성 서비스를 시작할 수 없습니다.", "Voice service could not be started.",
    "音声サービスを開始できません。", "無法啟動語音服務。"
  ) }
  static var emptyCommand: String { localized(
    "인식된 음성이 없습니다.", "No speech was recognized.",
    "音声を認識できませんでした。", "未辨識到語音。"
  ) }
  static var emptyResponse: String { localized(
    "읽을 응답이 없습니다.", "There is no response to read.",
    "読み上げる応答がありません。", "沒有可朗讀的回覆。"
  ) }
  static var alreadyListening: String { localized(
    "이미 음성을 듣고 있습니다.", "Daily is already listening.",
    "すでに音声を聞き取っています。", "Daily 已在聆聽。"
  ) }
  static var speechPermissionRequired: String { localized(
    "음성 인식 권한이 필요합니다.", "Speech recognition permission is required.",
    "音声認識の権限が必要です。", "需要語音辨識權限。"
  ) }
  static var microphonePermissionRequired: String { localized(
    "마이크 권한이 필요합니다.", "Microphone permission is required.",
    "マイクの権限が必要です。", "需要麥克風權限。"
  ) }
  static var recognizerUnavailable: String { localized(
    "현재 언어의 음성 인식을 사용할 수 없습니다.", "Speech recognition is unavailable for the current language.",
    "現在の言語では音声認識を利用できません。", "目前語言無法使用語音辨識。"
  ) }
  static var listeningCancelled: String { localized(
    "음성 듣기를 취소했습니다.", "Listening was cancelled.",
    "音声入力をキャンセルしました。", "已取消語音聆聽。"
  ) }
  static var noSpeech: String { localized(
    "음성을 인식하지 못했습니다. 다시 말씀해 주세요.", "I couldn't recognize the speech. Please try again.",
    "音声を認識できませんでした。もう一度お話しください。", "無法辨識語音，請再說一次。"
  ) }
  static var signalUnavailable: String { localized(
    "이 운영체제 버전에서는 Daily Signal을 사용할 수 없습니다.", "Daily Signal is unavailable on this operating system version.",
    "このOSバージョンではDaily Signalを利用できません。", "此作業系統版本無法使用 Daily Signal。"
  ) }
  static var signalResultMissing: String { localized(
    "시그널 실행 결과를 확인하지 못했습니다.", "The Signal result could not be verified.",
    "Signalの実行結果を確認できませんでした。", "無法確認 Signal 執行結果。"
  ) }

  static var databaseUnavailable: String {
    return switch language {
    case .korean: "Daily 캘린더 데이터를 사용할 수 없습니다. Daily를 한 번 연 후 다시 시도해 주세요."
    case .english: "Daily calendar data is unavailable. Open Daily once and try again."
    case .japanese: "Dailyのカレンダーデータを利用できません。Dailyを一度開いてから、もう一度お試しください。"
    case .traditionalChinese: "無法使用 Daily 行事曆資料。請先開啟一次 Daily，然後再試一次。"
    }
  }

  static var lmsOriginalReadOnly: String { localized(
    "학교에서 받은 일정은 Siri에서 변경하거나 삭제할 수 없습니다. 개인 메모·분류·알림은 Daily에서 수정해 주세요.",
    "School events cannot be changed or deleted with Siri. Edit personal notes, categories and reminders in Daily.",
    "大学から取得した予定はSiriで変更・削除できません。個人のメモ・分類・通知はDailyで編集してください。",
    "無法透過 Siri 變更或刪除學校行程。請在 Daily 編輯個人備註、分類及提醒。"
  ) }

  static var lmsReadCompleted: String { localized(
    "학교 일정 조회 완료",
    "School event lookup completed",
    "大学の予定を取得しました",
    "已完成查詢學校行程"
  ) }

  static var eventNotFound: String {
    switch language {
    case .korean: "Daily에서 일치하는 일정을 찾지 못했습니다."
    case .english: "I couldn't find a matching event in Daily."
    case .japanese: "Dailyで一致する予定が見つかりませんでした。"
    case .traditionalChinese: "在 Daily 中找不到符合的行程。"
    }
  }

  static var ambiguousEvent: String {
    switch language {
    case .korean: "일치하는 일정이 여러 개 있습니다. 더 구체적인 제목을 사용해 주세요."
    case .english: "There is more than one matching event. Please use a more specific title."
    case .japanese: "一致する予定が複数あります。より具体的なタイトルを指定してください。"
    case .traditionalChinese: "有多個符合的行程。請使用更明確的標題。"
    }
  }

  static var invalidTime: String {
    switch language {
    case .korean: "종료 시각은 시작 시각보다 이후여야 합니다."
    case .english: "The end time must be later than the start time."
    case .japanese: "終了時刻は開始時刻より後に設定してください。"
    case .traditionalChinese: "結束時間必須晚於開始時間。"
    }
  }

  static var commandRequest: String {
    switch language {
    case .korean: "Daily에서 실행할 작업을 말해 주세요."
    case .english: "Tell me what you want to do in Daily."
    case .japanese: "Dailyで実行する操作を話してください。"
    case .traditionalChinese: "請說出要在 Daily 中執行的操作。"
    }
  }

  static var commandConfirmation: String {
    switch language {
    case .korean: "이 명령을 실행할까요?"
    case .english: "Would you like to run this command?"
    case .japanese: "このコマンドを実行しますか？"
    case .traditionalChinese: "要執行這個指令嗎？"
    }
  }

  static var supportedActionRequest: String {
    switch language {
    case .korean: "어제 일정, 오늘 일정, 내일 일정, 지정 날짜 일정, 다음 일정, 일정 검색, D-day, 일정 추가, 일정 수정, 일정 삭제 중 하나를 말해 주세요."
    case .english: "Ask for yesterday's, today's, or tomorrow's events, events on a date, the next event, search, D-day, add, update, or delete."
    case .japanese: "昨日、今日、明日の予定、指定日の予定、次の予定、予定の検索、D-day、追加、変更、削除のいずれかを話してください。"
    case .traditionalChinese: "請說出昨天、今天、明天、指定日期行程、下一個行程、搜尋、D-day、新增、修改或刪除。"
    }
  }

  static var dateRequest: String {
    switch language {
    case .korean: "어느 날짜의 일정을 확인할까요?"
    case .english: "Which date would you like to check?"
    case .japanese: "どの日付の予定を確認しますか？"
    case .traditionalChinese: "要查看哪一天的行程？"
    }
  }

  static var searchRequest: String {
    switch language {
    case .korean: "검색할 일정 제목이나 장소를 말해 주세요."
    case .english: "Tell me the event title or location to search for."
    case .japanese: "検索する予定のタイトルまたは場所を話してください。"
    case .traditionalChinese: "請說出要搜尋的行程標題或地點。"
    }
  }

  static var addTitleRequest: String {
    switch language {
    case .korean: "추가할 일정 제목을 말해 주세요."
    case .english: "What is the title of the event?"
    case .japanese: "追加する予定のタイトルを話してください。"
    case .traditionalChinese: "請說出要新增的行程標題。"
    }
  }

  static var startRequest: String {
    switch language {
    case .korean: "일정 시작 날짜와 시간을 말해 주세요."
    case .english: "Tell me the event's start date and time."
    case .japanese: "予定の開始日時を話してください。"
    case .traditionalChinese: "請說出行程的開始日期與時間。"
    }
  }

  static var endRequest: String {
    switch language {
    case .korean: "일정 종료 날짜와 시간을 말해 주세요."
    case .english: "Tell me the event's end date and time."
    case .japanese: "予定の終了日時を話してください。"
    case .traditionalChinese: "請說出行程的結束日期與時間。"
    }
  }

  static var allDayRequest: String {
    switch language {
    case .korean: "이 일정은 종일 일정인가요?"
    case .english: "Is this an all-day event?"
    case .japanese: "この予定は終日ですか？"
    case .traditionalChinese: "這是全天行程嗎？"
    }
  }

  static var categoryRequest: String {
    let labels = DailySiriPreferences.categories.map(\.label).joined(separator: listSeparator)
    return switch language {
    case .korean: "일정 분류를 말해 주세요. 사용할 수 있는 분류는 \(labels)입니다."
    case .english: "Tell me the event category. Available categories are \(labels)."
    case .japanese: "予定の分類を話してください。利用できる分類は\(labels)です。"
    case .traditionalChinese: "請說出行程分類。可用分類為\(labels)。"
    }
  }

  static var updateTargetRequest: String {
    switch language {
    case .korean: "수정할 일정을 선택해 주세요."
    case .english: "Choose the event you want to update."
    case .japanese: "変更する予定を選択してください。"
    case .traditionalChinese: "請選擇要修改的行程。"
    }
  }

  static var updateValueRequest: String {
    switch language {
    case .korean: "일정의 새 제목이나 변경할 시간을 말해 주세요."
    case .english: "Tell me the new title or time for the event."
    case .japanese: "予定の新しいタイトルまたは変更する時刻を話してください。"
    case .traditionalChinese: "請說出行程的新標題或要變更的時間。"
    }
  }

  static var deleteTargetRequest: String {
    switch language {
    case .korean: "삭제할 일정을 선택해 주세요."
    case .english: "Choose the event you want to delete."
    case .japanese: "削除する予定を選択してください。"
    case .traditionalChinese: "請選擇要刪除的行程。"
    }
  }

  static var updateAuthentication: String {
    switch language {
    case .korean: "Daily 일정 수정을 승인해 주세요."
    case .english: "Authenticate to update the Daily event."
    case .japanese: "Dailyの予定を変更するために認証してください。"
    case .traditionalChinese: "請驗證以修改 Daily 行程。"
    }
  }

  static var deleteAuthentication: String {
    switch language {
    case .korean: "Daily 일정 삭제를 승인해 주세요."
    case .english: "Authenticate to delete the Daily event."
    case .japanese: "Dailyの予定を削除するために認証してください。"
    case .traditionalChinese: "請驗證以刪除 Daily 行程。"
    }
  }

  static func todayLabel() -> String {
    switch language {
    case .korean: "오늘"
    case .english: "today"
    case .japanese: "今日"
    case .traditionalChinese: "今天"
    }
  }

  static func yesterdayLabel() -> String {
    switch language {
    case .korean: "어제"
    case .english: "yesterday"
    case .japanese: "昨日"
    case .traditionalChinese: "昨天"
    }
  }

  static func tomorrowLabel() -> String {
    switch language {
    case .korean: "내일"
    case .english: "tomorrow"
    case .japanese: "明日"
    case .traditionalChinese: "明天"
    }
  }

  static func date(_ date: Date, includeTime: Bool) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = .current
    formatter.timeZone = .current
    formatter.dateStyle = .medium
    formatter.timeStyle = includeTime ? .short : .none
    return formatter.string(from: date)
  }

  static func added(_ title: String) -> String {
    switch language {
    case .korean: "Daily에 \(title) 일정을 추가했습니다."
    case .english: "Added \(title) to Daily."
    case .japanese: "Dailyに\(title)の予定を追加しました。"
    case .traditionalChinese: "已將「\(title)」新增至 Daily。"
    }
  }

  static func updated(_ title: String) -> String {
    switch language {
    case .korean: "Daily에서 \(title) 일정을 수정했습니다."
    case .english: "Updated \(title) in Daily."
    case .japanese: "Dailyで\(title)の予定を変更しました。"
    case .traditionalChinese: "已在 Daily 中修改「\(title)」。"
    }
  }

  static func deleteConfirmation(_ title: String) -> String {
    switch language {
    case .korean: "\(title) 일정을 삭제할까요?"
    case .english: "Do you want to delete \(title)?"
    case .japanese: "\(title)の予定を削除しますか？"
    case .traditionalChinese: "要刪除「\(title)」嗎？"
    }
  }

  static func deleted(_ title: String) -> String {
    switch language {
    case .korean: "Daily에서 \(title) 일정을 삭제했습니다."
    case .english: "Deleted \(title) from Daily."
    case .japanese: "Dailyから\(title)の予定を削除しました。"
    case .traditionalChinese: "已從 Daily 刪除「\(title)」。"
    }
  }

  static func nextEvent(_ event: DailySiriEvent?) -> String {
    guard let event else {
      switch language {
      case .korean: return "예정된 다음 일정이 없습니다."
      case .english: return "There are no upcoming events in Daily."
      case .japanese: return "Dailyに今後の予定はありません。"
      case .traditionalChinese: return "Daily 中沒有接下來的行程。"
      }
    }
    let value = spokenDetailedEvent(event)
    switch language {
    case .korean: return "다음 일정은 \(value)입니다."
    case .english: return "Your next event is \(value)."
    case .japanese: return "次の予定は\(value)です。"
    case .traditionalChinese: return "下一個行程是\(value)。"
    }
  }

  static var noSearchResults: String {
    switch language {
    case .korean: "일치하는 일정을 찾지 못했습니다."
    case .english: "No matching events were found in Daily."
    case .japanese: "Dailyで一致する予定が見つかりませんでした。"
    case .traditionalChinese: "在 Daily 中找不到符合的行程。"
    }
  }

  static var noDdayEvents: String {
    switch language {
    case .korean: "등록된 D-day 일정이 없습니다."
    case .english: "There are no D-day events in Daily."
    case .japanese: "Dailyに登録されたD-dayの予定はありません。"
    case .traditionalChinese: "Daily 中沒有已登錄的 D-day 行程。"
    }
  }

  static func holidayTitle(_ title: String) -> String {
    title
      .components(separatedBy: " · ")
      .map(holidayPart)
      .joined(separator: " · ")
  }

  static func holidayMatches(_ title: String, query: String) -> Bool {
    let normalizedQuery = query.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: language.locale
    )
    let categoryAliases = ["공휴일", "holiday", "holidays", "祝日", "國定假日"]
    if categoryAliases.contains(where: {
      $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: language.locale)
        .contains(normalizedQuery)
    }) {
      return true
    }
    return title.components(separatedBy: " · ").contains { part in
      holidayTranslations(part).contains { candidate in
        candidate.folding(
          options: [.caseInsensitive, .diacriticInsensitive],
          locale: language.locale
        ).contains(normalizedQuery)
      }
    }
  }

  private static func holidayPart(_ value: String) -> String {
    let translations = holidayTranslations(value)
    switch language {
    case .korean: return translations[0]
    case .english: return translations[1]
    case .japanese: return translations[2]
    case .traditionalChinese: return translations[3]
    }
  }

  private static func holidayTranslations(_ value: String) -> [String] {
    switch value {
    case "신정": ["신정", "New Year's Day", "元日", "元旦"]
    case "삼일절": ["삼일절", "March 1st Movement Day", "三一節", "三一節"]
    case "노동절": ["노동절", "Labor Day", "労働節", "勞動節"]
    case "어린이날": ["어린이날", "Children's Day", "こどもの日", "兒童節"]
    case "현충일": ["현충일", "Memorial Day", "顕忠日", "顯忠日"]
    case "제헌절": ["제헌절", "Constitution Day", "制憲節", "制憲節"]
    case "광복절": ["광복절", "Liberation Day", "光復節", "光復節"]
    case "개천절": ["개천절", "National Foundation Day", "開天節", "開天節"]
    case "한글날": ["한글날", "Hangeul Day", "ハングルの日", "韓文日"]
    case "기독탄신일": ["기독탄신일", "Christmas Day", "クリスマス", "聖誕節"]
    case "설날 연휴": ["설날 연휴", "Seollal Holiday", "旧正月連休", "春節連假"]
    case "설날": ["설날", "Seollal", "旧正月", "春節"]
    case "부처님 오신 날": ["부처님 오신 날", "Buddha's Birthday", "釈迦誕生日", "佛誕日"]
    case "추석 연휴": ["추석 연휴", "Chuseok Holiday", "秋夕連休", "秋夕連假"]
    case "추석": ["추석", "Chuseok", "秋夕", "秋夕"]
    case "대체공휴일": ["대체공휴일", "Substitute Holiday", "振替休日", "補假"]
    default: [value, value, value, value]
    }
  }

  static func noEvents(_ label: String) -> String {
    switch language {
    case .korean: "\(label) Daily 일정이 없습니다."
    case .english: "There are no events in Daily for \(label)."
    case .japanese: "\(label)のDailyの予定はありません。"
    case .traditionalChinese: "Daily 在\(label)沒有行程。"
    }
  }

  static func scheduleSummary(
    for date: Date,
    events: [DailySiriEvent]
  ) -> String {
    let holidays = events.filter(\.isHoliday)
    let schedules = events.filter { !$0.isHoliday }
    var lines = [scheduleIntroduction(date)]

    if !holidays.isEmpty {
      let titles = holidays.map(\.title).joined(separator: listSeparator)
      switch language {
      case .korean:
        let subject = Calendar.current.isDateInToday(date) ? "오늘은" : "이날은"
        lines.append("\(subject) 공휴일로 \(titles)입니다.")
      case .english: lines.append("The public holiday is \(titles).")
      case .japanese: lines.append("この日の祝日は\(titles)です。")
      case .traditionalChinese: lines.append("這天的國定假日是\(titles)。")
      }
    }

    if schedules.isEmpty {
      switch language {
      case .korean: lines.append("등록된 일정은 없습니다.")
      case .english: lines.append("There are no other events.")
      case .japanese: lines.append("ほかに登録された予定はありません。")
      case .traditionalChinese: lines.append("沒有其他已登錄的行程。")
      }
    } else {
      for (index, event) in schedules.enumerated() {
        lines.append(spokenScheduleLine(
          event,
          followsHoliday: !holidays.isEmpty && index == 0
        ))
      }
    }
    // Siri can visually collapse a single newline. A blank separator preserves
    // one clearly separated block per event while keeping every event isolated.
    return lines.joined(separator: "\n\n")
  }

  private static func scheduleIntroduction(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = .current
    formatter.timeZone = .current
    switch language {
    case .korean:
      formatter.dateFormat = "yyyy년 M월 d일 EEEE"
      let descriptor = Calendar.current.isDateInToday(date)
        ? "오늘 일정"
        : Calendar.current.isDateInTomorrow(date) ? "내일 일정" : "일정"
      return "\(formatter.string(from: date)) \(descriptor)입니다."
    case .english:
      formatter.dateFormat = "EEEE, MMMM d, yyyy"
      return "Here is your schedule for \(formatter.string(from: date))."
    case .japanese:
      formatter.dateFormat = "yyyy年M月d日EEEE"
      return "\(formatter.string(from: date))の予定です。"
    case .traditionalChinese:
      formatter.dateFormat = "yyyy年M月d日 EEEE"
      return "以下是\(formatter.string(from: date))的行程。"
    }
  }

  private static func spokenScheduleLine(
    _ event: DailySiriEvent,
    followsHoliday: Bool
  ) -> String {
    if event.allDay {
      let calendar = Calendar.current
      let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: event.endAt) ?? event.endAt
      let sameDay = calendar.isDate(event.startAt, inSameDayAs: inclusiveEnd)
      let range = sameDay
        ? spokenDate(event.startAt)
        : "\(spokenDate(event.startAt))~\(spokenDate(inclusiveEnd))"
      switch language {
      case .korean:
        return "\(followsHoliday ? "또한 " : "")\(range) 종일 \(event.title) 일정이 있습니다."
      case .english:
        return "\(followsHoliday ? "Also, " : "")\(event.title) is an all-day event on \(range)."
      case .japanese:
        return "\(followsHoliday ? "また、" : "")\(range)に終日予定「\(event.title)」があります。"
      case .traditionalChinese:
        return "\(followsHoliday ? "另外，" : "")\(range)有全天行程「\(event.title)」。"
      }
    }
    let range = "\(spokenTime(event.startAt))~\(spokenTime(event.endAt))"
    switch language {
    case .korean:
      return "\(followsHoliday ? "또한 " : "")\(range)에 \(event.title) 일정이 있습니다."
    case .english:
      return "\(followsHoliday ? "Also, " : "")\(event.title) is scheduled from \(range)."
    case .japanese:
      return "\(followsHoliday ? "また、" : "")\(range)に「\(event.title)」の予定があります。"
    case .traditionalChinese:
      return "\(followsHoliday ? "另外，" : "")\(range)有「\(event.title)」行程。"
    }
  }

  private static func spokenDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = .current
    formatter.timeZone = .current
    formatter.dateFormat = switch language {
    case .korean: "M월 d일"
    case .english: "MMM d"
    case .japanese: "M月d日"
    case .traditionalChinese: "M月d日"
    }
    return formatter.string(from: date)
  }

  private static func spokenTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = .current
    formatter.timeZone = .current
    if DailySiriPreferences.uses24HourTime {
      formatter.dateFormat = "HH:mm"
    } else {
      formatter.dateFormat = language == .korean ? "a h:mm" : "h:mm a"
    }
    return formatter.string(from: date)
  }

  static func eventList(_ events: [DailySiriEvent], empty: String) -> String {
    guard !events.isEmpty else { return empty }
    let shown = events.prefix(5).map(spokenDetailedEvent).joined(separator: listSeparator)
    let remaining = events.count - min(events.count, 5)
    guard remaining > 0 else { return shown + sentenceTerminator }
    switch language {
    case .korean: return "\(shown), 그 외 \(remaining)개가 더 있습니다."
    case .english: return "\(shown), and \(remaining) more."
    case .japanese: return "\(shown)、ほかに\(remaining)件あります。"
    case .traditionalChinese: return "\(shown)，另外還有 \(remaining) 個。"
    }
  }

  private static func spokenDetailedEvent(_ event: DailySiriEvent) -> String {
    let calendar = Calendar.current
    if event.allDay {
      let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: event.endAt) ?? event.endAt
      let range = calendar.isDate(event.startAt, inSameDayAs: inclusiveEnd)
        ? spokenFullDate(event.startAt)
        : "\(spokenFullDate(event.startAt))~\(spokenFullDate(inclusiveEnd))"
      switch language {
      case .korean: return "\(range) 종일 \(event.title)"
      case .english: return "\(event.title), all day on \(range)"
      case .japanese: return "\(range)終日の「\(event.title)」"
      case .traditionalChinese: return "\(range)全天的「\(event.title)」"
      }
    }
    let crossesDate = !calendar.isDate(event.startAt, inSameDayAs: event.endAt)
    let end = crossesDate
      ? "\(spokenFullDate(event.endAt)) \(spokenTime(event.endAt))"
      : spokenTime(event.endAt)
    let range = "\(spokenFullDate(event.startAt)) \(spokenTime(event.startAt))~\(end)"
    switch language {
    case .korean: return "\(range) \(event.title)"
    case .english: return "\(event.title), \(range)"
    case .japanese: return "\(range)の「\(event.title)」"
    case .traditionalChinese: return "\(range)的「\(event.title)」"
    }
  }

  private static func spokenFullDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = .current
    formatter.timeZone = .current
    formatter.dateFormat = switch language {
    case .korean: "yyyy년 M월 d일 EEEE"
    case .english: "EEEE, MMM d, yyyy"
    case .japanese: "yyyy年M月d日EEEE"
    case .traditionalChinese: "yyyy年M月d日 EEEE"
    }
    return formatter.string(from: date)
  }

  private static var listSeparator: String {
    switch language {
    case .japanese: "、"
    case .traditionalChinese: "，"
    default: ", "
    }
  }

  private static var sentenceTerminator: String {
    switch language {
    case .japanese, .traditionalChinese: "。"
    default: "."
    }
  }
}

private func siriEventDetails(_ event: DailySiriEvent) -> [String: String] {
  var details = [
    "eventId": event.id,
    "title": event.title,
    "startAtMillis": String(Int64(event.startAt.timeIntervalSince1970 * 1000)),
    "endAtMillis": String(Int64(event.endAt.timeIntervalSince1970 * 1000)),
    "allDay": event.allDay ? "true" : "false",
  ]
  if let location = event.location, !location.isEmpty {
    details["location"] = location
  }
  if let memo = event.memo, !memo.isEmpty {
    details["memo"] = memo
  }
  return details
}

struct DailySiriEventChange: Codable, Sendable {
  let token: String
  let eventID: String
  let action: String
  let reminderMinutesBefore: [Int]
}

enum DailySiriEventChangeSignal {
  static let notificationName = "com.littlebit0.daily.siri.events-changed"
  private static let fileName = "daily-siri-pending-event-changes.json"
  private static let lock = NSLock()

  #if os(macOS)
  private static let appGroup = "A6Y73X2ZLS.com.littlebit0.daily.widgets"
  #else
  private static let appGroup = "group.com.littlebit0.daily.widgets"
  #endif

  static func pending() -> [DailySiriEventChange] {
    lock.lock()
    defer { lock.unlock() }
    return loadUnlocked()
  }

  static func acknowledge(tokens: [String]) {
    guard !tokens.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    let acknowledged = Set(tokens)
    saveUnlocked(loadUnlocked().filter { !acknowledged.contains($0.token) })
  }

  static func post(eventID: String, action: String, reminderMinutesBefore: [Int]) {
    lock.lock()
    var changes = loadUnlocked()
    changes.append(DailySiriEventChange(
      token: UUID().uuidString,
      eventID: eventID,
      action: action,
      reminderMinutesBefore: reminderMinutesBefore
    ))
    saveUnlocked(changes)
    lock.unlock()
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(notificationName as CFString),
      nil,
      nil,
      true
    )
  }

  private static func loadUnlocked() -> [DailySiriEventChange] {
    guard let url = fileURL(),
          let data = try? Data(contentsOf: url),
          let changes = try? JSONDecoder().decode([DailySiriEventChange].self, from: data) else {
      return []
    }
    return changes
  }

  private static func saveUnlocked(_ changes: [DailySiriEventChange]) {
    guard let url = fileURL(), let data = try? JSONEncoder().encode(changes) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private static func fileURL() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    )?.appendingPathComponent(fileName)
  }
}

private struct DailySignalConfirmationRequired: Error {}

@available(iOS 16.0, macOS 13.0, *)
private struct DailyGenerativeUnderstanding: Sendable {
  let action: DailySiriAction
  let eventReference: String?
  let searchText: String?
  let eventTitle: String?
  let startAt: Date?
  let endAt: Date?
  let allDay: Bool?
  let category: String?
  let location: String?
  let memo: String?
  let url: String?
  let weather: String?
  let reminderRequested: Bool?
  let reminderMinutesBefore: Int?
  let alarmEnabled: Bool?
  let showDday: Bool?
  let newTitle: String?
  let newStartAt: Date?
  let newEndAt: Date?
  let newAllDay: Bool?
  let newCategory: String?
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A supported action in the Daily personal calendar app.")
private enum DailyGeneratedAction {
  case yesterday
  case today
  case tomorrow
  case date
  case next
  case search
  case dday
  case add
  case update
  case delete
  case unknown

  var siriAction: DailySiriAction? {
    switch self {
    case .yesterday: .yesterday
    case .today: .today
    case .tomorrow: .tomorrow
    case .date: .date
    case .next: .next
    case .search: .search
    case .dday: .dday
    case .add: .add
    case .update: .update
    case .delete: .delete
    case .unknown: nil
    }
  }
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A strictly structured interpretation of one Daily calendar command.")
private struct DailyGeneratedCommand {
  @Guide(description: "The single Daily action requested by the person. Use unknown for unrelated or ambiguous text.")
  var action: DailyGeneratedAction

  @Guide(description: "The existing event title, place, or identifying phrase. Omit when the person did not identify an event.")
  var eventReference: String?

  @Guide(description: "Only the meaningful event title, place, or phrase to search for. Remove words that merely ask to search.")
  var searchText: String?

  @Guide(description: "The title of a new event. Omit unless the person clearly supplied a title for an add request.")
  var eventTitle: String?

  @Guide(description: "The new event start as an ISO 8601 timestamp with UTC offset. Set it only when the person supplied both a date and time, or explicitly requested an all-day event. Omit when any required date or time detail is missing.")
  var startAtISO8601: String?

  @Guide(description: "The new event end as an ISO 8601 timestamp with UTC offset. Omit unless the person explicitly supplied an end or duration. For an all-day date range, encode the exclusive end at midnight after the last spoken date.")
  var endAtISO8601: String?

  @Guide(description: "True only when the person explicitly requested an all-day event, false when they explicitly supplied a clock time, otherwise omit.")
  var allDay: Bool?

  @Guide(description: "The event category exactly as supplied by the person. This is required for add and update. Never infer it from the title.")
  var category: String?

  @Guide(description: "The new event location exactly as supplied by the person. Omit when absent.")
  var location: String?

  @Guide(description: "The new event notes exactly as supplied by the person. Omit when absent.")
  var memo: String?

  @Guide(description: "The event link exactly as supplied by the person. Omit when absent.")
  var url: String?

  @Guide(description: "Weather information exactly as supplied by the person. Omit when absent.")
  var weather: String?

  @Guide(description: "True only when the person explicitly requested a normal notification, false only when they explicitly rejected one, otherwise omit.")
  var reminderRequested: Bool?

  @Guide(description: "How many minutes before the event to notify. Omit when the person did not specify an offset.")
  var reminderMinutesBefore: Int?

  @Guide(description: "True only when the person explicitly requested an alarm, false only when explicitly disabled, otherwise omit.")
  var alarmEnabled: Bool?

  @Guide(description: "True only when the person explicitly requested D-day display, false only when explicitly disabled, otherwise omit.")
  var showDday: Bool?

  @Guide(description: "The replacement event title for an update request. Omit unless the person clearly supplied a new title.")
  var newTitle: String?

  @Guide(description: "The replacement start as an ISO 8601 timestamp with UTC offset. Omit unless the person clearly supplied it.")
  var newStartAtISO8601: String?

  @Guide(description: "The replacement end as an ISO 8601 timestamp with UTC offset. Omit unless the person clearly supplied it. For an all-day date range, encode the exclusive end at midnight after the last spoken date.")
  var newEndAtISO8601: String?

  @Guide(description: "For an update, true only when the replacement event is explicitly all-day and false when a replacement clock time was explicitly supplied. Otherwise omit.")
  var newAllDay: Bool?

  @Guide(description: "The replacement category exactly as supplied for an update. Never infer it.")
  var newCategory: String?
}

@available(iOS 26.0, macOS 26.0, *)
private enum DailyAppleIntelligenceInterpreter {
  static func interpret(_ command: String) async -> DailyGenerativeUnderstanding? {
    let model = SystemLanguageModel.default
    guard model.availability == .available,
          model.supportsLocale(.current) else {
      return nil
    }

    let session = LanguageModelSession(instructions: """
      You interpret a single spoken command for the Daily personal calendar app.
      The command may be in Korean, English, Japanese, or Traditional Chinese.
      Select only one supported action: yesterday, today, tomorrow, date, next, search,
      dday, add, update, or delete. Use unknown for unrelated text, general web
      questions, requests for another app, or ambiguous commands.

      Never invent an event, title, location, date, time, note, or requested
      change. Preserve identifying words from the person's command. A request to
      cancel or remove an existing calendar event is delete. A request to
      reschedule, rename, or move an event is update. Merely mentioning a date
      does not mean add. For an add request, leave startAtISO8601 empty unless a
      complete date and clock time were supplied, or the person explicitly said
      the event is all-day. A timed add or update needs both a start and an end.
      An all-day request needs an explicit date and may include a multi-day date
      range. Category is required for add and update and must never be guessed.
      Extract notification, alarm, D-day, location, link, weather, and notes only
      when the person explicitly mentions them. Never invent optional values.
      Use the current time and time zone supplied with the command only to
      resolve relative expressions such as yesterday, today, or tomorrow.
      """
    )

    do {
      let formatter = ISO8601DateFormatter()
      formatter.timeZone = .current
      formatter.formatOptions = [.withInternetDateTime]
      let context = "Current local time: \(formatter.string(from: Date())). Time zone: \(TimeZone.current.identifier)."
      let response = try await session.respond(
        to: "\(context) Interpret this Daily command exactly as spoken: \(command)",
        generating: DailyGeneratedCommand.self
      )
      guard let action = response.content.action.siriAction else { return nil }
      return DailyGenerativeUnderstanding(
        action: action,
        eventReference: normalizedGeneratedValue(response.content.eventReference),
        searchText: normalizedGeneratedValue(response.content.searchText),
        eventTitle: normalizedGeneratedValue(response.content.eventTitle),
        startAt: parsedDate(response.content.startAtISO8601),
        endAt: parsedDate(response.content.endAtISO8601),
        allDay: response.content.allDay,
        category: normalizedGeneratedValue(response.content.category),
        location: normalizedGeneratedValue(response.content.location),
        memo: normalizedGeneratedValue(response.content.memo),
        url: normalizedGeneratedValue(response.content.url),
        weather: normalizedGeneratedValue(response.content.weather),
        reminderRequested: response.content.reminderRequested,
        reminderMinutesBefore: response.content.reminderMinutesBefore,
        alarmEnabled: response.content.alarmEnabled,
        showDday: response.content.showDday,
        newTitle: normalizedGeneratedValue(response.content.newTitle),
        newStartAt: parsedDate(response.content.newStartAtISO8601),
        newEndAt: parsedDate(response.content.newEndAtISO8601),
        newAllDay: response.content.newAllDay,
        newCategory: normalizedGeneratedValue(response.content.newCategory)
      )
    } catch {
      NSLog("[DailySiri] Apple Intelligence interpretation failed: \(error.localizedDescription)")
      return nil
    }
  }

  private static func normalizedGeneratedValue(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func parsedDate(_ value: String?) -> Date? {
    guard let value = normalizedGeneratedValue(value) else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
      return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}

@available(iOS 26.0, macOS 26.0, *)
private enum DailyAppleIntelligenceNarrator {
  static func narrate(
    _ factualMessage: String,
    events: [DailySiriEvent]
  ) async -> String? {
    let model = SystemLanguageModel.default
    guard model.availability == .available,
          model.supportsLocale(.current) else {
      return nil
    }
    let session = LanguageModelSession(instructions: """
      You edit a factual Daily calendar response so it sounds natural when Siri
      reads it aloud. Never add, remove, reinterpret, translate, or change any
      date, weekday, time, event title, holiday, or count. Keep the first line as
      the date introduction. Keep every calendar event on its own separate line.
      Use a connective equivalent to 'also' only when an event line follows a
      holiday line. Do not use bullets, markdown, headings, or extra commentary.
      """)
    do {
      let response = try await session.respond(to: """
        Rewrite only the phrasing of this response while preserving every fact
        and every newline exactly as instructed:

        \(factualMessage)
        """)
      let candidate = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
      return validatesNarration(candidate, factualMessage: factualMessage, events: events)
        ? candidate
        : nil
    } catch {
      NSLog("[DailySiri] Apple Intelligence narration failed: \(error.localizedDescription)")
      return nil
    }
  }

  private static func validatesNarration(
    _ candidate: String,
    factualMessage: String,
    events: [DailySiriEvent]
  ) -> Bool {
    guard !candidate.isEmpty,
          candidate.split(separator: "\n", omittingEmptySubsequences: false).count ==
            factualMessage.split(separator: "\n", omittingEmptySubsequences: false).count,
          events.allSatisfy({ candidate.contains($0.title) }) else {
      return false
    }
    let factualNumbers = numericTokens(in: factualMessage)
    let candidateNumbers = numericTokens(in: candidate)
    return factualNumbers == candidateNumbers
  }

  private static func numericTokens(in value: String) -> [String] {
    guard let expression = try? NSRegularExpression(pattern: #"\d+"#) else {
      return []
    }
    return expression.matches(
      in: value,
      range: NSRange(value.startIndex..., in: value)
    ).compactMap { match in
      guard let range = Range(match.range, in: value) else { return nil }
      return String(value[range])
    }
  }
}

struct DailySiriEvent: Sendable {
  let id: String
  let title: String
  let memo: String?
  let location: String?
  let url: String?
  let weather: String?
  let startAt: Date
  let endAt: Date
  let allDay: Bool
  let categoryID: String
  let colorValue: Int64
  let reminderMinutesBefore: [Int]
  let showDday: Bool
  let alarmEnabled: Bool
  let allDayAlarmMinutes: Int
  let isHoliday: Bool
  let isLms: Bool
  let recurrenceFrequency: String
  let recurrenceInterval: Int
  let recurrenceUntil: Date?
  let recurrenceCount: Int?
  let recurrenceExcludedDates: Set<String>

  init(
    id: String,
    title: String,
    memo: String?,
    location: String?,
    url: String? = nil,
    weather: String? = nil,
    startAt: Date,
    endAt: Date,
    allDay: Bool,
    categoryID: String = "basic",
    colorValue: Int64 = 0xff2563eb,
    reminderMinutesBefore: [Int] = [],
    showDday: Bool,
    alarmEnabled: Bool = false,
    allDayAlarmMinutes: Int = 540,
    isHoliday: Bool = false,
    isLms: Bool = false,
    recurrenceFrequency: String = "none",
    recurrenceInterval: Int = 1,
    recurrenceUntil: Date? = nil,
    recurrenceCount: Int? = nil,
    recurrenceExcludedDates: Set<String> = []
  ) {
    self.id = id
    self.title = title
    self.memo = memo
    self.location = location
    self.url = url
    self.weather = weather
    self.startAt = startAt
    self.endAt = endAt
    self.allDay = allDay
    self.categoryID = categoryID
    self.colorValue = colorValue
    self.reminderMinutesBefore = reminderMinutesBefore
    self.showDday = showDday
    self.alarmEnabled = alarmEnabled
    self.allDayAlarmMinutes = allDayAlarmMinutes
    self.isHoliday = isHoliday
    self.isLms = isLms
    self.recurrenceFrequency = recurrenceFrequency
    self.recurrenceInterval = recurrenceInterval
    self.recurrenceUntil = recurrenceUntil
    self.recurrenceCount = recurrenceCount
    self.recurrenceExcludedDates = recurrenceExcludedDates
  }
}

#if os(iOS)
@available(iOS 16.0, *)
enum DailyWallpaperDataSource {
  static func events(from start: Date, to end: Date) throws -> [DailyWallpaperEvent] {
    try DailySiriDatabase.wallpaperEvents(from: start, to: end)
  }
}

@available(iOS 16.0, *)
private extension DailySiriDatabase {
  static func wallpaperEvents(from start: Date, to end: Date) throws -> [DailyWallpaperEvent] {
    let defaults = UserDefaults.standard
    let hidden = Set((defaults.string(forKey: "flutter.hiddenCategoryIds") ?? "[]")
      .data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [])
    let colors = Dictionary(DailySiriPreferences.categories.map { ($0.id, $0.colorValue) },
                            uniquingKeysWith: { _, latest in latest })
    let completed: Set<String> = try withDatabase { database in
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database,
        "SELECT id FROM event_records WHERE deleted_at IS NULL AND completed = 1", -1, &statement, nil) == SQLITE_OK else {
        throw DailySiriError.databaseUnavailable
      }
      defer { sqlite3_finalize(statement) }
      var ids = Set<String>()
      var status = sqlite3_step(statement)
      while status == SQLITE_ROW {
        ids.insert(string(statement, 0))
        status = sqlite3_step(statement)
      }
      guard status == SQLITE_DONE else { throw DailySiriError.databaseUnavailable }
      return ids
    }
    return try events(from: start, to: end).filter { !hidden.contains($0.categoryID) }.map {
      DailyWallpaperEvent(id: "\($0.id):\($0.startAt.timeIntervalSince1970)", title: $0.title,
        start: $0.startAt, end: $0.endAt, color: colors[$0.categoryID] ?? $0.colorValue,
        completed: completed.contains($0.id), holiday: $0.isHoliday)
    }
  }
}
#endif

enum DailyKoreanHolidayService {
  static func events(
    from start: Date,
    to end: Date,
    respectVisibilitySetting: Bool = true
  ) -> [DailySiriEvent] {
    guard end > start,
          !respectVisibilitySetting || holidaysAreVisible else {
      return []
    }
    let calendar = localGregorianCalendar
    let startYear = calendar.component(.year, from: start) - 1
    let endYear = calendar.component(.year, from: end) + 1
    return (startYear...endYear)
      .flatMap(holidays(for:))
      .filter { $0.date >= calendar.startOfDay(for: start) && $0.date < calendar.startOfDay(for: end) }
      .map { holiday in
        DailySiriEvent(
          id: "kr-holiday-\(dayKey(holiday.date))-\(holiday.title)",
          title: DailySiriText.holidayTitle(holiday.title),
          memo: nil,
          location: nil,
          startAt: holiday.date,
          endAt: calendar.date(byAdding: .day, value: 1, to: holiday.date)!,
          allDay: true,
          categoryID: "holiday",
          colorValue: 0xffef4444,
          showDday: false,
          isHoliday: true
        )
      }
      .sorted { $0.startAt < $1.startAt }
  }

  static func search(_ query: String, from start: Date, to end: Date) -> [DailySiriEvent] {
    guard holidaysAreVisible else { return [] }
    return events(from: start, to: end, respectVisibilitySetting: false).filter { event in
      let rawTitle = rawHolidayTitle(from: event.id) ?? event.title
      return DailySiriText.holidayMatches(rawTitle, query: query)
    }
  }

  private struct Holiday {
    let date: Date
    let title: String
  }

  private static var holidaysAreVisible: Bool {
    let defaults = UserDefaults.standard
    let key = "flutter.calendarShowHolidays"
    return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
  }

  private static func holidays(for year: Int) -> [Holiday] {
    let calendar = localGregorianCalendar
    var byDate: [Date: [String]] = [:]
    var substituteGroups: [[Date]] = []
    var singleSubstituteDates = Set<Date>()

    func add(_ date: Date, _ title: String) {
      let day = calendar.startOfDay(for: date)
      if !(byDate[day] ?? []).contains(title) {
        byDate[day, default: []].append(title)
      }
    }

    func fixed(_ month: Int, _ day: Int, _ title: String, substitute: Bool = false) {
      guard let date = localDate(year: year, month: month, day: day) else { return }
      add(date, title)
      if substitute { singleSubstituteDates.insert(date) }
    }

    fixed(1, 1, "신정")
    fixed(3, 1, "삼일절", substitute: true)
    if year >= 2027 { fixed(5, 1, "노동절", substitute: true) }
    fixed(5, 5, "어린이날", substitute: true)
    fixed(6, 6, "현충일")
    if year >= 2026 { fixed(7, 17, "제헌절", substitute: true) }
    fixed(8, 15, "광복절", substitute: true)
    fixed(10, 3, "개천절", substitute: true)
    fixed(10, 9, "한글날", substitute: true)
    fixed(12, 25, "기독탄신일", substitute: true)

    if let lunarNewYear = lunarDate(in: year, month: 1, day: 1),
       let previous = calendar.date(byAdding: .day, value: -1, to: lunarNewYear),
       let next = calendar.date(byAdding: .day, value: 1, to: lunarNewYear) {
      let group = [previous, lunarNewYear, next]
      add(previous, "설날 연휴")
      add(lunarNewYear, "설날")
      add(next, "설날 연휴")
      substituteGroups.append(group)
    }
    if let buddhaBirthday = lunarDate(in: year, month: 4, day: 8) {
      add(buddhaBirthday, "부처님 오신 날")
      singleSubstituteDates.insert(buddhaBirthday)
    }
    if let chuseok = lunarDate(in: year, month: 8, day: 15),
       let previous = calendar.date(byAdding: .day, value: -1, to: chuseok),
       let next = calendar.date(byAdding: .day, value: 1, to: chuseok) {
      let group = [previous, chuseok, next]
      add(previous, "추석 연휴")
      add(chuseok, "추석")
      add(next, "추석 연휴")
      substituteGroups.append(group)
    }

    var occupied = Set(byDate.keys)
    for date in singleSubstituteDates.sorted() {
      let day = calendar.startOfDay(for: date)
      if isWeekend(day) || (byDate[day]?.count ?? 0) > 1 {
        let substitute = nextAvailableBusinessDay(
          after: calendar.date(byAdding: .day, value: 1, to: day)!,
          occupied: occupied
        )
        add(substitute, "대체공휴일")
        occupied.insert(substitute)
      }
    }
    for group in substituteGroups {
      let needsSubstitute = group.contains { date in
        calendar.component(.weekday, from: date) == 1 ||
          (byDate[calendar.startOfDay(for: date)]?.count ?? 0) > 1
      }
      if needsSubstitute, let last = group.last {
        let substitute = nextAvailableBusinessDay(
          after: calendar.date(byAdding: .day, value: 1, to: last)!,
          occupied: occupied
        )
        add(substitute, "대체공휴일")
        occupied.insert(substitute)
      }
    }

    return byDate.map { date, titles in
      Holiday(date: date, title: titles.joined(separator: " · "))
    }.sorted { $0.date < $1.date }
  }

  private static func lunarDate(in year: Int, month: Int, day: Int) -> Date? {
    guard var cursor = seoulGregorianDate(year: year, month: 1, day: 1),
          let rangeEnd = seoulGregorianDate(year: year + 1, month: 1, day: 1) else {
      return nil
    }
    var lunarCalendar = Calendar(identifier: .chinese)
    lunarCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    var solarCalendar = Calendar(identifier: .gregorian)
    solarCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    while cursor < rangeEnd {
      let lunar = lunarCalendar.dateComponents([.month, .day], from: cursor)
      // In the Chinese/Korean lunar calendar the regular month precedes a
      // leap month with the same number, so the first match is the regular one.
      if lunar.month == month, lunar.day == day {
        let solar = solarCalendar.dateComponents([.year, .month, .day], from: cursor)
        guard let solarYear = solar.year,
              let solarMonth = solar.month,
              let solarDay = solar.day else { return nil }
        return localDate(year: solarYear, month: solarMonth, day: solarDay)
      }
      cursor = solarCalendar.date(byAdding: .day, value: 1, to: cursor)!
    }
    return nil
  }

  private static func seoulGregorianDate(year: Int, month: Int, day: Int) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
  }

  private static func localDate(year: Int, month: Int, day: Int) -> Date? {
    localGregorianCalendar.date(
      from: DateComponents(year: year, month: month, day: day)
    )
  }

  private static func nextAvailableBusinessDay(after start: Date, occupied: Set<Date>) -> Date {
    let calendar = localGregorianCalendar
    var candidate = calendar.startOfDay(for: start)
    while isWeekend(candidate) || occupied.contains(candidate) {
      candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
    }
    return candidate
  }

  private static func isWeekend(_ date: Date) -> Bool {
    let weekday = localGregorianCalendar.component(.weekday, from: date)
    return weekday == 1 || weekday == 7
  }

  private static func dayKey(_ date: Date) -> String {
    let components = localGregorianCalendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  private static func rawHolidayTitle(from identifier: String) -> String? {
    let components = identifier.split(separator: "-", maxSplits: 5, omittingEmptySubsequences: false)
    guard components.count == 6 else { return nil }
    return String(components[5])
  }

  private static var localGregorianCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar
  }
}

@available(iOS 16.0, macOS 13.0, *)
private enum DailySiriError: Error, CustomLocalizedStringResourceConvertible {
  case databaseUnavailable
  case eventNotFound
  case ambiguousEvent
  case invalidTime
  case lmsOriginalReadOnly

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .databaseUnavailable:
      LocalizedStringResource(stringLiteral: DailySiriText.databaseUnavailable)
    case .eventNotFound:
      LocalizedStringResource(stringLiteral: DailySiriText.eventNotFound)
    case .ambiguousEvent:
      LocalizedStringResource(stringLiteral: DailySiriText.ambiguousEvent)
    case .invalidTime:
      LocalizedStringResource(stringLiteral: DailySiriText.invalidTime)
    case .lmsOriginalReadOnly:
      LocalizedStringResource(stringLiteral: DailySiriText.lmsOriginalReadOnly)
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
private enum DailySiriDatabase {
  static func add(
    title: String,
    startAt: Date,
    endAt: Date,
    allDay: Bool,
    category: DailySiriCategory,
    location: String?,
    memo: String?,
    url: String? = nil,
    weather: String? = nil,
    reminderMinutesBefore: Int? = nil,
    showDday: Bool = false,
    alarmEnabled: Bool = false,
    allDayAlarmMinutes: Int = 540
  ) throws -> DailySiriEvent {
    guard endAt > startAt else { throw DailySiriError.invalidTime }
    let id = UUID().uuidString
    let now = Int64(Date().timeIntervalSince1970)
    try withDatabase { database in
      let sql = """
        INSERT INTO event_records (
          id, title, memo, location, url, weather, start_at, end_at, all_day,
          category, color_value, reminder_minutes_before,
          reminder_minutes_before_list, recurrence_frequency,
          recurrence_interval, recurrence_until, recurrence_count,
          recurrence_excluded_dates, created_at, updated_at, deleted_at,
          device_id, sync_status, show_dday, alarm_enabled,
          all_day_alarm_minutes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'none', 1,
          NULL, NULL, '[]', ?, ?, NULL, 'siri', 'pending', ?, ?, ?)
        """
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw DailySiriError.databaseUnavailable
      }
      defer { sqlite3_finalize(statement) }
      bind(id, to: 1, in: statement)
      bind(title, to: 2, in: statement)
      bind(location: memo, to: 3, in: statement)
      bind(location: location, to: 4, in: statement)
      bind(location: url, to: 5, in: statement)
      bind(location: weather, to: 6, in: statement)
      sqlite3_bind_int64(statement, 7, Int64(startAt.timeIntervalSince1970))
      sqlite3_bind_int64(statement, 8, Int64(endAt.timeIntervalSince1970))
      sqlite3_bind_int(statement, 9, allDay ? 1 : 0)
      bind(category.id, to: 10, in: statement)
      sqlite3_bind_int64(statement, 11, category.colorValue)
      if let reminderMinutesBefore {
        sqlite3_bind_int(statement, 12, Int32(reminderMinutesBefore))
        bind("[\(reminderMinutesBefore)]", to: 13, in: statement)
      } else {
        sqlite3_bind_null(statement, 12)
        bind("[]", to: 13, in: statement)
      }
      sqlite3_bind_int64(statement, 14, now)
      sqlite3_bind_int64(statement, 15, now)
      sqlite3_bind_int(statement, 16, showDday ? 1 : 0)
      sqlite3_bind_int(statement, 17, alarmEnabled ? 1 : 0)
      sqlite3_bind_int(statement, 18, Int32(min(max(allDayAlarmMinutes, 0), 1439)))
      guard sqlite3_step(statement) == SQLITE_DONE else {
        throw DailySiriError.databaseUnavailable
      }
    }
    if #available(iOS 18.0, macOS 15.0, *) {
      DailySiriSearchIndexer.scheduleRefresh()
    }
    DailySiriEventChangeSignal.post(
      eventID: id,
      action: "add",
      reminderMinutesBefore: reminderMinutesBefore.map { [$0] } ?? []
    )
    return DailySiriEvent(
      id: id,
      title: title,
      memo: memo,
      location: location,
      url: url,
      weather: weather,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      categoryID: category.id,
      colorValue: category.colorValue,
      reminderMinutesBefore: reminderMinutesBefore.map { [$0] } ?? [],
      showDday: showDday,
      alarmEnabled: alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes
    )
  }

  static func events(from start: Date, to end: Date) throws -> [DailySiriEvent] {
    let storedEvents = try storedEvents(from: start, to: end)
    return (storedEvents + DailyKoreanHolidayService.events(from: start, to: end))
      .sorted { left, right in
        if left.startAt != right.startAt { return left.startAt < right.startAt }
        return left.title < right.title
      }
  }

  private static func storedEvents(from start: Date, to end: Date) throws -> [DailySiriEvent] {
    let baseEvents = try query(
      whereClause: """
        deleted_at IS NULL AND start_at < ? AND (
          (recurrence_frequency = 'none' AND end_at > ?) OR
          (recurrence_frequency != 'none' AND (recurrence_until IS NULL OR recurrence_until >= ?))
        )
        """,
      bindings: [
        .integer(Int64(end.timeIntervalSince1970)),
        .integer(Int64(start.timeIntervalSince1970)),
        .integer(Int64(start.timeIntervalSince1970)),
      ]
    )
    return baseEvents
      .flatMap { occurrences(of: $0, from: start, to: end) }
      .sorted { $0.startAt < $1.startAt }
  }

  static func nextEvent(after date: Date) throws -> DailySiriEvent? {
    let horizon = Calendar.current.date(byAdding: .year, value: 10, to: date)!
    return try events(from: date, to: horizon).first
  }

  static func search(_ queryText: String) throws -> [DailySiriEvent] {
    let calendar = Calendar.current
    let now = Date()
    let holidayStart = calendar.date(byAdding: .year, value: -1, to: now) ?? now
    let holidayEnd = calendar.date(byAdding: .year, value: 10, to: now) ?? now
    let holidays = DailyKoreanHolidayService.search(
      queryText,
      from: holidayStart,
      to: holidayEnd
    )
    return Array((try searchEditable(queryText) + holidays)
      .sorted { $0.startAt < $1.startAt }
      .prefix(10))
  }

  static func searchEditable(_ queryText: String) throws -> [DailySiriEvent] {
    let pattern = "%\(queryText)%"
    return try query(
      whereClause: "deleted_at IS NULL AND (title LIKE ? OR memo LIKE ? OR location LIKE ?)",
      bindings: [.text(pattern), .text(pattern), .text(pattern)],
      limit: 10
    )
  }

  static func events(withIDs identifiers: [String]) throws -> [DailySiriEvent] {
    guard !identifiers.isEmpty else { return [] }
    let placeholders = Array(repeating: "?", count: identifiers.count).joined(separator: ", ")
    return try query(
      whereClause: "deleted_at IS NULL AND id IN (\(placeholders))",
      bindings: identifiers.map(Binding.text)
    )
  }

  static func suggestedEvents() throws -> [DailySiriEvent] {
    let start = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    let end = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    return Array(try storedEvents(from: start, to: end).prefix(50))
  }

  static func indexableEvents() throws -> [DailySiriEvent] {
    try query(
      whereClause: "deleted_at IS NULL",
      bindings: []
    ).filter { !$0.isLms }
  }

  static func requireEditable(id: String) throws {
    guard !id.hasPrefix("lms:") else { throw DailySiriError.lmsOriginalReadOnly }
    guard let event = try events(withIDs: [id]).first else { throw DailySiriError.eventNotFound }
    guard !event.isLms else { throw DailySiriError.lmsOriginalReadOnly }
  }

  static func ddayEvents() throws -> [DailySiriEvent] {
    try query(
      whereClause: "deleted_at IS NULL AND show_dday = 1",
      bindings: [],
      limit: 10
    )
  }

  static func update(
    matching title: String,
    newTitle: String?,
    newStartAt: Date?,
    newEndAt: Date?,
    newAllDay: Bool? = nil,
    newCategory: DailySiriCategory? = nil,
    newLocation: String? = nil,
    newMemo: String? = nil,
    newURL: String? = nil,
    newWeather: String? = nil,
    reminderMinutesBefore: Int? = nil,
    showDday: Bool? = nil,
    alarmEnabled: Bool? = nil
  ) throws -> DailySiriEvent {
    let matches = try exactMatches(title)
    guard let event = matches.first else { throw DailySiriError.eventNotFound }
    guard matches.count == 1 else { throw DailySiriError.ambiguousEvent }
    return try update(
      event: event,
      newTitle: newTitle,
      newStartAt: newStartAt,
      newEndAt: newEndAt,
      newAllDay: newAllDay,
      newCategory: newCategory,
      newLocation: newLocation,
      newMemo: newMemo,
      newURL: newURL,
      newWeather: newWeather,
      reminderMinutesBefore: reminderMinutesBefore,
      showDday: showDday,
      alarmEnabled: alarmEnabled
    )
  }

  static func update(
    id: String,
    newTitle: String?,
    newStartAt: Date?,
    newEndAt: Date?,
    newAllDay: Bool? = nil,
    newCategory: DailySiriCategory? = nil,
    newLocation: String? = nil,
    newMemo: String? = nil,
    newURL: String? = nil,
    newWeather: String? = nil,
    reminderMinutesBefore: Int? = nil,
    showDday: Bool? = nil,
    alarmEnabled: Bool? = nil
  ) throws -> DailySiriEvent {
    guard let event = try events(withIDs: [id]).first else {
      throw DailySiriError.eventNotFound
    }
    return try update(
      event: event,
      newTitle: newTitle,
      newStartAt: newStartAt,
      newEndAt: newEndAt,
      newAllDay: newAllDay,
      newCategory: newCategory,
      newLocation: newLocation,
      newMemo: newMemo,
      newURL: newURL,
      newWeather: newWeather,
      reminderMinutesBefore: reminderMinutesBefore,
      showDday: showDday,
      alarmEnabled: alarmEnabled
    )
  }

  private static func update(
    event: DailySiriEvent,
    newTitle: String?,
    newStartAt: Date?,
    newEndAt: Date?,
    newAllDay: Bool?,
    newCategory: DailySiriCategory?,
    newLocation: String?,
    newMemo: String?,
    newURL: String?,
    newWeather: String?,
    reminderMinutesBefore: Int?,
    showDday: Bool?,
    alarmEnabled: Bool?
  ) throws -> DailySiriEvent {
    guard !event.isLms else { throw DailySiriError.lmsOriginalReadOnly }
    let updatedTitle = normalized(newTitle) ?? event.title
    let updatedStart = newStartAt ?? event.startAt
    let updatedEnd: Date
    if let newEndAt {
      updatedEnd = newEndAt
    } else if newStartAt != nil {
      updatedEnd = updatedStart.addingTimeInterval(event.endAt.timeIntervalSince(event.startAt))
    } else {
      updatedEnd = event.endAt
    }
    guard updatedEnd > updatedStart else { throw DailySiriError.invalidTime }
    let resolvedReminders = reminderMinutesBefore.map { [$0] } ?? event.reminderMinutesBefore
    try withDatabase { database in
      let sql = """
        UPDATE event_records SET title = ?, start_at = ?, end_at = ?, all_day = ?,
          category = ?, color_value = ?, location = ?, memo = ?, url = ?, weather = ?,
          reminder_minutes_before = ?, reminder_minutes_before_list = ?,
          show_dday = ?, alarm_enabled = ?, updated_at = ?, sync_status = 'pending'
        WHERE id = ? AND id NOT LIKE 'lms:%' \(try lmsMutationPredicate(database))
        """
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw DailySiriError.databaseUnavailable
      }
      defer { sqlite3_finalize(statement) }
      bind(updatedTitle, to: 1, in: statement)
      sqlite3_bind_int64(statement, 2, Int64(updatedStart.timeIntervalSince1970))
      sqlite3_bind_int64(statement, 3, Int64(updatedEnd.timeIntervalSince1970))
      sqlite3_bind_int(statement, 4, (newAllDay ?? event.allDay) ? 1 : 0)
      bind(newCategory?.id ?? event.categoryID, to: 5, in: statement)
      sqlite3_bind_int64(statement, 6, newCategory?.colorValue ?? event.colorValue)
      bind(location: newLocation ?? event.location, to: 7, in: statement)
      bind(location: newMemo ?? event.memo, to: 8, in: statement)
      bind(location: newURL ?? event.url, to: 9, in: statement)
      bind(location: newWeather ?? event.weather, to: 10, in: statement)
      if let first = resolvedReminders.first {
        sqlite3_bind_int(statement, 11, Int32(first))
      } else {
        sqlite3_bind_null(statement, 11)
      }
      let reminderData = try? JSONEncoder().encode(resolvedReminders)
      bind(String(data: reminderData ?? Data("[]".utf8), encoding: .utf8) ?? "[]", to: 12, in: statement)
      sqlite3_bind_int(statement, 13, (showDday ?? event.showDday) ? 1 : 0)
      sqlite3_bind_int(statement, 14, (alarmEnabled ?? event.alarmEnabled) ? 1 : 0)
      sqlite3_bind_int64(statement, 15, Int64(Date().timeIntervalSince1970))
      bind(event.id, to: 16, in: statement)
      guard sqlite3_step(statement) == SQLITE_DONE else { throw DailySiriError.databaseUnavailable }
      guard sqlite3_changes(database) == 1 else { throw DailySiriError.eventNotFound }
    }
    if #available(iOS 18.0, macOS 15.0, *) {
      DailySiriSearchIndexer.scheduleRefresh()
    }
    DailySiriEventChangeSignal.post(
      eventID: event.id,
      action: "update",
      reminderMinutesBefore: Array(Set(event.reminderMinutesBefore + resolvedReminders))
    )
    return DailySiriEvent(
      id: event.id,
      title: updatedTitle,
      memo: newMemo ?? event.memo,
      location: newLocation ?? event.location,
      url: newURL ?? event.url,
      weather: newWeather ?? event.weather,
      startAt: updatedStart,
      endAt: updatedEnd,
      allDay: newAllDay ?? event.allDay,
      categoryID: newCategory?.id ?? event.categoryID,
      colorValue: newCategory?.colorValue ?? event.colorValue,
      reminderMinutesBefore: reminderMinutesBefore.map { [$0] } ?? event.reminderMinutesBefore,
      showDday: showDday ?? event.showDday,
      alarmEnabled: alarmEnabled ?? event.alarmEnabled,
      allDayAlarmMinutes: event.allDayAlarmMinutes,
      recurrenceFrequency: event.recurrenceFrequency,
      recurrenceInterval: event.recurrenceInterval,
      recurrenceUntil: event.recurrenceUntil,
      recurrenceCount: event.recurrenceCount,
      recurrenceExcludedDates: event.recurrenceExcludedDates
    )
  }

  static func delete(matching title: String) throws -> DailySiriEvent {
    let matches = try exactMatches(title)
    guard let event = matches.first else { throw DailySiriError.eventNotFound }
    guard matches.count == 1 else { throw DailySiriError.ambiguousEvent }
    return try delete(event: event)
  }

  static func delete(id: String) throws -> DailySiriEvent {
    guard let event = try events(withIDs: [id]).first else {
      throw DailySiriError.eventNotFound
    }
    return try delete(event: event)
  }

  private static func delete(event: DailySiriEvent) throws -> DailySiriEvent {
    guard !event.isLms else { throw DailySiriError.lmsOriginalReadOnly }
    try withDatabase { database in
      let sql = "UPDATE event_records SET deleted_at = ?, updated_at = ?, sync_status = 'pending_delete' WHERE id = ? AND id NOT LIKE 'lms:%' \(try lmsMutationPredicate(database))"
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw DailySiriError.databaseUnavailable
      }
      defer { sqlite3_finalize(statement) }
      let now = Int64(Date().timeIntervalSince1970)
      sqlite3_bind_int64(statement, 1, now)
      sqlite3_bind_int64(statement, 2, now)
      bind(event.id, to: 3, in: statement)
      guard sqlite3_step(statement) == SQLITE_DONE else { throw DailySiriError.databaseUnavailable }
      guard sqlite3_changes(database) == 1 else { throw DailySiriError.eventNotFound }
    }
    if #available(iOS 18.0, macOS 15.0, *) {
      DailySiriSearchIndexer.scheduleRefresh()
    }
    DailySiriEventChangeSignal.post(
      eventID: event.id,
      action: "delete",
      reminderMinutesBefore: event.reminderMinutesBefore
    )
    return event
  }

  private enum Binding {
    case integer(Int64)
    case text(String)
  }

  private static func exactMatches(_ title: String) throws -> [DailySiriEvent] {
    try query(
      whereClause: "deleted_at IS NULL AND title = ? COLLATE NOCASE",
      bindings: [.text(title)],
      limit: 2
    )
  }

  private static func query(
    whereClause: String,
    bindings: [Binding],
    limit: Int? = nil
  ) throws -> [DailySiriEvent] {
    try withDatabase { database in
      let visibility = lmsVisibility()
      let metadataColumn = try hasLmsMetadataColumn(database) ? "lms_metadata" : "NULL"
      let sql = """
        SELECT id, title, memo, location, url, weather, start_at, end_at,
          all_day, category, color_value, reminder_minutes_before_list,
          show_dday, alarm_enabled, all_day_alarm_minutes,
          recurrence_frequency, recurrence_interval, recurrence_until,
          recurrence_count, recurrence_excluded_dates, \(metadataColumn)
        FROM event_records WHERE \(whereClause) ORDER BY start_at ASC
        """
      var statement: OpaquePointer?
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw DailySiriError.databaseUnavailable
      }
      defer { sqlite3_finalize(statement) }
      for (offset, binding) in bindings.enumerated() {
        switch binding {
        case .integer(let value): sqlite3_bind_int64(statement, Int32(offset + 1), value)
        case .text(let value): bind(value, to: Int32(offset + 1), in: statement)
        }
      }
      var events: [DailySiriEvent] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let id = string(statement, 0)
        let metadata = optionalString(statement, 20)
        guard visibility.allows(id: id, metadata: metadata) else { continue }
        events.append(
          DailySiriEvent(
            id: id,
            title: string(statement, 1),
            memo: optionalString(statement, 2),
            location: optionalString(statement, 3),
            url: optionalString(statement, 4),
            weather: optionalString(statement, 5),
            startAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 6))),
            endAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 7))),
            allDay: sqlite3_column_int(statement, 8) == 1,
            categoryID: string(statement, 9),
            colorValue: sqlite3_column_int64(statement, 10),
            reminderMinutesBefore: integerList(optionalString(statement, 11)),
            showDday: sqlite3_column_int(statement, 12) == 1,
            alarmEnabled: sqlite3_column_int(statement, 13) == 1,
            allDayAlarmMinutes: Int(sqlite3_column_int(statement, 14)),
            isLms: DailySiriLmsVisibility.isLms(id: id, metadata: metadata),
            recurrenceFrequency: string(statement, 15),
            recurrenceInterval: max(Int(sqlite3_column_int(statement, 16)), 1),
            recurrenceUntil: optionalDate(statement, 17),
            recurrenceCount: optionalInt(statement, 18),
            recurrenceExcludedDates: excludedDates(optionalString(statement, 19))
          )
        )
        // Apply limits after authorization, so hidden LMS rows cannot consume
        // the ordinary event search result limit.
        if let limit, events.count >= limit { break }
      }
      if visibility != lmsVisibility() { events.removeAll { $0.isLms } }
      return events
    }
  }

  private static func hasLmsMetadataColumn(_ database: OpaquePointer) throws -> Bool {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "PRAGMA table_info(event_records)", -1, &statement, nil) == SQLITE_OK else {
      throw DailySiriError.databaseUnavailable
    }
    defer { sqlite3_finalize(statement) }
    while sqlite3_step(statement) == SQLITE_ROW {
      if string(statement, 1) == "lms_metadata" { return true }
    }
    return false
  }

  private static func lmsMutationPredicate(_ database: OpaquePointer) throws -> String {
    try hasLmsMetadataColumn(database) ? "AND lms_metadata IS NULL" : ""
  }

  private static func lmsVisibility() -> DailySiriLmsVisibility {
    var owner: String?
    if let accountJSON = UserDefaults.standard.string(forKey: "flutter.dailyAccount"),
       let data = accountJSON.data(using: .utf8),
       let account = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       let google = account["googleAccount"] as? [String: Any] {
      owner = google["email"] as? String
    }
    var snapshot: [String: Any]?
    if let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: DailySiriLogStore.appGroup
    )?.appendingPathComponent("daily-widget-snapshot.json"),
       let data = try? Data(contentsOf: url) {
      snapshot = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    return DailySiriLmsVisibility(ownerID: owner, snapshot: snapshot)
  }

  private static func withDatabase<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
    guard let url = databaseURL(), FileManager.default.fileExists(atPath: url.path) else {
      throw DailySiriError.databaseUnavailable
    }
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
          let database else {
      throw DailySiriError.databaseUnavailable
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 5000)
    return try operation(database)
  }

  private static func databaseURL() -> URL? {
    guard var directory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else { return nil }
    #if os(macOS)
    directory.appendPathComponent(Bundle.main.bundleIdentifier ?? "com.littlebit0.daily", isDirectory: true)
    #endif
    return directory.appendingPathComponent("daily.sqlite")
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func bind(_ value: String, to index: Int32, in statement: OpaquePointer?) {
    sqlite3_bind_text(statement, index, value, -1, dailySQLiteTransient)
  }

  private static func bind(location value: String?, to index: Int32, in statement: OpaquePointer?) {
    if let value { bind(value, to: index, in: statement) } else { sqlite3_bind_null(statement, index) }
  }

  private static func string(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let value = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: value)
  }

  private static func optionalString(_ statement: OpaquePointer?, _ column: Int32) -> String? {
    sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : string(statement, column)
  }

  private static func optionalDate(_ statement: OpaquePointer?, _ column: Int32) -> Date? {
    guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, column)))
  }

  private static func optionalInt(_ statement: OpaquePointer?, _ column: Int32) -> Int? {
    guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int(statement, column))
  }

  private static func excludedDates(_ json: String?) -> Set<String> {
    guard let json, let data = json.data(using: .utf8),
          let values = try? JSONDecoder().decode([String].self, from: data) else {
      return []
    }
    return Set(values.compactMap { value in
      guard value.count >= 10 else { return nil }
      return String(value.prefix(10))
    })
  }

  private static func integerList(_ json: String?) -> [Int] {
    guard let json, let data = json.data(using: .utf8),
          let values = try? JSONDecoder().decode([Int].self, from: data) else {
      return []
    }
    return values
  }

  private static func occurrences(
    of event: DailySiriEvent,
    from rangeStart: Date,
    to rangeEnd: Date
  ) -> [DailySiriEvent] {
    guard event.recurrenceFrequency != "none" else {
      return event.startAt < rangeEnd && event.endAt > rangeStart ? [event] : []
    }
    let calendar = Calendar.current
    let duration = event.endAt.timeIntervalSince(event.startAt)
    var start = event.startAt
    var occurrenceIndex = 0
    var result: [DailySiriEvent] = []
    while start < rangeEnd && occurrenceIndex < 100_000 {
      if let count = event.recurrenceCount, occurrenceIndex >= count { break }
      if let until = event.recurrenceUntil, start > until { break }
      let occurrenceEnd = start.addingTimeInterval(duration)
      if occurrenceEnd > rangeStart &&
          !event.recurrenceExcludedDates.contains(dayKey(start)) {
        result.append(
          DailySiriEvent(
            id: event.id,
            title: event.title,
            memo: event.memo,
            location: event.location,
            url: event.url,
            weather: event.weather,
            startAt: start,
            endAt: occurrenceEnd,
            allDay: event.allDay,
            categoryID: event.categoryID,
            colorValue: event.colorValue,
            reminderMinutesBefore: event.reminderMinutesBefore,
            showDday: event.showDday,
            alarmEnabled: event.alarmEnabled,
            allDayAlarmMinutes: event.allDayAlarmMinutes,
            isHoliday: event.isHoliday,
            isLms: event.isLms,
            recurrenceFrequency: event.recurrenceFrequency,
            recurrenceInterval: event.recurrenceInterval,
            recurrenceUntil: event.recurrenceUntil,
            recurrenceCount: event.recurrenceCount,
            recurrenceExcludedDates: event.recurrenceExcludedDates
          )
        )
      }
      occurrenceIndex += 1
      guard let next = nextOccurrence(after: start, event: event, calendar: calendar),
            next > start else { break }
      start = next
    }
    return result
  }

  private static func nextOccurrence(
    after date: Date,
    event: DailySiriEvent,
    calendar: Calendar
  ) -> Date? {
    let interval = max(event.recurrenceInterval, 1)
    switch event.recurrenceFrequency {
    case "daily": return calendar.date(byAdding: .day, value: interval, to: date)
    case "weekly": return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
    case "monthly": return calendar.date(byAdding: .month, value: interval, to: date)
    case "yearly": return calendar.date(byAdding: .year, value: interval, to: date)
    default: return nil
    }
  }

  private static func dayKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct DailyEventQuery: EntityStringQuery {
  func entities(for identifiers: [DailyEventEntity.ID]) async throws -> [DailyEventEntity] {
    try DailySiriDatabase.events(withIDs: identifiers).map(DailyEventEntity.init)
  }

  func entities(matching string: String) async throws -> [DailyEventEntity] {
    try DailySiriDatabase.searchEditable(string).map(DailyEventEntity.init)
  }

  func suggestedEntities() async throws -> [DailyEventEntity] {
    try DailySiriDatabase.suggestedEvents().map(DailyEventEntity.init)
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct DailyEventEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Daily event"
  static var defaultQuery = DailyEventQuery()

  let id: String
  @Property(title: "Title") var title: String
  @Property(title: "Start") var startAt: Date
  @Property(title: "End") var endAt: Date
  @Property(title: "Location") var location: String?
  @Property(title: "Notes") var memo: String?
  @Property(title: "All-day") var allDay: Bool

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(title)",
      subtitle: "\(startAt.formatted(date: .abbreviated, time: .shortened))"
    )
  }

  fileprivate init(_ event: DailySiriEvent) {
    id = event.id
    title = event.title
    startAt = event.startAt
    endAt = event.endAt
    location = event.location
    memo = event.memo
    allDay = event.allDay
  }
}

@available(iOS 18.0, macOS 15.0, *)
extension DailyEventEntity: IndexedEntity {
  var attributeSet: CSSearchableItemAttributeSet {
    let attributes = defaultAttributeSet
    attributes.title = title
    attributes.contentDescription = [memo, location]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
    attributes.startDate = startAt
    attributes.endDate = endAt
    attributes.allDay = NSNumber(value: allDay)
    attributes.namedLocation = location
    attributes.keywords = [
      "Daily", "DailyCalendar", "calendar", "event", "일정", "캘린더",
    ]
    return attributes
  }
}

@available(iOS 18.0, macOS 15.0, *)
actor DailySiriSearchIndexer {
  static let shared = DailySiriSearchIndexer()

  private let index = CSSearchableIndex(name: "com.littlebit0.daily.events")
  private var pendingRefresh: Task<Void, Never>?

  nonisolated static func scheduleRefresh() {
    Task { await shared.schedule() }
  }

  private func schedule() {
    pendingRefresh?.cancel()
    pendingRefresh = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      await self?.refresh()
    }
  }

  private func refresh() async {
    do {
      let entities = try DailySiriDatabase.indexableEvents().map(DailyEventEntity.init)
      try await index.deleteAppEntities(ofType: DailyEventEntity.self)
      if !entities.isEmpty {
        try await index.indexAppEntities(entities, priority: 5)
      }
    } catch {
      NSLog("[DailySiri] Spotlight event indexing failed: \(error.localizedDescription)")
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
enum DailySiriAction: String, AppEnum {
  case yesterday
  case today
  case tomorrow
  case date
  case next
  case search
  case dday
  case add
  case update
  case delete

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Daily action")
  static var caseDisplayRepresentations: [DailySiriAction: DisplayRepresentation] = [
    .yesterday: DisplayRepresentation(title: "어제 일정"),
    .today: DisplayRepresentation(title: "오늘 일정"),
    .tomorrow: DisplayRepresentation(title: "내일 일정"),
    .date: DisplayRepresentation(title: "지정 날짜 일정"),
    .next: DisplayRepresentation(title: "다음 일정"),
    .search: DisplayRepresentation(title: "일정 검색"),
    .dday: DisplayRepresentation(title: "D-day 일정"),
    .add: DisplayRepresentation(title: "일정 추가"),
    .update: DisplayRepresentation(title: "일정 수정"),
    .delete: DisplayRepresentation(title: "일정 삭제"),
  ]
}

@available(iOS 16.0, macOS 13.0, *)
struct AddDailyEventIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Daily Event"
  static var description = IntentDescription("Adds one event to Daily.")
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: "Title") var eventTitle: String
  @Parameter(title: "Start") var startAt: Date
  @Parameter(title: "End") var endAt: Date?
  @Parameter(title: "All-day") var allDay: Bool
  @Parameter(title: "Category") var category: String
  @Parameter(title: "Location") var location: String?
  @Parameter(title: "Notes") var memo: String?
  @Parameter(title: "Link") var url: String?
  @Parameter(title: "Weather") var weather: String?
  @Parameter(title: "Notify minutes before") var reminderMinutesBefore: Int?
  @Parameter(title: "Alarm") var alarmEnabled: Bool?
  @Parameter(title: "D-day") var showDday: Bool?

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$eventTitle) at \(\.$startAt)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let calendar = Calendar.current
    let start = allDay ? calendar.startOfDay(for: startAt) : startAt
    if !allDay && endAt == nil {
      throw $endAt.requestValue(IntentDialog(stringLiteral: DailySiriText.endRequest))
    }
    guard let resolvedCategory = DailySiriPreferences.category(matching: category) else {
      throw $category.requestValue(IntentDialog(stringLiteral: DailySiriText.categoryRequest))
    }
    let fallbackEnd = calendar.date(byAdding: .day, value: 1, to: start)!
    let event = try loggedSiriOperation(action: "add", summary: eventTitle) {
      try DailySiriDatabase.add(
        title: eventTitle,
        startAt: start,
        endAt: endAt ?? fallbackEnd,
        allDay: allDay,
        category: resolvedCategory,
        location: location,
        memo: memo,
        url: url,
        weather: weather,
        reminderMinutesBefore: reminderMinutesBefore,
        showDday: showDday ?? false,
        alarmEnabled: alarmEnabled ?? false
      )
    }
    let summary = "\(event.title) · \(DailySiriText.date(event.startAt, includeTime: true))"
    DailySiriLogStore.append(
      action: "add",
      summary: summary,
      result: "completed",
      success: true,
      details: siriEventDetails(event)
    )
    return .result(dialog: IntentDialog(stringLiteral: DailySiriText.added(event.title)))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct GetTodayDailyEventsIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Today's Daily Events"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let start = Calendar.current.startOfDay(for: Date())
    let response = try await eventDialog(action: "today", label: DailySiriText.todayLabel(), from: start, to: Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct GetTomorrowDailyEventsIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Tomorrow's Daily Events"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let today = Calendar.current.startOfDay(for: Date())
    let start = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let response = try await eventDialog(action: "tomorrow", label: DailySiriText.tomorrowLabel(), from: start, to: Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct GetDailyEventsOnDateIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Daily Events on Date"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @Parameter(title: "Date") var date: Date
  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let start = Calendar.current.startOfDay(for: date)
    let response = try await eventDialog(action: "date", label: DailySiriText.date(date, includeTime: false), from: start, to: Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct GetNextDailyEventIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Next Daily Event"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let event = try loggedSiriOperation(action: "next", summary: "Next event") {
      try DailySiriDatabase.nextEvent(after: Date())
    }
    let message = DailySiriText.nextEvent(event)
    logSiriRead(action: "next", summary: "Next event", result: message, events: event.map { [$0] } ?? [])
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct SearchDailyEventsIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Daily Events"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @Parameter(title: "Search text") var query: String
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let events = try loggedSiriOperation(action: "search", summary: query) {
      try DailySiriDatabase.search(query)
    }
    let message = summaryMessage(events, empty: DailySiriText.noSearchResults)
    logSiriRead(action: "search", summary: query, result: message, events: events)
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct UpdateDailyEventIntent: AppIntent {
  static var title: LocalizedStringResource = "Update Daily Event"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
  @Parameter(title: "Event") var event: DailyEventEntity
  @Parameter(title: "New title") var newTitle: String?
  @Parameter(title: "New start") var newStartAt: Date?
  @Parameter(title: "New end") var newEndAt: Date?
  @Parameter(title: "All-day") var newAllDay: Bool?
  @Parameter(title: "Category") var newCategory: String?
  @Parameter(title: "Location") var newLocation: String?
  @Parameter(title: "Notes") var newMemo: String?
  @Parameter(title: "Link") var newURL: String?
  @Parameter(title: "Weather") var newWeather: String?
  @Parameter(title: "Notify minutes before") var reminderMinutesBefore: Int?
  @Parameter(title: "Alarm") var alarmEnabled: Bool?
  @Parameter(title: "D-day") var showDday: Bool?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try DailySiriDatabase.requireEditable(id: event.id)
    guard let newTitle, !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw $newTitle.requestValue(IntentDialog(stringLiteral: DailySiriText.addTitleRequest))
    }
    guard let newStartAt else {
      throw $newStartAt.requestValue(IntentDialog(stringLiteral: DailySiriText.startRequest))
    }
    guard let newAllDay else {
      throw $newAllDay.requestValue(IntentDialog(stringLiteral: DailySiriText.allDayRequest))
    }
    if !newAllDay && newEndAt == nil {
      throw $newEndAt.requestValue(IntentDialog(stringLiteral: DailySiriText.endRequest))
    }
    guard let newCategory,
          let resolvedCategory = DailySiriPreferences.category(matching: newCategory) else {
      throw $newCategory.requestValue(IntentDialog(stringLiteral: DailySiriText.categoryRequest))
    }
    let resolvedEnd = newEndAt ?? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: newStartAt))!
    let updatedEvent = try loggedSiriOperation(action: "update", summary: event.title) {
      try DailySiriDatabase.update(
        id: event.id,
        newTitle: newTitle,
        newStartAt: newStartAt,
        newEndAt: resolvedEnd,
        newAllDay: newAllDay,
        newCategory: resolvedCategory,
        newLocation: newLocation,
        newMemo: newMemo,
        newURL: newURL,
        newWeather: newWeather,
        reminderMinutesBefore: reminderMinutesBefore,
        showDday: showDday,
        alarmEnabled: alarmEnabled
      )
    }
    DailySiriLogStore.append(
      action: "update",
      summary: event.title,
      result: updatedEvent.title,
      success: true,
      details: siriEventDetails(updatedEvent)
    )
    return .result(dialog: IntentDialog(stringLiteral: DailySiriText.updated(updatedEvent.title)))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct DeleteDailyEventIntent: AppIntent {
  static var title: LocalizedStringResource = "Delete Daily Event"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
  @Parameter(title: "Event") var event: DailyEventEntity

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try DailySiriDatabase.requireEditable(id: event.id)
    do {
      try await requestConfirmation(result: .result(
        dialog: IntentDialog(stringLiteral: DailySiriText.deleteConfirmation(event.title))
      ))
    } catch {
      DailySiriLogStore.append(
        action: "delete",
        summary: event.title,
        result: "cancelled",
        success: false
      )
      throw error
    }
    let deletedEvent = try loggedSiriOperation(action: "delete", summary: event.title) {
      try DailySiriDatabase.delete(id: event.id)
    }
    DailySiriLogStore.append(
      action: "delete",
      summary: deletedEvent.title,
      result: "completed",
      success: true,
      details: siriEventDetails(deletedEvent)
    )
    return .result(dialog: IntentDialog(stringLiteral: DailySiriText.deleted(deletedEvent.title)))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct GetDailyDdayEventsIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Daily D-day Events"
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let events = try loggedSiriOperation(action: "dday", summary: "D-day") {
      try DailySiriDatabase.ddayEvents()
    }
    let message = summaryMessage(events, empty: DailySiriText.noDdayEvents)
    logSiriRead(action: "dday", summary: "D-day", result: message, events: events)
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenDailyCalendarIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Daily Calendar"
  static var openAppWhenRun = true
  func perform() async throws -> some IntentResult {
    DailySiriLogStore.append(action: "open", summary: "Daily calendar", result: "completed", success: true)
    return .result()
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct DailySignalCommandIntent: AppIntent {
  static var title: LocalizedStringResource = "Daily Signal"
  static var description = IntentDescription("Interprets a captured Signal phrase as one of Daily's supported calendar actions.")
  // Read-only Signal requests respect the user's Siri/Shortcuts permission.
  // Sensitive mutations request device-owner authentication at execution time.
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(
    title: "Signal phrase",
    requestValueDialog: IntentDialog(stringLiteral: DailySiriText.commandRequest)
  )
  var spokenCommand: String?

  @Parameter(title: "Daily action") var action: DailySiriAction?

  @Parameter(title: "Date") var date: Date?
  @Parameter(title: "Search text") var query: String?
  @Parameter(title: "Event") var event: DailyEventEntity?
  @Parameter(title: "Title") var eventTitle: String?
  @Parameter(title: "Start") var startAt: Date?
  @Parameter(title: "End") var endAt: Date?
  @Parameter(title: "All-day") var allDay: Bool?
  @Parameter(title: "Category") var category: String?
  @Parameter(title: "Location") var location: String?
  @Parameter(title: "Notes") var memo: String?
  @Parameter(title: "Link") var url: String?
  @Parameter(title: "Weather") var weather: String?
  @Parameter(title: "Notify minutes before") var reminderMinutesBefore: Int?
  @Parameter(title: "Alarm") var alarmEnabled: Bool?
  @Parameter(title: "D-day") var showDday: Bool?
  @Parameter(title: "New title") var newTitle: String?
  @Parameter(title: "New start") var newStartAt: Date?
  @Parameter(title: "New end") var newEndAt: Date?
  @Parameter(title: "New all-day") var newAllDay: Bool?
  @Parameter(title: "New category") var newCategory: String?

  // These values are set only by Daily's in-app bridge and are intentionally
  // scoped to this intent value so concurrent Siri requests cannot share state.
  var isBridgeExecution = false
  var confirmedInApp = false

  static var parameterSummary: some ParameterSummary {
    Summary("Run \(\.$spokenCommand) in Daily")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let ruleBasedAction = classify(spokenCommand)
    let spokenTemporal = DailySpokenTemporalParser.parse(spokenCommand)
    var generatedUnderstanding: DailyGenerativeUnderstanding?
    if action == nil, let command = normalized(spokenCommand) {
      if #available(iOS 26.0, macOS 26.0, *) {
        generatedUnderstanding = await DailyAppleIntelligenceInterpreter.interpret(command)
      }
    }

    let resolvedAction: DailySiriAction
    if let action {
      resolvedAction = action
    } else if let ruleBasedAction, isMutating(ruleBasedAction) {
      resolvedAction = ruleBasedAction
    } else if let generatedUnderstanding {
      resolvedAction = generatedUnderstanding.action
    } else if let ruleBasedAction {
      resolvedAction = ruleBasedAction
    } else {
      throw $action.requestValue(IntentDialog(stringLiteral: DailySiriText.supportedActionRequest))
    }

    switch resolvedAction {
    case .yesterday:
      let today = Calendar.current.startOfDay(for: Date())
      let start = Calendar.current.date(byAdding: .day, value: -1, to: today)!
      let response = try await eventDialog(
        action: "signal-yesterday",
        label: DailySiriText.yesterdayLabel(),
        from: start,
        to: today
      )
      return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
    case .today:
      let start = Calendar.current.startOfDay(for: Date())
      let response = try await eventDialog(
        action: "signal-today",
        label: DailySiriText.todayLabel(),
        from: start,
        to: Calendar.current.date(byAdding: .day, value: 1, to: start)!
      )
      return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
    case .tomorrow:
      let today = Calendar.current.startOfDay(for: Date())
      let start = Calendar.current.date(byAdding: .day, value: 1, to: today)!
      let response = try await eventDialog(
        action: "signal-tomorrow",
        label: DailySiriText.tomorrowLabel(),
        from: start,
        to: Calendar.current.date(byAdding: .day, value: 1, to: start)!
      )
      return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
    case .date:
      guard let date = date ?? generatedUnderstanding?.startAt else {
        throw $date.requestValue(IntentDialog(stringLiteral: DailySiriText.dateRequest))
      }
      let start = Calendar.current.startOfDay(for: date)
      let response = try await eventDialog(
        action: "signal-date",
        label: DailySiriText.date(date, includeTime: false),
        from: start,
        to: Calendar.current.date(byAdding: .day, value: 1, to: start)!
      )
      return .result(dialog: response.dialog, view: DailySiriSnippetView(message: response.message))
    case .next:
      let nextEvent = try loggedSiriOperation(action: "signal-next", summary: "Next event") {
        try DailySiriDatabase.nextEvent(after: Date())
      }
      let message = DailySiriText.nextEvent(nextEvent)
      logSiriRead(
        action: "signal-next",
        summary: "Next event",
        result: message,
        events: nextEvent.map { [$0] } ?? []
      )
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    case .search:
      guard let query = normalized(query) ??
          generatedUnderstanding?.searchText ??
          generatedUnderstanding?.eventReference ??
          searchQuery(from: spokenCommand) else {
        throw $query.requestValue(IntentDialog(stringLiteral: DailySiriText.searchRequest))
      }
      let events = try loggedSiriOperation(action: "signal-search", summary: query) {
        try DailySiriDatabase.search(query)
      }
      let message = summaryMessage(events, empty: DailySiriText.noSearchResults)
      logSiriRead(
        action: "signal-search",
        summary: query,
        result: message,
        events: events
      )
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    case .dday:
      let events = try loggedSiriOperation(action: "signal-dday", summary: "D-day") {
        try DailySiriDatabase.ddayEvents()
      }
      let message = summaryMessage(events, empty: DailySiriText.noDdayEvents)
      logSiriRead(
        action: "signal-dday",
        summary: "D-day",
        result: message,
        events: events
      )
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    case .add:
      guard let eventTitle = normalized(eventTitle) ??
          generatedUnderstanding?.eventTitle ??
          generatedUnderstanding?.eventReference else {
        throw $eventTitle.requestValue(IntentDialog(stringLiteral: DailySiriText.addTitleRequest))
      }
      guard let startAt = startAt ??
          spokenTemporal?.startAt ??
          generatedUnderstanding?.startAt else {
        throw $startAt.requestValue(IntentDialog(stringLiteral: DailySiriText.startRequest))
      }
      guard let isAllDay = allDay ??
          spokenTemporal?.allDay ??
          generatedUnderstanding?.allDay else {
        throw $allDay.requestValue(IntentDialog(stringLiteral: DailySiriText.allDayRequest))
      }
      guard let categoryName = normalized(category) ?? generatedUnderstanding?.category,
            let resolvedCategory = DailySiriPreferences.category(matching: categoryName) else {
        throw $category.requestValue(IntentDialog(stringLiteral: DailySiriText.categoryRequest))
      }
      let calendar = Calendar.current
      let start = isAllDay ? calendar.startOfDay(for: startAt) : startAt
      let suppliedEnd = endAt ?? spokenTemporal?.endAt ?? generatedUnderstanding?.endAt
      if !isAllDay && suppliedEnd == nil {
        throw $endAt.requestValue(IntentDialog(stringLiteral: DailySiriText.endRequest))
      }
      let fallbackEnd = calendar.date(byAdding: .day, value: 1, to: start)!
      let resolvedReminder = reminderMinutesBefore ??
        generatedUnderstanding?.reminderMinutesBefore ??
        (generatedUnderstanding?.reminderRequested == true ? 60 : nil)
      if isBridgeExecution && !confirmedInApp {
        throw DailySignalConfirmationRequired()
      }
      let addedEvent = try loggedSiriOperation(action: "signal-add", summary: eventTitle) {
        try DailySiriDatabase.add(
          title: eventTitle,
          startAt: start,
          endAt: suppliedEnd ?? fallbackEnd,
          allDay: isAllDay,
          category: resolvedCategory,
          location: normalized(location) ?? generatedUnderstanding?.location,
          memo: normalized(memo) ?? generatedUnderstanding?.memo,
          url: normalized(url) ?? generatedUnderstanding?.url,
          weather: normalized(weather) ?? generatedUnderstanding?.weather,
          reminderMinutesBefore: resolvedReminder,
          showDday: showDday ?? generatedUnderstanding?.showDday ?? false,
          alarmEnabled: alarmEnabled ?? generatedUnderstanding?.alarmEnabled ?? false
        )
      }
      DailySiriLogStore.append(
        action: "signal-add",
        summary: addedEvent.title,
        result: "completed",
        success: true,
        details: siriEventDetails(addedEvent)
      )
      let message = DailySiriText.added(addedEvent.title)
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    case .update:
      guard let event = event ?? resolvedEvent(from: generatedUnderstanding?.eventReference) else {
        throw $event.requestValue(IntentDialog(stringLiteral: DailySiriText.updateTargetRequest))
      }
      try DailySiriDatabase.requireEditable(id: event.id)
      guard let resolvedNewTitle = normalized(newTitle) ?? generatedUnderstanding?.newTitle else {
        throw $newTitle.requestValue(IntentDialog(stringLiteral: DailySiriText.addTitleRequest))
      }
      guard let resolvedNewStartAt = newStartAt ??
          spokenTemporal?.startAt ??
          generatedUnderstanding?.newStartAt else {
        throw $newStartAt.requestValue(IntentDialog(stringLiteral: DailySiriText.startRequest))
      }
      guard let resolvedNewAllDay = newAllDay ??
          spokenTemporal?.allDay ??
          generatedUnderstanding?.newAllDay else {
        throw $newAllDay.requestValue(IntentDialog(stringLiteral: DailySiriText.allDayRequest))
      }
      let suppliedNewEnd = newEndAt ??
        spokenTemporal?.endAt ??
        generatedUnderstanding?.newEndAt
      if !resolvedNewAllDay && suppliedNewEnd == nil {
        throw $newEndAt.requestValue(IntentDialog(stringLiteral: DailySiriText.endRequest))
      }
      guard let categoryName = normalized(newCategory) ?? generatedUnderstanding?.newCategory,
            let resolvedNewCategory = DailySiriPreferences.category(matching: categoryName) else {
        throw $newCategory.requestValue(IntentDialog(stringLiteral: DailySiriText.categoryRequest))
      }
      let resolvedNewEnd = suppliedNewEnd ?? Calendar.current.date(
        byAdding: .day,
        value: 1,
        to: Calendar.current.startOfDay(for: resolvedNewStartAt)
      )!
      if isBridgeExecution && !confirmedInApp {
        throw DailySignalConfirmationRequired()
      }
      try await authenticateMutation(DailySiriText.updateAuthentication)
      let updatedEvent = try loggedSiriOperation(action: "signal-update", summary: event.title) {
        try DailySiriDatabase.update(
          id: event.id,
          newTitle: resolvedNewTitle,
          newStartAt: resolvedNewStartAt,
          newEndAt: resolvedNewEnd,
          newAllDay: resolvedNewAllDay,
          newCategory: resolvedNewCategory,
          newLocation: normalized(location) ?? generatedUnderstanding?.location,
          newMemo: normalized(memo) ?? generatedUnderstanding?.memo,
          newURL: normalized(url) ?? generatedUnderstanding?.url,
          newWeather: normalized(weather) ?? generatedUnderstanding?.weather,
          reminderMinutesBefore: reminderMinutesBefore ?? generatedUnderstanding?.reminderMinutesBefore,
          showDday: showDday ?? generatedUnderstanding?.showDday,
          alarmEnabled: alarmEnabled ?? generatedUnderstanding?.alarmEnabled
        )
      }
      DailySiriLogStore.append(
        action: "signal-update",
        summary: event.title,
        result: updatedEvent.title,
        success: true,
        details: siriEventDetails(updatedEvent)
      )
      let message = DailySiriText.updated(updatedEvent.title)
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    case .delete:
      guard let event = event ?? resolvedEvent(from: generatedUnderstanding?.eventReference) else {
        throw $event.requestValue(IntentDialog(stringLiteral: DailySiriText.deleteTargetRequest))
      }
      try DailySiriDatabase.requireEditable(id: event.id)
      try await authenticateMutation(DailySiriText.deleteAuthentication)
      if !confirmedInApp {
        do {
          try await requestConfirmation(result: .result(
            dialog: IntentDialog(stringLiteral: DailySiriText.deleteConfirmation(event.title))
          ))
        } catch {
          DailySiriLogStore.append(action: "signal-delete", summary: event.title, result: "cancelled", success: false)
          throw error
        }
      }
      let deletedEvent = try loggedSiriOperation(action: "signal-delete", summary: event.title) {
        try DailySiriDatabase.delete(id: event.id)
      }
      DailySiriLogStore.append(
        action: "signal-delete",
        summary: deletedEvent.title,
        result: "completed",
        success: true,
        details: siriEventDetails(deletedEvent)
      )
      let message = DailySiriText.deleted(deletedEvent.title)
      return .result(
        dialog: IntentDialog(stringLiteral: message),
        view: DailySiriSnippetView(message: message)
      )
    }
  }

  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func classify(_ value: String?) -> DailySiriAction? {
    guard let command = normalized(value)?.lowercased() else { return nil }

    // Mutating actions take precedence so a phrase such as "내일 일정 삭제" can
    // never be downgraded to a read-only tomorrow query.
    if containsAny(command, ["삭제", "지워", "지우기", "없애", "취소", "delete", "remove"]) {
      return .delete
    }
    if containsAny(command, ["수정", "변경", "바꿔", "고쳐", "update", "edit", "change"]) {
      return .update
    }
    if containsAny(command, ["추가", "등록", "만들", "생성", "잡아", "add", "create", "schedule"]) {
      return .add
    }
    if containsAny(command, ["검색", "찾아", "찾기", "search", "find"]) {
      return .search
    }
    if containsAny(command, ["d-day", "d day", "dday", "디데이"]) {
      return .dday
    }
    if containsAny(command, ["다음 일정", "가장 가까운", "다가오는", "예정된 다음", "next event", "what's next"]) {
      return .next
    }
    if containsAny(command, ["어제", "yesterday", "昨日", "昨天"]) {
      return .yesterday
    }
    if containsAny(command, ["내일", "tomorrow"]) {
      return .tomorrow
    }
    if containsAny(command, ["오늘", "today"]) {
      return .today
    }
    if containsAny(command, ["지정 날짜", "특정 날짜", "날짜별", "그날", "on a date", "specific date"]) {
      return .date
    }
    return nil
  }

  private func containsAny(_ value: String, _ candidates: [String]) -> Bool {
    candidates.contains { value.contains($0) }
  }

  private func isMutating(_ action: DailySiriAction?) -> Bool {
    action == .add || action == .update || action == .delete
  }

  private func resolvedEvent(from reference: String?) -> DailyEventEntity? {
    guard let reference = normalized(reference),
          let matches = try? DailySiriDatabase.searchEditable(reference) else {
      return nil
    }
    let exactMatches = matches.filter {
      $0.title.compare(reference, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
    if exactMatches.count == 1 {
      return DailyEventEntity(exactMatches[0])
    }
    if matches.count == 1 {
      return DailyEventEntity(matches[0])
    }
    return nil
  }

  private func authenticateMutation(_ reason: String) async throws {
    let context = LAContext()
    try await context.evaluatePolicy(
      .deviceOwnerAuthentication,
      localizedReason: reason
    )
  }

  private func searchQuery(from value: String?) -> String? {
    guard var command = normalized(value) else { return nil }
    let removable = [
      "시그널", "데일리", "daily", "일정", "스케줄", "검색해줘", "검색", "찾아줘", "찾아", "찾기",
      "search", "find", "please", "해줘", "해주세요",
    ]
    for token in removable {
      command = command.replacingOccurrences(of: token, with: "", options: [.caseInsensitive])
    }
    return normalized(command)
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct DailyAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddDailyEventIntent(),
      phrases: [
        "Add an event in \(.applicationName)",
        "\(.applicationName) 앱에 일정 추가",
        "\(.applicationName)에서 일정 만들어줘",
      ],
      shortTitle: "Add Event",
      systemImageName: "calendar.badge.plus"
    )
    AppShortcut(
      intent: GetTodayDailyEventsIntent(),
      phrases: [
        "Show today's events in \(.applicationName)",
        "\(.applicationName) 앱에서 오늘 일정 알려줘",
        "\(.applicationName)에서 오늘 스케줄 확인",
      ],
      shortTitle: "Today's Events",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: GetTomorrowDailyEventsIntent(),
      phrases: [
        "Show tomorrow's events in \(.applicationName)",
        "\(.applicationName) 앱에서 내일 일정 알려줘",
        "\(.applicationName)에서 내일 스케줄 확인",
      ],
      shortTitle: "Tomorrow's Events",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: GetDailyEventsOnDateIntent(),
      phrases: [
        "Show events on a date in \(.applicationName)",
        "\(.applicationName) 앱에서 지정 날짜 일정 알려줘",
        "\(.applicationName)에서 날짜별 일정 확인",
      ],
      shortTitle: "Events on Date",
      systemImageName: "calendar.badge.clock"
    )
    AppShortcut(
      intent: GetNextDailyEventIntent(),
      phrases: [
        "What's next in \(.applicationName)",
        "\(.applicationName) 앱에서 다음 일정 알려줘",
        "\(.applicationName)에서 가장 가까운 일정 알려줘",
      ],
      shortTitle: "Next Event",
      systemImageName: "clock"
    )
    AppShortcut(
      intent: SearchDailyEventsIntent(),
      phrases: [
        "Search events in \(.applicationName)",
        "\(.applicationName) 앱에서 일정 검색",
        "\(.applicationName)에서 일정 찾아줘",
      ],
      shortTitle: "Search Events",
      systemImageName: "magnifyingglass"
    )
    AppShortcut(
      intent: UpdateDailyEventIntent(),
      phrases: [
        "Update an event in \(.applicationName)",
        "\(.applicationName) 앱에서 일정 수정",
        "\(.applicationName)에서 일정 바꿔줘",
      ],
      shortTitle: "Update Event",
      systemImageName: "calendar.badge.exclamationmark"
    )
    AppShortcut(
      intent: DeleteDailyEventIntent(),
      phrases: [
        "Delete an event in \(.applicationName)",
        "\(.applicationName) 앱에서 일정 삭제",
        "\(.applicationName)에서 일정 지워줘",
      ],
      shortTitle: "Delete Event",
      systemImageName: "calendar.badge.minus"
    )
    AppShortcut(
      intent: GetDailyDdayEventsIntent(),
      phrases: [
        "Show D-day events in \(.applicationName)",
        "\(.applicationName) 앱에서 D-day 알려줘",
        "\(.applicationName)에서 디데이 일정 확인",
      ],
      shortTitle: "D-day Events",
      systemImageName: "flag"
    )
    AppShortcut(
      intent: DailySignalCommandIntent(),
      phrases: [
        "Run Signal in \(.applicationName)",
        "\(.applicationName)에서 시그널 실행",
        "\(.applicationName) 시그널",
      ],
      shortTitle: "Signal",
      systemImageName: "waveform"
    )
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct DailySiriSnippetView: View {
  let paragraphs: [String]

  init(message: String) {
    paragraphs = message
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
        Text(paragraph)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
  }
}

@available(iOS 16.0, macOS 13.0, *)
private struct DailyScheduleResponse {
  let dialog: IntentDialog
  let message: String
}

@available(iOS 16.0, macOS 13.0, *)
private func eventDialog(
  action: String,
  label: String,
  from start: Date,
  to end: Date
) async throws -> DailyScheduleResponse {
  let events = try loggedSiriOperation(action: action, summary: label) {
    try DailySiriDatabase.events(from: start, to: end)
  }
  let factualMessage = DailySiriText.scheduleSummary(for: start, events: events)
  let message: String
  if #available(iOS 26.0, macOS 26.0, *),
     let narrated = await DailyAppleIntelligenceNarrator.narrate(
       factualMessage,
       events: events
     ) {
    message = narrated
  } else {
    message = factualMessage
  }
  logSiriRead(action: action, summary: label, result: message, events: events)
  return DailyScheduleResponse(
    dialog: IntentDialog(stringLiteral: message),
    message: message
  )
}

@available(iOS 16.0, macOS 13.0, *)
private func logSiriRead(action: String, summary: String, result: String, events: [DailySiriEvent]) {
  // The action history outlives account switches; do not persist LMS titles,
  // source details, or the matching search phrase in that unscoped history.
  let containsLms = events.contains { $0.isLms }
  DailySiriLogStore.append(
    action: action,
    summary: containsLms ? DailySiriText.lmsReadCompleted : summary,
    result: containsLms ? DailySiriText.lmsReadCompleted : result,
    success: true
  )
}

@available(iOS 16.0, macOS 13.0, *)
private func loggedSiriOperation<T>(
  action: String,
  summary: String,
  operation: () throws -> T
) throws -> T {
  do {
    return try operation()
  } catch {
    DailySiriLogStore.append(
      action: action,
      summary: summary,
      result: String(describing: error),
      success: false
    )
    throw error
  }
}

@available(iOS 16.0, macOS 13.0, *)
private func summaryMessage(_ events: [DailySiriEvent], empty: String) -> String {
  DailySiriText.eventList(events, empty: empty)
}
