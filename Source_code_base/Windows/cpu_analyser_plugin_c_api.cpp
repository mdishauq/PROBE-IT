#include "include/cpu_analyser/cpu_analyser_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "cpu_analyser_plugin.h"

void CpuAnalyserPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  cpu_analyser::CpuAnalyserPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
