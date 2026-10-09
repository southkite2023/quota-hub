import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/snapshot.dart';

class _Vault implements AccountsStore {
  String? content;
  @override
  Future<String?> read() async => content;
  @override
  Future<void> write(String value) async { content = value; }
}

ApiAccount _subscription(String endpoint, {String id = 'node'}) => ApiAccount(
  id: id, name: '测试节点', provider: BalanceProvider.subscription,
  category: BalanceCategory.nodes, key: '', endpoint: endpoint,
);

void main() {
  test('subscription metadata converts bytes, expiry and preserves URL tokens privately', () async {
    const secret = 'do-not-leak-123';
    final vault = _Vault();
    final api = BalanceApi(clientFactory: () => MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['token'], secret);
      expect(request.followRedirects, false);
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response('private proxy config must not be snapshotted', 200, headers: {
        'Subscription-Userinfo':
            'upload=1073741824; download=2147483648; total=107374182400; expire=1794182400',
      });
    }));
    final manager = ApiAccounts(store: vault, api: api);
    await manager.initialize();
    expect(await manager.save(_subscription('https://sub.example/client/subscribe?token=$secret')), true);
    final saved = DemoCase.fromJson({...jsonDecode(manager.raw) as Map<String, dynamic>, 'name': 'test'});
    final account = saved.accounts.single;
    expect(account.id, 'node_byte');
    expect(account.provider, 'subscription');
    expect(account.metrics.map((m) => m.key).toList(), ['remaining', 'used', 'total', 'expires_at']);
    expect(account.metrics[0].displayValue, '97.00 GiB');
    expect(account.metrics[1].displayValue, '3.00 GiB');
    expect(account.metrics[2].displayValue, '100.00 GiB');
    expect(account.metrics[3].kind, 'expiry');
    expect(account.metrics[3].state, MetricState.ok);
    expect(manager.raw, isNot(contains(secret)));
    expect(manager.raw, isNot(contains('private proxy config')));
    final reopened = ApiAccounts(store: vault);
    await reopened.initialize(query: false);
    expect(reopened.entries.single.endpoint, contains(secret));
    expect(reopened.entries.single.category, BalanceCategory.nodes);
    manager.dispose();
    reopened.dispose();
  });

  test('alternate case-insensitive metadata header and missing expiry remain valid', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('', 200, headers: {
      'X-Subscription-Userinfo': 'TOTAL=2147483648, UPLOAD=0, DOWNLOAD=1073741824',
    })));
    final result = DemoCase.fromJson({
      ...await api.fetch(_subscription('https://sub.example/sub?key=sample')), 'name': 'test',
    });
    expect(result.accounts.single.metrics[0].displayValue, '1.00 GiB');
    expect(result.accounts.single.metrics[3].state, MetricState.unknown);
  });

  test('zero total is ambiguous and remains unknown instead of a fake zero', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('', 200,
      headers: {'subscription-userinfo': 'upload=0; download=123; total=0; expire=0'})));
    final result = DemoCase.fromJson({
      ...await api.fetch(_subscription('https://sub.example/unlimited')), 'name': 'test',
    });
    expect(result.accounts.single.metrics[0].state, MetricState.unknown);
    expect(result.accounts.single.metrics[1].value, '123');
    expect(result.accounts.single.metrics[2].state, MetricState.unknown);
    expect(result.accounts.single.metrics[3].state, MetricState.unknown);
  });

  test('does not follow redirects or treat HTML subscriptions as zero', () async {
    for (final status in [301, 302, 401, 403, 429, 503]) {
      final api = BalanceApi(clientFactory: () => MockClient((r) async =>
          http.Response('', status, headers: {'Location': 'https://other.example/leak'})));
      await expectLater(api.fetch(_subscription('https://sub.example/secret?token=private')),
          throwsA(isA<DeepSeekFailure>()));
    }
    final missing = BalanceApi(clientFactory: () => MockClient((_) async =>
      http.Response('<html>login required</html>', 200)));
    await expectLater(missing.fetch(_subscription('https://sub.example/sub?token=private')),
      throwsA(isA<DeepSeekFailure>().having((e) => e.message, 'message', contains('流量响应头'))));
  });

  test('invalid metadata never becomes available traffic', () async {
    for (final data in [
      'upload=-1; download=0; total=100',
      'upload=1; download=not-number; total=100',
      'upload=1; download=2',
      'upload=1; download=2; total=100; expire=hello',
    ]) {
      final api = BalanceApi(clientFactory: () => MockClient((_) async =>
        http.Response('', 200, headers: {'subscription-userinfo': data})));
      await expectLater(api.fetch(_subscription('https://sub.example/sub?key=secret')),
        throwsA(isA<DeepSeekFailure>()));
    }
  });

  test('subscription URL requires HTTPS without credentials, redirects, fragments or spaces', () {
    for (final url in [
      'http://sub.example/subscribe?token=x',
      'https://name:password@sub.example/sub',
      'https://sub.example/sub#secret',
      'https://sub.example/a b',
    ]) {
      expect(() => _subscription(url).validate(), throwsA(isA<DeepSeekFailure>()));
    }
    expect(() => ApiAccount(id: 'invalid', provider: BalanceProvider.subscription,
      category: BalanceCategory.ai, name: 'invalid', key: '', endpoint: 'https://sub.example').validate(),
      throwsA(isA<DeepSeekFailure>()));
  });

  test('failure leaves a prior valid snapshot stale without exposing the URL', () async {
    var available = true;
    final manager = ApiAccounts(store: _Vault(), api: BalanceApi(clientFactory: () => MockClient((_) async {
      if (available) return http.Response('', 200, headers: {
        'subscription-userinfo': 'upload=0; download=1073741824; total=2147483648',
      });
      return http.Response('', 403);
    })));
    await manager.initialize();
    expect(await manager.save(_subscription('https://sub.example/sub?token=hidden')), true);
    available = false;
    await manager.refresh();
    expect(manager.accounts.single.metrics[0].state, MetricState.stale);
    expect(manager.accounts.single.metrics[0].displayValue, '1.00 GiB');
    expect(jsonEncode(manager.errors), isNot(contains('hidden')));
    manager.dispose();
  });
}
