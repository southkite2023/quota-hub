import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/yuashie_account.dart';
import 'package:quota_hub/yuashie_login.dart';

const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
const person = {
  'id': 7,
  'username': 'website_user',
  'displayName': 'Website user',
};
const config = {
  'captcha': null,
  'captchaRequired': false,
  'providers': [
    {'id': 'github', 'enabled': false},
  ],
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'website credentials create a native session; only the session is persisted',
    () async {
      final requests = <http.Request>[];
      final account = YuashieAccount(
        storage: const FlutterSecureStorage(),
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/config')) return json(config);
          if (r.url.path.endsWith('/native/login'))
            return json({'user': person, 'token': token});
          if (r.url.path.endsWith('/logout')) return json({'ok': true});
          return json({'message': 'Unexpected'}, 404);
        }),
      );
      await account.initialize();
      expect(
        await account.login('website@example.test', 'private-password'),
        true,
      );
      expect(account.user!['id'], 7);
      final saved = await const FlutterSecureStorage().readAll();
      expect(saved.values, [token]);
      expect(jsonEncode(saved), isNot(contains('private-password')));
      expect(requests.last.headers['Origin'], YuashieAccount.origin);
      await account.logout();
      expect(requests.last.headers['Authorization'], 'Bearer $token');
      expect(account.user, null);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      account.dispose();
    },
  );
  test('bad credentials never become a logged-in account', () async {
    final account = YuashieAccount(
      storage: const FlutterSecureStorage(),
      client: MockClient(
        (r) async => r.url.path.endsWith('/config')
            ? json(config)
            : json({'message': '账号或密码不正确。'}, 401),
      ),
    );
    await account.initialize();
    expect(await account.login('a@example.test', 'wrong'), false);
    expect(account.user, null);
    expect(account.error, contains('密码'));
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    account.dispose();
  });
  test('a saved native session restores the same website identity', () async {
    FlutterSecureStorage.setMockInitialValues({
      'yuashie_login_session_v1': token,
    });
    final account = YuashieAccount(
      storage: const FlutterSecureStorage(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/config')) return json(config);
        expect(r.headers['Authorization'], 'Bearer $token');
        return json({'user': person});
      }),
    );
    await account.initialize();
    expect(account.user!['username'], 'website_user');
    account.dispose();
  });
  test(
    'browser authorization binds exchange to an app-held verifier and can be cancelled',
    () {
      fakeAsync((async) {
        Uri? launched;
        String? challenge;
        final account = YuashieAccount(
          storage: const FlutterSecureStorage(),
          openBrowser: (uri) async {
            launched = uri;
            return true;
          },
          client: MockClient((r) async {
            if (r.url.path.endsWith('/requests')) {
              challenge = (jsonDecode(r.body) as Map)['challenge'] as String;
              return json({'id': '11111111-1111-1111-1111-111111111111'});
            }
            final payload = jsonDecode(r.body) as Map;
            expect(payload['verifier'], isNot(challenge));
            expect(payload['verifier'], hasLength(43));
            return json({'user': person, 'token': token});
          }),
        );
        account.browserLogin(provider: 'github');
        async.flushMicrotasks();
        expect(launched!.host, 'yuashie.cn');
        expect(launched!.path, '/api/auth/oauth/github/start');
        expect(
          launched!.queryParameters['redirect'],
          startsWith('/auth/approve?request='),
        );
        expect(launched.toString(), isNot(contains('verifier')));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(account.user!['id'], 7);
        expect(account.busy, false);
        account.browserLogin();
        async.flushMicrotasks();
        account.cancelBrowserLogin();
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(account.busy, false);
        account.dispose();
      });
    },
  );
  testWidgets(
    'settings login shows credentials, registration, recovery and three providers',
    (tester) async {
      final account = YuashieAccount(
        storage: const FlutterSecureStorage(),
        client: MockClient((r) async => json(config)),
      );
      await tester.pumpWidget(
        MaterialApp(home: YuashieLoginPage(account: account)),
      );
      await tester.pumpAndSettle();
      expect(find.text('邮箱 / 手机号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('注册账号'), findsOneWidget);
      expect(find.text('忘记密码？'), findsOneWidget);
      for (final name in ['QQ', 'GitHub', 'Google']) {
        expect(find.text('$name · 待开通'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      account.dispose();
    },
  );
}
