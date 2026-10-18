#include "windows_widget_bridge.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <objbase.h>
#include <windowsx.h>

#include <algorithm>
#include <array>
#include <cstdio>
#include <cwctype>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <limits>
#include <set>
#include <sstream>
#include <utility>
#include <variant>

#include "app_identity.h"
#include "widget_date_rollover.h"
#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr wchar_t kPopupClassName[] = L"DAILY_WINDOWS_WIDGET_SURFACE";

const flutter::EncodableValue* MapValue(const flutter::EncodableMap& map,
                                        const char* key) {
  const auto value = map.find(flutter::EncodableValue(key));
  return value == map.end() ? nullptr : &value->second;
}

const flutter::EncodableMap* AsMap(const flutter::EncodableValue* value) {
  return value == nullptr
             ? nullptr
             : std::get_if<flutter::EncodableMap>(value);
}

const flutter::EncodableList* AsList(const flutter::EncodableValue* value) {
  return value == nullptr
             ? nullptr
             : std::get_if<flutter::EncodableList>(value);
}

std::string StringValue(const flutter::EncodableMap& map,
                        const char* key,
                        const std::string& fallback = {}) {
  const auto* value = MapValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? fallback : *text;
}

bool BoolValue(const flutter::EncodableMap& map,
               const char* key,
               bool fallback = false) {
  const auto* value = MapValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  const auto* boolean = std::get_if<bool>(value);
  return boolean == nullptr ? fallback : *boolean;
}

std::int64_t IntegerValue(const flutter::EncodableMap& map,
                          const char* key,
                          std::int64_t fallback = 0) {
  const auto* value = MapValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* integer = std::get_if<std::int32_t>(value)) {
    return *integer;
  }
  if (const auto* integer = std::get_if<std::int64_t>(value)) {
    return *integer;
  }
  return fallback;
}

