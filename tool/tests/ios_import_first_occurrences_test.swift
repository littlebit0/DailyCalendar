import Foundation

@main
struct IosImportFirstOccurrencesTest {
  struct Occurrence: Equatable {
    let id: String
    let start: Date
  }

  static func main() {
    func at(_ day: Double) -> Date { Date(timeIntervalSince1970: day * 86_400) }
    // Window 1: a daily series from day 0, a single event, and an item without an id.
    // Window 2: the series again (every day), the single event's id again, a new event.
    let windows: [[Occurrence]] = [
      (0..<1095).reversed().map { Occurrence(id: "daily", start: at(Double($0))) }
        + [Occurrence(id: "single", start: at(10)), Occurrence(id: "", start: at(1))],
      (1095..<2190).map { Occurrence(id: "daily", start: at(Double($0))) }
        + [Occurrence(id: "later", start: at(1100)), Occurrence(id: "single", start: at(1096))],
    ]
    var seen = Set<String>()
    var collected: [Occurrence] = []
    var largest = 0
    for window in windows {
      DailyAppleCalendarImport.appendFirstOccurrences(
        of: window, into: &collected, seen: &seen, id: { $0.id }, start: { $0.start }
      )
      largest = max(largest, collected.count)
    }
    // One item per calendar item, each at its first occurrence, oldest first.
    precondition(collected == [
      Occurrence(id: "daily", start: at(0)),
      Occurrence(id: "single", start: at(10)),
      Occurrence(id: "later", start: at(1100)),
    ], "\(collected)")
    // What is kept never grows with the number of occurrences.
    precondition(largest == 3)
    print("ios import first occurrence checks passed")
  }
}
