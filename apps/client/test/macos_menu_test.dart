import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/macos_menu_bar.dart';
import 'package:quota_hub/snapshot.dart';

class MenuHost implements MacMenuHost {
  String? saved;
  bool failSave = false, failUpdate = false;
  final updates = <Map<String, Object>>[];
  Future<void> Function(String, Object?)? action;
  Completer<void>? block;
  @override
  Future<String?> initialize(Future<void> Function(String, Object?) onAction) async { action = onAction; return saved; }
  @override
  Future<void> select(String id) async { if (failSave) throw StateError('disk'); saved = id; }
  @override
  Future<void> update(Map<String, Object> data) async {
    if (failUpdate) throw StateError('native');
    if (block != null) await block!.future;
    updates.add(data);
  }
  @override
  void dispose() {}
}
Account fixture({String id = 'account_usd', MetricState state = MetricState.ok, String key = 'available', String? value = '0'}) => Account(
  id: id, provider: key == 'month_spent' ? 'openai' : 'openrouter', label: '测试账户 · USD',
  lastSuccessAt: value == null ? null : DateTime.utc(2026, 10, 8),
  metrics: [Metric(key: key, kind: 'money', state: state, value: value, unit: 'USD', errorCode: state == MetricState.stale || state == MetricState.error ? 'timeout' : null)],
);
Future<void> flush() async { await Future<void>.delayed(Duration.zero); }

void main() {
  test('menu selection round-trips separately from account credentials and can clear to icon only', () async {
    final host = MenuHost(); final menu = MacMenuController(host: host);
    await menu.initialize((_, _) async {});
    menu.update([fixture()], hidden: false); await flush();
    expect(host.updates.last['title'], '');
    await menu.select(menu.choices.single.id);
    menu.update([fixture()], hidden: false); await flush();
    expect(host.updates.last['title'], '0.00 USD');
    final restored = MacMenuController(host: host);
    await restored.initialize((_, _) async {});
    expect(restored.selected, menu.selected);
    await menu.select('not-an-account'); expect(menu.selected, restored.selected);
    host.failSave = true; await menu.select(''); expect(menu.selected, restored.selected);
    host.failSave = false; await menu.select(''); menu.update([fixture()], hidden: false); await flush();
    expect(host.updates.last['title'], '');
    menu.dispose(); restored.dispose();
  });
  test('stale unknown costs privacy and vault failure have unambiguous status text', () async {
    final host = MenuHost(); final menu = MacMenuController(host: host);
    await menu.initialize((_, _) async {}); menu.update([fixture()], hidden: false);
    await menu.select(menu.choices.single.id);
    menu.update([fixture(state: MetricState.stale)], hidden: false); await flush();
    expect(host.updates.last['title'], '过期 0.00 USD');
    menu.update([fixture(value: '123.45')], hidden: true); await flush();
    expect(host.updates.last.toString(), isNot(contains('123.45')));
    expect(host.updates.last['title'], '•••• USD');
    menu.update([fixture(state: MetricState.unknown, value: null)], hidden: false); await flush();
    expect(host.updates.last['title'], '未知');
    menu.update([fixture(state: MetricState.error, value: null)], hidden: false); await flush();
    expect(host.updates.last['title'], '失败 暂不可用');
    menu.update([fixture()], hidden: false, storageFailed: true); await flush();
    expect(host.updates.last['title'], '存储异常');
    menu.update([], hidden: false); await flush(); expect(host.updates.last['title'], '未选择');
    menu.update([fixture(key: 'month_spent', value: '20')], hidden: false);
    await menu.select(menu.choices.single.id);
    menu.update([fixture(key: 'month_spent', value: '20')], hidden: false); await flush();
    expect(host.updates.last['title'], '费用 20.00 USD');
    expect(host.updates.last['tooltip'].toString(), contains('本月费用'));
    menu.dispose();
  });
  test('OpenAI selection survives its unknown placeholder becoming a monthly cost', () async {
    final unknown = fixture(state: MetricState.unknown, value: null);
    final openai = Account(id: unknown.id, provider: 'openai', label: unknown.label,
      lastSuccessAt: null, metrics: unknown.metrics);
    final host = MenuHost(); final menu = MacMenuController(host: host);
    await menu.initialize((_, _) async {});
    menu.update([openai], hidden: false); await menu.select(menu.choices.single.id);
    menu.update([openai], hidden: false); await flush();
    expect(host.updates.last['title'], '费用 未知');
    menu.update([fixture(key: 'month_spent', value: '4')], hidden: false); await flush();
    expect(host.updates.last['title'], '费用 4.00 USD');
    menu.dispose();
  });
  test('native updates are serialized and recover on the next account refresh', () async {
    final host = MenuHost()..block = Completer<void>(); final menu = MacMenuController(host: host);
    await menu.initialize((_, _) async {});
    menu.update([fixture()], hidden: false); await menu.select(menu.choices.single.id);
    menu.update([fixture(value: '5')], hidden: false); menu.update([fixture(value: '9')], hidden: false);
    host.block!.complete(); await flush();
    expect(host.updates.last['title'], '9.00 USD');
    host.failUpdate = true; menu.update([fixture(value: '11')], hidden: false); await flush();
    expect(menu.error, isNotNull);
    host.failUpdate = false; menu.update([fixture(value: '12')], hidden: false); await flush();
    expect(host.updates.last['title'], '12.00 USD');
    menu.dispose();
  });
}
