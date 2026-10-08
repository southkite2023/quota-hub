import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/account_settings.dart';
import 'package:quota_hub/main.dart';
import 'package:quota_hub/snapshot.dart';

class MemoryVault implements AccountsStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { data = value; }
}
void main() {
  test('category survives serialization and legacy accounts infer defaults', () {
    const node = ApiAccount(id: 'node', provider: BalanceProvider.custom,
      category: BalanceCategory.nodes, name: '节点', key: 'fake', endpoint: 'https://example.com/balance');
    expect(ApiAccount.fromJson(node.toJson()).category, BalanceCategory.nodes);
    final legacy = node.toJson()..remove('category');
    expect(ApiAccount.fromJson(legacy).category, BalanceCategory.ai);
    legacy['provider'] = 'aliyun'; legacy['accessKeyId'] = 'fakeId';
    expect(ApiAccount.fromJson(legacy).category, BalanceCategory.cloud);
  });

  testWidgets('category filters providers and node account persists after reopening', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vault = MemoryVault();
    final manager = ApiAccounts(store: vault, api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"data":{"balance":12}}', 200))));
    await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: AccountSettings(connection: manager)));
    await tester.ensureVisible(find.text('添加余额账户'));
    await tester.tap(find.text('添加余额账户')); await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(DropdownButtonFormField<BalanceCategory>)).dy,
      lessThan(tester.getTopLeft(find.byType(DropdownButtonFormField<String>)).dy));
    await tester.enterText(find.byType(TextField).last, 'discarded-secret');
    await tester.tap(find.byType(DropdownButtonFormField<BalanceCategory>)); await tester.pumpAndSettle();
    await tester.tap(find.text('云服务器').last); await tester.pumpAndSettle();
    final cloudChoices = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    expect(cloudChoices.initialValue, 'aliyun');
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '');
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    expect(find.text('DeepSeek'), findsNothing);
    expect(find.text('腾讯云 · 云账户余额'), findsOneWidget);
    await tester.tap(find.text('腾讯云 · 云账户余额')); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<BalanceCategory>)); await tester.pumpAndSettle();
    await tester.tap(find.text('节点订阅').last); await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '节点账户');
    await tester.enterText(fields.at(1), 'https://example.com/balance');
    await tester.enterText(fields.last, 'node-secret');
    await tester.ensureVisible(find.text('验证并保存'));
    await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
    await tester.tap(find.text('验证连接')); await tester.pumpAndSettle();
    expect(manager.entries.single.category, BalanceCategory.nodes);
    expect(find.text('节点订阅 · 自定义余额接口'), findsOneWidget);
    final reopened = ApiAccounts(store: vault); await reopened.initialize();
    expect(reopened.entries.single.category, BalanceCategory.nodes);
    await tester.tap(find.text('编辑')); await tester.pumpAndSettle();
    expect(tester.widget<DropdownButtonFormField<BalanceCategory>>(find.byType(DropdownButtonFormField<BalanceCategory>)).initialValue, BalanceCategory.nodes);
    manager.dispose(); reopened.dispose();
  });

  testWidgets('cloud editor hides saved secret and rejects reuse after ID changes', (tester) async {
    var requests = 0;
    final vault = MemoryVault();
    final manager = ApiAccounts(store: vault, api: BalanceApi(clientFactory: () => MockClient((_) async {
      requests++;
      return http.Response('{"Success":true,"Code":"200","Data":{"Currency":"CNY","AvailableAmount":"12.00"}}', 200);
    })));
    await manager.initialize();
    const original = ApiAccount(id: 'cloud', provider: BalanceProvider.aliyun, name: '云账户', key: 'fakeSecret', accessKeyId: 'fakeId');
    expect(await manager.save(original), true);
    await tester.pumpWidget(MaterialApp(home: AccountEditor(connection: manager, account: original)));
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.last).controller!.text, '');
    expect(tester.widget<TextField>(fields.last).obscureText, true);
    await tester.enterText(fields.at(1), 'changedId');
    await tester.ensureVisible(find.text('验证并保存'));
    await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
    expect(requests, 1);
    expect(manager.entries.single.accessKeyId, 'fakeId');
    expect(find.textContaining('请填写完整的 Secret'), findsOneWidget);
    await tester.enterText(fields.last, 'newSecret');
    await tester.ensureVisible(find.text('验证并保存'));
    await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
    expect(requests, 2);
    expect(manager.entries.single.accessKeyId, 'changedId');
    expect(manager.raw, isNot(contains('newSecret')));
  });

  testWidgets('OpenRouter can be selected and saved as an independent account', (tester) async {
    final manager = ApiAccounts(store: MemoryVault(), api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"data":{"total_credits":10,"total_usage":2}}', 200))));
    await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: AccountSettings(connection: manager)));
    await tester.ensureVisible(find.text('添加余额账户'));
    await tester.tap(find.text('添加余额账户')); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRouter').last); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工作 OpenRouter');
    await tester.enterText(find.byType(TextField).last, 'fake-management-key');
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, true);
    await tester.ensureVisible(find.text('验证并保存')); await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
    expect(manager.entries.single.provider, BalanceProvider.openrouter);
    expect(manager.entries.single.name, '工作 OpenRouter');
    expect(find.text('工作 OpenRouter'), findsOneWidget);
  });
  for (final choice in ['Kimi（国内站）', 'OpenAI · 本月费用', '智谱 · 实验性余额']) {
    testWidgets('$choice can be configured and saved', (tester) async {
      final isKimi = choice.startsWith('Kimi');
      final isZhipu = choice.startsWith('智谱');
      final manager = ApiAccounts(store: MemoryVault(), api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response(isKimi
        ? '{"code":0,"status":true,"data":{"available_balance":3,"voucher_balance":1,"cash_balance":2}}'
        : isZhipu ? '{"code":200,"data":{"availableBalance":10}}' : '{"object":"page","data":[],"has_more":false}', 200))));
      await manager.initialize();
      await tester.pumpWidget(MaterialApp(home: AccountEditor(connection: manager)));
      await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(choice).last);
      await tester.tap(find.text(choice).last); await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      if (!isKimi && !isZhipu) expect(find.text('Admin API Key'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'fake-key');
      await tester.ensureVisible(find.text('验证并保存'));
      await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
      expect(manager.entries.single.provider, isKimi ? BalanceProvider.kimi : isZhipu ? BalanceProvider.zhipu : BalanceProvider.openai);
    });
  }
  testWidgets('OpenAI summary distinguishes costs from unknown balance and hides amounts', (tester) async {
    final account = Account(id: 'openai_usd', provider: 'openai', label: 'OpenAI 费用', lastSuccessAt: DateTime.utc(2026, 9, 29), metrics: const [
      Metric(key: 'available', kind: 'money', state: MetricState.unknown, value: null, unit: 'USD'),
      Metric(key: 'month_spent', kind: 'money', state: MetricState.ok, value: '12.34', unit: 'USD'),
    ]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BalanceSummary(account: account, hideMoney: false))));
    expect(find.text('本月费用（UTC）'), findsOneWidget);
    expect(find.text('12.34 USD'), findsOneWidget);
    expect(find.text('未知'), findsNWidgets(2));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BalanceSummary(account: account, hideMoney: true))));
    expect(find.text('12.34 USD'), findsNothing);
  });
  testWidgets('unavailable provider explains limitation without collecting a key', (tester) async {
    final manager = ApiAccounts(store: MemoryVault()); await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: AccountEditor(connection: manager)));
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('硅基流动 · 待适配').last); await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('验证并保存'), findsNothing);
    expect(find.textContaining('2026-08-14'), findsOneWidget);
  });
}
