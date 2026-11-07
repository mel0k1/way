#include "generated_plugin_registrant.h"

#include <dynamic_color/dynamic_color_plugin.h>
#include <file_selector_linux/file_selector_plugin.h>
#include <flutter_secure_storage_linux/flutter_secure_storage_linux_plugin.h>
#include <path_provider_linux/path_provider_linux_plugin.h>
#include <shared_preferences_linux/shared_preferences_linux_plugin.h>
#include <system_tray/system_tray_plugin.h>

void RegisterPlugins(fl::PluginRegistry* registry) {
  DynamicColorPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DynamicColorPlugin"));
  FileSelectorPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorPlugin"));
  FlutterSecureStorageLinuxPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSecureStorageLinuxPlugin"));
  PathProviderLinuxRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PathProviderLinuxPlugin"));
  SharedPreferencesLinuxRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SharedPreferencesLinuxPlugin"));
  SystemTrayPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SystemTrayPlugin"));
}
