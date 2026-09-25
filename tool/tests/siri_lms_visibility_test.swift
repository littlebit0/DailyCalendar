import Foundation

@main
struct SiriLmsVisibilityTests {
  static func main() throws {
    var checks = 0
    func check(_ condition: Bool, _ message: String) {
      precondition(condition, message)
      checks += 1
    }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let id = "lms:owned-event"
    let owner = "student@example.test"
    func snapshot(
      ownerID: String = "student@example.test",
      checkedAt: Any? = 1_800_000_000_000,
      ids: [String] = ["lms:owned-event"]
    ) throws -> [String: Any] {
      // Exercise Foundation's actual JSON integer/number conversion, matching
      // the widget snapshot file rather than a Swift-only dictionary fixture.
      let source: [String: Any] = ["lmsVisibility": [
        "ownerId": ownerID,
        "checkedAt": checkedAt ?? NSNull(),
        "eventIds": ids,
      ]]
      return try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: source)) as! [String: Any]
    }
    func metadata(ownerID: String = "student@example.test", provider: String = "coursemos", principal: String = "123") throws -> String {
      let data = try JSONSerialization.data(withJSONObject: [
        "provider": provider, "schoolId": "smu", "ownerId": ownerID, "lmsUserId": principal,
      ])
      return String(data: data, encoding: .utf8)!
    }
    let source = try metadata()
    let policy = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(), now: now)
    check(policy.allows(id: id, metadata: source), "Verified current owner can read the granted LMS row")
    check(policy.allows(id: "ordinary", metadata: nil), "Ordinary events retain existing behavior")
    check(!policy.allows(id: "lms:another", metadata: source), "Valid metadata cannot grant a missing event ID")
    check(!policy.allows(id: id, metadata: nil), "LMS-prefixed orphan never becomes an ordinary event")
    check(!policy.allows(id: id, metadata: "not json"), "Malformed metadata fails closed")
    check(!policy.allows(id: id, metadata: "{}"), "Incomplete metadata fails closed")
    check(!policy.allows(id: id, metadata: try metadata(ownerID: "other@example.test")), "Metadata must belong to the current account")
    check(!policy.allows(id: id, metadata: try metadata(provider: "unknown")), "Unknown provider fails closed")
    check(!policy.allows(id: id, metadata: try metadata(principal: "")), "Missing LMS identity fails closed")
    let normalized = DailySiriLmsVisibility(ownerID: " STUDENT@example.test ", snapshot: try snapshot(ownerID: " STUDENT@example.test "), now: now)
    check(normalized.allows(id: id, metadata: try metadata(ownerID: " STUDENT@example.test ")), "Account normalization matches Flutter")
    let absent = DailySiriLmsVisibility(ownerID: owner, snapshot: nil, now: now)
    check(!absent.allows(id: id, metadata: source), "Missing widget grant does not expose local LMS")
    check(absent.allows(id: "ordinary", metadata: nil), "Ordinary rows work without a widget snapshot")
    let loggedOut = DailySiriLmsVisibility(ownerID: nil, snapshot: try snapshot(), now: now)
    check(!loggedOut.allows(id: id, metadata: source), "Signed-out account cannot reuse a previous grant")
    let changed = DailySiriLmsVisibility(ownerID: "other@example.test", snapshot: try snapshot(), now: now)
    check(!changed.allows(id: id, metadata: source), "Account switch invalidates the previous grant")
    let fallback = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(checkedAt: nil), now: now)
    check(!fallback.allows(id: id, metadata: source), "Fallback or loading cannot use an old successful read")
    let boundary = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(checkedAt: 1_799_999_700_000), now: now)
    check(boundary.allows(id: id, metadata: source), "Five-minute bound is inclusive")
    let expired = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(checkedAt: 1_799_999_699_999), now: now)
    check(!expired.allows(id: id, metadata: source), "Older verification cannot authorize cached LMS")
    let future = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(checkedAt: 1_800_000_000_001), now: now)
    check(!future.allows(id: id, metadata: source), "Future verification fails closed")
    let invalidDate = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(checkedAt: "recent"), now: now)
    check(!invalidDate.allows(id: id, metadata: source), "Invalid timestamp fails closed")
    let noIDs = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(ids: []), now: now)
    check(!noIDs.allows(id: id, metadata: source), "Explicit empty permission list wins over valid metadata")
    let legacyID = DailySiriLmsVisibility(ownerID: owner, snapshot: try snapshot(ids: ["old-id"]), now: now)
    check(legacyID.allows(id: "old-id", metadata: source), "Metadata marks LMS even with an older non-prefixed ID")
    check(DailySiriLmsVisibility.isLms(id: "old-id", metadata: source), "Source mutation protection follows metadata too")
    check(policy != changed && policy != fallback && policy != noIDs, "Grant changes during a read are detectable")
    print("Siri LMS visibility: \(checks) checks passed")
  }
}
