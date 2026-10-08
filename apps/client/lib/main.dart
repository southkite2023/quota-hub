import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'api_accounts.dart';
import 'app_theme.dart';
import 'balance_summary.dart';
import 'desktop_platform.dart';
import 'desktop_dashboard.dart';
import 'desktop_window.dart';
export 'balance_summary.dart';
import 'account_settings.dart';
import 'background_refresh.dart';
import 'package:flutter/services.dart';

import 'snapshot.dart';
import 'live_snapshot.dart';
import 'widget_bridge.dart';

@pragma('vm:entry-point')
void balanceServiceMain() => startBalanceService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopClient) await NativeDesktopWindow.initialize();
  runApp(const QuotaHubApp());
}

class QuotaHubApp extends StatelessWidget {
  const QuotaHubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '星账 Astracct',
        debugShowCheckedModeBanner: false,
        theme: AstracctTheme.light(),
        home: isDesktopClient ? const DesktopDashboard() : const Dashboard(),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  late final Future<List<DemoCase>> _cases = rootBundle.loadString('assets/cases.json').then(parseDemoCases);
  String _selected = 'overview';
  bool _hideMoney = false;
  String? _widgetAccountId;
  Account? _liveAccount;
  String? _liveRaw;
  String? _liveError;
  bool _loadingLive = false;
  final _personal = ApiAccounts();
  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _serverConfigured => !_android && liveConfigured;
  String? _widgetError;
  String? _lastWidgetPayload;

  Future<void> _syncPersonalWidget() async {
    if (!_personal.ready || _personal.storageFailed) return;
    final raw = _personal.raw;
    final widgetRaw = _personal.widgetRaw;
    final payload = '$raw:$widgetRaw:$_hideMoney';
    if (payload == _lastWidgetPayload) return;
    _lastWidgetPayload = payload;
    try {
      await WidgetBridge.showLiveSnapshot(raw, hideMoney: _hideMoney, widgetSnapshot: widgetRaw);
      if (mounted) setState(() => _widgetError = null);
    } catch (_) {
      _lastWidgetPayload = null;
      if (mounted) setState(() => _widgetError = '余额已在应用中更新，桌面组件同步失败，请重试刷新。');
    }
  }

