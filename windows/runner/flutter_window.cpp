#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

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
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "freekmusic/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "takeFiles") {
          flutter::EncodableList list;
          for (const std::string& path : pending_files_) {
            list.push_back(flutter::EncodableValue(path));
          }
          pending_files_.clear();
          result->Success(flutter::EncodableValue(list));
        } else if (call.method_name() == "setTitle") {
          const auto* title = std::get_if<std::string>(call.arguments());
          if (title) {
            int len = ::MultiByteToWideChar(CP_UTF8, 0, title->c_str(), -1,
                                            nullptr, 0);
            if (len > 0) {
              std::wstring wide(len, L'\0');
              ::MultiByteToWideChar(CP_UTF8, 0, title->c_str(), -1, &wide[0],
                                    len);
              ::SetWindowText(GetHandle(), wide.c_str());
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Marks that the window has been shown once (read by a second launch, main.cpp).
    ::SetProp(GetHandle(), L"FreeKmusicShown", reinterpret_cast<HANDLE>(1));
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  channel_ = nullptr;
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
    case WM_COPYDATA: {
      // Files of a second launch (see main.cpp), one path per line.
      const auto* data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (data && data->dwData == 0x464B4D31 && data->lpData && channel_) {
        std::string joined(static_cast<const char*>(data->lpData),
                           data->cbData);
        size_t start = 0;
        while (start < joined.size()) {
          size_t end = joined.find('\n', start);
          if (end == std::string::npos) end = joined.size();
          if (end > start) pending_files_.push_back(joined.substr(start, end - start));
          start = end + 1;
        }
        channel_->InvokeMethod("opened", nullptr);
        return TRUE;
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
