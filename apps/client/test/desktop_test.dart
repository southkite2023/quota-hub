import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/desktop_accounts_store.dart';
import 'package:quota_hub/desktop_dashboard.dart';
import 'package:quota_hub/desktop_window.dart';
import 'package:quota_hub/macos_menu_bar.dart';
import 'macos_menu_test.dart' show MenuHost;

class MemoryStore implements AccountsStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { data = value; }
}
class WindowHost implements DesktopWindowHost {
  Rect rect = const Rect.fromLTWH(100, 80, 900, 680);
  bool floating = false, pinned = false, failNext = false, failPin = false, closed = false;
  int drags = 0;
  @override
  Future<Rect> bounds() async => rect;
  @override
  Future<void> apply({required bool floating, required Rect bounds, required bool pinned}) async {
    this.floating = floating; rect = bounds; this.pinned = pinned;
    if (failNext) { failNext = false; throw StateError('Native change failed halfway'); }
  }
  @override
  Future<void> pin(bool value) async { if (failPin) throw StateError('denied'); pinned = value; }
  @override
  Future<void> drag() async { drags++; }
  @override
  Future<void> close() async { closed = true; }
}

Future<ApiAccounts> manager(MemoryStore store) async {
  final accounts = ApiAccounts(store: store, api: BalanceApi(clientFactory: () => MockClient((request) async {
    return http.Response(jsonEncode({'data': {'total_credits': 10, 'total_usage': 1}}), 200);
  })));
  await accounts.initialize(query: false);
  await accounts.setRefreshMinutes(0);
  await accounts.save(const ApiAccount(id: 'first', provider: BalanceProvider.openrouter, name: '工作账户', key: 'fake-key'));
  await accounts.save(const ApiAccount(id: 'second', provider: BalanceProvider.openrouter, name: '不选的账户', key: 'fake-key-2'));
  await accounts.setWidgetSelected('second', false);
  return accounts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('macOS menu privacy, selections and click action share live dashboard state', (tester) async {
    final accounts = await manager(MemoryStore());
    final host = WindowHost(); final window = DesktopWindowController(host: host);
    final menuHost = MenuHost(); final menu = MacMenuController(host: menuHost);
    await tester.pumpWidget(MaterialApp(theme: AstracctTheme.light(), home: DesktopDashboard(accounts: accounts, window: window, menu: menu)));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    await menuHost.action!('selection', menu.choices.first.id);
    await tester.pumpAndSettle();
    expect(menuHost.updates.last['title'], '9.00 USD');
    await tester.tap(find.byTooltip('隐藏金额')); await tester.pumpAndSettle();
    expect(menuHost.updates.last['title'], '•••• USD');
    await menuHost.action!('privacy', null); await tester.pumpAndSettle();
    expect(menuHost.updates.last['title'], '9.00 USD');
    await window.setFloating(true); await tester.pumpAndSettle();
    await menuHost.action!('open', null); await tester.pumpAndSettle();
    expect(window.floating, false);
    expect(find.text('账户余额'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    menu.dispose(); window.dispose(); accounts.dispose();
  });

  test('desktop vault and selected accounts round-trip; snapshot contains no credentials', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final vault = DesktopAccountsStore();
    await vault.write(jsonEncode({'version': 1, 'refreshMinutes': 0, 'accounts': [
      const ApiAccount(id: 'personal', provider: BalanceProvider.openrouter, name: '个人', key: 'fake-key').toJson(),
    ], 'widgetAccountIds': <String>[]}));
    final restored = ApiAccounts(store: DesktopAccountsStore());
    await restored.initialize(query: false);
    expect(restored.storageFailed, false);
    expect(restored.entries.single.key, 'fake-key');
    expect(restored.widgetAccountIds, isEmpty);
    expect(restored.widgetRaw, isNot(contains('fake-key')));
    restored.dispose();
  });

  test('floating mode restores bounds and rolls back a partial native failure', () async {
    final host = WindowHost(); final window = DesktopWindowController(host: host);
    final original = host.rect;
    await window.setFloating(true);
    expect(window.floating, true); expect(host.pinned, true);
    expect(host.rect.size, const Size(360, 320));
    await window.togglePin(); expect(host.pinned, false);
    await window.setFloating(false);
    expect(host.rect, original); expect(host.pinned, false);
    host.failNext = true;
    await window.setFloating(true);
    expect(window.floating, false); expect(host.floating, false);
    expect(host.rect, original); expect(window.error, isNotNull);
    host.failPin = true;
    await window.togglePin(); expect(window.pinned, false); expect(window.error, isNotNull);
    window.dispose();
  });

  testWidgets('floating window shows only selected real balances and retains privacy', (tester) async {
    final accounts = await manager(MemoryStore());
    final host = WindowHost(); final window = DesktopWindowController(host: host);
    await tester.pumpWidget(MaterialApp(theme: AstracctTheme.light(), home: DesktopDashboard(accounts: accounts, window: window)));
    expect(find.text('工作账户 · USD'), findsOneWidget);
    expect(find.text('不选的账户 · USD'), findsOneWidget);
    await tester.tap(find.byTooltip('隐藏金额')); await tester.pump();
    await tester.tap(find.byTooltip('打开余额悬浮窗')); await tester.pumpAndSettle();
    expect(find.text('工作账户 · USD'), findsOneWidget);
    expect(find.text('不选的账户 · USD'), findsNothing);
    expect(find.text('9.00 USD'), findsNothing);
    expect(find.text('•••• USD'), findsOneWidget);
    await tester.tap(find.byTooltip('显示金额')); await tester.pump();
    expect(find.text('9.00 USD'), findsOneWidget);
    await accounts.setWidgetSelected('first', false); await tester.pump();
    expect(find.textContaining('尚未选择余额'), findsOneWidget);
    expect(find.text('9.00 USD'), findsNothing);
    await tester.tap(find.byTooltip('返回主界面')); await tester.pumpAndSettle();
    expect(find.text('不选的账户 · USD'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); accounts.dispose(); window.dispose();
  });

  testWidgets('desktop settings show floating selection and no Android background controls', (tester) async {
    final store = MemoryStore(); final accounts = await manager(store);
    final window = DesktopWindowController(host: WindowHost());
    await tester.pumpWidget(MaterialApp(theme: AstracctTheme.light(), home: DesktopDashboard(accounts: accounts, window: window)));
    await tester.tap(find.text('管理 / 添加余额账户')); await tester.pumpAndSettle();
    expect(find.text('显示在悬浮窗'), findsWidgets);
    expect(find.text('后台继续刷新'), findsNothing);
    await tester.scrollUntilVisible(find.text('不选的账户'), 200, scrollable: find.byType(Scrollable).last);
    final secondCard = find.ancestor(of: find.text('不选的账户'), matching: find.byType(Card));
    final checkbox = find.descendant(of: secondCard, matching: find.byType(CheckboxListTile));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox); await tester.pump();
    final restored = ApiAccounts(store: store); await restored.initialize(query: false);
    expect(restored.widgetAccountIds.toSet(), {'first', 'second'});
    await tester.pumpWidget(const SizedBox());
    accounts.dispose(); restored.dispose(); window.dispose();
  });

  testWidgets('selected currencies and stale zero stay separate in floating mode', (tester) async {
    final store = MemoryStore()..data = jsonEncode({'version': 1, 'refreshMinutes': 0,
      'widgetAccountIds': ['a', 'b'], 'accounts': [
        const ApiAccount(id: 'a', provider: BalanceProvider.deepseek, name: '人民币', key: 'fake-a').toJson(),
        const ApiAccount(id: 'b', provider: BalanceProvider.openai, name: '费用', key: 'fake-b').toJson(),
      ]});
    final accounts = ApiAccounts(store: store); await accounts.initialize(query: false);
    accounts.restoreSnapshot(jsonEncode({'schemaVersion': 1, 'generatedAt': '2026-10-08T00:00:00Z', 'accounts': [
      {'id': 'a_cny', 'provider': 'deepseek', 'label': '人民币', 'lastSuccessAt': '2026-10-08T00:00:00Z',
       'metrics': [{'key': 'available', 'kind': 'money', 'state': 'stale', 'value': '0', 'unit': 'CNY', 'errorCode': 'timeout'}]},
      {'id': 'b_usd', 'provider': 'openai', 'label': '费用', 'lastSuccessAt': '2026-10-08T00:00:00Z',
       'metrics': [{'key': 'month_spent', 'kind': 'money', 'state': 'ok', 'value': '2.5', 'unit': 'USD'},
         {'key': 'available', 'kind': 'money', 'state': 'unknown', 'value': null, 'unit': 'USD'}]},
    ]}));
    final window = DesktopWindowController(host: WindowHost()); await window.setFloating(true);
    await tester.pumpWidget(MaterialApp(home: DesktopDashboard(accounts: accounts, window: window)));
    expect(find.text('0.00 CNY'), findsOneWidget);
    expect(find.text('缓存已过期'), findsOneWidget);
    expect(find.text('2.50 USD'), findsOneWidget);
    expect(find.text('本月费用（UTC）'), findsOneWidget);
    expect(find.text('未知'), findsNWidgets(2));
    expect(find.text('2.50 CNY'), findsNothing);
    await tester.pumpWidget(const SizedBox()); accounts.dispose(); window.dispose();
  });

  testWidgets('compact controls fit minimum window size and close remains accessible', (tester) async {
    tester.view.physicalSize = const Size(320, 180); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = await manager(MemoryStore());
    final host = WindowHost(); final window = DesktopWindowController(host: host);
    await window.setFloating(true);
    await tester.pumpWidget(MaterialApp(home: DesktopDashboard(accounts: accounts, window: window)));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('退出应用')); await tester.pump(); expect(host.closed, true);
    await tester.pumpWidget(const SizedBox()); accounts.dispose(); window.dispose();
  });
}
