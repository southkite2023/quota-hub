import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/main.dart';
import 'package:quota_hub/snapshot.dart';

class Vault implements AccountsStore {
  String? data; bool fail = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { if (fail) throw StateError('fail'); data = value; }
}
BalanceApi api() => BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"data":{"total_credits":10,"total_usage":1}}', 200)));
ApiAccount entry(String id) => ApiAccount(id: id, provider: BalanceProvider.openrouter, name: id, key: 'secret');
void main() {
  test('all checked accounts appear, unchecked stay on dashboard, no selection stays empty', () async {
    final vault = Vault(); final manager = ApiAccounts(store: vault, api: api()); await manager.initialize();
    await manager.save(entry('first')); await manager.save(entry('second'));
    expect(jsonDecode(manager.widgetRaw)['accounts'].length, 2);
    await manager.setWidgetSelected('first', false);
    expect(manager.accounts.length, 2); expect(jsonDecode(manager.widgetRaw)['accounts'].single['id'], 'second_usd');
    final restored = ApiAccounts(store: vault, api: api()); await restored.initialize();
    expect(restored.widgetAccountIds, ['second']);
    await manager.selectAllWidgets(false); expect(jsonDecode(manager.widgetRaw)['accounts'], isEmpty);
    final empty = ApiAccounts(store: vault); await empty.initialize(query: false); expect(empty.widgetAccountIds, isEmpty);
    await manager.selectAllWidgets(true); await manager.remove('first'); expect(manager.widgetAccountIds, ['second']);
    expect(manager.widgetRaw, isNot(contains('secret')));
    manager.dispose(); restored.dispose(); empty.dispose();
  });
  test('legacy selection migrates and failed write keeps previous checkboxes', () async {
    final vault = Vault()..data = jsonEncode({'version': 1, 'widgetAccountId': 'second', 'accounts': [entry('first').toJson(), entry('second').toJson()]});
    final manager = ApiAccounts(store: vault, api: api()); await manager.initialize();
    expect(manager.widgetAccountIds, ['second']); vault.fail = true;
    await manager.setWidgetSelected('first', true); expect(manager.widgetAccountIds, ['second']);
    manager.dispose();
  });
  testWidgets('home balance summary shows zero, currency, stale status and privacy', (tester) async {
    final account = Account(id: 'first_cny', provider: 'deepseek', label: '工作账户', lastSuccessAt: DateTime(2026),
      metrics: const [Metric(key: 'available', kind: 'money', state: MetricState.stale, value: '0.00', unit: 'CNY', errorCode: 'timeout')]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BalanceSummary(account: account, hideMoney: false))));
    expect(find.text('工作账户'), findsOneWidget); expect(find.text('0.00 CNY'), findsOneWidget); expect(find.text('缓存已过期'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BalanceSummary(account: account, hideMoney: true))));
    expect(find.text('0.00 CNY'), findsNothing); expect(find.text('•••• CNY'), findsOneWidget);
  });
}
