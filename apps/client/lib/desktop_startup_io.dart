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

File get _linuxAgent => File(
  '${Platform.environment['XDG_CONFIG_HOME'] ?? '${Platform.environment['HOME']}/.config'}/autostart/com.yuashie.astracct.desktop',
);

String linuxDesktopExec(String path) {
  if (path.contains('\n') || path.contains('\r'))
    throw ArgumentError('Invalid executable path');
  return '"${path.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll(r'$', r'\$').replaceAll('`', r'\`').replaceAll('%', '%%')}"';
}

Future<bool> startupEnabled() async {
  if (Platform.isLinux) return _linuxAgent.exists();
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
  if (Platform.isLinux) {
    if (enabled) {
      final path = Platform.environment['APPIMAGE'] ?? executable.path;
      await _linuxAgent.parent.create(recursive: true);
      await _linuxAgent.writeAsString(
        '[Desktop Entry]\nType=Application\nName=Astracct\nExec=${linuxDesktopExec(path)}\nTerminal=false\n',
        flush: true,
      );
    } else if (await _linuxAgent.exists()) {
      await _linuxAgent.delete();
    }
    return;
  }
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
