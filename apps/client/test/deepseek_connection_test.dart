import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/snapshot.dart';

class MemoryStore implements KeyStore {
  String? value;
  bool failSave = false;
  bool failRead = false;
  @override
  Future<String?> read() async { if (failRead) throw Exception(); return value; }
  @override
  Future<void> save(String key) async { if (failSave) throw Exception(); value = key; }
  @override
  Future<void> remove() async { value = null; }
}

String response({String amount = '0', bool available = true}) => jsonEncode({
  'is_available': available,
  'balance_infos': [for (final currency in ['USD', 'CNY']) {
    'currency': currency, 'total_balance': amount,
    'granted_balance': '0', 'topped_up_balance': amount,
  }],
});

void main() {
  test('official endpoint, bearer auth, no redirects; exact zero and currencies', () async {
    final api = DeepSeekApi(clientFactory: () => MockClient((request) async {
      expect(request.url.toString(), 'https://api.deepseek.com/user/balance');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer fake-key');
      expect(request.followRedirects, false);
      return http.Response(response(available: false), 200);
    }));
    final snapshot = await api.balance('fake-key');
    final parsed = DemoCase.fromJson({...snapshot, 'name': 'test'});
    expect(parsed.accounts.map((a) => a.id), ['deepseek_cny', 'deepseek_usd']);
    expect(parsed.accounts.first.metrics.first.value, '0');
    expect(parsed.accounts.first.label, contains('当前不可调用'));
    expect(jsonEncode(snapshot), isNot(contains('fake-key')));
  });

  test('negative balances retain decimal precision', () async {
    final api = DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response(response(amount: '-0.001'), 200)));
    final snapshot = DemoCase.fromJson({...await api.balance('fake'), 'name': 'test'});
    expect(snapshot.accounts.first.metrics.first.displayValue, '-0.001 CNY');
  });

  for (final pair in [(401, 'unauthorized'), (403, 'unauthorized'), (429, 'rate_limited'), (500, 'provider_unavailable'), (302, 'provider_unavailable')]) {
    test('HTTP ${pair.$1} produces safe error', () async {
      final api = DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response('secret response', pair.$1)));
      await expectLater(api.balance('fake'), throwsA(isA<DeepSeekFailure>().having((e) => e.code, 'code', pair.$2).having((e) => e.message, 'message', isNot(contains('secret')))));
    });
  }

  test('malformed success is rejected', () async {
    final api = DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response('{"is_available": true, "balance_infos": []}', 200)));
    await expectLater(api.balance('fake'), throwsA(isA<DeepSeekFailure>()));
  });

  test('failed replacement preserves existing key and balance; failed refresh is stale; removal clears all', () async {
    var status = 200;
    final store = MemoryStore();
    final connection = DeepSeekConnection(store: store, api: DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response(response(amount: '23.45'), status))));
    await connection.initialize();
    expect(await connection.connect('old-key'), true);
    status = 401;
    expect(await connection.connect('bad-new-key'), false);
    expect(store.value, 'old-key');
    expect(connection.accounts.first.metrics.first.value, '23.45');
    await connection.refresh();
    expect(connection.accounts.first.metrics.first.state, MetricState.stale);
    expect(connection.accounts.first.metrics.first.value, '23.45');
    expect(await connection.disconnect(), true);
    expect(store.value, null);
    expect(connection.connected, false);
    expect(connection.raw, isNot(contains('23.45')));
    expect(connection.accounts.first.metrics.first.state, MetricState.unknown);
  });

  test('first query failure never displays demo money', () async {
    final store = MemoryStore()..value = 'saved-key';
    final connection = DeepSeekConnection(store: store, api: DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response('', 500))));
    await connection.initialize();
    expect(connection.accounts.first.metrics.first.value, null);
    expect(connection.accounts.first.metrics.first.state, MetricState.error);
  });

  test('storage failure does not activate unpersisted connection', () async {
    final store = MemoryStore()..failSave = true;
    final connection = DeepSeekConnection(store: store, api: DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response(response(), 200))));
    await connection.initialize();
    expect(await connection.connect('new-key'), false);
    expect(connection.connected, false);
    expect(connection.error, contains('安全保存失败'));
  });

  test('unreadable credentials can be removed', () async {
    final connection = DeepSeekConnection(store: MemoryStore()..failRead = true);
    await connection.initialize();
    expect(connection.ready, true);
    expect(connection.error, isNotNull);
    expect(await connection.disconnect(), true);
    expect(connection.error, null);
  });

  test('in-flight verification cannot race with removal or duplicate requests', () async {
    final pending = Completer<http.Response>();
    final store = MemoryStore();
    final connection = DeepSeekConnection(store: store, api: DeepSeekApi(clientFactory: () => MockClient((_) => pending.future)));
    await connection.initialize();
    final first = connection.connect('fake-key');
    expect(connection.busy, true);
    expect(await connection.disconnect(), false);
    expect(await connection.connect('other-key'), false);
    pending.complete(http.Response(response(), 200));
    expect(await first, true);
    expect(store.value, 'fake-key');
  });
}