COLORREF ColorFromArgb(std::uint32_t argb) {
  return RGB((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

bool ContainsPoint(const RECT& bounds, POINT point) {
  return PtInRect(&bounds, point) != FALSE;
}

void FillSolidRect(HDC dc, const RECT& bounds, COLORREF color) {
  HBRUSH brush = CreateSolidBrush(color);
  FillRect(dc, &bounds, brush);
  DeleteObject(brush);
}

void FillRoundedRect(HDC dc,
                     const RECT& bounds,
                     int radius,
                     COLORREF color) {
  HBRUSH brush = CreateSolidBrush(color);
  HPEN pen = CreatePen(PS_NULL, 0, color);
  HGDIOBJ previous_brush = SelectObject(dc, brush);
  HGDIOBJ previous_pen = SelectObject(dc, pen);
  RoundRect(dc, bounds.left, bounds.top, bounds.right, bounds.bottom, radius,
            radius);
  SelectObject(dc, previous_pen);
  SelectObject(dc, previous_brush);
  DeleteObject(pen);
  DeleteObject(brush);
}

HFONT MakeFont(UINT dpi,
               int point_size,
               int weight = FW_NORMAL,
               bool strike_out = false) {
  return CreateFontW(-MulDiv(point_size, dpi, 72), 0, 0, 0, weight, FALSE,
                     strike_out, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                     CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                     DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
}

enum class UiLanguage { kEnglish, kKorean, kJapanese, kTraditionalChinese };

UiLanguage ResolveUiLanguage(const std::wstring& requested_locale) {
  std::wstring locale = requested_locale;
  if (locale.empty()) {
    wchar_t system_locale[LOCALE_NAME_MAX_LENGTH] = {};
    if (GetUserDefaultLocaleName(system_locale, LOCALE_NAME_MAX_LENGTH) != 0) {
      locale = system_locale;
    }
  }
  std::transform(locale.begin(), locale.end(), locale.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(std::towlower(character));
                 });
  if (locale.rfind(L"ko", 0) == 0) {
    return UiLanguage::kKorean;
  }
  if (locale.rfind(L"ja", 0) == 0) {
    return UiLanguage::kJapanese;
  }
  if (locale.rfind(L"zh-hant", 0) == 0 ||
      locale.rfind(L"zh-tw", 0) == 0 ||
      locale.rfind(L"zh-hk", 0) == 0) {
    return UiLanguage::kTraditionalChinese;
  }
  return UiLanguage::kEnglish;
}

std::wstring OpenLabel(const std::wstring& locale) {
  switch (ResolveUiLanguage(locale)) {
    case UiLanguage::kKorean:
      return L"\xC5F4\xAE30";
    case UiLanguage::kJapanese:
      return L"\x958B\x304F";
    case UiLanguage::kTraditionalChinese:
      return L"\x958B\x555F";
    default:
      return L"Open";
  }
}

std::wstring EmptyTodayLabel(const std::wstring& locale) {
  switch (ResolveUiLanguage(locale)) {
    case UiLanguage::kKorean:
      return L"\xC624\xB298 \xC77C\xC815\xC774 \xC5C6\xC2B5\xB2C8\xB2E4.";
    case UiLanguage::kJapanese:
      return L"\x4ECA\x65E5\x306E\x4E88\x5B9A\x306F\x3042\x308A\x307E\x305B\x3093\x3002";
    case UiLanguage::kTraditionalChinese:
      return L"\x4ECA\x5929\x6C92\x6709\x884C\x7A0B\x3002";
    default:
      return L"No schedules for today.";
  }
}

std::wstring TodayLabel(const std::wstring& locale) {
  switch (ResolveUiLanguage(locale)) {
    case UiLanguage::kKorean:
      return L"\xC624\xB298";
    case UiLanguage::kJapanese:
      return L"\x4ECA\x65E5";
    case UiLanguage::kTraditionalChinese:
      return L"\x4ECA\x5929";
    default:
      return L"Today";
  }
}

std::wstring MoreLabel(const std::wstring& locale, int count) {
  switch (ResolveUiLanguage(locale)) {
    case UiLanguage::kKorean:
      return L"+" + std::to_wstring(count) + L"\xAC1C \xB354";
    case UiLanguage::kJapanese:
      return L"\x4ED6 " + std::to_wstring(count) + L" \x4EF6";
    case UiLanguage::kTraditionalChinese:
      return L"\x9084\x6709 " + std::to_wstring(count) + L" \x500B";
    default:
      return L"+" + std::to_wstring(count) + L" more";
  }
}

std::array<std::wstring, 7> WeekdayLabels(
    bool monday_first,
    const std::wstring& requested_locale) {
  std::array<std::wstring, 7> monday_labels;
  if (!requested_locale.empty()) {
    switch (ResolveUiLanguage(requested_locale)) {
      case UiLanguage::kKorean:
        monday_labels = {L"\xC6D4", L"\xD654", L"\xC218", L"\xBAA9",
                         L"\xAE08", L"\xD1A0", L"\xC77C"};
        break;
      case UiLanguage::kJapanese:
        monday_labels = {L"\x6708", L"\x706B", L"\x6C34", L"\x6728",
                         L"\x91D1", L"\x571F", L"\x65E5"};
        break;
      case UiLanguage::kTraditionalChinese:
        monday_labels = {L"\x9031\x4E00", L"\x9031\x4E8C",
                         L"\x9031\x4E09", L"\x9031\x56DB",
                         L"\x9031\x4E94", L"\x9031\x516D",
                         L"\x9031\x65E5"};
        break;
      default:
        monday_labels = {L"Mon", L"Tue", L"Wed", L"Thu", L"Fri",
                         L"Sat", L"Sun"};
        break;
    }
  } else {
    for (int index = 0; index < 7; ++index) {
      wchar_t label[32] = {};
      GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT,
                      LOCALE_SABBREVDAYNAME1 + index, label,
                      static_cast<int>(std::size(label)));
      monday_labels[index] = label[0] == L'\0' ? L"-" : label;
    }
  }
  if (monday_first) {
    return monday_labels;
  }
  return {monday_labels[6], monday_labels[0], monday_labels[1],
          monday_labels[2], monday_labels[3], monday_labels[4],
          monday_labels[5]};
}

}  // namespace

WindowsWidgetBridge::WindowsWidgetBridge(flutter::BinaryMessenger* messenger,
                                         HWND owner,
                                         std::function<void()> open_app)
    : owner_(owner), open_app_(std::move(open_app)) {
  snapshot_ = BuildCurrentMonthFallback();
  LoadPendingActions();
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "daily/windows_widgets",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

WindowsWidgetBridge::~WindowsWidgetBridge() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (popup_ != nullptr) {
    DestroyWindow(popup_);
    popup_ = nullptr;
  }
}

void WindowsWidgetBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "updateSnapshot") {
    const auto* snapshot = std::get_if<flutter::EncodableMap>(call.arguments());
    if (snapshot == nullptr || !UpdateSnapshot(*snapshot)) {
      result->Error("invalid_widget_snapshot",
                    "The Windows widget snapshot must be a map.");
      return;
    }
    result->Success();
    return;
  }
  if (call.method_name() == "pendingTodoActions") {
    result->Success(flutter::EncodableValue(PendingActionsForFlutter()));
    return;
  }
  if (call.method_name() == "acknowledgeTodoActions") {
    if (!AcknowledgeActions(
            std::get_if<flutter::EncodableMap>(call.arguments()))) {
      // The tokens stay queued (memory and disk agree), so the caller retries.
      result->Error("pending_actions_save_failed",
                    "The widget action queue could not be saved.");
      return;
    }
    result->Success();
    return;
  }
  result->NotImplemented();
}

void WindowsWidgetBridge::RollSnapshotToToday() {
  const std::time_t now = std::time(nullptr);
  const std::string today = daily_widgets::LocalDateKey(now);
  std::vector<std::string> view_dates;
  view_dates.reserve(snapshot_.daily_views.size());
  for (const auto& view : snapshot_.daily_views) {
    view_dates.push_back(view.date);
  }
  const auto decision = daily_widgets::DecideRollover(
      snapshot_.snapshot_date, today, snapshot_.has_utc_offset,
      snapshot_.utc_offset_minutes,
      daily_widgets::LocalUtcOffsetMinutes(static_cast<std::time_t>(
          snapshot_.utc_offset_at_ms / 1000)),
      view_dates);
  if (decision.action == daily_widgets::RolloverAction::kKeep) {
    return;
  }
  for (auto& day : snapshot_.month_days) {
    day.is_today = !day.date.empty() && day.date == today;
  }
  if (decision.action == daily_widgets::RolloverAction::kNeedsRefresh) {
    // The cache cannot represent today (outside the grid, or the time zone
    // changed): do not present old values as current. Ask the user to open the
    // app, which sends a fresh snapshot.
    snapshot_.today_events.clear();
    snapshot_.today_remaining_count = 0;
    snapshot_.today_title = OpenLabel(snapshot_.locale_tag);
    snapshot_.ddays.clear();
    for (auto& day : snapshot_.month_days) {
      day.is_today = false;
    }
    return;
  }
  const DailyView& view = snapshot_.daily_views[decision.view_index];
  snapshot_.today_title = view.today_title;
  snapshot_.today_events = view.today_events;
  snapshot_.today_remaining_count = view.today_remaining_count;
  snapshot_.ddays = view.ddays;
  snapshot_.snapshot_date = today;
}

