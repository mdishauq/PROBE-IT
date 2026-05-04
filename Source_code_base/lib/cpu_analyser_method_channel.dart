import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'cpu_analyser_platform_interface.dart';

/// An implementation of [CpuAnalyserPlatform] that uses method channels.
class MethodChannelCpuAnalyser extends CpuAnalyserPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('cpu_analyser');

  /// The event channel for streaming sensor data.
  @visibleForTesting
  final eventChannel = const EventChannel('cpu_analyser/sensor_data');

  late Stream<Map<String, dynamic>> _sensorDataStream;

  MethodChannelCpuAnalyser() {
    _sensorDataStream = eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return {};
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  /// Call native engine via method channel.
  @override
  Future<Map<String, dynamic>?> analyze(Map<String, dynamic> params) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'analyze',
      params,
    );
    if (result == null) return null;
    // Normalize types to `Map<String, dynamic>`.
    return Map<String, dynamic>.from(result.map((k, v) => MapEntry(k.toString(), v)));
  }

  /// Get the sensor data stream.
  @override
  Stream<Map<String, dynamic>> get sensorDataStream => _sensorDataStream;

  /// Start polling sensors.
  @override
  Future<void> startSensorPolling() async {
    await methodChannel.invokeMethod<void>('startSensorPolling');
  }

  /// Stop polling sensors.
  @override
  Future<void> stopSensorPolling() async {
    await methodChannel.invokeMethod<void>('stopSensorPolling');
  }
}
