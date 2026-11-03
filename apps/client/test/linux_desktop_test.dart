import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/desktop_platform.dart';
import 'package:quota_hub/desktop_startup_io.dart';

void main() {
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
