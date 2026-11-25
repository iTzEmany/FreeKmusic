#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <string>

namespace {
// Tag of the WM_COPYDATA that carries the files of a second launch.
constexpr ULONG_PTR kOpenFilesMagic = 0x464B4D31;  // "FKM1"
constexpr wchar_t kWindowClassName[] = L"FREEKMUSIC_RUNNER_WIN32_WINDOW";

// Hands the arguments (UTF-8, one per line) to the window of the first
// instance and brings it forward. Returns false when no window is found.
bool ForwardToRunningInstance() {
  HWND hwnd = ::FindWindow(kWindowClassName, nullptr);
  if (!hwnd) {
    return false;
  }
  std::string joined;
  for (const std::string& arg : GetCommandLineArguments()) {
    joined += arg;
    joined += '\n';
  }
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }
  ::SetForegroundWindow(hwnd);
  if (!joined.empty()) {
    COPYDATASTRUCT data;
    data.dwData = kOpenFilesMagic;
    data.cbData = static_cast<DWORD>(joined.size());
    data.lpData = const_cast<char*>(joined.data());
    DWORD_PTR ignored = 0;
    ::SendMessageTimeout(hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data),
                         SMTO_ABORTIFHUNG, 2000, &ignored);
  }
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One window per user: a second launch forwards its files to the first.
  // FREEKMUSIC_NON_UNIQUE=1 opts out (tests, `flutter run` beside the app).
  wchar_t opt_out[2] = {};
  bool unique = !(::GetEnvironmentVariable(L"FREEKMUSIC_NON_UNIQUE", opt_out,
                                           2) == 1 &&
                  opt_out[0] == L'1');
  if (unique) {
    ::CreateMutex(nullptr, TRUE, L"Local\\FreeKmusic.SingleInstance");
    if (::GetLastError() == ERROR_ALREADY_EXISTS &&
        ForwardToRunningInstance()) {
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"FreeKmusic", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
