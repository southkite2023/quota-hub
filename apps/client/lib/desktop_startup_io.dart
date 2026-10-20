import 'dart:io';

const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
File get _agent => File(
  '${Platform.environment['HOME']}/Library/LaunchAgents/com.yuashie.astracct.autostart.plist',
);
String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

Future<bool> startupEnabled() async {
  if (Platform.isMacOS) return _agent.exists();
  if (Platform.isWindows) {
    final result = await Process.run('reg.exe', [
      'query',
      _runKey,
      '/v',
      'Astracct',
    ], stdoutEncoding: systemEncoding);
    return result.exitCode == 0;
  }
  return false;
}

Future<void> configureStartup(bool enabled) async {
  final executable = File(Platform.resolvedExecutable).absolute;
  if (Platform.isMacOS) {
    if (enabled) {
      final bundle = executable.parent.parent.parent.path;
      if (!bundle.endsWith('.app'))
        throw StateError('Install the application bundle first');
      await _agent.parent.create(recursive: true);
      await _agent.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.yuashie.astracct.autostart</string>
<key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>${_xml(bundle)}</string></array>
<key>RunAtLoad</key><true/></dict></plist>''', flush: true);
    } else if (await _agent.exists()) {
      await _agent.delete();
    }
    return;
  }
  if (Platform.isWindows) {
    final result = await Process.run(
      'reg.exe',
      enabled
          ? [
              'add',
              _runKey,
              '/v',
              'Astracct',
              '/t',
              'REG_SZ',
              '/d',
              '"${executable.path}"',
              '/f',
            ]
          : ['delete', _runKey, '/v', 'Astracct', '/f'],
    );
    if (result.exitCode != 0 && (enabled || await startupEnabled())) {
      throw StateError('System rejected startup change');
    }
    return;
  }
  throw UnsupportedError('desktop only');
}
