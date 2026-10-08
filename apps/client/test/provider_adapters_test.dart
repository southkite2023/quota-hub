import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/snapshot.dart';
import 'package:quota_hub/background_refresh.dart';

const kimi = ApiAccount(id: 'kimi', provider: BalanceProvider.kimi, name: 'Kimi', key: 'fake-key');
const openai = ApiAccount(id: 'openai', provider: BalanceProvider.openai, name: 'OpenAI', key: 'fake-admin');
Map<String, dynamic> costPage(List<Object?> amounts, {bool more = false, String? cursor, String currency = 'usd'}) => {
  'object': 'page', 'has_more': more, 'next_page': cursor,
  'data': [{'object': 'bucket', 'results': [for (final amount in amounts)
    {'object': 'organization.costs.result', 'amount': {'value': amount, 'currency': currency}}]}],
};
DemoCase parse(Map<String, dynamic> raw) => DemoCase.fromJson({...raw, 'name': 'test'});

void main() {
  const zhipu = ApiAccount(id: 'zhipu', provider: BalanceProvider.zhipu, name: '智谱', key: 'fake-api-key');
  test('experimental Zhipu uses observed official route and raw Authorization', () async {
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.toString(), 'https://open.bigmodel.cn/api/biz/account/query-customer-account-report');
      expect(r.headers['Authorization'], 'fake-api-key');
      expect(r.followRedirects, false);
      return http.Response('{"code":200,"success":true,"data":{"availableBalance":"10.001","cashBalance":"12","frozenBalance":"1.999"}}', 200);
    }));
    final raw = await api.fetch(zhipu);
    final account = parse(raw).accounts.single;
    expect(account.metrics.map((m) => m.value), ['10.001', '12', '1.999']);
    expect(account.metrics.every((m) => m.unit == 'CNY'), true);
    expect(account.label, contains('实验性'));
    expect(jsonEncode(raw), isNot(contains('fake-api-key')));
    expect(ApiAccount.fromJson(zhipu.toJson()).provider, BalanceProvider.zhipu);
  });
  test('Zhipu can omit optional fields without inventing cash or frozen balances', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"code":200,"data":{"availableBalance":0}}', 200)));
    final metrics = parse(await api.fetch(zhipu)).accounts.single.metrics;
    expect(metrics.length, 1); expect(metrics.single.value, '0');
  });
  for (final body in [
    '{"code":1001,"success":false,"data":{"availableBalance":100}}',
    '{"code":200,"success":false,"data":{"availableBalance":100}}',
    '{"code":500,"data":{"availableBalance":100}}',
    '{"code":200,"data":{"balance":100}}',
    '{"code":200,"data":{"availableBalance":true}}',
  ]) {
    test('Zhipu rejects auth errors and missing/invalid available balances: $body', () async {
      final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response(body, 200)));
      await expectLater(api.fetch(zhipu), throwsA(isA<DeepSeekFailure>()));
    });
  }

  test('Kimi uses official China endpoint and preserves cash debt independently', () async {
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.toString(), 'https://api.moonshot.cn/v1/users/me/balance');
      expect(r.headers['Authorization'], 'Bearer fake-key');
      expect(r.followRedirects, false);
      return http.Response('{"code":0,"status":true,"data":{"available_balance":2.12345,"voucher_balance":2.12345,"cash_balance":-1.25}}', 200);
    }));
    final raw = await api.fetch(kimi);
    final metrics = parse(raw).accounts.single.metrics;
    expect(metrics.map((m) => m.value), ['2.12345', '2.12345', '-1.25']);
    expect(metrics.every((m) => m.unit == 'CNY'), true);
    expect(jsonEncode(raw), isNot(contains('fake-key')));
    expect(ApiAccount.fromJson(kimi.toJson()).provider, BalanceProvider.kimi);
  });
  for (final body in [
    '{"code":1,"status":true,"data":{"available_balance":100}}',
    '{"code":0,"status":false,"data":{"available_balance":100}}',
    '{"code":0,"status":true,"data":{"available_balance":100}}',
    '{"code":0,"status":true,"data":{"available_balance":"NaN","voucher_balance":0,"cash_balance":0}}',
  ]) {
    test('Kimi rejects errors and incomplete amounts: $body', () async {
      final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response(body, 200)));
      await expectLater(api.fetch(kimi), throwsA(isA<DeepSeekFailure>()));
    });
  }
  test('OpenAI sums every page exactly, keeps balance unknown and UTC month fixed', () async {
    var calls = 0;
    final now = DateTime.utc(2026, 9, 29, 5);
    final api = BalanceApi(now: () => now, clientFactory: () => MockClient((r) async {
      calls++;
      expect(r.url.host, 'api.openai.com');
      expect(r.url.path, '/v1/organization/costs');
      expect(r.headers['Authorization'], 'Bearer fake-admin');
      expect(r.followRedirects, false);
      expect(r.url.queryParameters['start_time'], '${DateTime.utc(2026, 9).millisecondsSinceEpoch ~/ 1000}');
      expect(r.url.queryParameters['end_time'], '${now.millisecondsSinceEpoch ~/ 1000}');
      expect(r.url.queryParameters['limit'], '31');
      if (calls == 1) return http.Response(jsonEncode(costPage(['0.10', 0.2], more: true, cursor: 'next+/=')), 200);
      expect(r.url.queryParameters['page'], 'next+/=');
      return http.Response(jsonEncode(costPage([-0.05])), 200);
    }));
    final raw = await api.fetch(openai);
    final account = parse(raw).accounts.single;
    expect(calls, 2);
    expect(account.metrics.first.state, MetricState.unknown);
    expect(account.metrics.first.value, null);
    expect(account.metrics.last.key, 'month_spent');
    expect(account.metrics.last.value, '0.25');
    expect(account.label, contains('2026-09'));
    expect(jsonEncode(raw), isNot(contains('fake-admin')));
    expect(ApiAccount.fromJson(openai.toJson()).provider, BalanceProvider.openai);
  });
  test('new providers survive background restore and failed refresh without false zero', () async {
    final config = jsonEncode({'version': 1, 'accounts': [kimi.toJson(), openai.toJson()], 'widgetAccountIds': ['kimi', 'openai']});
    final success = BalanceApi(clientFactory: () => MockClient((r) async => http.Response(r.url.host == 'api.moonshot.cn'
      ? '{"code":0,"status":true,"data":{"available_balance":3,"voucher_balance":1,"cash_balance":2}}'
      : jsonEncode(costPage([1.25])), 200)));
    final cached = await refreshInBackground(config, null, api: success);
    final failed = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('', 401)));
    final raw = await refreshInBackground(config, cached, api: failed);
    final accounts = parse(jsonDecode(raw) as Map<String, dynamic>).accounts;
    expect(accounts.first.metrics.first.value, '3');
    expect(accounts.first.metrics.first.state, MetricState.stale);
    expect(accounts.last.metrics.last.value, '1.25');
    expect(accounts.last.metrics.last.state, MetricState.stale);
    expect(accounts.last.metrics.first.value, null);
    expect(raw, isNot(contains('fake-admin')));
  });
  test('OpenAI empty cost results mean zero spending, not zero balance', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response(jsonEncode(costPage([])), 200)));
    final metrics = parse(await api.fetch(openai)).accounts.single.metrics;
    expect(metrics.first.value, null);
    expect(metrics.last.value, '0');
  });
  for (final body in [
    costPage([1], currency: 'cny'), costPage([null]),
    costPage([1], more: true), costPage([1], more: true, cursor: 'cycle'),
    {'object': 'page', 'data': [], 'has_more': 'false'},
  ]) {
    test('OpenAI malformed pages never publish partial costs: $body', () async {
      var requests = 0;
      final api = BalanceApi(clientFactory: () => MockClient((_) async {
        requests++; return http.Response(jsonEncode(body), 200);
      }));
      await expectLater(api.fetch(openai), throwsA(isA<DeepSeekFailure>()));
      expect(requests, lessThanOrEqualTo(2));
    });
  }
  for (final status in [401, 403, 429, 302, 500]) {
    test('OpenAI HTTP $status is sanitized and never follows redirects', () async {
      final api = BalanceApi(clientFactory: () => MockClient((r) async {
        expect(r.followRedirects, false);
        return http.Response('secret response', status);
      }));
      await expectLater(api.fetch(openai), throwsA(isA<DeepSeekFailure>().having((e) => e.message, 'sanitized', isNot(contains('secret response')))));
    });
  }
  for (final endpoint in ['https://one.example', 'https://one.example/v1/', 'https://one.example/sub/v1']) {
    test('OneAPI accepts root and API base URLs: $endpoint', () async {
      final prefix = endpoint.contains('/sub') ? '/sub' : '';
      final paths = <String>[];
      final api = BalanceApi(clientFactory: () => MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path == '$prefix/api/status') {
          expect(r.headers.containsKey('Authorization'), false);
          return http.Response('{"success":true,"data":{"display_in_currency":true}}', 200);
        }
        expect(r.headers['Authorization'], 'Bearer fake');
        return http.Response(r.url.path.endsWith('/subscription') ? '{"hard_limit_usd":10}' : '{"total_usage":125}', 200);
      }));
      final raw = await api.fetch(ApiAccount(id: 'one', provider: BalanceProvider.oneapi, name: 'one', key: 'fake', endpoint: endpoint));
      expect(paths, ['$prefix/api/status', '$prefix/v1/dashboard/billing/subscription', '$prefix/v1/dashboard/billing/usage']);
      expect(parse(raw).accounts.single.metrics.first.value, '8.75');
    });
  }
}
