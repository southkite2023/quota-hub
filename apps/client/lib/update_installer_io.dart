import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'app_update.dart';

const _channel = MethodChannel('astracct/update');

Future<String> downloadUpdate(
  AppRelease release,
  void Function(double) progress,
) async {
  final temporary = await getTemporaryDirectory();
  final directory = await Directory(
    '${temporary.path}/astracct-updates',
  ).create(recursive: true);
  final file = File('${directory.path}/${release.url.pathSegments.last}');
  final partial = File('${file.path}.part');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  IOSink? output;
  try {
    final request = await client
        .getUrl(release.url)
        .timeout(const Duration(seconds: 20));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200)
      throw const FormatException('下载服务器暂时不可用，请稍后重试');
    if (response.contentLength >= 0 && response.contentLength != release.bytes)
      throw const FormatException('安装包大小不匹配');
    output = partial.openWrite();
    var received = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 45))) {
      received += chunk.length;
      if (received > release.bytes) throw const FormatException('安装包超出预期大小');
      output.add(chunk);
      progress(received / release.bytes);
    }
    await output.close();
    output = null;
    if (received != release.bytes ||
        (await sha256.bind(partial.openRead()).first).toString() !=
            release.checksum) {
      throw const FormatException('安装包校验失败，请重新下载');
    }
    await partial.rename(file.path);
    return file.path;
  } finally {
    await output?.close();
    client.close(force: true);
    if (await partial.exists()) await partial.delete();
  }
}

Future<void> installUpdate(String path, AppRelease release) async {
  // Verify again immediately before handing the file to the installer.
  final file = File(path);
  if (await file.length() != release.bytes ||
      (await sha256.bind(file.openRead()).first).toString() !=
          release.checksum) {
    throw const FormatException('安装包已改变，请重新下载');
  }
  if (Platform.isAndroid) {
    await _channel.invokeMethod<void>('install', {
      'path': path,
      'sha256': release.checksum,
    });
    return;
  }
  if (!Platform.isMacOS && !Platform.isWindows)
    throw UnsupportedError('此平台暂不支持安装');
  final temporary = await Directory.systemTemp.createTemp('astracct-install-');
  final isMac = Platform.isMacOS;
  final script = File(
    '${temporary.path}/${isMac ? 'install.sh' : 'install.ps1'}',
  );
  await script.writeAsString(
    await rootBundle.loadString(
      'assets/updater/${isMac ? 'install.sh' : 'install.ps1'}',
    ),
  );
  final executable = File(Platform.resolvedExecutable).absolute;
  final target = isMac
      ? executable.parent.parent.parent.path
      : executable.parent.path;
  // Helpers validate the bundle, wait for this PID, back up the existing app, then replace and restart.
  final process = await Process.start(isMac ? '/bin/sh' : 'powershell.exe', [
    if (!isMac) ...['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File'],
    script.path,
    path,
    target,
    '$pid',
    release.version,
  ], mode: ProcessStartMode.detachedWithStdio);
  final ready = await process.stdout
      .transform(const SystemEncoding().decoder)
      .first
      .timeout(const Duration(seconds: 60));
  if (!ready.startsWith('READY'))
    throw const FormatException('无法准备安装，请确认应用目录可写，或通过网页下载后安装');
  exit(0);
}
