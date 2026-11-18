import Foundation

// Fake notification center: the production replacement runs against it with
// injected add failures (#924).
struct Failure: Error {}
var pending: Set<String> = ["old-1", "old-2", "same"]
func check(_ condition: Bool, _ message: String) {
  if !condition { fatalError(message) }
}

func replace(_ additions: [String], stale: Set<String>, failing: Set<String> = []) -> Bool {
  let done = DispatchSemaphore(value: 0)
  var succeeded = false
  let previous = pending
  DailyMacAlarmReplacement.run(
    additions: additions,
    previous: previous,
    stale: stale,
    add: { identifier, completion in
      DispatchQueue.global().async {
        if failing.contains(identifier) { completion(Failure()); return }
        DispatchQueue.main.async { pending.insert(identifier); completion(nil) }
      }
    },
    remove: { identifiers in DispatchQueue.main.sync { pending.subtract(identifiers) } },
    completion: { failure in succeeded = failure == nil; done.signal() }
  )
  while done.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
  return succeeded
}

// A failed add keeps the previous requests.
check(!replace(["new-1"], stale: pending, failing: ["new-1"]), "failure is reported")
check(pending == ["old-1", "old-2", "same"], "failed add keeps the previous requests: \(pending)")

// Partial success: the added part is removed, the replaced identifier stays.
check(!replace(["new-1", "same", "new-2"], stale: pending, failing: ["new-2"]), "partial failure is reported")
check(pending == ["old-1", "old-2", "same"], "partial failure restores the previous set: \(pending)")

// Success removes the stale requests and keeps the new ones.
check(replace(["new-1", "same"], stale: pending), "success is reported")
check(pending == ["new-1", "same"], "success replaces the requests: \(pending)")

// Nothing to add: the stale requests are removed.
check(replace([], stale: pending), "empty replacement succeeds")
check(pending.isEmpty, "stale requests are removed")
print("macOS alarm replacement checks passed")
