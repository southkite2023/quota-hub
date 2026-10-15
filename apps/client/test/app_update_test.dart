import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/app_update.dart';

Map<String, dynamic> asset(
  String platform,
  String version, {
  String? architecture,
}) => {
  'platform': platform,
  'architecture':
      architecture ??
      (platform == 'android' ? 'universal' : '$platform-universal'),
  'version': version,
  'url':
      'https://yuashie.cn/downloads/astracct/v$version/astracct-$version-${platform == 'android' ? 'android.apk' : '$platform-universal.zip'}',
  'bytes': 10,
  'sha256': 'a' * 64,
  'notes': '测试版',
};
void main() {
  test('numeric versions do not downgrade or compare lexicographically', () {
    expect(compareAppVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareAppVersions('1.3.0+17', '1.3.0'), 0);
    expect(compareAppVersions('0.10.0', '1.0.0'), lessThan(0));
  });
  test(
    'each platform receives its own latest release; Android uses universal APK',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), updateManifestUrl);
        expect(request.headers['Cache-Control'], 'no-cache');
        return http.Response(
          jsonEncode({
            'schema': 1,
            'packages': [
              asset('android', '1.3.0'),
              asset('macos', '1.1.0'),
              asset('windows', '0.10.0'),
              asset('android', '1.4.0', architecture: 'x86_64'),
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      expect(
        (await findAppUpdate(
          '1.0.0',
          client: client,
          platform: 'android',
        ))!.version,
        '1.3.0',
      );
      expect(
        await findAppUpdate('1.2.0', client: client, platform: 'macos'),
        isNull,
      );
      expect(
        await findAppUpdate('0.10.0', client: client, platform: 'windows'),
        isNull,
      );
    },
  );
  test('rejects untrusted, mismatched and malformed package metadata', () {
    for (final change in [
      {'url': 'https://evil.example/app.apk'},
      {'url': 'https://yuashie.cn/downloads/astracct/v1.0.0/evil.apk'},
      {'sha256': 'bad'},
      {'bytes': -1},
      {'bytes': 600 * 1024 * 1024},
      {'version': 'latest'},
      {'url': '${asset('android', '1.3.0')['url']}?token=private'},
    ]) {
      expect(
        () => AppRelease.fromJson({...asset('android', '1.3.0'), ...change}),
        throwsFormatException,
      );
    }
  });
  test(
    'missing platform and server errors are not reported as up to date',
    () async {
      final missing = MockClient(
        (_) async => http.Response('{"schema":1,"packages":[]}', 200),
      );
      await expectLater(
        findAppUpdate('1.0.0', client: missing, platform: 'android'),
        throwsFormatException,
      );
      final unavailable = MockClient(
        (_) async => http.Response('maintenance', 503),
      );
      await expectLater(
        findAppUpdate('1.0.0', client: unavailable, platform: 'android'),
        throwsFormatException,
      );
    },
  );
}
