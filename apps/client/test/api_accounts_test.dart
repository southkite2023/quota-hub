import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/snapshot.dart';

class Vault implements AccountsStore {
  String? data;
  bool fail = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { if (fail) throw Exception(); data = value; }
}
ApiAccount account(String id, {BalanceProvider provider = BalanceProvider.openrouter,
  String endpoint = '', String key = 'fake-key'}) => ApiAccount(id: id, provider: provider,
    name: id, key: key, endpoint: endpoint);
http.Response credits(String total, String usage) => http.Response(jsonEncode({
  'data': {'total_credits': total, 'total_usage': usage},
}), 200);

void main() {
  test('OpenRouter uses management endpoint and subtracts decimals exactly', () async {
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.toString(), 'https://openrouter.ai/api/v1/credits');
      expect(r.headers['Authorization'], 'Bearer fake-key');
      expect(r.followRedirects, false);
      return credits('10.10', '0.20');
    }));
    final snapshot = await api.fetch(account('work'));
    final parsed = DemoCase.fromJson({...snapshot, 'name': 'test'});
    expect(parsed.accounts.single.id, 'work_usd');
    expect(parsed.accounts.single.metrics.first.value, '9.90');
    expect(jsonEncode(snapshot), isNot(contains('fake-key')));
    expect(decimalDifference('0.1', '0.2'), '-0.1');
    expect(decimalValue(1e-7), '0.0000001');
  });
  test('custom endpoint sends key only to selected HTTPS host and extracts numeric field', () async {
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.host, 'balance.example'); expect(r.followRedirects, false);
      return http.Response('{"data":{"balance":0}}', 200);
    }));
    final snapshot = await api.fetch(account('custom', provider: BalanceProvider.custom, endpoint: 'https://balance.example/check'));
    expect((snapshot['accounts'] as List).first['metrics'][0]['value'], '0');
  });
  for (final url in ['http://balance.example', 'https://key@balance.example', 'https://balance.example?key=x', 'https://balance.example#key']) {
    test('rejects unsafe endpoint before sending: $url', () async {
      var sent = false;
      final api = BalanceApi(clientFactory: () => MockClient((_) async { sent = true; return credits('1', '0'); }));
      await expectLater(api.fetch(account('custom', provider: BalanceProvider.custom, endpoint: url)), throwsA(isA<DeepSeekFailure>()));
      expect(sent, false);
    });
  }
  test('missing custom field and permission failure never become zero', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"data":{}}', 200)));
    await expectLater(api.fetch(account('custom', provider: BalanceProvider.custom, endpoint: 'https://balance.example')), throwsA(isA<DeepSeekFailure>()));
    final denied = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('sensitive-server-body', 403)));
    await expectLater(denied.fetch(account('router')), throwsA(isA<DeepSeekFailure>().having((e) => e.message, 'message', contains('Management Key'))));
  });
  test('OneAPI validates currency mode without auth, divides usage cents and avoids unlimited fake balance', () async {
    var unlimited = false;
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.host, 'one.example'); expect(r.followRedirects, false);
      if (r.url.path == '/api/status') {
        expect(r.headers.containsKey('Authorization'), false);
        return http.Response('{"success":true,"data":{"display_in_currency":true}}', 200);
      }
      expect(r.headers['Authorization'], 'Bearer fake-key');
      if (r.url.path.endsWith('/subscription')) return http.Response(jsonEncode({'hard_limit_usd': unlimited ? 100000000 : 10}), 200);
      expect(r.url.path, '/v1/dashboard/billing/usage');
      return http.Response('{"total_usage":125}', 200);
    }));
    final config = account('one', provider: BalanceProvider.oneapi, endpoint: 'https://one.example');
    final parsed = DemoCase.fromJson({...await api.fetch(config), 'name': 'test'});
    expect(parsed.accounts.single.metrics.first.value, '8.75');
    unlimited = true;
    final infinite = DemoCase.fromJson({...await api.fetch(config), 'name': 'test'});
    expect(infinite.accounts.single.metrics.first.value, null);
    expect(infinite.accounts.single.metrics.first.state, MetricState.unknown);
  });
  test('OneAPI token units are not presented as money', () async {
    var requests = 0;
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      requests++; return http.Response('{"success":true,"data":{"display_in_currency":false}}', 200);
    }));
    await expectLater(api.fetch(account('one', provider: BalanceProvider.oneapi, endpoint: 'https://one.example')), throwsA(isA<DeepSeekFailure>()));
    expect(requests, 1);
  });
  test('accounts stay isolated on refresh failure, replacement, widget selection and removal', () async {
    final vault = Vault();
    var failFirst = false;
    final manager = ApiAccounts(store: vault, api: BalanceApi(clientFactory: () => MockClient((r) async {
      final key = r.headers['Authorization'];
      if (key == 'Bearer invalid' || (failFirst && key == 'Bearer first-key')) return http.Response('', 401);
      return credits(key == 'Bearer first-key' ? '20' : '40', '0');
    })));
    await manager.initialize();
    expect(await manager.save(account('first', key: 'first-key')), true);
    expect(await manager.save(account('second', key: 'second-key')), true);
    expect(manager.accounts.map((a) => a.id), ['first_usd', 'second_usd']);
    expect(await manager.save(account('first', key: 'invalid')), false);
    expect(manager.entries.first.key, 'first-key');
    failFirst = true; await manager.refresh();
    expect(manager.accounts.first.metrics.first.state, MetricState.stale);
    expect(manager.accounts.last.metrics.first.state, MetricState.ok);
    expect(manager.errors.keys, ['first']);
    await manager.selectWidget('second');
    expect(jsonDecode(manager.raw)['accounts'][0]['id'], 'second_usd');
    expect(manager.raw, isNot(contains('second-key')));
    vault.fail = true;
    expect(await manager.remove('second'), false);
    expect(manager.entries.length, 2);
    vault.fail = false;
    expect(await manager.remove('second'), true);
    expect(manager.widgetAccountId, 'first');
    expect(await manager.remove('first'), true);
    expect(jsonDecode(manager.raw)['accounts'], isEmpty);
    expect(jsonDecode(vault.data!)['accounts'], isEmpty);
  });
  test('legacy migration record restores one DeepSeek account without leaking keys to snapshot', () async {
    final vault = Vault()..data = jsonEncode({'version': 1, 'widgetAccountId': 'legacy_deepseek', 'accounts': [
      {'id': 'legacy_deepseek', 'provider': 'deepseek', 'name': '旧账户', 'key': 'legacy-key'},
    ]});
    final manager = ApiAccounts(store: vault, api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response(jsonEncode({
      'is_available': true, 'balance_infos': [{'currency': 'CNY', 'total_balance': '3', 'granted_balance': '1', 'topped_up_balance': '2'}],
    }), 200))));
    await manager.initialize();
    expect(manager.accounts.single.id, 'legacy_deepseek_cny');
    expect(manager.accounts.single.label, contains('旧账户'));
    expect(manager.raw, isNot(contains('legacy-key')));
  });
  test('corrupt vault cannot be silently overwritten', () async {
    final vault = Vault()..data = 'not-json';
    final manager = ApiAccounts(store: vault);
    await manager.initialize();
    expect(manager.storageFailed, true);
    expect(await manager.save(account('new')), false);
    expect(vault.data, 'not-json');
  });
  test('concurrent save and removal cannot overwrite each other', () async {
    final pending = Completer<http.Response>();
    final manager = ApiAccounts(store: Vault(), api: BalanceApi(clientFactory: () => MockClient((_) => pending.future)));
    await manager.initialize();
    final saving = manager.save(account('first'));
    expect(await manager.save(account('second')), false);
    expect(await manager.remove('first'), false);
    pending.complete(credits('1', '0'));
    expect(await saving, true);
    expect(manager.entries.length, 1);
  });
}