bool WindowsWidgetBridge::UpdateSnapshot(const flutter::EncodableMap& map) {
  Snapshot parsed = BuildCurrentMonthFallback();
  parsed.month_title = Utf16FromUtf8(StringValue(map, "monthTitle"));
  if (parsed.month_title.empty()) {
    parsed.month_title = daily::app_identity::kDisplayName;
  }
  parsed.today_title = Utf16FromUtf8(StringValue(map, "todayTitle"));
  parsed.theme_mode = Utf16FromUtf8(StringValue(map, "themeMode", "system"));
  parsed.locale_tag = Utf16FromUtf8(StringValue(map, "localeTag"));
  if (parsed.today_title.empty()) {
    parsed.today_title = TodayLabel(parsed.locale_tag);
  }
  parsed.week_starts_on_monday =
      BoolValue(map, "weekStartsOnMonday", false);
  parsed.today_remaining_count = static_cast<int>(std::clamp<std::int64_t>(
      IntegerValue(map, "todayRemainingCount"), 0, 100000));

  if (const auto* days = AsList(MapValue(map, "monthDays"));
      days != nullptr && !days->empty()) {
    std::vector<MonthDay> parsed_days;
    parsed_days.reserve(std::min<std::size_t>(days->size(), 42));
    for (const auto& encoded_day : *days) {
      const auto* day_map = std::get_if<flutter::EncodableMap>(&encoded_day);
      if (day_map == nullptr) {
        continue;
      }
      MonthDay day;
      day.date = StringValue(*day_map, "date");
      day.day = static_cast<int>(
          std::clamp<std::int64_t>(IntegerValue(*day_map, "day"), 0, 31));
      day.in_month = BoolValue(*day_map, "inMonth");
      day.is_today = BoolValue(*day_map, "isToday");
      day.event_count = static_cast<int>(std::clamp<std::int64_t>(
          IntegerValue(*day_map, "eventCount"), 0, 100000));
      if (const auto* events = AsList(MapValue(*day_map, "events"))) {
        for (const auto& encoded_event : *events) {
          const auto* event_map =
              std::get_if<flutter::EncodableMap>(&encoded_event);
          if (event_map == nullptr) {
            continue;
          }
          day.event_colors.push_back(static_cast<std::uint32_t>(
              IntegerValue(*event_map, "color", 0xFF2563EB)));
          if (day.event_colors.size() == 3) {
            break;
          }
        }
      }
      parsed_days.push_back(std::move(day));
      if (parsed_days.size() == 42) {
        break;
      }
    }
    if (!parsed_days.empty()) {
      parsed.month_days = std::move(parsed_days);
    }
  }

  const auto parse_ddays = [](const flutter::EncodableList* ddays) {
    std::vector<DdayEvent> parsed_ddays;
    if (ddays == nullptr) {
      return parsed_ddays;
    }
    parsed_ddays.reserve(ddays->size());
    for (const auto& encoded_dday : *ddays) {
      const auto* dday_map = std::get_if<flutter::EncodableMap>(&encoded_dday);
      if (dday_map == nullptr) {
        continue;
      }
      DdayEvent dday;
      dday.title = Utf16FromUtf8(StringValue(*dday_map, "title"));
      dday.date_label = Utf16FromUtf8(StringValue(*dday_map, "dateLabel"));
      dday.days_remaining = static_cast<int>(std::clamp<std::int64_t>(
          IntegerValue(*dday_map, "daysRemaining"),
          std::numeric_limits<int>::min(), std::numeric_limits<int>::max()));
      dday.color = static_cast<std::uint32_t>(
          IntegerValue(*dday_map, "color", 0xFF2563EB));
      dday.completed = BoolValue(*dday_map, "completed");
      parsed_ddays.push_back(std::move(dday));
    }
    return parsed_ddays;
  };
  const auto parse_today_events = [](const flutter::EncodableList* events) {
    std::vector<TodayEvent> parsed_events;
    if (events == nullptr) {
      return parsed_events;
    }
    parsed_events.reserve(events->size());
    for (const auto& encoded_event : *events) {
      const auto* event_map =
          std::get_if<flutter::EncodableMap>(&encoded_event);
      if (event_map == nullptr) {
        continue;
      }
      TodayEvent event;
      event.event_id = StringValue(*event_map, "eventId");
      if (event.event_id.empty()) {
        event.event_id = StringValue(*event_map, "id");
      }
      event.occurrence_id = StringValue(*event_map, "id");
      event.title = Utf16FromUtf8(StringValue(*event_map, "title"));
      event.time_label = Utf16FromUtf8(StringValue(*event_map, "timeLabel"));
      event.color = static_cast<std::uint32_t>(
          IntegerValue(*event_map, "color", 0xFF2563EB));
      event.completed = BoolValue(*event_map, "completed");
      parsed_events.push_back(std::move(event));
    }
    return parsed_events;
  };
  parsed.today_events = parse_today_events(AsList(MapValue(map, "todayEvents")));

  parsed.snapshot_date = StringValue(map, "snapshotDate");
  if (MapValue(map, "utcOffsetMinutes") != nullptr &&
      MapValue(map, "utcOffsetAtMs") != nullptr) {
    parsed.has_utc_offset = true;
    parsed.utc_offset_minutes = static_cast<int>(
        std::clamp<std::int64_t>(IntegerValue(map, "utcOffsetMinutes"), -1440, 1440));
    parsed.utc_offset_at_ms = IntegerValue(map, "utcOffsetAtMs");
  }
  parsed.daily_views.clear();
  if (const auto* views = AsList(MapValue(map, "dailyViews"))) {
    parsed.daily_views.reserve(views->size());
    for (const auto& encoded_view : *views) {
      const auto* view_map = std::get_if<flutter::EncodableMap>(&encoded_view);
      if (view_map == nullptr) {
        continue;
      }
      DailyView view;
      view.date = StringValue(*view_map, "date");
      view.today_title = Utf16FromUtf8(StringValue(*view_map, "todayTitle"));
      view.today_remaining_count = static_cast<int>(std::clamp<std::int64_t>(
          IntegerValue(*view_map, "todayRemainingCount"), 0, 100000));
      view.today_events =
          parse_today_events(AsList(MapValue(*view_map, "todayEvents")));
      view.ddays = parse_ddays(AsList(MapValue(*view_map, "ddays")));
      parsed.daily_views.push_back(std::move(view));
    }
  }

  parsed.ddays = parse_ddays(AsList(MapValue(map, "ddays")));

  snapshot_ = std::move(parsed);
  RollSnapshotToToday();
  ApplyWindowTheme();
  if (popup_ != nullptr) {
    InvalidateRect(popup_, nullptr, FALSE);
  }
  return true;
}

