// Drives the production DailyLmsBindRegistry extracted from both Apple runners.
@main
struct LmsCookieBindRegistryTests {
  static var checks = 0
  static func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
    checks += 1
  }

  static func main() {
    let host = "ecampus.smu.ac.kr"
    var registry = DailyLmsBindRegistry<String>()

    let late = registry.begin()
    let current = registry.begin()
    check(registry.finish(current, store: "new", host: host), "latest bind registers")
    check(!registry.finish(late, store: "old", host: host), "earlier bind is superseded")
    check(registry.store(host: host) == "new", "late bind keeps the newer store")

    let beforeClear = registry.begin()
    registry.supersedeBinds()
    registry.remove(host: host)
    check(!registry.finish(beforeClear, store: "old", host: host), "clear cancels a pending bind")
    check(registry.store(host: host) == nil, "cancelled bind leaves no store")

    let next = registry.begin()
    check(registry.finish(next, store: "next", host: host), "bind after clear registers")
    check(registry.store(host: host) == "next", "bind after clear is current")
    print("LMS cookie bind registry: \(checks) checks passed")
  }
}
