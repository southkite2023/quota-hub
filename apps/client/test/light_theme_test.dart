import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/main.dart';
import 'package:quota_hub/snapshot.dart';

void main() {
  test('status text stays readable on every account surface', () {
    for (final provider in ['deepseek', 'aliyun', 'subscription', 'custom']) {
      final background = AstracctTheme.accountSurface(provider).computeLuminance();
      for (final foreground in [AstracctTheme.success, AstracctTheme.warning,
        AstracctTheme.error, AstracctTheme.muted]) {
        final luminance = foreground.computeLuminance();
        expect((background + 0.05) / (luminance + 0.05), greaterThanOrEqualTo(4.5),
          reason: 'Status text must meet normal-text contrast on $provider');
      }
    }
  });

  testWidgets('light balance card preserves privacy and failure meaning at phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const account = Account(id: 'work', provider: 'deepseek', label: '工作账户',
      lastSuccessAt: null, metrics: [
        Metric(key: 'available', kind: 'money', state: MetricState.stale,
          value: '0.00', unit: 'CNY', errorCode: 'timeout'),
        Metric(key: 'available_credit', kind: 'money', state: MetricState.unknown,
          value: null, unit: 'CNY'),
        Metric(key: 'month_spent', kind: 'money', state: MetricState.error,
          value: null, unit: 'USD', errorCode: 'unauthorized'),
      ]);
    await tester.pumpWidget(MaterialApp(theme: AstracctTheme.light(), home: const Scaffold(
      body: BalanceSummary(account: account, hideMoney: true))));
    final context = tester.element(find.byType(BalanceSummary));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(find.text('0.00 CNY'), findsNothing);
    expect(find.text('•••• CNY'), findsOneWidget);
    expect(find.text('缓存已过期'), findsOneWidget);
    expect(find.text('未知'), findsNWidgets(2));
    expect(find.text('查询失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
