#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

class WindowsWidgetBridge;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void AddTrayIcon();
  // True when the tray icon exists now: confirms an icon believed present,
  // otherwise adds it (or adopts one that is already there).
  bool EnsureTrayIcon();
  void FillTrayIconData();
  // The icon could not be restored: keep a taskbar button and retry a few times.
  void BeginTrayRecovery();
  void RemoveTrayIcon();
  void RestoreFromTray();
  void ShowTrayMenu();
  void ShowMiniCalendar();
  void ExitFromTray();
  void RegisterMapLauncherChannel();
  void OpenMapChooser(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      map_launcher_channel_;
  std::unique_ptr<WindowsWidgetBridge> windows_widget_bridge_;

  NOTIFYICONDATA notify_icon_data_ = {};
  bool tray_icon_added_ = false;
  // Broadcast by Explorer when the taskbar is (re)created; it drops our icon.
  UINT taskbar_created_message_ = 0;
  int tray_retry_attempts_ = 0;
  bool exit_requested_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
