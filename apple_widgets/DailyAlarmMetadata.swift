#if os(iOS)
import AlarmKit
import Foundation

@available(iOS 26.0, *)
struct DailyAlarmMetadata: AlarmMetadata {
  let title: String
  let memo: String?
  // Absent on alarms scheduled by earlier versions (#921).
  var snoozeMinutes: Int? = nil
  var localeTag: String? = nil
}
#endif