flutter::EncodableList WindowsWidgetBridge::PendingActionsForFlutter() const {
  flutter::EncodableList encoded;
  encoded.reserve(pending_actions_.size());
  for (const auto& action : pending_actions_) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("token")] =
        flutter::EncodableValue(action.token);
    map[flutter::EncodableValue("eventId")] =
        flutter::EncodableValue(action.event_id);
    map[flutter::EncodableValue("completed")] =
        flutter::EncodableValue(action.completed);
    map[flutter::EncodableValue("occurrenceId")] = flutter::EncodableValue(action.occurrence_id);
    encoded.emplace_back(map);
  }
  return encoded;
}

bool WindowsWidgetBridge::AcknowledgeActions(
    const flutter::EncodableMap* arguments) {
  if (arguments == nullptr) {
    return true;
  }
  const auto* tokens = AsList(MapValue(*arguments, "tokens"));
  if (tokens == nullptr || tokens->empty()) {
    return true;
  }
  std::set<std::string> acknowledged;
  for (const auto& encoded_token : *tokens) {
    if (const auto* token = std::get_if<std::string>(&encoded_token)) {
      acknowledged.insert(*token);
    }
  }
  const auto previous_actions = pending_actions_;
  const auto old_size = pending_actions_.size();
  pending_actions_.erase(
      std::remove_if(pending_actions_.begin(), pending_actions_.end(),
                     [&acknowledged](const PendingAction& action) {
                       return acknowledged.count(action.token) != 0;
                     }),
      pending_actions_.end());
  if (pending_actions_.size() != old_size && !SavePendingActions()) {
    // Do not report the tokens as handled when the file still lists them.
    pending_actions_ = previous_actions;
    return false;
  }
  return true;
}

void WindowsWidgetBridge::ToggleEvent(std::size_t index) {
  if (index >= snapshot_.today_events.size()) {
    return;
  }
  const std::string event_id = snapshot_.today_events[index].event_id;
  if (event_id.empty()) {
    return;
  }
  const bool completed = !snapshot_.today_events[index].completed;
  const std::string occurrence_id = snapshot_.today_events[index].occurrence_id;
  pending_actions_.push_back(
      PendingAction{NewActionToken(), event_id, completed, occurrence_id});
  if (!SavePendingActions()) {
    // Without a durable request a restart would lose the click, so neither the
    // queue nor the displayed state may claim it happened.
    pending_actions_.pop_back();
    return;
  }
  UpdateEventCompletion(occurrence_id.empty() ? event_id : occurrence_id, completed);
  InvalidateRect(popup_, nullptr, FALSE);
  channel_->InvokeMethod("todoActionsChanged", nullptr);
}

void WindowsWidgetBridge::UpdateEventCompletion(const std::string& event_id,
                                                bool completed) {
  const auto apply = [&](std::vector<TodayEvent>& events) {
    for (auto& event : events) {
      if ((event.occurrence_id.empty() ? event.event_id : event.occurrence_id) == event_id) {
        event.completed = completed;
      }
    }
  };
  apply(snapshot_.today_events);
  for (auto& view : snapshot_.daily_views) {
    apply(view.today_events);
  }
}

void WindowsWidgetBridge::ShowMiniCalendar() {
  RollSnapshotToToday();
  EnsurePopupWindow();
  if (popup_ == nullptr) {
    return;
  }
  ApplyWindowTheme();
  PositionPopup();
  ShowWindow(popup_, SW_SHOWNORMAL);
  SetForegroundWindow(popup_);
  SetFocus(popup_);
  InvalidateRect(popup_, nullptr, FALSE);
}

void WindowsWidgetBridge::EnsurePopupWindow() {
  if (popup_ != nullptr) {
    return;
  }
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
  window_class.lpfnWndProc = PopupWindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hIcon =
      LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.hIconSm = window_class.hIcon;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kPopupClassName;
  if (RegisterClassExW(&window_class) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return;
  }

  popup_ = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kPopupClassName,
      daily::app_identity::kDisplayName, WS_POPUP | WS_BORDER, CW_USEDEFAULT,
      CW_USEDEFAULT, Scale(440), Scale(700), nullptr, nullptr,
      GetModuleHandle(nullptr), this);
}

