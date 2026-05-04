import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:async';

import 'cpu_analyser_method_channel.dart';

abstract class CpuAnalyserPlatform extends PlatformInterface {
  /// Constructs a CpuAnalyserPlatform.
  CpuAnalyserPlatform() : super(token: _token);

  static final Object _token = Object();

  static CpuAnalyserPlatform _instance = MethodChannelCpuAnalyser();

  /// The default instance of [CpuAnalyserPlatform] to use.
  ///
  /// Defaults to [MethodChannelCpuAnalyser].
  static CpuAnalyserPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CpuAnalyserPlatform] when
  /// they register themselves.
  static set instance(CpuAnalyserPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Analyze using the native engine. Implementations should accept a
  /// parameter map and return a (possibly nested) result map, or null on
  /// failure.
  Future<Map<String, dynamic>?> analyze(Map<String, dynamic> params) {
    throw UnimplementedError('analyze() has not been implemented.');
  }

  /// Stream of continuous sensor data from the engine.
  /// Emits Map<String, dynamic> with sensor readings (RAM, CPU, etc.)
  Stream<Map<String, dynamic>> get sensorDataStream {
    throw UnimplementedError('sensorDataStream has not been implemented.');
  }

  /// Start the sensor polling (printer threads).
  Future<void> startSensorPolling() {
    throw UnimplementedError('startSensorPolling() has not been implemented.');
  }

  /// Stop the sensor polling.
  Future<void> stopSensorPolling() {
    throw UnimplementedError('stopSensorPolling() has not been implemented.');
  }
}
