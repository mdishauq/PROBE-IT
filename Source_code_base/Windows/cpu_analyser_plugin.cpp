#include "cpu_analyser_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <thread>
#include <mutex>
#include <atomic>

// Include your engine
#include "cpu_analyser/health_sensor.hpp"

namespace cpu_analyser {

// Global variables for event streaming
std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> g_event_sink;
std::mutex g_event_sink_mutex;
std::atomic<bool> g_polling_active{false};
std::unique_ptr<std::thread> g_polling_thread;

// Printer thread function - continuously reads sensor data
void SensorPollingThread() {
  health_sensor sensor;
  
  while (g_polling_active) {
    // 1. Get fresh system memory/CPU data
    sensor.CPU_AttributesRetriver();
    sensor.getsystemtimes();

    // 2. Calculate metrics
    double ram_usage = sensor.RamUsageLevel();
    double page_file_stress = sensor.PageFileStressLevel();
    double virtual_mem_pressure = sensor.VirtualMemoryPressureLevel();
    double cpu_load = sensor.CpuWorkingLoad();
    double memory_to_swap = sensor.MemoryTOSwapRatio();

    // 3. Get detailed RAM usage
    health_sensor::ResultPackage ram_used{};
    sensor.UsedRamCalculator(&ram_used);

    // 4. Build response map
    flutter::EncodableMap response;
    response[flutter::EncodableValue("ram_usage_percent")] = 
      flutter::EncodableValue(ram_usage);
    response[flutter::EncodableValue("page_file_stress_percent")] = 
      flutter::EncodableValue(page_file_stress);
    response[flutter::EncodableValue("virtual_memory_pressure_percent")] = 
      flutter::EncodableValue(virtual_mem_pressure);
    response[flutter::EncodableValue("cpu_load_percent")] = 
      flutter::EncodableValue(cpu_load);
    response[flutter::EncodableValue("memory_to_swap_ratio")] = 
      flutter::EncodableValue(memory_to_swap);

    // Add RAM details
    flutter::EncodableMap ram_details;
    ram_details[flutter::EncodableValue("value")] = 
      flutter::EncodableValue(ram_used.Value);
    ram_details[flutter::EncodableValue("unit")] = 
      flutter::EncodableValue(static_cast<int32_t>(ram_used.unit));
    response[flutter::EncodableValue("ram_details")] = 
      flutter::EncodableValue(ram_details);

    // 5. Send via event channel (thread-safe)
    {
      std::lock_guard<std::mutex> lock(g_event_sink_mutex);
      if (g_event_sink) {
        g_event_sink->Success(flutter::EncodableValue(response));
      }
    }

    // Sleep for 100ms before next read
    Sleep(100);
  }
}

// static
void CpuAnalyserPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  
  // === METHOD CHANNEL ===
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "cpu_analyser",
          &flutter::StandardMethodCodec::GetInstance());

  // === EVENT CHANNEL ===
  auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "cpu_analyser/sensor_data",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<CpuAnalyserPlugin>();

  // Setup method channel handler
  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Setup event channel listener
  auto event_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      // onListen
      [](const flutter::EncodableValue* arguments,
         std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        std::lock_guard<std::mutex> lock(g_event_sink_mutex);
        g_event_sink = std::move(events);
        return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>();
      },
      // onCancel
      [](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        std::lock_guard<std::mutex> lock(g_event_sink_mutex);
        g_event_sink.reset();
        return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>();
      });

  event_channel->SetStreamHandler(std::move(event_handler));

  registrar->AddPlugin(std::move(plugin));
}

CpuAnalyserPlugin::CpuAnalyserPlugin() {}

CpuAnalyserPlugin::~CpuAnalyserPlugin() {
  // Stop polling if still active
  g_polling_active = false;
  if (g_polling_thread && g_polling_thread->joinable()) {
    g_polling_thread->join();
  }
}

void CpuAnalyserPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } 
  else if (method_call.method_name().compare("analyze") == 0) {
    // One-time analysis call
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("bad_args", "analyze requires a map of parameters");
      return;
    }

    health_sensor sensor;
    sensor.CPU_AttributesRetriver();
    sensor.getsystemtimes();

    flutter::EncodableMap response;
    response[flutter::EncodableValue("status")] = flutter::EncodableValue("ok");
    response[flutter::EncodableValue("ram_usage_percent")] = 
      flutter::EncodableValue(sensor.RamUsageLevel());
    response[flutter::EncodableValue("cpu_load_percent")] = 
      flutter::EncodableValue(sensor.CpuWorkingLoad());

    result->Success(flutter::EncodableValue(response));
  }
  else if (method_call.method_name().compare("startSensorPolling") == 0) {
    // Start the printer thread
    if (g_polling_active) {
      result->Success();
      return;
    }

    g_polling_active = true;
    g_polling_thread = std::make_unique<std::thread>(SensorPollingThread);
    result->Success();
  }
  else if (method_call.method_name().compare("stopSensorPolling") == 0) {
    // Stop the printer thread
    g_polling_active = false;
    if (g_polling_thread && g_polling_thread->joinable()) {
      g_polling_thread->join();
    }
    g_polling_thread.reset();
    result->Success();
  }
  else {
    result->NotImplemented();
  }
}

}  // namespace cpu_analyser
