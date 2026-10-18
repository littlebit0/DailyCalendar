#ifndef DAILY_WIDGET_DATE_ROLLOVER_H_
#define DAILY_WIDGET_DATE_ROLLOVER_H_
// Pure (Flutter-free) helpers for re-deriving a widget snapshot's "today"
// values on the device date (#103). Kept header-only so a test can compile
// it on its own.
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <string>
#include <vector>

namespace daily_widgets {

// Days since 1970-01-01 for a proleptic Gregorian date.
inline long long DaysFromCivil(int year, int month, int day) {
  year -= month <= 2 ? 1 : 0;
  const long long era = (year >= 0 ? year : year - 399) / 400;
  const long long yoe = year - era * 400;
  const long long doy =
      (153LL * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
  const long long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097 + doe - 719468;
}

inline bool LocalTime(std::time_t t, std::tm* out) {
#ifdef _WIN32
  return localtime_s(out, &t) == 0;
#else
  return localtime_r(&t, out) != nullptr;
#endif
}

// yyyy-MM-dd of [t] in the process's local time zone (always Gregorian).
inline std::string LocalDateKey(std::time_t t) {
  std::tm local{};
  if (!LocalTime(t, &local)) return {};
  char buffer[16];
  std::snprintf(buffer, sizeof(buffer), "%04d-%02d-%02d", local.tm_year + 1900,
                local.tm_mon + 1, local.tm_mday);
  return buffer;
}

// UTC offset, in minutes, the local time zone has at instant [t].
inline int LocalUtcOffsetMinutes(std::time_t t) {
  std::tm local{};
  if (!LocalTime(t, &local)) return 0;
  const long long local_seconds =
      DaysFromCivil(local.tm_year + 1900, local.tm_mon + 1, local.tm_mday) *
          86400 +
      local.tm_hour * 3600LL + local.tm_min * 60LL + local.tm_sec;
  return static_cast<int>((local_seconds - static_cast<long long>(t)) / 60);
}

enum class RolloverAction {
  kKeep,         // Show the stored values as they are.
  kUseView,      // Use daily view [view_index].
  kNeedsRefresh  // The cache cannot represent today; ask for a refresh.
};

struct RolloverDecision {
  RolloverAction action = RolloverAction::kKeep;
  std::size_t view_index = 0;
};

// [snapshot_date] empty: written before this contract, nothing to compare.
// [has_offset]: the snapshot recorded the UTC offset it was built with;
// [offset_now_at_build] is the offset the device's zone has at that instant.
inline RolloverDecision DecideRollover(
    const std::string& snapshot_date, const std::string& today,
    bool has_offset, int built_offset_minutes, int offset_now_at_build,
    const std::vector<std::string>& view_dates) {
  if (snapshot_date.empty()) return {};
  if (has_offset && built_offset_minutes != offset_now_at_build) {
    return {RolloverAction::kNeedsRefresh, 0};
  }
  if (snapshot_date == today) return {};
  for (std::size_t index = 0; index < view_dates.size(); ++index) {
    if (view_dates[index] == today) return {RolloverAction::kUseView, index};
  }
  return {RolloverAction::kNeedsRefresh, 0};
}

}  // namespace daily_widgets

#endif  // DAILY_WIDGET_DATE_ROLLOVER_H_
