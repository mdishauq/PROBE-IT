import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_analyser/cpu_analyser.dart';
import 'package:cpu_analyser/cpu_analyser_platform_interface.dart';
import 'package:cpu_analyser/cpu_analyser_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCpuAnalyserPlatform
    with MockPlatformInterfaceMixin
    implements CpuAnalyserPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CpuAnalyserPlatform initialPlatform = CpuAnalyserPlatform.instance;

  test('$MethodChannelCpuAnalyser is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCpuAnalyser>());
  });

  test('getPlatformVersion', () async {
    CpuAnalyser cpuAnalyserPlugin = CpuAnalyser();
    MockCpuAnalyserPlatform fakePlatform = MockCpuAnalyserPlatform();
    CpuAnalyserPlatform.instance = fakePlatform;

    expect(await cpuAnalyserPlugin.getPlatformVersion(), '42');
  });
}
