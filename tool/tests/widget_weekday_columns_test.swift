@main
struct WidgetWeekdayColumnsTest {
  static func main() {
    // Sunday start: columns are Sunday...Saturday.
    precondition((0..<7).map { dailyWeekdayOfColumn($0, weekStartsOnMonday: false) } == [0, 1, 2, 3, 4, 5, 6])
    precondition(dailyWeekdayLabels(weekStartsOnMonday: false) == ["일", "월", "화", "수", "목", "금", "토"])
    // Monday start: Saturday is column 5, Sunday the last column.
    precondition((0..<7).map { dailyWeekdayOfColumn($0, weekStartsOnMonday: true) } == [1, 2, 3, 4, 5, 6, 0])
    precondition(dailyWeekdayLabels(weekStartsOnMonday: true) == ["월", "화", "수", "목", "금", "토", "일"])
    for monday in [false, true] {
      let labels = dailyWeekdayLabels(weekStartsOnMonday: monday)
      for column in 0..<7 {
        let weekday = dailyWeekdayOfColumn(column, weekStartsOnMonday: monday)
        // The label and the colour rule read the same weekday.
        precondition(labels[column] == ["일", "월", "화", "수", "목", "금", "토"][weekday])
      }
    }
    print("widget weekday columns passed")
  }
}
