// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'dart:async';
import 'cpu_analyser_platform_interface.dart';

class CpuAnalyser {
  Future<String?> getPlatformVersion() {
    return CpuAnalyserPlatform.instance.getPlatformVersion();
  }

  Future<Map<String, dynamic>?> analyze(Map<String, dynamic> params) {
    return CpuAnalyserPlatform.instance.analyze(params);
  }

  /// Stream of continuous sensor data.
  Stream<Map<String, dynamic>> get sensorDataStream =>
      CpuAnalyserPlatform.instance.sensorDataStream;

  /// Start sensor polling (printer threads).
  Future<void> startSensorPolling() =>
      CpuAnalyserPlatform.instance.startSensorPolling();

  /// Stop sensor polling.
  Future<void> stopSensorPolling() =>
      CpuAnalyserPlatform.instance.stopSensorPolling();
}