  void _personalChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_personal.busy) unawaited(_syncPersonalWidget());
  }

  Future<void> _initializePersonal() async {
    await _loadWidgetTarget();
    if (mounted) {
      final cached = await const MethodChannel('quota_hub/widget').invokeMethod<String>('readSnapshot').catchError((_) => null);
      await _personal.initialize(query: false);
      _personal.restoreSnapshot(cached);
      if (mounted) setState(() {});
      await _personal.refresh();
      await _personal.readBackgroundStatus();
    }
  }

  void _settings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountSettings(connection: _personal)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _personal.removeListener(_personalChanged);
    _personal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetBridge.listen(_openWidgetAccount);
    if (_android) {
      _personal.setForeground(WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
      _personal.addListener(_personalChanged);
      unawaited(_initializePersonal());
    } else {
      unawaited(_loadWidgetTarget());
      if (_serverConfigured) unawaited(_refreshLive());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_android) {
      if (state == AppLifecycleState.resumed) { unawaited(_resumePersonal()); }
      else { _personal.setForeground(false); }
    }
  }

  Future<void> _resumePersonal() async {
    try {
      final snapshot = await const MethodChannel('quota_hub/widget').invokeMethod<String>('readSnapshot');
      if (mounted && _personal.ready && !_personal.busy) {
        _personal.restoreSnapshot(snapshot);
        setState(() {});
      }
    } catch (_) { /* Keep the last in-memory balance if native cache is unavailable. */ }
    if (!mounted || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _personal.setForeground(true);
    await _personal.readBackgroundStatus();
  }

  Future<void> _refreshLive() async {
    if (_loadingLive) return;
    setState(() { _loadingLive = true; _liveError = null; });
    try {
      final (account, raw) = await fetchDeepSeek();
      if (!mounted) return;
      setState(() { _liveAccount = account; _liveRaw = raw; });
      await WidgetBridge.showLiveSnapshot(raw, hideMoney: _hideMoney);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveError = '连接失败；请检查服务地址、只读令牌和网络。';
        _liveAccount = null;
        _liveRaw = null;
      });
      final failed = jsonEncode({
        'schemaVersion': 1, 'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'accounts': [{
          'id': 'deepseek_cny', 'provider': 'deepseek', 'label': 'DeepSeek API · CNY', 'lastSuccessAt': null,
          'metrics': [{'key': 'available', 'kind': 'money', 'state': 'error', 'value': null, 'unit': 'CNY', 'errorCode': 'provider_unavailable'}],
        }],
      });
      await WidgetBridge.showLiveSnapshot(failed, hideMoney: _hideMoney);
    } finally {
      if (mounted) setState(() => _loadingLive = false);
    }
  }

  Future<void> _loadWidgetTarget() async {
    final hidden = await WidgetBridge.savedHideMoney();
    if (!mounted) return;
    setState(() => _hideMoney = hidden);
    final accountId = await WidgetBridge.initialAccount();
    if (!mounted) return;
    if (accountId == null) {
      if (!_android && !_serverConfigured) await WidgetBridge.showScenario('overview', hideMoney: _hideMoney);
    } else {
      _openWidgetAccount(accountId);
    }
  }

  void _openWidgetAccount(String id) {
    if (!mounted) return;
    final scenario = switch (id) {
      'deepseek_cached' => 'stale',
      'subscription_missing' => 'unknown',
      'aliyun_failure' => 'first_failure',
      _ => 'overview',
    };
    setState(() {
      _selected = scenario;
      _widgetAccountId = id;
    });
    if (!_android && !_serverConfigured) unawaited(WidgetBridge.showScenario(scenario, hideMoney: _hideMoney));
  }

  void _selectScenario(String scenario) {
    setState(() {
      _selected = scenario;
      _widgetAccountId = null;
    });
    if (!_android && !_serverConfigured) unawaited(WidgetBridge.showScenario(scenario, hideMoney: _hideMoney));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('星账 Astracct'), actions: [
          IconButton(
            tooltip: _hideMoney ? '显示金额' : '隐藏金额',
            icon: Icon(_hideMoney ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () {
              setState(() => _hideMoney = !_hideMoney);
              if (_android) unawaited(_syncPersonalWidget());
              if (_serverConfigured && _liveRaw != null) {
                unawaited(WidgetBridge.showLiveSnapshot(_liveRaw!, hideMoney: _hideMoney));
              } else if (!_android && !_serverConfigured) {
                unawaited(WidgetBridge.showScenario(_selected, hideMoney: _hideMoney));
              }
            },
          ),
          if (_android) IconButton(tooltip: '余额账户设置', icon: const Icon(Icons.settings_outlined), onPressed: _settings),
          if (_android && _personal.connected) IconButton(tooltip: '刷新余额', icon: const Icon(Icons.refresh), onPressed: _personal.busy ? null : _personal.refresh),
          if (_serverConfigured) IconButton(tooltip: '刷新余额', icon: const Icon(Icons.refresh), onPressed: _loadingLive ? null : _refreshLive),
        ]),
        body: FutureBuilder<List<DemoCase>>(
          future: _cases,
          builder: (context, result) {
            if (result.hasError) return const Center(child: Text('演示快照无法读取，请检查资产与协议版本。'));
            if (!result.hasData) return const Center(child: CircularProgressIndicator());
            final cases = {for (final item in result.data!) item.name: item};
            if (!{'normal', 'zero', 'unknown', 'stale', 'first_failure'}.every(cases.containsKey)) {
              return const Center(child: Text('演示快照不完整。'));
            }
            final accounts = [
              cases['normal']!.accounts[0],
              _selected == 'unknown' ? cases['unknown']!.accounts[0] : cases['normal']!.accounts[1],
              _selected == 'first_failure' ? cases['first_failure']!.accounts[0] : cases['zero']!.accounts[0],
            ];
            if (_selected == 'stale') accounts[0] = cases['stale']!.accounts[0];
            if (_serverConfigured) {
              accounts[0] = _liveAccount ?? const Account(
                id: 'deepseek_cny', provider: 'deepseek', label: '等待首次查询', lastSuccessAt: null,
                metrics: [Metric(key: 'available', kind: 'money', state: MetricState.unknown, value: null, unit: 'CNY')],
              );
            }
            if (_android) {
              accounts.clear();
              accounts.addAll(_personal.accounts);
            }
            return SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text(_android ? (_personal.connected ? '账户余额 · 各平台分别查询' : '添加余额账户，集中查看余额') : liveConfigured ? 'DeepSeek 实时查询 · 另外两项为演示数据' : '演示数据 · 未连接真实账户', style: const TextStyle(color: AstracctTheme.success)),
                if (_android) ...[
                  const SizedBox(height: 12),
                  if (!_personal.ready || _personal.busy) const LinearProgressIndicator(),
                  Text(_personal.refreshMinutes == 0 ? '自动刷新已关闭' : '自动刷新：每 ${_personal.refreshMinutes} 分钟'),
                  if (_personal.error != null) Text(_personal.error!, style: const TextStyle(color: AstracctTheme.error)),
                  for (final entry in _personal.entries.where((e) => _personal.errors.containsKey(e.id))) Text('${entry.name}：${_personal.errors[entry.id]}', style: const TextStyle(color: AstracctTheme.error)),
                  if (_widgetError != null) Text(_widgetError!, style: const TextStyle(color: AstracctTheme.error)),
                  FilledButton.icon(onPressed: _personal.ready ? _settings : null, icon: const Icon(Icons.link), label: const Text('管理 / 添加余额账户')),
                ],
                if (_serverConfigured && _loadingLive) const LinearProgressIndicator(),
                if (_serverConfigured && _liveError != null) Text(_liveError!, style: const TextStyle(color: AstracctTheme.error)),
                if (_serverConfigured && _liveAccount == null) const Text('DeepSeek 尚未取得余额。'),
                const SizedBox(height: 12),
                Text('账户概览', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(_android ? (_personal.connected ? '每个账户单独更新，不跨币种相加。' : '选择服务商，配置账户后验证并查看余额。') : liveConfigured ? 'DeepSeek 经自托管服务查询；订阅和阿里云仍为虚构示例。' : '三类账户共用一份版本化快照。金额与流量均为虚构示例。'),
                if (_widgetAccountId != null) ...[
                  const SizedBox(height: 10),
                  const Text('已从桌面组件打开对应账户', style: TextStyle(color: AstracctTheme.success)),
                ],
                if (_android) ...[
                  const SizedBox(height: 12),
                  for (final account in accounts) BalanceSummary(account: account, hideMoney: _hideMoney),
                  if (accounts.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('尚未添加账户。添加并验证后，余额会显示在这里。'))),
                  const SizedBox(height: 20),
                  Text('余额明细', style: Theme.of(context).textTheme.titleLarge),
                ],
                const SizedBox(height: 20),
                if (!_android) Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (key, label) in [
                    ('overview', '综合预览'), ('zero', '零余额'), ('unknown', '未知'),
                    ('stale', '过期缓存'), ('first_failure', '首次失败'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _selected == key,
                      onSelected: (_) => _selectScenario(key),
                    ),
                ]),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 850 ? 3 : constraints.maxWidth >= 540 ? 2 : 1;
                  final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(spacing: 14, runSpacing: 14, children: [
                    for (final account in accounts)
                      SizedBox(width: width, child: _AccountCard(
                        account: account,
                        hideMoney: _hideMoney,
                        selected: account.id == _widgetAccountId,
                      )),
                  ]);
                }),
                const SizedBox(height: 24),
                Text(_android ? '按设置自动刷新 · 主界面显示全部账户 · 小组件显示勾选账户' : '模拟快照：2026-09-22 · 协议 v1', style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
          },
        ),
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.hideMoney, required this.selected});
  final Account account;
  final bool hideMoney;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final name = switch (account.provider) {
      'deepseek' => 'DeepSeek API',
      'openrouter' => 'OpenRouter',
      'oneapi' => 'OneAPI 兼容接口',
      'custom' => 'API 余额',
      'subscription' => '代理订阅',
      'aliyun' => '阿里云',
      'tencent' => '腾讯云',
      'kimi' => 'Kimi（国内站）',
      'openai' => 'OpenAI · 本月费用',
      'zhipu' => '智谱 · 实验性余额',
      _ => account.provider,
    };
    return Card(
      margin: EdgeInsets.zero,
      color: AstracctTheme.accountSurface(account.provider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AstracctTheme.success : const Color(0xFFDCE2ED), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(account.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          for (final metric in account.metrics) ...[
            MetricLine(metric: metric, hideMoney: hideMoney),
            const SizedBox(height: 12),
          ],
          const Divider(),
          Text(
            account.lastSuccessAt == null
                ? '尚无成功记录'
                : '上次成功：${_formatTime(account.lastSuccessAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}

String _formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
