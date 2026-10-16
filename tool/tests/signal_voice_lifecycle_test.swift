// OS doubles only: the Python runner appends the unmodified production bridge.
import Foundation

typealias FlutterResult = (Any?) -> Void
class FlutterBinaryMessenger {}
struct FlutterMethodCall { let method: String; let arguments: Any? }
struct FlutterError { let code: String; let message: String?; let details: Any? }
let FlutterMethodNotImplemented = "not implemented"
class FlutterMethodChannel {
  static var last: FlutterMethodChannel!
  var handler: ((FlutterMethodCall, @escaping FlutterResult) -> Void)?
  var events: [(String, Any?)] = []
  init(name: String, binaryMessenger: FlutterBinaryMessenger) { Self.last = self }
  func setMethodCallHandler(_ value: @escaping (FlutterMethodCall, @escaping FlutterResult) -> Void) { handler = value }
  func invokeMethod(_ method: String, arguments: Any?) { events.append((method, arguments)) }
  func call(_ method: String, _ id: Int, _ result: @escaping FlutterResult = { _ in }) {
    handler?(FlutterMethodCall(method: method, arguments: ["requestId": id]), result)
  }
}
enum DailySiriText {
  static let voiceUnavailable = "unavailable", emptyCommand = "empty", emptyResponse = "empty"
  static let alreadyListening = "busy", speechPermissionRequired = "speech", microphonePermissionRequired = "mic"
  static let recognizerUnavailable = "unavailable", listeningCancelled = "cancelled", noSpeech = "empty"
}
enum Boundary { case immediate }
class AVSpeechSynthesizer { func stopSpeaking(at: Boundary) {} }
enum Media { case audio }
class AVCaptureDevice {
  static var replies: [(Bool) -> Void] = []
  static func requestAccess(for media: Media, completionHandler: @escaping (Bool) -> Void) { replies.append(completionHandler) }
}
class InputNode {
  func outputFormat(forBus: Int) -> Int { 1 }
  func installTap(onBus: Int, bufferSize: Int, format: Int, block: @escaping (Int, Int) -> Void) {}
  func removeTap(onBus: Int) {}
}
class AVAudioEngine {
  static var starts = 0
  static var fail = false
  var isRunning = false
  let inputNode = InputNode()
  func prepare() {}
  func start() throws { if Self.fail { throw Failure.test }; Self.starts += 1; isRunning = true }
  func stop() { isRunning = false }
}
enum Failure: Error { case test }
enum Authorization { case authorized, denied }
enum Hint { case dictation }
class SFSpeechAudioBufferRecognitionRequest {
  var shouldReportPartialResults = false
  var taskHint = Hint.dictation
  func append(_ buffer: Int) {}
  func endAudio() {}
}
struct Recognition {
  let bestTranscription: Transcription
  let isFinal: Bool
}
struct Transcription { let formattedString: String }
class SFSpeechRecognitionTask { func cancel() {} }
class SFSpeechRecognizer {
  static var permissions: [(Authorization) -> Void] = []
  static var callbacks: [(Recognition?, Error?) -> Void] = []
  var isAvailable = true
  init?(locale: Locale) {}
  static func requestAuthorization(_ callback: @escaping (Authorization) -> Void) { permissions.append(callback) }
  func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, resultHandler: @escaping (Recognition?, Error?) -> Void) -> SFSpeechRecognitionTask {
    Self.callbacks.append(resultHandler); return SFSpeechRecognitionTask()
  }
}
func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
let bridge = DailySignalVoiceBridge(binaryMessenger: FlutterBinaryMessenger())
let channel = FlutterMethodChannel.last!
var results: [Int: [Any?]] = [:]
func start(_ id: Int) { channel.call("startListening", id) { results[id, default: []].append($0) } }
func code(_ id: Int) -> String? { results[id]?.first.flatMap { $0 as? FlutterError }?.code }
func allowSpeech() { SFSpeechRecognizer.permissions.last?(.authorized); drain() }
func allowMic() { AVCaptureDevice.replies.last?(true); drain() }
func allowAll() { allowSpeech(); allowMic() }
start(1)
let oldPermission = SFSpeechRecognizer.permissions.last!
start(2)
assert(code(2) == "already_listening")
channel.call("cancelListening", 1)
oldPermission(.authorized); drain()
assert(AVAudioEngine.starts == 0 && AVCaptureDevice.replies.isEmpty)
assert(code(1) == "listening_cancelled" && results[1]?.count == 1)
start(3); allowSpeech()
let oldMic = AVCaptureDevice.replies.last!
channel.call("finishListening", 3)
oldMic(true); drain()
assert(AVAudioEngine.starts == 0 && code(3) == "no_speech")
start(4); allowAll()
let oldCallback = SFSpeechRecognizer.callbacks.last!
channel.call("cancelListening", 4)
start(5); allowAll()
let count = channel.events.count
oldCallback(Recognition(bestTranscription: Transcription(formattedString: "stale"), isFinal: true), nil)
oldCallback(nil, Failure.test); drain()
channel.call("cancelListening", 4)
assert(results[5] == nil && channel.events.count == count)
SFSpeechRecognizer.callbacks.last?(Recognition(bestTranscription: Transcription(formattedString: "current"), isFinal: true), nil); drain()
assert(results[5]?.count == 1 && results[5]?.first as? String == "current")
SFSpeechRecognizer.callbacks.last?(nil, Failure.test); drain()
assert(results[5]?.count == 1)
start(6); SFSpeechRecognizer.permissions.last?(.denied); drain()
assert(code(6) == "speech_denied")
start(7); allowSpeech(); AVCaptureDevice.replies.last?(false); drain()
assert(code(7) == "microphone_denied")
AVAudioEngine.fail = true
start(8); allowAll()
assert(code(8) == "recognition_failed")
AVAudioEngine.fail = false
start(9); allowAll()
SFSpeechRecognizer.callbacks.last?(nil, Failure.test); drain()
assert(code(9) == "recognition_failed")
start(10); allowAll()
SFSpeechRecognizer.callbacks.last?(Recognition(bestTranscription: Transcription(formattedString: "silence"), isFinal: false), nil); drain()
RunLoop.main.run(until: Date().addingTimeInterval(2.1))
assert(results[10]?.count == 1 && results[10]?.first as? String == "silence")
print("voice lifecycle checks passed")
