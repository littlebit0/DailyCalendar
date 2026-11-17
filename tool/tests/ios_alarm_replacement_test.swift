import Foundation

// Fake AlarmKit state: the production plan runs against it with an injected
// schedule failure (#924).
final class FakeAlarms {
  var alarms: [UUID: String] = [:]  // id -> fingerprint
  var stored = Set<UUID>()
  var failing = false
  struct Failure: Error {}

  func id(_ value: String) -> UUID {
    var bytes = [UInt8](repeating: 0, count: 16)
    for (index, byte) in value.utf8.enumerated() { bytes[index % 16] = bytes[index % 16] &* 31 &+ byte }
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
  }

  @discardableResult
  func run(_ times: [Int64], text: String, reconcile: Bool = false) async -> Bool {
    let plan = DailyAlarmPlan.make(
      eventID: "event", fireTimes: times, reconcile: reconcile,
      existing: Set(alarms.keys), stored: stored, now: Date(timeIntervalSince1970: 0),
      alarmID: id, fingerprint: { "\($0)|\(text)" }, storedFingerprint: { self.alarms[$0] }
    )
    do {
      _ = try await plan.apply(
        schedule: { alarm in
          if self.failing { throw Failure() }
          precondition(self.alarms[alarm.id] == nil, "AlarmKit IDs are unique")
          self.alarms[alarm.id] = alarm.fingerprint
        },
        cancel: { self.alarms[$0] = nil },
        store: { self.stored = $0 }
      )
      return true
    } catch {
      return false
    }
  }

  var fingerprints: [String] { alarms.values.sorted() }
}

func check(_ condition: Bool, _ message: String) {
  if !condition { fatalError(message) }
}

@main
struct Main {
  static func main() async {
    let fake = FakeAlarms()
    await fake.run([1000], text: "a")
    check(fake.fingerprints == ["1000|a"], "first schedule")

    // Changed time: a failed schedule keeps the previous alarm.
    fake.failing = true
    check(!(await fake.run([2000], text: "a")), "failure is reported")
    check(fake.fingerprints == ["1000|a"], "edit failure keeps the previous alarm")
    check(!(await fake.run([2000], text: "a", reconcile: true)), "reconcile failure is reported")
    check(fake.fingerprints == ["1000|a"], "reconcile failure keeps the previous alarm")

    // The next reconciliation schedules it again and removes the previous one.
    fake.failing = false
    await fake.run([2000], text: "a", reconcile: true)
    check(fake.fingerprints == ["2000|a"], "success cancels the previous alarm")
    check(fake.stored == Set(fake.alarms.keys), "stored IDs match")

    // Same time, changed text: the previous configuration survives a failure.
    fake.failing = true
    await fake.run([2000], text: "b")
    check(fake.fingerprints == ["2000|a"], "same-time failure keeps the previous alarm")
    fake.failing = false
    await fake.run([2000], text: "b")
    check(fake.fingerprints == ["2000|b"], "same-time success replaces the alarm")

    // Reconcile keeps an unchanged alarm under either ID (#104).
    fake.failing = true
    check(await fake.run([2000], text: "b", reconcile: true), "unchanged alarm is kept without scheduling")
    check(fake.fingerprints == ["2000|b"], "kept alarm remains")

    // A removed time is cancelled; a repeated schedule alternates the two IDs.
    fake.failing = false
    await fake.run([2000, 3000], text: "b", reconcile: true)
    check(fake.fingerprints == ["2000|b", "3000|b"], "second time added")
    await fake.run([2000], text: "b")
    await fake.run([2000], text: "b")
    check(fake.fingerprints == ["2000|b"], "repeated schedule leaves one alarm")

    // No future time: the previous alarms are removed.
    await fake.run([-1], text: "b")
    check(fake.alarms.isEmpty && fake.stored.isEmpty, "passed time clears alarms")
    print("iOS alarm replacement checks passed")
  }
}
