#ifndef CPU_ANALYSER_WINDOWS_CPU_ANALYSER_PLUGIN_FORWARDER_H_
#define CPU_ANALYSER_WINDOWS_CPU_ANALYSER_PLUGIN_FORWARDER_H_

#include "cpu_analyser_plugin_c_api.h"

inline void CpuAnalyserPluginRegisterWithRegistrar(
		FlutterDesktopPluginRegistrarRef registrar) {
	CpuAnalyserPluginCApiRegisterWithRegistrar(registrar);
}

#endif  // CPU_ANALYSER_WINDOWS_CPU_ANALYSER_PLUGIN_FORWARDER_H_
