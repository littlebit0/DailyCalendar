import Foundation

@main
struct LmsCookieReadPolicyTests {
  static func main() {
    var checks = 0
    func check(_ condition: Bool, _ message: String) {
      precondition(condition, message)
      checks += 1
    }
    let host = "ecampus.smu.ac.kr"
    func cookie(
      name: String = "MoodleSession", domain: String = "ecampus.smu.ac.kr",
      secure: Bool = false, httpOnly: Bool = false
    ) -> HTTPCookie {
      var properties: [HTTPCookiePropertyKey: Any] = [
        .name: name, .value: "fixture-only", .domain: domain, .path: "/",
      ]
      if secure { properties[.secure] = "TRUE" }
      if httpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
      return HTTPCookie(properties: properties)!
    }
    func allows(_ cookie: HTTPCookie, for boundHost: String = "ecampus.smu.ac.kr") -> Bool {
      DailyLmsCookieReadPolicy.permitsSessionCookie(cookie, host: boundHost)
    }

    // Parse the actual response-header shape; no school/account request is made.
    let issued = HTTPCookie.cookies(
      withResponseHeaderFields: ["Set-Cookie": "MoodleSession=fixture-only; path=/"],
      for: URL(string: "https://\(host)/login.php")!
    ).first!
    check(!issued.isSecure, "Fixture reproduces missing Secure issuance flag")
    check(!issued.isHTTPOnly, "Fixture reproduces missing HttpOnly issuance flag")
    check(allows(issued), "A valid exact-host session is not rejected by issuance flags")
    check(allows(cookie(secure: true, httpOnly: true)), "Hardened restored sessions remain readable")
    check(allows(cookie(name: "MoodleSession_course")), "Existing MoodleSession underscore names remain allowed")
    check(allows(cookie(domain: ".\(host)")), "Existing leading-dot normalization remains allowed")
    check(allows(cookie(domain: "\(host).")), "Existing trailing-dot normalization remains allowed")
    check(!allows(cookie(domain: ".smu.ac.kr")), "Parent-domain cookies cannot broaden scope")
    check(!allows(cookie(domain: "child.\(host)")), "Child-domain cookies cannot broaden scope")
    check(!allows(cookie(domain: "\(host).example.test")), "Lookalike suffix hosts are rejected")
    check(!allows(cookie(domain: "sel.jnu.ac.kr")), "Another allowed school is not the bound school")
    check(allows(cookie(domain: "sel.jnu.ac.kr"), for: "sel.jnu.ac.kr"), "The existing JNU host keeps its own scope")
    check(!allows(cookie(domain: "other.example.test"), for: "other.example.test"), "Matching an unlisted host is insufficient")
    check(!allows(cookie(name: "PHPSESSID")), "Unrelated session-cookie names are rejected")
    check(!allows(cookie(name: "MoodleSessionOther")), "MoodleSession prefix without underscore is rejected")
    check(!allows(cookie(name: "moodlesession")), "Cookie-name case is not broadened")
    print("LMS cookie read policy: \(checks) checks passed")
  }
}
