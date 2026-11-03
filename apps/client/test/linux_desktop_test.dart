import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quota_hub/desktop_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/desktop_platform.dart';
import 'package:quota_hub/desktop_startup_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Linux close keeps taskbar access even when a tray was created', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final calls = <String>[];
    const channel = MethodChannel('window_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async { calls.add(call.method); return null; });
    addTearDown(() { debugDefaultTargetPlatformOverride = null; TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null); });
    DesktopRuntime.instance.trayReady = true;
    await DesktopRuntime.instance.minimizeToTray();
    expect(calls, ['minimize']);
    DesktopRuntime.instance.trayReady = false;
  });
  test('Linux uses desktop layout and window lifecycle', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(isDesktopClient, isTrue);
  });
  test('autostart quotes paths and escapes desktop field codes', () {
    expect(linuxDesktopExec('/opt/My App/100%.AppImage'), '"/opt/My App/100%%.AppImage"');
    expect(() => linuxDesktopExec('/tmp/a\nExec=bad'), throwsArgumentError);
    expect(linuxDesktopExec(r'/tmp/a$`"'), r'"/tmp/a\$\`\""');
  });
}
