import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/yuashie_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
  const person = {
    'id': 7,
    'username': 'native_smoke',
    'displayName': 'Synthetic',
  };
  final stored = <String, String>{};
  final calls = <MethodCall>[];
  bool failWrites = false;
  http.Client client() => MockClient(
    (request) async => http.Response(
      jsonEncode(
        request.url.path.endsWith('/config')
            ? {'captchaRequired': false}
            : request.url.path.endsWith('/logout')
            ? {'ok': true}
            : {'token': token, 'user': person},
      ),
      200,
      headers: {'content-type': 'application/json'},
    ),
  );
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    stored.clear();
    calls.clear();
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final options = Map<Object?, Object?>.from(args['options'] as Map);
          // A non-provisioned macOS distribution cannot write to the protected keychain.
          if (options['usesDataProtectionKeychain'] != 'false' || failWrites) {
            throw PlatformException(
              code: '-34018',
              message: 'Missing keychain entitlement',
            );
          }
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              return stored[key];
            case 'write':
              stored[key] = args['value'] as String;
              return null;
            case 'delete':
              stored.remove(key);
              return null;
            default:
              throw StateError('Unexpected vault method');
          }
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'distributed macOS login persists, restores and removes the same secure session',
    () async {
      final first = YuashieAccount(
        client: client(),
        storage: YuashieAccount.sessionStorage,
      );
      await first.initialize();
      expect(
        await first.login('synthetic@example.test', 'synthetic-password'),
        true,
      );
      expect(first.user?['id'], 7);
      final restored = YuashieAccount(
        client: client(),
        storage: YuashieAccount.sessionStorage,
      );
      await restored.initialize();
      expect(restored.user?['id'], 7);
      await restored.logout();
      expect(stored, isEmpty);
      expect(
        calls.map((c) => c.method),
        containsAll(['read', 'write', 'delete']),
      );
      final services = calls
          .map(
            (call) =>
                ((call.arguments as Map)['options'] as Map)['accountName'],
          )
          .toSet();
      expect(services, {'com.yuashie.astracct.identity'});
      first.dispose();
      restored.dispose();
    },
  );
  test('a vault write failure never accepts a memory-only login', () async {
    final account = YuashieAccount(
      client: client(),
      storage: YuashieAccount.sessionStorage,
    );
    await account.initialize();
    failWrites = true;
    expect(
      await account.login('synthetic@example.test', 'synthetic-password'),
      false,
    );
    expect(account.user, isNull);
    expect(stored, isEmpty);
    expect(account.error, contains('安全保存'));
    account.dispose();
  });
}
