#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
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

  const POINT target_point = {0, 0};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitor_info);
  const RECT work_area = monitor_info.rcWork;
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;

  const int work_width =
      static_cast<int>((work_area.right - work_area.left) / scale_factor);
  const int work_height =
      static_cast<int>((work_area.bottom - work_area.top) / scale_factor);
  constexpr int kMaxClientWidth = 1920;
  constexpr int kMinClientWidth = 640;
  constexpr int kWindowPadding = 80;
  constexpr double kStageAspect = 16.0 / 9.0;

  const int available_width = std::max(1, work_width - kWindowPadding);
  const int available_height = std::max(1, work_height - kWindowPadding);
  int client_width = std::min(kMaxClientWidth, available_width);
  int client_height = static_cast<int>(client_width / kStageAspect);
  if (client_height > available_height) {
    client_height = available_height;
    client_width = static_cast<int>(client_height * kStageAspect);
  }
  if (available_width >= kMinClientWidth &&
      available_height >= static_cast<int>(kMinClientWidth / kStageAspect)) {
    client_width = std::max(kMinClientWidth, client_width);
    client_height = static_cast<int>(client_width / kStageAspect);
  }

  FlutterWindow window(project);
  Win32Window::Point origin(
      static_cast<int>(work_area.left / scale_factor) +
          (work_width - client_width) / 2,
      static_cast<int>(work_area.top / scale_factor) +
          (work_height - client_height) / 2);
  Win32Window::Size size(client_width, client_height);
  if (!window.Create(L"Cannon Mile", origin, size)) {
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
