import Foundation

@main
struct AppleWidgetTextTest {
  static func main() {
    typealias Text = DailyWidgetText
    // The app writes ko, en, ja or zh-Hant; device identifiers vary more.
    precondition(Text.resolve("ko") == .korean && Text.resolve("ko_KR") == .korean)
    precondition(Text.resolve("ja-JP") == .japanese)
    precondition(Text.resolve("zh-Hant") == .traditionalChinese && Text.resolve("zh-TW") == .traditionalChinese)
    precondition(Text.resolve("en-US") == .english && Text.resolve("fr") == .english && Text.resolve(nil) == .english)

    // Korean keeps the wording the widgets had before localization.
    let ko = Text(localeTag: "ko")
    precondition(ko.noEventsToday == "오늘 일정이 없습니다")
    precondition(ko.noEventsTodayShort == "오늘 일정 없음")
    precondition(ko.noRemainingEvents == "남은 일정이 없습니다")
    precondition(ko.moreEvents(3) == "외 3개 일정" && ko.more(2) == "외 2개")
    precondition(ko.allDay == "종일" && ko.inProgress == "진행 중" && ko.events == "일정")
    precondition(ko.todayEvents == "오늘 일정" && ko.thisWeek == "이번 주 일정")
    precondition(ko.refresh == "앱을 열어 일정을 갱신하세요")
    precondition(ko.snoozeAfter(10) == "10분 후 다시 알림" && ko.minutes(10) == "10분")
    precondition(ko.weekdayNames == ["일", "월", "화", "수", "목", "금", "토"])

    let en = Text(localeTag: "en")
    precondition(en.noEventsToday == "No events today")
    precondition(en.snoozeAfter(5) == "Snooze for 5 min" && en.minutes(5) == "5 min")
    precondition(en.weekdayNames == ["S", "M", "T", "W", "T", "F", "S"])
    let ja = Text(localeTag: "ja")
    precondition(ja.noEventsToday == "今日の予定はありません")
    precondition(ja.weekdayNames == ["日", "月", "火", "水", "木", "金", "土"])
    let zh = Text(localeTag: "zh-Hant")
    precondition(zh.noEventsToday == "今天沒有行程")
    precondition(zh.weekdayNames == ["日", "一", "二", "三", "四", "五", "六"])

    // No language falls back to another one's wording.
    let all = [ko, en, ja, zh]
    let wordings: [(Text) -> String] = [
      { $0.todayEvents }, { $0.noEventsToday }, { $0.noRemainingEvents }, { $0.thisWeek },
      { $0.noEventsThisWeek }, { $0.noDdays }, { $0.refresh }, { $0.markDone }, { $0.markNotDone },
      { $0.moreEvents(2) }, { $0.more(2) }, { $0.allDay }, { $0.eventAlarm }, { $0.snoozeAfter(10) },
      { $0.minutes(10) }, { $0.todayWidgetDescription }, { $0.calendarWidgetName },
      { $0.calendarWidgetDescription }, { $0.ddayWidgetDescription },
    ]
    for wording in wordings {
      let values = all.map(wording)
      precondition(Set(values).count == 4 && !values.contains(""), "\(values)")
    }

    // The AlarmKit wording (app target).
    let alarm = DailyAlarmText(language: .korean)
    precondition(alarm.snoozeAfter(10) == "10분 후 다시 알림" && alarm.stop == "중지")
    precondition(alarm.untilSnoozeEnds == "다시 알림까지" && alarm.localeTag == "ko")
    precondition(DailyAlarmText(language: .english).stop == "Stop")
    precondition(DailyAlarmText(language: .japanese).snoozeAfter(10) == "10分後に再通知")
    // The tag handed to the Live Activity resolves back to the same language there.
    precondition(Text(localeTag: DailyAlarmText(language: .traditionalChinese).localeTag).language == .traditionalChinese)
    precondition(Text(localeTag: DailyAlarmText(language: .english).localeTag).snoozeAfter(10)
      == DailyAlarmText(language: .english).snoozeAfter(10))
    print("apple widget text checks passed")
  }
}
