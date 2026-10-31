import Cocoa
import FlutterMacOS
import XCTest
@testable import Daily_Test

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testKoreanSpokenTimeRangeUsesLocalClock() throws {
    let parsed = try XCTUnwrap(
      DailySpokenTemporalParser.parse("오늘 일정 추가 헬스장 9~11시")
    )
    let calendar = Calendar.current
    XCTAssertEqual(calendar.component(.hour, from: parsed.startAt), 9)
    XCTAssertEqual(calendar.component(.minute, from: parsed.startAt), 0)
    let endAt = try XCTUnwrap(parsed.endAt)
    XCTAssertEqual(calendar.component(.hour, from: endAt), 11)
    XCTAssertEqual(calendar.component(.minute, from: endAt), 0)
  }

  func testKoreanAllDayDateRangeUsesExclusiveEnd() throws {
    let parsed = try XCTUnwrap(
      DailySpokenTemporalParser.parse("8월 20일부터 9월 10일까지 종일 여행 추가")
    )
    let calendar = Calendar.current
    XCTAssertEqual(parsed.allDay, true)
    XCTAssertEqual(calendar.component(.month, from: parsed.startAt), 8)
    XCTAssertEqual(calendar.component(.day, from: parsed.startAt), 20)
    let endAt = try XCTUnwrap(parsed.endAt)
    XCTAssertEqual(calendar.component(.month, from: endAt), 9)
    XCTAssertEqual(calendar.component(.day, from: endAt), 11)
  }

  func testSiriUpdateRequirementComparesVersionsLikeFlutter() {
    XCTAssertTrue(DailySiriUpdateRequirement.isNewer("4.1.0", than: "4.0.9"))
    XCTAssertTrue(DailySiriUpdateRequirement.isNewer("4.10", than: "4.9.9"))
    XCTAssertFalse(DailySiriUpdateRequirement.isNewer("4.1.0", than: "4.1"))
    XCTAssertFalse(DailySiriUpdateRequirement.isNewer("4.0.9", than: "4.1.0"))
    XCTAssertFalse(DailySiriUpdateRequirement.isNewer("4.1.0-beta", than: "4.1.0"))
  }

  func testSiriLanguageFollowsSupportedSystemLanguage() {
    XCTAssertEqual(DailySiriLanguage.resolve("ko-KR"), .korean)
    XCTAssertEqual(DailySiriLanguage.resolve("en-US"), .english)
    XCTAssertEqual(DailySiriLanguage.resolve("ja-JP"), .japanese)
    XCTAssertEqual(DailySiriLanguage.resolve("zh-Hant-TW"), .traditionalChinese)
    XCTAssertEqual(DailySiriLanguage.resolve("zh-HK"), .traditionalChinese)
    XCTAssertEqual(DailySiriLanguage.resolve("zh-Hans-CN"), .english)
  }

  func testSiriRecognizesGeneratedKoreanHolidays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
    let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
    let identifiers = Set(
      DailyKoreanHolidayService.events(
        from: start,
        to: end,
        respectVisibilitySetting: false
      ).map(\.id)
    )
    XCTAssertTrue(identifiers.contains("kr-holiday-2026-02-17-설날"))
    XCTAssertTrue(identifiers.contains("kr-holiday-2026-05-25-대체공휴일"))
    XCTAssertTrue(identifiers.contains("kr-holiday-2026-08-15-광복절"))
    XCTAssertTrue(identifiers.contains("kr-holiday-2026-08-17-대체공휴일"))
  }

}
