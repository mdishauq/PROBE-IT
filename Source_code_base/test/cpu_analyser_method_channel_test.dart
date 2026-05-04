import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_analyser/cpu_analyser_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCpuAnalyser platform = MethodChannelCpuAnalyser();
  const MethodChannel channel = MethodChannel('cpu_analyser');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
