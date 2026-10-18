#include "flutter_window.h"

#include <commctrl.h>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>
#include "app_identity.h"
#include "resource.h"
#include "windows_widget_bridge.h"

namespace {

constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayIconMessage = WM_APP + 1;
constexpr UINT kTrayOpenCommand = 40001;
constexpr UINT kTrayExitCommand = 40002;
constexpr UINT kTrayMiniCalendarCommand = 40003;

using TaskDialogIndirectFn = HRESULT(WINAPI*)(
    const TASKDIALOGCONFIG*, int*, int*, BOOL*);

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterMapLauncherChannel();
  windows_widget_bridge_ = std::make_unique<WindowsWidgetBridge>(
      flutter_controller_->engine()->messenger(), GetHandle(),
      [this]() { RestoreFromTray(); });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
  AddTrayIcon();

  return true;
}

void FlutterWindow::RegisterMapLauncherChannel() {
  map_launcher_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "daily/map_launcher",
          &flutter::StandardMethodCodec::GetInstance());
  map_launcher_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "openLocation") {
          result->NotImplemented();
          return;
        }
        OpenMapChooser(call, std::move(result));
      });
}

void FlutterWindow::OpenMapChooser(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }
  const auto iterator = arguments->find(flutter::EncodableValue("location"));
  if (iterator == arguments->end() ||
      !std::holds_alternative<std::string>(iterator->second)) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }
  const auto& location = std::get<std::string>(iterator->second);
  if (location.empty()) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }

  TASKDIALOG_BUTTON buttons[] = {
      {1001, L"카카오맵"},
      {1002, L"네이버지도"},
      {IDCANCEL, L"취소"},
  };
  TASKDIALOGCONFIG config = {};
  config.cbSize = sizeof(config);
  config.hwndParent = GetHandle();
  config.dwFlags = TDF_ALLOW_DIALOG_CANCELLATION;
  config.pszWindowTitle = daily::app_identity::kDisplayName;
  config.pszMainInstruction = L"지도에서 열기";
  config.pszContent = L"선택한 지도 서비스의 웹사이트가 기본 브라우저에서 열립니다.";
  config.cButtons = ARRAYSIZE(buttons);
  config.pButtons = buttons;
  config.nDefaultButton = IDCANCEL;

  int selected = IDCANCEL;
  // TaskDialogIndirect is only exported by Common Controls v6. Resolve it at
  // runtime so an installation with the legacy control library can still open
  // the application and use the map chooser fallback.
  HMODULE common_controls = LoadLibraryW(L"comctl32.dll");
  const auto task_dialog = common_controls == nullptr
      ? nullptr
      : reinterpret_cast<TaskDialogIndirectFn>(
            GetProcAddress(common_controls, "TaskDialogIndirect"));
  if (task_dialog != nullptr) {
    task_dialog(&config, &selected, nullptr, nullptr);
  } else {
    const int fallback = MessageBoxW(
        GetHandle(),
        L"Yes: Kakao Map\nNo: Naver Map\nCancel: Close",
        daily::app_identity::kDisplayName,
        MB_YESNOCANCEL | MB_ICONQUESTION);
    selected = fallback == IDYES ? 1001 : fallback == IDNO ? 1002 : IDCANCEL;
  }
  if (common_controls != nullptr) {
    FreeLibrary(common_controls);
  }
  switch (selected) {
    case 1001:
      result->Success(flutter::EncodableValue("kakao"));
      break;
    case 1002:
      result->Success(flutter::EncodableValue("naver"));
      break;
    default:
      result->Success(flutter::EncodableValue("handled"));
      break;
  }
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  windows_widget_bridge_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    // Explorer restarted: the shell forgot the icon, so add it again.
    tray_icon_added_ = false;
    AddTrayIcon();
    return 0;
  }
  switch (message) {
    case WM_CLOSE:
      if (!exit_requested_) {
        if (!tray_icon_added_) {
          AddTrayIcon();
        }
        if (tray_icon_added_) {
          ShowWindow(hwnd, SW_HIDE);
        } else {
          // Nothing in the tray to restore from: keep a taskbar button instead
          // of hiding the only way back to the window.
          ShowWindow(hwnd, SW_MINIMIZE);
        }
        return 0;
      }
      break;
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kTrayOpenCommand:
          RestoreFromTray();
          return 0;
        case kTrayMiniCalendarCommand:
          ShowMiniCalendar();
          return 0;
        case kTrayExitCommand:
          ExitFromTray();
          return 0;
      }
      break;
    case kTrayIconMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
        case NIN_SELECT:
        case NIN_KEYSELECT:
          RestoreFromTray();
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
      }
      break;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::AddTrayIcon() {
  if (tray_icon_added_) {
    return;
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  notify_icon_data_ = {};
  notify_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
  notify_icon_data_.hWnd = hwnd;
  notify_icon_data_.uID = kTrayIconId;
  notify_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  notify_icon_data_.uCallbackMessage = kTrayIconMessage;
  notify_icon_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(notify_icon_data_.szTip, daily::app_identity::kDisplayName);

  tray_icon_added_ = Shell_NotifyIcon(NIM_ADD, &notify_icon_data_) == TRUE;
  if (tray_icon_added_) {
    notify_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &notify_icon_data_);
  }
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &notify_icon_data_);
  tray_icon_added_ = false;
}

void FlutterWindow::RestoreFromTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  ShowWindow(hwnd, SW_SHOW);
  ShowWindow(hwnd, SW_RESTORE);
  SetForegroundWindow(hwnd);
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  AppendMenu(menu, MF_STRING, kTrayOpenCommand,
             daily::app_identity::kOpenTrayLabel);
  AppendMenu(menu, MF_STRING, kTrayMiniCalendarCommand, L"Mini Calendar");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayExitCommand, L"Exit");

  POINT cursor_position;
  GetCursorPos(&cursor_position);
  SetForegroundWindow(hwnd);
  TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON,
                 cursor_position.x, cursor_position.y, 0, hwnd, nullptr);
  DestroyMenu(menu);
}

void FlutterWindow::ExitFromTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    PostQuitMessage(0);
    return;
  }

  exit_requested_ = true;
  RemoveTrayIcon();
  DestroyWindow(hwnd);
}

void FlutterWindow::ShowMiniCalendar() {
  if (windows_widget_bridge_) {
    windows_widget_bridge_->ShowMiniCalendar();
  }
}
