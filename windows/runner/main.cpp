#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

static bool WriteImportMailbox(const std::wstring &url) {
  wchar_t appdata[MAX_PATH];
  DWORD n = ::GetEnvironmentVariableW(L"LOCALAPPDATA", appdata, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return false;
  }
  std::wstring dir = std::wstring(appdata) + L"\\way";
  if (!::CreateDirectoryW(dir.c_str(), nullptr) &&
      ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return false;
  }
  std::wstring path = dir + L"\\import.url";
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  int size = ::WideCharToMultiByte(CP_UTF8, 0, url.c_str(),
                                   static_cast<int>(url.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string bytes(size, 0);
  ::WideCharToMultiByte(CP_UTF8, 0, url.c_str(), static_cast<int>(url.size()),
                        bytes.data(), size, nullptr, nullptr);
  DWORD written = 0;
  ::WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()), &written,
              nullptr);
  ::CloseHandle(file);
  return true;
}

static bool ForwardDeepLinkToRunningInstance() {
  int argc = 0;
  LPWSTR *argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (!argv) {
    return false;
  }
  bool ok = false;
  for (int i = 0; i < argc; ++i) {
    std::wstring arg = argv[i];
    if (arg.find(L"://") != std::wstring::npos) {
      ok = WriteImportMailbox(arg);
      break;
    }
  }
  ::LocalFree(argv);
  return ok;
}

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

  HANDLE single = ::CreateMutexW(nullptr, TRUE, L"Local\\WaySingleInstance");
  if (single && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ForwardDeepLinkToRunningInstance();
    ::CloseHandle(single);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"way", origin, size)) {
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
