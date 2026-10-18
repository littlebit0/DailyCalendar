// Behaviour of the Windows mini-calendar rollover helpers (#103).
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>

#include "../../windows/runner/widget_date_rollover.h"

using daily_widgets::DecideRollover;
using daily_widgets::RolloverAction;

static void UseZone(const char* zone) {
  setenv("TZ", zone, 1);
  tzset();
}

static std::time_t Utc(int y, int m, int d, int hh, int mm) {
  return static_cast<std::time_t>(daily_widgets::DaysFromCivil(y, m, d) * 86400 +
                                  hh * 3600 + mm * 60);
}

int main() {
  const std::vector<std::string> views = {"2026-10-31", "2026-11-01", "2026-11-02"};

  // Civil date arithmetic across month, year and leap boundaries.
  assert(daily_widgets::DaysFromCivil(1970, 1, 1) == 0);
  assert(daily_widgets::DaysFromCivil(2027, 1, 1) - daily_widgets::DaysFromCivil(2026, 12, 31) == 1);
  assert(daily_widgets::DaysFromCivil(2028, 3, 1) - daily_widgets::DaysFromCivil(2028, 2, 28) == 2);

  // The key and the offset follow the device zone (always Gregorian).
  UseZone("Asia/Seoul");
  const std::time_t instant = Utc(2026, 10, 31, 16, 30);  // 01:30 on 11/01 in Seoul
  assert(daily_widgets::LocalDateKey(instant) == "2026-11-01");
  assert(daily_widgets::LocalUtcOffsetMinutes(instant) == 540);
  UseZone("UTC");
  assert(daily_widgets::LocalDateKey(instant) == "2026-10-31");
  assert(daily_widgets::LocalUtcOffsetMinutes(instant) == 0);
  UseZone("America/New_York");
  assert(daily_widgets::LocalUtcOffsetMinutes(Utc(2026, 10, 26, 7, 0)) == -240);  // EDT
  assert(daily_widgets::LocalUtcOffsetMinutes(Utc(2026, 11, 6, 7, 0)) == -300);   // EST

  // Same day and legacy snapshots are kept.
  assert(DecideRollover("2026-10-31", "2026-10-31", true, 540, 540, views).action == RolloverAction::kKeep);
  assert(DecideRollover("", "2026-11-01", true, 540, 540, views).action == RolloverAction::kKeep);

  // The next day (a month boundary) picks that day's view.
  auto next = DecideRollover("2026-10-31", "2026-11-01", true, 540, 540, views);
  assert(next.action == RolloverAction::kUseView && next.view_index == 1);

  // A day outside the cached grid, or an empty cache, needs a refresh.
  assert(DecideRollover("2026-10-31", "2026-12-25", true, 540, 540, views).action == RolloverAction::kNeedsRefresh);
  assert(DecideRollover("2026-10-31", "2026-11-01", true, 540, 540, {}).action == RolloverAction::kNeedsRefresh);

  // A changed time zone invalidates the buckets even on the same date ...
  assert(DecideRollover("2026-10-31", "2026-10-31", true, 540, 0, views).action == RolloverAction::kNeedsRefresh);
  assert(DecideRollover("2026-10-31", "2026-11-01", true, 540, 0, views).action == RolloverAction::kNeedsRefresh);
  // ... while a snapshot without a recorded offset is not judged by it.
  assert(DecideRollover("2026-10-31", "2026-10-31", false, 0, 0, views).action == RolloverAction::kKeep);

  std::cout << "widget date rollover (C++) checks passed\n";
  return 0;
}
