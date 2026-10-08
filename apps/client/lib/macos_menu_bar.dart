import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'snapshot.dart';

bool get supportsMacMenuBar => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
const macMenuChannel = MethodChannel('com.yuashie.astracct/menu_bar');

class MenuBalance {
  const MenuBalance(this.account, this.metric);
  final Account account;
  final Metric metric;
  // OpenAI's pre-query placeholder uses available; keep the eventual cost selection stable.
  String get metricKey => account.provider == 'openai' ? 'month_spent' : metric.key;
  String get id => jsonEncode([account.id, metricKey]);
  String get kind => switch (metricKey) {
    'month_spent' => '本月费用（UTC）', 'available_credit' => '可用额度',
    'cash_balance' || 'cash' => '现金余额', 'bonus' => '赠送余额',
    'voucher' => '代金券余额', 'frozen' => '冻结余额',
    'spent' => '已用额度', 'purchased' => '累计购买额度', _ => '可用余额',
  };
  String get label => '${account.label} · $kind';
  String value(bool hidden) {
    final value = hidden && metric.value != null ? '•••• ${metric.unit}' : metric.displayValue;
    final prefix = switch (metric.state) {
      MetricState.stale => '过期 ', MetricState.error => '失败 ', _ => '',
    };
    return '${metricKey == 'month_spent' ? '费用 ' : ''}$prefix$value';
  }
}

abstract interface class MacMenuHost {
  Future<String?> initialize(Future<void> Function(String, Object?) onAction);
  Future<void> select(String id);
  Future<void> update(Map<String, Object> data);
  void dispose();
}

class NativeMacMenuHost with WindowListener implements MacMenuHost {
  @override
  Future<String?> initialize(Future<void> Function(String, Object?) onAction) async {
    macMenuChannel.setMethodCallHandler((call) => onAction(call.method, call.arguments));
    final selected = await macMenuChannel.invokeMethod<String>('initialize');
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    return selected;
  }
  @override
  void onWindowClose() { unawaited(windowManager.hide()); }
  @override
  Future<void> select(String id) => macMenuChannel.invokeMethod<void>('select', id);
  @override
  Future<void> update(Map<String, Object> data) => macMenuChannel.invokeMethod<void>('update', data);
  @override
  void dispose() { windowManager.removeListener(this); macMenuChannel.setMethodCallHandler(null); }
}

class MacMenuController extends ChangeNotifier {
  MacMenuController({MacMenuHost? host}) : _host = host ?? NativeMacMenuHost();
  final MacMenuHost _host;
  String selected = '';
  String? error;
  bool ready = false, _disposed = false, _sending = false;
  Map<String, Object>? _pending;
  List<MenuBalance> choices = [];

  Future<void> initialize(Future<void> Function(String, Object?) onAction) async {
    try { selected = await _host.initialize(onAction) ?? ''; ready = true; }
    catch (_) { error = '菜单栏初始化失败，请重新打开应用。'; }
    if (!_disposed) notifyListeners();
  }
  Future<void> select(String id) async {
    if (!ready || (id.isNotEmpty && !choices.any((c) => c.id == id))) return;
    try { await _host.select(id); selected = id; error = null; }
    catch (_) { error = '菜单栏选择保存失败，请重试。'; }
    if (!_disposed) notifyListeners();
  }
  void update(List<Account> accounts, {required bool hidden, bool storageFailed = false}) {
    choices = [for (final account in accounts) for (final metric in account.metrics)
      if (metric.kind == 'money') MenuBalance(account, metric)];
    final match = choices.where((c) => c.id == selected).firstOrNull;
    // Deleted accounts never leave a stale number visible. Keep the ID to restore after vault recovery.
    final title = storageFailed ? '存储异常' : selected.isEmpty ? '' : match?.value(hidden) ?? '未选择';
    _pending = {
      'title': title.length > 40 ? '${title.substring(0, 39)}…' : title,
      'tooltip': storageFailed ? '账户存储异常，余额不可用' : match == null ? '星账 Astracct · 左键打开，右键选择余额' : '${match.label} · ${match.value(hidden)}',
      'selected': match?.id ?? '', 'hidden': hidden,
      'choices': [for (final choice in choices) {'id': choice.id, 'label': choice.label}],
    };
    if (ready) unawaited(_flush());
  }
  Future<void> _flush() async {
    if (_sending || _disposed) return;
    _sending = true;
    try {
      while (_pending != null && !_disposed) {
        final data = _pending!; _pending = null;
        await _host.update(data);
        if (error != null) { error = null; if (!_disposed) notifyListeners(); }
      }
    } catch (_) { error = '菜单栏更新失败，请重试刷新。'; if (!_disposed) notifyListeners(); }
    finally { _sending = false; }
  }
  @override
  void dispose() { _disposed = true; _host.dispose(); super.dispose(); }
}
