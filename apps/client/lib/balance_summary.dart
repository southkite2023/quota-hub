import 'package:flutter/material.dart';
import 'snapshot.dart';
import 'app_theme.dart';

class BalanceSummary extends StatelessWidget {
  const BalanceSummary({super.key, required this.account, required this.hideMoney});
  final Account account;
  final bool hideMoney;
  @override
  Widget build(BuildContext context) {
    final balances = account.metrics.where((m) => {'available', 'available_credit', 'month_spent', 'remaining', 'used', 'total', 'expires_at'}.contains(m.key)).toList();
    return Card(color: AstracctTheme.accountSurface(account.provider), child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(account.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final metric in balances) MetricLine(metric: metric, hideMoney: hideMoney),
        if (balances.isEmpty) const Text('暂无可用余额'),
      ],
    )));
  }
}

class MetricLine extends StatelessWidget {
  const MetricLine({required this.metric, required this.hideMoney});
  final Metric metric;
  final bool hideMoney;

  @override
  Widget build(BuildContext context) {
    final label = switch (metric.key) {
      'available' => '可用余额',
      'available_credit' => '可用额度',
      'cash_balance' => '现金余额',
      'bonus' => '赠送余额',
      'cash' => '充值余额',
      'purchased' => '累计购买额度',
      'spent' => '已用额度',
      'month_spent' => '本月费用（UTC）',
      'voucher' => '代金券余额',
      'frozen' => '冻结余额',
      'remaining' => '剩余流量',
      'used' => '已使用流量',
      'total' => '套餐总流量',
      'expires_at' => '到期时间',
      _ => metric.key,
    };
    final expired = metric.kind == 'expiry' && metric.state == MetricState.ok &&
        metric.value != null && !DateTime.parse(metric.value!).isAfter(DateTime.now());
    final status = expired ? '已过期' : switch (metric.state) {
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
        Text(status, style: TextStyle(color: expired ? AstracctTheme.error : switch (metric.state) {
          MetricState.ok => AstracctTheme.success,
          MetricState.unknown => AstracctTheme.muted,
          MetricState.stale => AstracctTheme.warning,
          MetricState.error => AstracctTheme.error,
        })),
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

