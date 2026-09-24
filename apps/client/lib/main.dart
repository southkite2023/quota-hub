import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'api_accounts.dart';
import 'account_settings.dart';
import 'package:flutter/services.dart';

import 'snapshot.dart';
import 'live_snapshot.dart';
import 'widget_bridge.dart';

void main() => runApp(const QuotaHubApp());

class QuotaHubApp extends StatelessWidget {
  const QuotaHubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Quota Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF72DAB2), brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF0D1118),
        ),
        home: const Dashboard(),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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
    final payload = '$raw:$_hideMoney';
    if (payload == _lastWidgetPayload) return;
    _lastWidgetPayload = payload;
    try {
      await WidgetBridge.showLiveSnapshot(raw, hideMoney: _hideMoney);
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
    if (mounted) await _personal.initialize();
  }

  void _settings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountSettings(connection: _personal)));
  }

  @override
  void dispose() {
    _personal.removeListener(_personalChanged);
    // In-flight requests may finish after leaving the dashboard.
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetBridge.listen(_openWidgetAccount);
    if (_android) {
      _personal.addListener(_personalChanged);
      unawaited(_initializePersonal());
    } else {
      unawaited(_loadWidgetTarget());
      if (_serverConfigured) unawaited(_refreshLive());
    }
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
        appBar: AppBar(title: const Text('Quota Hub'), actions: [
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
          if (_android) IconButton(tooltip: 'API 账户设置', icon: const Icon(Icons.settings_outlined), onPressed: _settings),
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
                Text(_android ? (_personal.connected ? 'API 账户余额 · 各平台分别查询' : '添加 API 账户，集中查看余额') : liveConfigured ? 'DeepSeek 实时查询 · 另外两项为演示数据' : '演示数据 · 未连接真实账户', style: const TextStyle(color: Color(0xFF8FD8BA))),
                if (_android) ...[
                  const SizedBox(height: 12),
                  if (!_personal.ready || _personal.busy) const LinearProgressIndicator(),
                  if (_personal.error != null) Text(_personal.error!, style: const TextStyle(color: Color(0xFFFFC77D))),
                  for (final entry in _personal.entries.where((e) => _personal.errors.containsKey(e.id))) Text('${entry.name}：${_personal.errors[entry.id]}', style: const TextStyle(color: Color(0xFFFFC77D))),
                  if (_widgetError != null) Text(_widgetError!, style: const TextStyle(color: Color(0xFFFFC77D))),
                  FilledButton.icon(onPressed: _personal.ready ? _settings : null, icon: const Icon(Icons.link), label: const Text('管理 / 添加 API 账户')),
                ],
                if (_serverConfigured && _loadingLive) const LinearProgressIndicator(),
                if (_serverConfigured && _liveError != null) Text(_liveError!, style: const TextStyle(color: Color(0xFFFFC77D))),
                if (_serverConfigured && _liveAccount == null) const Text('DeepSeek 尚未取得余额。'),
                const SizedBox(height: 12),
                Text('账户概览', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(_android ? (_personal.connected ? '每个账户单独更新，不跨币种相加。' : '选择服务商，配置账户后验证并查看余额。') : liveConfigured ? 'DeepSeek 经自托管服务查询；订阅和阿里云仍为虚构示例。' : '三类账户共用一份版本化快照。金额与流量均为虚构示例。'),
                if (_widgetAccountId != null) ...[
                  const SizedBox(height: 10),
                  const Text('已从桌面组件打开对应账户', style: TextStyle(color: Color(0xFF8FD8BA))),
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
                Text(_android ? '打开应用或点击刷新时更新 · 不同币种分别显示' : '模拟快照：2026-09-22 · 协议 v1', style: Theme.of(context).textTheme.bodySmall),
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
      _ => account.provider,
    };
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? const Color(0xFF8FD8BA) : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(account.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          for (final metric in account.metrics) ...[
            _MetricLine(metric: metric, hideMoney: hideMoney),
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

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.metric, required this.hideMoney});
  final Metric metric;
  final bool hideMoney;

  @override
  Widget build(BuildContext context) {
    final label = switch (metric.key) {
      'available' => '可用余额',
      'bonus' => '赠送余额',
      'cash' => '充值余额',
      'purchased' => '累计购买额度',
      'spent' => '已用额度',
      'remaining' => '剩余流量',
      'expires_at' => '到期时间',
      _ => metric.key,
    };
    final status = switch (metric.state) {
      MetricState.ok => '正常',
      MetricState.unknown => '未知',
      MetricState.stale => '缓存已过期',
      MetricState.error => '查询失败',
    };
    final value = hideMoney && metric.kind == 'money' && metric.value != null
        ? '•••• ${metric.unit}'
        : metric.displayValue;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Text(status, style: TextStyle(color: metric.state == MetricState.ok
            ? const Color(0xFF8FD8BA) : const Color(0xFFFFC77D))),
      ]),
      const SizedBox(height: 5),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      if (metric.state == MetricState.stale) Text('上次成功值 · ${_errorLabel(metric.errorCode)}', style: Theme.of(context).textTheme.bodySmall),
      if (metric.state == MetricState.error) Text(_errorLabel(metric.errorCode), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

String _errorLabel(String? code) => switch (code) {
      'timeout' => '连接超时',
      'unauthorized' => '授权失败',
      'rate_limited' => '请求过频',
      'provider_unavailable' => '服务不可用',
      _ => '更新失败',
    };

String _formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
