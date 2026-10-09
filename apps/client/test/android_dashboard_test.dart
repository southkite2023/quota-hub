import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/account_settings.dart';
import 'package:quota_hub/android_dashboard.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/snapshot.dart';

class Vault implements AccountsStore {
  String? data;
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw StateError('unavailable');
    return data;
  }

  @override
  Future<void> write(String value) async {
    data = value;
  }
}

const ai = ApiAccount(
  id: 'work',
  provider: BalanceProvider.deepseek,
  name: '工作账户',
  key: 'fake-key',
);
const node = ApiAccount(
  id: 'work_other',
  provider: BalanceProvider.custom,
  category: BalanceCategory.nodes,
  name: '节点账户',
  key: 'fake-key',
  endpoint: 'https://example.com/balance',
);

Future<ApiAccounts> manager([Vault? vault]) async {
  final accounts = ApiAccounts(
    store: vault ?? Vault(),
    api: BalanceApi(
      clientFactory: () => MockClient(
        (request) async => request.url.host == 'api.deepseek.com'
            ? http.Response(
                jsonEncode({
                  'is_available': true,
                  'balance_infos': [
                    {
                      'currency': 'CNY',
                      'total_balance': '0',
                      'granted_balance': '0',
                      'topped_up_balance': '0',
                    },
                    {
                      'currency': 'USD',
                      'total_balance': '12.50',
                      'granted_balance': '2.50',
                      'topped_up_balance': '10',
                    },
                  ],
                }),
                200,
              )
            : http.Response('{"data":{"balance":42}}', 200),
      ),
    ),
  );
  await accounts.initialize(query: false);
  await accounts.save(ai);
  await accounts.save(node);
  await accounts.setRefreshMinutes(0);
  return accounts;
}

Widget app(
  ApiAccounts accounts, {
  double scale = 1,
  String? selected,
  int openSerial = 0,
}) => MaterialApp(
  theme: AstracctTheme.mobile(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: ListenableBuilder(
    listenable: accounts,
    builder: (context, _) => AndroidDashboard(
      accounts: accounts,
      hideMoney: false,
      selectedAccountId: selected,
      widgetOpenSerial: openSerial,
      onToggleMoney: () {},
      onSettings: () {},
    ),
  ),
);

void main() {
  testWidgets(
    'category filter preserves all queried accounts, currencies and widget choices',
    (tester) async {
      final accounts = await manager();
      addTearDown(accounts.dispose);
      await accounts.setWidgetSelected(node.id, true);
      final selections = [...accounts.widgetAccountIds];
      await tester.pumpWidget(app(accounts));
      await tester.pumpAndSettle();
      expect(find.byType(MobileAccountCard), findsNWidgets(3));
      expect(find.text('0.00 CNY'), findsNWidgets(3));
      expect(find.text('12.50 USD'), findsOneWidget);
      // IDs sharing a prefix must not duplicate another account's card.
      final cards = tester.widgetList<MobileAccountCard>(
        find.byType(MobileAccountCard),
      );
      expect(cards.where((card) => card.entry.id == ai.id).length, 2);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '节点订阅'));
      await tester.tap(find.widgetWithText(ChoiceChip, '节点订阅'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileAccountCard), findsOneWidget);
      await accounts.refresh();
      await tester.pumpAndSettle();
      expect(accounts.accounts.length, 3);
      expect(accounts.widgetAccountIds, selections);
      expect(accounts.accounts.first.metrics.first.value, '0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline editing retains encrypted credentials; removal requires confirmation',
    (tester) async {
      final vault = Vault();
      final accounts = await manager(vault);
      addTearDown(accounts.dispose);
      await tester.pumpWidget(app(accounts));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('编辑').first);
      await tester.tap(find.text('编辑').first);
      await tester.pumpAndSettle();
      expect(find.byType(AccountEditor), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField).first, '重命名账户');
      await tester.ensureVisible(find.text('验证并保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('验证并保存'));
      await tester.pumpAndSettle();
      expect(accounts.entries.first.key, ai.key);
      expect(accounts.entries.first.id, ai.id);
      expect(accounts.entries.first.name, '重命名账户');
      await tester.ensureVisible(find.text('移除').first);
      await tester.tap(find.text('移除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(accounts.entries.length, 2);
      await tester.tap(find.text('移除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pumpAndSettle();
      expect(accounts.entries.single.id, node.id);
      final reopened = ApiAccounts(store: vault);
      await reopened.initialize(query: false);
      expect(reopened.entries.single.id, node.id);
      reopened.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unreadable storage prevents adding or overwriting accounts', (
    tester,
  ) async {
    final vault = Vault()..fail = true;
    final accounts = ApiAccounts(store: vault);
    await accounts.initialize(query: false);
    addTearDown(accounts.dispose);
    await tester.pumpWidget(app(accounts));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '添加余额账户'))
          .onPressed,
      isNull,
    );
    expect(vault.data, isNull);
  });

  testWidgets('widget deep link reveals target even after category filtering', (
    tester,
  ) async {
    final accounts = await manager();
    addTearDown(accounts.dispose);
    await tester.pumpWidget(app(accounts));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '节点订阅'));
    await tester.tap(find.widgetWithText(ChoiceChip, '节点订阅'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(accounts, selected: 'work_usd'));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
      (w) => w is MobileAccountCard && w.account.id == 'work_usd',
    );
    expect(target, findsOneWidget);
    expect(tester.widget<MobileAccountCard>(target).selected, true);
    expect(
      tester.getRect(target).overlaps(Offset.zero & tester.view.physicalSize),
      true,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '节点订阅'));
    await tester.tap(find.widgetWithText(ChoiceChip, '节点订阅'));
    await tester.pumpAndSettle();
    expect(target, findsNothing);
    await tester.pumpWidget(app(accounts, selected: 'work_usd', openSerial: 1));
    await tester.pumpAndSettle();
    expect(target, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px and large text preserve privacy and failure states without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const snapshot = Account(
        id: 'work_cny',
        provider: 'deepseek',
        label: '很长的账户名称 · CNY',
        lastSuccessAt: null,
        metrics: [
          Metric(
            key: 'available',
            kind: 'money',
            state: MetricState.stale,
            value: '0',
            unit: 'CNY',
            errorCode: 'timeout',
          ),
          Metric(
            key: 'bonus',
            kind: 'money',
            state: MetricState.unknown,
            value: null,
            unit: 'CNY',
          ),
          Metric(
            key: 'cash',
            kind: 'money',
            state: MetricState.error,
            value: null,
            unit: 'CNY',
            errorCode: 'unauthorized',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AstracctTheme.mobile(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: MobileAccountCard(
                  entry: ai,
                  account: snapshot,
                  hideMoney: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.00 CNY'), findsNothing);
      expect(find.text('•••• CNY'), findsOneWidget);
      expect(find.text('缓存已过期'), findsOneWidget);
      expect(find.text('查询失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile dashboard renders at narrow width and accessibility scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = await manager();
      addTearDown(accounts.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: app(accounts)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Optional local preview; never includes real credentials or balances.
      if (Platform.environment['ASTRACCT_UI_PREVIEW']
          case final String folder) {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await tester.runAsync(
          () async => File(
            '$folder/android-home.png',
          ).writeAsBytes(bytes!.buffer.asUint8List()),
        );
        image.dispose();
      }
      await tester.pumpWidget(app(accounts, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
