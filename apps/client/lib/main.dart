import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snapshot.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetBridge.listen(_openWidgetAccount);
    unawaited(_loadWidgetTarget());
  }

  Future<void> _loadWidgetTarget() async {
    final hidden = await WidgetBridge.savedHideMoney();
    if (!mounted) return;
    setState(() => _hideMoney = hidden);
    final accountId = await WidgetBridge.initialAccount();
    if (!mounted) return;
    if (accountId == null) {
      await WidgetBridge.showScenario('overview', hideMoney: _hideMoney);
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
    unawaited(WidgetBridge.showScenario(scenario, hideMoney: _hideMoney));
  }

  void _selectScenario(String scenario) {
    setState(() {
      _selected = scenario;
      _widgetAccountId = null;
    });
    unawaited(WidgetBridge.showScenario(scenario, hideMoney: _hideMoney));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quota Hub'), actions: [
          IconButton(
            tooltip: _hideMoney ? '显示金额' : '隐藏金额',
            icon: Icon(_hideMoney ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () {
              setState(() => _hideMoney = !_hideMoney);
              unawaited(WidgetBridge.showScenario(_selected, hideMoney: _hideMoney));
            },
          ),
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
            return SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Text('演示数据 · 未连接真实账户', style: TextStyle(color: Color(0xFF8FD8BA))),
                const SizedBox(height: 12),
                Text('账户概览', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('三类账户共用一份版本化快照。金额与流量均为虚构示例。'),
                if (_widgetAccountId != null) ...[
                  const SizedBox(height: 10),
                  const Text('已从桌面组件打开对应账户', style: TextStyle(color: Color(0xFF8FD8BA))),
                ],
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: [
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
                Text('模拟快照：2026-09-22 · 协议 v1', style: Theme.of(context).textTheme.bodySmall),
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
      'cash' => '现金余额',
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
