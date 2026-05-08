#include "flutter_window.h"

#include <mmsystem.h>
#include <optional>
#include <string>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

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

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "outlook_mail_manager/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto window = GetHandle();
        const auto& method = call.method_name();
        if (method == "drag") {
          ReleaseCapture();
          SendMessage(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        } else if (method == "minimize") {
          ShowWindow(window, SW_MINIMIZE);
          result->Success();
        } else if (method == "toggleMaximize") {
          ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
        } else if (method == "close") {
          PostMessage(window, WM_CLOSE, 0, 0);
          result->Success();
        } else if (method == "playSoundFile") {
          const auto* path = std::get_if<std::string>(call.arguments());
          if (path == nullptr || path->empty()) {
            result->Error("bad_args", "Missing sound file path.");
            return;
          }
          const int wide_size = MultiByteToWideChar(
              CP_UTF8, 0, path->c_str(), -1, nullptr, 0);
          if (wide_size <= 0) {
            result->Error("bad_path", "Could not decode the sound file path.");
            return;
          }
          std::wstring wide_path(wide_size, L'\0');
          MultiByteToWideChar(
              CP_UTF8, 0, path->c_str(), -1, wide_path.data(), wide_size);
          const BOOL played = PlaySoundW(
              wide_path.c_str(), nullptr, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
          if (!played) {
            result->Error("play_failed", "Could not play the sound file.");
            return;
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