void WindowsWidgetBridge::PositionPopup() {
  POINT cursor{};
  GetCursorPos(&cursor);
  const HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  GetMonitorInfoW(monitor, &monitor_info);

  const int width = Scale(440);
  const int height = Scale(700);
  int x = cursor.x - width;
  int y = cursor.y - height - Scale(8);
  const int work_left = static_cast<int>(monitor_info.rcWork.left);
  const int work_top = static_cast<int>(monitor_info.rcWork.top);
  const int work_right = static_cast<int>(monitor_info.rcWork.right);
  const int work_bottom = static_cast<int>(monitor_info.rcWork.bottom);
  x = std::clamp(x, work_left, std::max(work_left, work_right - width));
  y = std::clamp(y, work_top, std::max(work_top, work_bottom - height));
  SetWindowPos(popup_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void WindowsWidgetBridge::Paint(HDC target_dc) {
  RECT client{};
  GetClientRect(popup_, &client);
  const int width = client.right - client.left;
  const int height = client.bottom - client.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  HDC dc = CreateCompatibleDC(target_dc);
  HBITMAP bitmap = CreateCompatibleBitmap(target_dc, width, height);
  HGDIOBJ previous_bitmap = SelectObject(dc, bitmap);
  const bool dark = IsDarkMode();
  const COLORREF background = dark ? RGB(20, 20, 22) : RGB(255, 255, 255);
  const COLORREF surface = dark ? RGB(34, 34, 37) : RGB(246, 247, 249);
  const COLORREF text = dark ? RGB(244, 244, 245) : RGB(28, 30, 34);
  const COLORREF secondary = dark ? RGB(166, 167, 174) : RGB(103, 108, 119);
  const COLORREF faint = dark ? RGB(74, 75, 81) : RGB(221, 224, 230);
  const COLORREF blue = RGB(37, 99, 235);
  FillSolidRect(dc, client, background);
  SetBkMode(dc, TRANSPARENT);

  const UINT dpi = CurrentDpi();
  HFONT title_font = MakeFont(dpi, 15, FW_SEMIBOLD);
  HFONT section_font = MakeFont(dpi, 11, FW_SEMIBOLD);
  HFONT body_font = MakeFont(dpi, 10);
  HFONT body_completed_font = MakeFont(dpi, 10, FW_NORMAL, true);
  HFONT caption_font = MakeFont(dpi, 8);

  const int padding = Scale(18);
  const int header_height = Scale(54);
  const int icon_size = Scale(28);
  HICON icon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  if (icon != nullptr) {
    DrawIconEx(dc, padding, Scale(13), icon, icon_size, icon_size, 0, nullptr,
               DI_NORMAL);
  }

  HGDIOBJ previous_font = SelectObject(dc, title_font);
  SetTextColor(dc, text);
  RECT month_title{padding + icon_size + Scale(10), Scale(10),
                   width - Scale(104), header_height};
  DrawTextW(dc, snapshot_.month_title.c_str(), -1, &month_title,
            DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

  open_button_bounds_ = {width - Scale(92), Scale(12), width - padding,
                         Scale(42)};
  FillRoundedRect(dc, open_button_bounds_, Scale(14), blue);
  SetTextColor(dc, RGB(255, 255, 255));
  SelectObject(dc, section_font);
  const std::wstring open_label = OpenLabel(snapshot_.locale_tag);
  DrawTextW(dc, open_label.c_str(), -1, &open_button_bounds_,
            DT_SINGLELINE | DT_CENTER | DT_VCENTER);

  const int grid_left = padding;
  const int grid_right = width - padding;
  const int weekday_top = header_height + Scale(2);
  const int weekday_height = Scale(23);
  const int grid_top = weekday_top + weekday_height;
  const int cell_height = Scale(39);
  const int cell_width = (grid_right - grid_left) / 7;
  const auto weekdays = WeekdayLabels(snapshot_.week_starts_on_monday,
                                      snapshot_.locale_tag);
  SelectObject(dc, caption_font);
  SetTextColor(dc, secondary);
  for (int column = 0; column < 7; ++column) {
    RECT bounds{grid_left + column * cell_width, weekday_top,
                column == 6 ? grid_right
                            : grid_left + (column + 1) * cell_width,
                grid_top};
    DrawTextW(dc, weekdays[column].c_str(), -1, &bounds,
              DT_SINGLELINE | DT_CENTER | DT_VCENTER | DT_END_ELLIPSIS);
  }

  SelectObject(dc, body_font);
  for (std::size_t index = 0; index < snapshot_.month_days.size() && index < 42;
       ++index) {
    const int row = static_cast<int>(index) / 7;
    const int column = static_cast<int>(index) % 7;
    const auto& day = snapshot_.month_days[index];
    RECT cell{grid_left + column * cell_width, grid_top + row * cell_height,
              column == 6 ? grid_right
                          : grid_left + (column + 1) * cell_width,
              grid_top + (row + 1) * cell_height};
    if (day.is_today) {
      const RECT today_bounds{cell.left + Scale(5), cell.top + Scale(3),
                              cell.right - Scale(5), cell.bottom - Scale(3)};
      FillRoundedRect(dc, today_bounds, Scale(8),
                      dark ? RGB(31, 56, 103) : RGB(226, 235, 255));
    }
    SetTextColor(dc, day.in_month ? text : secondary);
    RECT day_label{cell.left, cell.top + Scale(3), cell.right,
                   cell.top + Scale(23)};
    const std::wstring day_text = std::to_wstring(day.day);
    DrawTextW(dc, day_text.c_str(), -1, &day_label,
              DT_SINGLELINE | DT_CENTER | DT_VCENTER);

    const int visible_dots = std::min(day.event_count, 3);
    const int dot_size = Scale(4);
    const int dot_gap = Scale(3);
    const int dots_width =
        visible_dots * dot_size + std::max(0, visible_dots - 1) * dot_gap;
    int dot_left = cell.left + (cell.right - cell.left - dots_width) / 2;
    for (int dot = 0; dot < visible_dots; ++dot) {
      const auto argb = dot < static_cast<int>(day.event_colors.size())
                            ? day.event_colors[dot]
                            : 0xFF2563EB;
      HBRUSH brush = CreateSolidBrush(ColorFromArgb(argb));
      HGDIOBJ old_brush = SelectObject(dc, brush);
      HPEN pen = CreatePen(PS_NULL, 0, ColorFromArgb(argb));
      HGDIOBJ old_pen = SelectObject(dc, pen);
      Ellipse(dc, dot_left, cell.bottom - Scale(10), dot_left + dot_size,
              cell.bottom - Scale(10) + dot_size);
      SelectObject(dc, old_pen);
      SelectObject(dc, old_brush);
      DeleteObject(pen);
      DeleteObject(brush);
      dot_left += dot_size + dot_gap;
    }
  }

  const int grid_bottom = grid_top + 6 * cell_height;
  RECT separator{padding, grid_bottom + Scale(8), width - padding,
                 grid_bottom + Scale(9)};
  FillSolidRect(dc, separator, faint);

  int cursor_y = grid_bottom + Scale(17);
  SelectObject(dc, section_font);
  SetTextColor(dc, text);
  RECT today_header{padding, cursor_y, width - padding, cursor_y + Scale(26)};
  DrawTextW(dc, snapshot_.today_title.c_str(), -1, &today_header,
            DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
  cursor_y += Scale(28);

  event_hit_targets_.clear();
  const std::size_t visible_today =
      std::min<std::size_t>(snapshot_.today_events.size(), 4);
  if (visible_today == 0) {
    RECT empty_bounds{padding, cursor_y, width - padding,
                      cursor_y + Scale(34)};
    FillRoundedRect(dc, empty_bounds, Scale(7), surface);
    SelectObject(dc, body_font);
    SetTextColor(dc, secondary);
    RECT empty_text{empty_bounds.left + Scale(10), empty_bounds.top,
                    empty_bounds.right - Scale(10), empty_bounds.bottom};
    const std::wstring empty_label = EmptyTodayLabel(snapshot_.locale_tag);
    DrawTextW(dc, empty_label.c_str(), -1, &empty_text,
              DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
    cursor_y += Scale(39);
  } else {
    const int row_height = Scale(38);
    for (std::size_t index = 0; index < visible_today; ++index) {
      const auto& event = snapshot_.today_events[index];
      RECT row{padding, cursor_y, width - padding, cursor_y + row_height};
      if (index % 2 == 0) {
        FillRoundedRect(dc, row, Scale(6), surface);
      }
      RECT checkbox{row.left + Scale(8), row.top + Scale(10),
                    row.left + Scale(26), row.top + Scale(28)};
      HPEN checkbox_pen = CreatePen(PS_SOLID, Scale(1),
                                    event.completed ? blue : secondary);
      HBRUSH checkbox_brush =
          CreateSolidBrush(event.completed ? blue : background);
      HGDIOBJ old_pen = SelectObject(dc, checkbox_pen);
      HGDIOBJ old_brush = SelectObject(dc, checkbox_brush);
      Ellipse(dc, checkbox.left, checkbox.top, checkbox.right, checkbox.bottom);
      if (event.completed) {
        HPEN check_pen = CreatePen(PS_SOLID, Scale(2), RGB(255, 255, 255));
        SelectObject(dc, check_pen);
        MoveToEx(dc, checkbox.left + Scale(4), checkbox.top + Scale(9), nullptr);
        LineTo(dc, checkbox.left + Scale(8), checkbox.bottom - Scale(4));
        LineTo(dc, checkbox.right - Scale(4), checkbox.top + Scale(5));
        SelectObject(dc, old_pen);
        DeleteObject(check_pen);
      } else {
        SelectObject(dc, old_pen);
      }
      SelectObject(dc, old_brush);
      DeleteObject(checkbox_pen);
      DeleteObject(checkbox_brush);
      event_hit_targets_.push_back(EventHitTarget{checkbox, index});

      RECT color_bar{checkbox.right + Scale(8), row.top + Scale(9),
                     checkbox.right + Scale(11), row.bottom - Scale(9)};
      FillRoundedRect(dc, color_bar, Scale(2), ColorFromArgb(event.color));
      SelectObject(dc, caption_font);
      SetTextColor(dc, secondary);
      RECT time_bounds{color_bar.right + Scale(8), row.top,
                       color_bar.right + Scale(62), row.bottom};
      DrawTextW(dc, event.time_label.c_str(), -1, &time_bounds,
                DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
      SelectObject(dc,
                   event.completed ? body_completed_font : body_font);
      SetTextColor(dc, event.completed ? secondary : text);
      RECT title_bounds{time_bounds.right + Scale(3), row.top,
                        row.right - Scale(8), row.bottom};
      DrawTextW(dc, event.title.c_str(), -1, &title_bounds,
                DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
      cursor_y += row_height;
    }
  }

  const int hidden_today =
      static_cast<int>(snapshot_.today_events.size() - visible_today) +
      snapshot_.today_remaining_count;
  if (hidden_today > 0) {
    SelectObject(dc, caption_font);
    SetTextColor(dc, secondary);
    const std::wstring more = MoreLabel(snapshot_.locale_tag, hidden_today);
    RECT more_bounds{padding, cursor_y, width - padding,
                     cursor_y + Scale(20)};
    DrawTextW(dc, more.c_str(), -1, &more_bounds,
              DT_SINGLELINE | DT_RIGHT | DT_VCENTER);
    cursor_y += Scale(20);
  } else {
    cursor_y += Scale(6);
  }

  if (!snapshot_.ddays.empty() && cursor_y + Scale(62) < height - Scale(8)) {
    SelectObject(dc, section_font);
    SetTextColor(dc, text);
    RECT dday_header{padding, cursor_y, width - padding,
                     cursor_y + Scale(25)};
    DrawTextW(dc, L"D-day", -1, &dday_header,
              DT_SINGLELINE | DT_VCENTER);
    cursor_y += Scale(25);
    const int dday_row_height = Scale(36);
    const int available = std::max(0, height - Scale(10) - cursor_y);
    const std::size_t visible_ddays = std::min<std::size_t>(
        snapshot_.ddays.size(), static_cast<std::size_t>(available / dday_row_height));
    for (std::size_t index = 0; index < visible_ddays; ++index) {
      const auto& dday = snapshot_.ddays[index];
      RECT row{padding, cursor_y, width - padding,
               cursor_y + dday_row_height};
      HBRUSH color_brush = CreateSolidBrush(ColorFromArgb(dday.color));
      HGDIOBJ old_brush = SelectObject(dc, color_brush);
      HPEN color_pen = CreatePen(PS_NULL, 0, ColorFromArgb(dday.color));
      HGDIOBJ old_pen = SelectObject(dc, color_pen);
      Ellipse(dc, row.left + Scale(7), row.top + Scale(14),
              row.left + Scale(14), row.top + Scale(21));
      SelectObject(dc, old_pen);
      SelectObject(dc, old_brush);
      DeleteObject(color_pen);
      DeleteObject(color_brush);

      SelectObject(dc, dday.completed ? body_completed_font : body_font);
      SetTextColor(dc, dday.completed ? secondary : text);
      RECT dday_title{row.left + Scale(23), row.top,
                      row.right - Scale(78), row.top + Scale(21)};
      DrawTextW(dc, dday.title.c_str(), -1, &dday_title,
                DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
      SelectObject(dc, caption_font);
      SetTextColor(dc, secondary);
      RECT date_bounds{row.left + Scale(23), row.top + Scale(18),
                       row.right - Scale(78), row.bottom};
      DrawTextW(dc, dday.date_label.c_str(), -1, &date_bounds,
                DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
      const std::wstring counter =
          dday.days_remaining == 0
              ? L"D-day"
              : (dday.days_remaining > 0
                     ? L"D-" + std::to_wstring(dday.days_remaining)
                     : L"D+" + std::to_wstring(-dday.days_remaining));
      SelectObject(dc, section_font);
      SetTextColor(dc, ColorFromArgb(dday.color));
      RECT counter_bounds{row.right - Scale(74), row.top, row.right,
                          row.bottom};
      DrawTextW(dc, counter.c_str(), -1, &counter_bounds,
                DT_SINGLELINE | DT_RIGHT | DT_VCENTER | DT_END_ELLIPSIS);
      cursor_y += dday_row_height;
    }
  }

  BitBlt(target_dc, 0, 0, width, height, dc, 0, 0, SRCCOPY);
  SelectObject(dc, previous_font);
  SelectObject(dc, previous_bitmap);
  DeleteObject(title_font);
  DeleteObject(section_font);
  DeleteObject(body_font);
  DeleteObject(body_completed_font);
  DeleteObject(caption_font);
  DeleteObject(bitmap);
  DeleteDC(dc);
}

void WindowsWidgetBridge::ApplyWindowTheme() {
  if (popup_ == nullptr) {
    return;
  }
  const BOOL dark = IsDarkMode() ? TRUE : FALSE;
  DwmSetWindowAttribute(popup_, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                        sizeof(dark));
}

void WindowsWidgetBridge::ClosePopup() {
  if (popup_ != nullptr) {
    ShowWindow(popup_, SW_HIDE);
  }
}

bool WindowsWidgetBridge::IsDarkMode() const {
  if (snapshot_.theme_mode == L"dark") {
    return true;
  }
  if (snapshot_.theme_mode == L"light") {
    return false;
  }
  DWORD apps_use_light_theme = 1;
  DWORD value_size = sizeof(apps_use_light_theme);
  RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr,
      &apps_use_light_theme, &value_size);
  return apps_use_light_theme == 0;
}

UINT WindowsWidgetBridge::CurrentDpi() const {
  return popup_ == nullptr ? 96 : GetDpiForWindow(popup_);
}

int WindowsWidgetBridge::Scale(int logical_pixels) const {
  return MulDiv(logical_pixels, CurrentDpi(), 96);
}

void WindowsWidgetBridge::LoadPendingActions() {
  std::ifstream input(std::filesystem::path(ActionsFilePath()),
                      std::ios::binary);
  if (!input) {
    return;
  }
  daily_widgets::ReadActions(input, &pending_actions_);
}

bool WindowsWidgetBridge::SavePendingActions() const {
  const std::filesystem::path target(ActionsFilePath());
  const std::filesystem::path temporary = target.wstring() + L".tmp";
  std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
  if (!output) {
    return false;
  }
  if (!daily_widgets::WriteActions(output, pending_actions_)) {
    output.close();
    DeleteFileW(temporary.c_str());
    return false;
  }
  output.flush();
  const bool succeeded = output.good();
  output.close();
  if (!succeeded) {
    DeleteFileW(temporary.c_str());
    return false;
  }
  if (!MoveFileExW(temporary.c_str(), target.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    DeleteFileW(temporary.c_str());
    return false;
  }
  return true;
}

std::wstring WindowsWidgetBridge::DataDirectory() const {
  const DWORD required = GetEnvironmentVariableW(L"LOCALAPPDATA", nullptr, 0);
  if (required == 0) {
    return L".";
  }
  std::wstring local_app_data(required, L'\0');
  const DWORD copied = GetEnvironmentVariableW(
      L"LOCALAPPDATA", local_app_data.data(), required);
  if (copied == 0 || copied >= required) {
    return L".";
  }
  local_app_data.resize(copied);
  const std::wstring directory =
      local_app_data + L"\\" + daily::app_identity::kWidgetDataDirectoryName;
  CreateDirectoryW(directory.c_str(), nullptr);
  return directory;
}

std::wstring WindowsWidgetBridge::ActionsFilePath() const {
  return DataDirectory() + L"\\windows-widget-todo-actions.bin";
}

WindowsWidgetBridge::Snapshot
WindowsWidgetBridge::BuildCurrentMonthFallback() {
  Snapshot snapshot;
  std::time_t now_time = std::time(nullptr);
  std::tm now{};
  localtime_s(&now, &now_time);
  const int year = now.tm_year + 1900;
  const int month = now.tm_mon + 1;
  std::wstringstream title;
  title << year << L"." << std::setw(2) << std::setfill(L'0') << month;
  snapshot.month_title = title.str();
  snapshot.theme_mode = L"system";
  wchar_t locale_name[LOCALE_NAME_MAX_LENGTH] = {};
  if (GetUserDefaultLocaleName(locale_name, LOCALE_NAME_MAX_LENGTH) != 0) {
    snapshot.locale_tag = locale_name;
  }
  snapshot.today_title = TodayLabel(snapshot.locale_tag);

  std::tm first{};
  first.tm_year = year - 1900;
  first.tm_mon = month - 1;
  first.tm_mday = 1;
  std::mktime(&first);
  const int leading_days = first.tm_wday;
  snapshot.month_days.reserve(42);
  for (int index = 0; index < 42; ++index) {
    std::tm date{};
    date.tm_year = year - 1900;
    date.tm_mon = month - 1;
    date.tm_mday = 1 - leading_days + index;
    date.tm_hour = 12;
    std::mktime(&date);
    MonthDay day;
    day.day = date.tm_mday;
    day.in_month = date.tm_year == now.tm_year && date.tm_mon == now.tm_mon;
    day.is_today = date.tm_year == now.tm_year && date.tm_mon == now.tm_mon &&
                   date.tm_mday == now.tm_mday;
    snapshot.month_days.push_back(std::move(day));
  }
  return snapshot;
}

std::wstring WindowsWidgetBridge::Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int required = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (required <= 0) {
    return {};
  }
  std::wstring converted(required, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), converted.data(),
                          required) != required) {
    return {};
  }
  return converted;
}

std::string WindowsWidgetBridge::NewActionToken() {
  GUID guid{};
  if (FAILED(CoCreateGuid(&guid))) {
    return std::to_string(GetCurrentProcessId()) + "-" +
           std::to_string(GetTickCount64());
  }
  wchar_t buffer[40] = {};
  StringFromGUID2(guid, buffer, static_cast<int>(std::size(buffer)));
  const int required = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, nullptr, 0,
                                           nullptr, nullptr);
  if (required <= 1) {
    return std::to_string(GetTickCount64());
  }
  std::string token(required, '\0');
  WideCharToMultiByte(CP_UTF8, 0, buffer, -1, token.data(), required, nullptr,
                      nullptr);
  token.resize(required - 1);
  return token;
}

LRESULT CALLBACK WindowsWidgetBridge::PopupWindowProc(HWND window,
                                                       UINT message,
                                                       WPARAM wparam,
                                                       LPARAM lparam) {
  WindowsWidgetBridge* bridge = reinterpret_cast<WindowsWidgetBridge*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    bridge = static_cast<WindowsWidgetBridge*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(bridge));
  }
  if (bridge != nullptr) {
    return bridge->HandlePopupMessage(window, message, wparam, lparam);
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

LRESULT WindowsWidgetBridge::HandlePopupMessage(HWND window,
                                                UINT message,
                                                WPARAM wparam,
                                                LPARAM lparam) {
  switch (message) {
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC dc = BeginPaint(window, &paint);
      Paint(dc);
      EndPaint(window, &paint);
      return 0;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_CLOSE:
      ClosePopup();
      return 0;
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        ClosePopup();
      }
      return 0;
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE) {
        ClosePopup();
        return 0;
      }
      if (wparam == VK_RETURN && open_app_) {
        ClosePopup();
        open_app_();
        return 0;
      }
      break;
    case WM_LBUTTONUP: {
      POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (ContainsPoint(open_button_bounds_, point)) {
        ClosePopup();
        if (open_app_) {
          open_app_();
        }
        return 0;
      }
      for (const auto& target : event_hit_targets_) {
        if (ContainsPoint(target.bounds, point)) {
          ToggleEvent(target.event_index);
          return 0;
        }
      }
      break;
    }
    case WM_SETCURSOR: {
      POINT point{};
      GetCursorPos(&point);
      ScreenToClient(window, &point);
      if (ContainsPoint(open_button_bounds_, point) ||
          std::any_of(event_hit_targets_.begin(), event_hit_targets_.end(),
                      [point](const EventHitTarget& target) {
                        return ContainsPoint(target.bounds, point);
                      })) {
        SetCursor(LoadCursor(nullptr, IDC_HAND));
        return TRUE;
      }
      break;
    }
    case WM_DPICHANGED: {
      const auto* suggested = reinterpret_cast<RECT*>(lparam);
      SetWindowPos(window, HWND_TOPMOST, suggested->left, suggested->top,
                   suggested->right - suggested->left,
                   suggested->bottom - suggested->top, SWP_NOACTIVATE);
      InvalidateRect(window, nullptr, FALSE);
      return 0;
    }
    case WM_SETTINGCHANGE:
      ApplyWindowTheme();
      InvalidateRect(window, nullptr, FALSE);
      return 0;
    case WM_NCDESTROY:
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      popup_ = nullptr;
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
