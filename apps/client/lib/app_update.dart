import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const updateManifestUrl = 'https://yuashie.cn/downloads/astracct/latest.json';

class AppRelease {
  AppRelease.fromJson(Map<String, dynamic> json)
    : platform = json['platform'] as String,
      architecture = json['architecture'] as String,
      version = json['version'] as String,
      url = Uri.parse(json['url'] as String),
      bytes = json['bytes'] as int,
      checksum = json['sha256'] as String,
      notes = json['notes'] as String? ?? '' {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum) ||
        bytes <= 0 ||
        bytes > 512 * 1024 * 1024 ||
        url.origin != 'https://yuashie.cn' ||
        url.hasQuery ||
        url.hasFragment ||
        !RegExp(
          r'^/downloads/astracct/v\d+\.\d+\.\d+/[a-zA-Z0-9._-]+\.(apk|zip)$',
        ).hasMatch(url.path) ||
        !url.path.startsWith('/downloads/astracct/v$version/')) {
      throw const FormatException('更新清单无效');
    }
  }
  final String platform, architecture, version, checksum, notes;
  final Uri url;
  final int bytes;
}

int compareAppVersions(String left, String right) {
  List<int> parts(String value) =>
      value.split('+').first.split('.').map(int.parse).toList();
  final a = parts(left), b = parts(right);
  if (a.length != 3 || b.length != 3) throw const FormatException('版本号无效');
  for (var index = 0; index < 3; index++) {
    final comparison = a[index].compareTo(b[index]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

String? get updatePlatform => kIsWeb
    ? null
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.windows => 'windows',
        TargetPlatform.macOS => 'macos',
        _ => null,
      };

Future<AppRelease?> findAppUpdate(
  String installedVersion, {
  http.Client? client,
  String? platform,
}) async {
  final owned = client == null;
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .get(
          Uri.parse(updateManifestUrl),
          headers: {'Cache-Control': 'no-cache'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 256 * 1024)
      throw const FormatException('暂时无法获取更新');
    final manifest =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (manifest['schema'] != 1) throw const FormatException('不支持的更新清单');
    final target = platform ?? updatePlatform;
    final releases = (manifest['packages'] as List)
        .map((item) => AppRelease.fromJson(item as Map<String, dynamic>))
        .where(
          (item) =>
              item.platform == target &&
              (target != 'android' || item.architecture == 'universal'),
        )
        .toList();
    releases.sort((a, b) => compareAppVersions(b.version, a.version));
    if (releases.isEmpty) throw const FormatException('此平台暂未提供安装包');
    return compareAppVersions(releases.first.version, installedVersion) > 0
        ? releases.first
        : null;
  } finally {
    if (owned) transport.close();
  }
}
