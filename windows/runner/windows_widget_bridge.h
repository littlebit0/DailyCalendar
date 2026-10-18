#ifndef RUNNER_WINDOWS_WIDGET_BRIDGE_H_
#define RUNNER_WINDOWS_WIDGET_BRIDGE_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>
#include "widget_action_codec.h"

// Hosts the Windows equivalent of the Apple calendar widgets. Flutter sends
// the same snapshot shape used by WidgetKit, while the tray mini calendar
// renders it as a native, interactive Win32 surface.
class WindowsWidgetBridge final {
 public:
  WindowsWidgetBridge(flutter::BinaryMessenger* messenger,
                      HWND owner,
                      std::function<void()> open_app);
  ~WindowsWidgetBridge();

  WindowsWidgetBridge(const WindowsWidgetBridge&) = delete;
  WindowsWidgetBridge& operator=(const WindowsWidgetBridge&) = delete;

  void ShowMiniCalendar();

 private:
  struct MonthDay {
    std::string date;  // yyyy-MM-dd
    int day = 0;
    bool in_month = false;
    bool is_today = false;
    int event_count = 0;
    std::vector<std::uint32_t> event_colors;
  };

  struct TodayEvent {
    std::string event_id;
    std::string occurrence_id;
    std::wstring title;
    std::wstring time_label;
    std::uint32_t color = 0xFF2563EB;
    bool completed = false;
  };

  struct DdayEvent {
    std::wstring title;
    std::wstring date_label;
    int days_remaining = 0;
    std::uint32_t color = 0xFF2563EB;
    bool completed = false;
  };

  // Values Flutter precomputed for one calendar day of the cached grid.
  struct DailyView {
    std::string date;  // yyyy-MM-dd
    std::wstring today_title;
    int today_remaining_count = 0;
    std::vector<TodayEvent> today_events;
    std::vector<DdayEvent> ddays;  // ranked for this day
  };

  struct Snapshot {
    // The day the "today" values were computed for; empty on older snapshots.
    std::string snapshot_date;
    // UTC offset the day buckets were built with, and the instant it is for.
    bool has_utc_offset = false;
    int utc_offset_minutes = 0;
    std::int64_t utc_offset_at_ms = 0;
    std::vector<DailyView> daily_views;
    std::wstring month_title;
    std::wstring today_title;
    std::wstring theme_mode;
    std::wstring locale_tag;
    bool week_starts_on_monday = false;
    int today_remaining_count = 0;
    std::vector<MonthDay> month_days;
    std::vector<TodayEvent> today_events;
    std::vector<DdayEvent> ddays;
  };

  using PendingAction = daily_widgets::TodoAction;

  struct EventHitTarget {
    RECT bounds{};
    std::size_t event_index = 0;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool UpdateSnapshot(const flutter::EncodableMap& map);
  // Re-derives today's title, events, highlight and D-day counters for the
  // device date from the cached daily views (#103).
  void RollSnapshotToToday();
  flutter::EncodableList PendingActionsForFlutter() const;
  bool AcknowledgeActions(const flutter::EncodableMap* arguments);
  void ToggleEvent(std::size_t index);
  void UpdateEventCompletion(const std::string& event_id, bool completed);

  void EnsurePopupWindow();
  void PositionPopup();
  void Paint(HDC target_dc);
  void ApplyWindowTheme();
  void ClosePopup();
  bool IsDarkMode() const;
  UINT CurrentDpi() const;
  int Scale(int logical_pixels) const;

  void LoadPendingActions();
  bool SavePendingActions() const;
  std::wstring DataDirectory() const;
  std::wstring ActionsFilePath() const;

  static Snapshot BuildCurrentMonthFallback();
  static std::wstring Utf16FromUtf8(const std::string& value);
  static std::string NewActionToken();
  static LRESULT CALLBACK PopupWindowProc(HWND window,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);
  LRESULT HandlePopupMessage(HWND window,
                             UINT message,
                             WPARAM wparam,
                             LPARAM lparam);

  HWND owner_ = nullptr;
  HWND popup_ = nullptr;
  std::function<void()> open_app_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  Snapshot snapshot_;
  std::vector<PendingAction> pending_actions_;
  std::vector<EventHitTarget> event_hit_targets_;
  RECT open_button_bounds_{};
};

#endif  // RUNNER_WINDOWS_WIDGET_BRIDGE_H_
