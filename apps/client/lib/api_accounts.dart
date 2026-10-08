import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'deepseek_connection.dart';
import 'snapshot.dart';
import 'aliyun_balance.dart';
import 'tencent_balance.dart';
import 'openai_costs.dart';

enum BalanceProvider { deepseek, openrouter, oneapi, custom, aliyun, tencent, kimi, openai, zhipu }

enum BalanceCategory { ai, cloud, nodes }

extension CategoryLabel on BalanceCategory {
  String get label => switch (this) {
    BalanceCategory.ai => 'AI 订阅',
    BalanceCategory.cloud => '云服务器',
    BalanceCategory.nodes => '节点订阅',
  };
  bool supports(BalanceProvider provider) => provider == BalanceProvider.custom ||
    switch (this) {
      BalanceCategory.ai => !provider.isCloud,
      BalanceCategory.cloud => provider.isCloud,
      BalanceCategory.nodes => false,
    };
}

extension ProviderLabel on BalanceProvider {
  bool get isCloud => this == BalanceProvider.aliyun || this == BalanceProvider.tencent;
  String get label => switch (this) {
    BalanceProvider.deepseek => 'DeepSeek',
    BalanceProvider.openrouter => 'OpenRouter',
    BalanceProvider.oneapi => 'OneAPI 兼容接口',
    BalanceProvider.custom => '自定义余额接口',
    BalanceProvider.aliyun => '阿里云',
    BalanceProvider.tencent => '腾讯云',
    BalanceProvider.kimi => 'Kimi（国内站）',
    BalanceProvider.zhipu => '智谱 · 实验性余额',
    BalanceProvider.openai => 'OpenAI · 本月费用',
  };
}

/// Configuration stays inside the encrypted vault. Never put this object in a snapshot.
class ApiAccount {
  const ApiAccount({required this.id, required this.provider, required this.name,
    required this.key, this.endpoint = '', this.balancePath = 'data.balance', this.currency = 'USD', this.accessKeyId = '', BalanceCategory? category}) : _category = category;
  final String id, name, key, endpoint, balancePath, currency, accessKeyId;
  final BalanceProvider provider;
  final BalanceCategory? _category;
  BalanceCategory get category => _category ?? (provider.isCloud ? BalanceCategory.cloud : BalanceCategory.ai);
  Uri get uri => switch (provider) {
    BalanceProvider.zhipu => Uri.https('open.bigmodel.cn', '/api/biz/account/query-customer-account-report'),
    BalanceProvider.kimi => Uri.https('api.moonshot.cn', '/v1/users/me/balance'),
    BalanceProvider.openai => Uri.https('api.openai.com', '/v1/organization/costs'),
    BalanceProvider.tencent => Uri.https('billing.tencentcloudapi.com', '/'),
    BalanceProvider.aliyun => Uri.https('business.aliyuncs.com', '/'),
    BalanceProvider.deepseek => Uri.https('api.deepseek.com', '/user/balance'),
    BalanceProvider.openrouter => Uri.https('openrouter.ai', '/api/v1/credits'),
    BalanceProvider.oneapi || BalanceProvider.custom => Uri.parse(endpoint),
  };
  void validate() {
    if (!category.supports(provider)) {
      throw const DeepSeekFailure('请选择该余额种类支持的服务商。', 'provider_unavailable');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id) || name.trim().isEmpty || name.length > 60) {
      throw const DeepSeekFailure('请填写账户名称（最多 60 字）。', 'provider_unavailable');
    }
    if (provider.isCloud && !RegExp(r'^[A-Za-z0-9]{1,128}$').hasMatch(accessKeyId)) {
      throw const DeepSeekFailure('请填写有效的 AccessKey ID / SecretId。', 'unauthorized');
    }
    if (key.isEmpty || key.length > 4096 || RegExp(r'\s|[^\x21-\x7E]').hasMatch(key)) {
      throw DeepSeekFailure(provider.isCloud ? '请填写完整的 Secret，不要包含空格或换行。' : '请填写完整 API Key，不要包含空格或换行。', 'unauthorized');
    }
    if (provider == BalanceProvider.custom || provider == BalanceProvider.oneapi) {
      final target = Uri.tryParse(endpoint);
      if (target == null || target.scheme != 'https' || target.host.isEmpty ||
          target.userInfo.isNotEmpty || target.hasQuery || target.hasFragment || endpoint.length > 2048) {
        throw const DeepSeekFailure('请填写完整 HTTPS 余额接口地址，不含账号、查询参数或片段。', 'provider_unavailable');
      }
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*|\.[0-9]+)*$').hasMatch(balancePath) ||
          balancePath.length > 200 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
        throw const DeepSeekFailure('请检查余额字段路径和三字母币种。', 'provider_unavailable');
      }
    }
  }
  Map<String, dynamic> toJson() => {'id': id, 'provider': provider.name, 'category': category.name, 'name': name,
    'key': key, 'accessKeyId': accessKeyId, 'endpoint': endpoint, 'balancePath': balancePath, 'currency': currency};
  factory ApiAccount.fromJson(Map<String, dynamic> json) {
    final account = ApiAccount(id: json['id'] as String,
      provider: BalanceProvider.values.byName(json['provider'] as String),
      category: json['category'] == null ? null : BalanceCategory.values.byName(json['category'] as String),
      name: json['name'] as String, key: json['key'] as String,
      accessKeyId: json['accessKeyId'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '', balancePath: json['balancePath'] as String? ?? 'data.balance',
      currency: json['currency'] as String? ?? 'USD');
    account.validate();
    return account;
  }
}

abstract class AccountsStore {
  Future<String?> read();
  Future<void> write(String value);
}
class AndroidAccountsStore implements AccountsStore {
  static const _channel = MethodChannel('quota_hub/accounts');
  @override
  Future<String?> read() => _channel.invokeMethod<String>('readAccounts');
  @override
  Future<void> write(String value) => _channel.invokeMethod<void>('saveAccounts', value);
}

/// Exact decimal arithmetic after parsing the provider's JSON numeric representation.
(BigInt, int) _decimal(Object? value) {
  if (value is! String && value is! num) throw const FormatException();
  final text = value.toString();
  if (text.length > 128) throw const FormatException();
  final match = RegExp(r'^(-?)(0|[1-9][0-9]*)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$').firstMatch(text);
  if (match == null) throw const FormatException();
  final fraction = match[3] ?? '';
  final exponent = int.tryParse(match[4] ?? '0');
  if (exponent == null || exponent.abs() > 100) throw const FormatException();
  var number = BigInt.parse('${match[1]}${match[2]}$fraction');
  var scale = fraction.length - exponent;
  if (scale < 0) { number *= BigInt.from(10).pow(-scale); scale = 0; }
  return (number, scale);
}
String _formatDecimal(BigInt number, int scale) {
  final digits = number.abs().toString().padLeft(scale + 1, '0');
  final value = scale == 0 ? digits : '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  return '${number.isNegative ? '-' : ''}$value';
}
String decimalValue(Object? value) { final (number, scale) = _decimal(value); return _formatDecimal(number, scale); }
String decimalDifference(Object? first, Object? second) {
  final (a, sa) = _decimal(first); final (b, sb) = _decimal(second);
  final scale = max(sa, sb);
  return _formatDecimal(a * BigInt.from(10).pow(scale - sa) - b * BigInt.from(10).pow(scale - sb), scale);
}

String decimalHundredth(Object value) {
  final (number, scale) = _decimal(value);
  return _formatDecimal(number, scale + 2);
}

class BalanceApi {
  BalanceApi({http.Client Function()? clientFactory, DateTime Function()? now})
      : _factory = clientFactory ?? http.Client.new, _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final http.Client Function() _factory;
  Future<Map<String, dynamic>> fetch(ApiAccount account) async {
    account.validate();
    if (account.provider == BalanceProvider.deepseek) {
      return _identify(await DeepSeekApi(clientFactory: _factory).balance(account.key), account);
    }
    final client = _factory();
    try {
      if (account.provider == BalanceProvider.tencent) return await fetchTencentBalance(client, account);
      if (account.provider == BalanceProvider.aliyun) return await fetchAliyunBalance(client, account);
      if (account.provider == BalanceProvider.oneapi) return await _oneApi(client, account);
      if (account.provider == BalanceProvider.openai) return await fetchOpenAiCosts(client, account, _now().toUtc());
      final request = http.Request('GET', account.uri)..followRedirects = false
        ..headers.addAll({'Authorization': account.provider == BalanceProvider.zhipu ? account.key : 'Bearer ${account.key}', 'Accept': 'application/json'});
      final response = await (() async => http.Response.fromStream(await client.send(request)))()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw DeepSeekFailure(account.provider == BalanceProvider.openrouter
          ? '授权失败。OpenRouter 账户余额需要 Management Key，请检查权限。'
          : 'Key 无效或没有余额查询权限。', 'unauthorized');
      }
      if (response.statusCode == 429) throw const DeepSeekFailure('查询过频，请稍后重试。', 'rate_limited');
      if (response.statusCode != 200) throw const DeepSeekFailure('平台暂时无法查询，请稍后重试。', 'provider_unavailable');
      final data = jsonDecode(response.body);
      if (account.provider == BalanceProvider.zhipu && data is Map &&
          {401, 403, 1001, 1002, 1003}.contains(data['code'])) {
        throw const DeepSeekFailure('智谱实验性余额接口未授权；该接口可能不接受此 API Key，请在官网查询。', 'unauthorized');
      }
      if (data is Map && (data['error'] != null || data['success'] == false)) throw const FormatException();
      final metrics = <Map<String, dynamic>>[];
      void money(String key, String amount, String currency) => metrics.add({
        'key': key, 'kind': 'money', 'state': 'ok', 'value': amount, 'unit': currency,
      });
      var currency = account.currency;
      if (account.provider == BalanceProvider.openrouter) {
        if (data is! Map || data['data'] is! Map) throw const FormatException();
        currency = 'USD';
        money('available', decimalDifference(data['data']['total_credits'], data['data']['total_usage']), currency);
        money('purchased', decimalValue(data['data']['total_credits']), currency);
        money('spent', decimalValue(data['data']['total_usage']), currency);
      } else if (account.provider == BalanceProvider.zhipu) {
        if (data is! Map || data['code'] != 200 || data['data'] is! Map) throw const FormatException();
        currency = 'CNY';
        money('available', decimalValue(data['data']['availableBalance']), currency);
        for (final pair in [('cash_balance', 'cashBalance'), ('frozen', 'frozenBalance')]) {
          if (data['data'][pair.$2] != null) money(pair.$1, decimalValue(data['data'][pair.$2]), currency);
        }
      } else if (account.provider == BalanceProvider.kimi) {
        if (data is! Map || data['code'] != 0 || data['status'] != true || data['data'] is! Map) {
          throw const FormatException();
        }
        currency = 'CNY';
        for (final pair in [('available', 'available_balance'), ('voucher', 'voucher_balance'), ('cash_balance', 'cash_balance')]) {
          money(pair.$1, decimalValue(data['data'][pair.$2]), currency);
        }
      } else {
        dynamic value = data;
        for (final part in account.balancePath.split('.')) {
          if (value is Map) { value = value[part]; }
          else if (value is List && int.tryParse(part) != null && int.parse(part) < value.length) { value = value[int.parse(part)]; }
          else { throw const FormatException(); }
        }
        money('available', decimalValue(value), currency);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      return {'schemaVersion': 1, 'generatedAt': now, 'accounts': [{
        'id': '${account.id}_${currency.toLowerCase()}', 'provider': account.provider.name,
        'label': '${account.name} · $currency${account.provider == BalanceProvider.zhipu ? ' · 实验性' : ''}', 'lastSuccessAt': now, 'metrics': metrics,
      }]};
    } on DeepSeekFailure { rethrow; }
    on TimeoutException { throw const DeepSeekFailure('连接超时，请重试。', 'timeout'); }
    on FormatException { throw const DeepSeekFailure('未找到有效余额，请检查接口和字段路径。', 'provider_unavailable'); }
    catch (_) { throw const DeepSeekFailure('无法连接平台，请检查网络和接口设置。', 'provider_unavailable'); }
    finally { client.close(); }
  }
  Future<Map<String, dynamic>> _oneApi(http.Client client, ApiAccount account) async {
    final base = account.endpoint.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'/v1$'), '');
    Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) async {
      final request = http.Request('GET', Uri.parse('$base$path'))..followRedirects = false
        ..headers['Accept'] = 'application/json';
      if (authenticated) request.headers['Authorization'] = 'Bearer ${account.key}';
      final response = await (() async => http.Response.fromStream(await client.send(request)))()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DeepSeekFailure('Key 无效或站点未开放账单查询。', 'unauthorized');
      }
      if (response.statusCode == 429) throw const DeepSeekFailure('查询过频，请稍后重试。', 'rate_limited');
      if (response.statusCode != 200) throw const DeepSeekFailure('站点未提供兼容的余额接口。', 'provider_unavailable');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data.containsKey('error') || data['success'] == false) throw const FormatException();
      return data;
    }
    final status = await get('/api/status', authenticated: false);
    if (status['success'] != true || status['data'] is! Map || status['data']['display_in_currency'] != true) {
      throw const DeepSeekFailure('此站点未确认使用货币计费，暂不将点数或 Token 额度显示为余额。', 'provider_unavailable');
    }
    final subscription = await get('/v1/dashboard/billing/subscription');
    final usage = await get('/v1/dashboard/billing/usage');
    final limit = decimalValue(subscription['hard_limit_usd']);
    final (used, scale) = _decimal(usage['total_usage']);
    final spent = _formatDecimal(used, scale + 2);
    final (limitNumber, limitScale) = _decimal(limit);
    final unlimited = limitNumber >= BigInt.from(100000000) * BigInt.from(10).pow(limitScale);
    final now = DateTime.now().toUtc().toIso8601String();
    return {'schemaVersion': 1, 'generatedAt': now, 'accounts': [{
      'id': '${account.id}_${account.currency.toLowerCase()}', 'provider': 'oneapi',
      'label': '${account.name} · ${account.currency} · ${unlimited ? '无限额度，余额未知' : '站点返回额度（可能是令牌额度）'}',
      'lastSuccessAt': now, 'metrics': [
        {'key': 'available', 'kind': 'money', 'state': unlimited ? 'unknown' : 'ok',
          'value': unlimited ? null : decimalDifference(limit, spent), 'unit': account.currency},
        {'key': 'spent', 'kind': 'money', 'state': 'ok', 'value': spent, 'unit': account.currency},
      ],
    }]};
  }
  Map<String, dynamic> _identify(Map<String, dynamic> snapshot, ApiAccount account) {
    for (final item in snapshot['accounts'] as List) {
      item['id'] = '${account.id}_${(item['id'] as String).split('_').last}';
      item['label'] = (item['label'] as String).replaceFirst('我的 DeepSeek', account.name);
    }
    return snapshot;
  }
}

class ApiAccounts extends ChangeNotifier {
  ApiAccounts({AccountsStore? store, BalanceApi? api, DateTime Function()? now}) : _now = now ?? DateTime.now, _store = store ?? AndroidAccountsStore(), _api = api ?? BalanceApi();
  final DateTime Function() _now;
  final AccountsStore _store;
  final BalanceApi _api;
  List<ApiAccount> _entries = [];
  final Map<String, Map<String, dynamic>> _snapshots = {};
  final Map<String, String> errors = {};
  List<String> _widgetAccountIds = [];
  List<String> get widgetAccountIds => List.unmodifiable(_widgetAccountIds);
  String? get widgetAccountId => _widgetAccountIds.isEmpty ? null : _widgetAccountIds.first;
  bool ready = false, busy = false, storageFailed = false;
  int refreshMinutes = 5;
  bool backgroundRefresh = false;
  String? backgroundStatus;
  Timer? _refreshTimer;
  DateTime? nextRefreshAt;
  bool _foreground = false, _disposed = false;

  void _emit() { if (!_disposed) notifyListeners(); }
  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    _scheduleRefresh();
  }
  void _scheduleRefresh({bool reset = false}) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_disposed || !ready || storageFailed || !connected || refreshMinutes == 0) {
      nextRefreshAt = null;
      return;
    }
    if (reset || nextRefreshAt == null) nextRefreshAt = _now().add(Duration(minutes: refreshMinutes));
    if (!_foreground || busy) return;
    final remaining = nextRefreshAt!.difference(_now());
    _refreshTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      _refreshTimer = null;
      unawaited(refresh());
    });
  }
  Future<bool> setRefreshMinutes(int minutes) async {
    if (minutes < 0 || minutes > 1440 || busy || !ready || storageFailed || _disposed) return false;
    busy = true; error = null; _emit();
    var saved = false;
    try {
      await _store.write(_serialize(_entries, widgetAccountId, minutes: minutes));
      refreshMinutes = minutes;
      saved = true;
      return true;
    } catch (_) { error = '刷新设置保存失败，原设置未更改。'; return false; }
    finally { busy = false; _scheduleRefresh(reset: saved); _emit(); }
  }
  Future<void> readBackgroundStatus() async {
    if (_store is! AndroidAccountsStore || _disposed) return;
    try { backgroundStatus = await const MethodChannel('quota_hub/refresh').invokeMethod<String>('status'); } catch (_) { backgroundStatus = '无法读取后台刷新状态'; }
    _emit();
  }
  Future<bool> setBackgroundRefresh(bool enabled) async {
    if (busy || !ready || storageFailed || _disposed) return false;
    busy = true; error = null; _emit();
    try {
      if (enabled && _store is AndroidAccountsStore) {
        final granted = await const MethodChannel('quota_hub/refresh').invokeMethod<bool>('requestNotifications');
        if (granted != true) { error = '后台刷新需要通知权限，请在系统设置中允许通知后重试。'; return false; }
      }
      await _store.write(_serialize(_entries, widgetAccountId, background: enabled));
      backgroundRefresh = enabled;
      if (_store is AndroidAccountsStore) await const MethodChannel('quota_hub/refresh').invokeMethod<void>(enabled ? 'start' : 'stop');
      await readBackgroundStatus();
      return true;
    } catch (_) { error = '后台刷新未能启动，请检查通知权限后重试。'; return false; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
  String? error;
  List<ApiAccount> get entries => List.unmodifiable(_entries);
  bool get connected => _entries.isNotEmpty;
  List<Account> get accounts => [for (final entry in _entries)
    ...DemoCase.fromJson({...(_snapshots[entry.id] ?? _empty(entry)), 'name': 'personal'}).accounts];
  String get raw {
    final ordered = [..._entries];
    final selected = ordered.indexWhere((a) => a.id == widgetAccountId);
    if (selected > 0) ordered.insert(0, ordered.removeAt(selected));
    return jsonEncode({'schemaVersion': 1, 'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': [for (final entry in ordered) ...((_snapshots[entry.id] ?? _empty(entry))['accounts'] as List)]});
  }
  String get widgetRaw => jsonEncode({'schemaVersion': 1, 'generatedAt': _now().toUtc().toIso8601String(),
    'accounts': [for (final entry in _entries.where((e) => _widgetAccountIds.contains(e.id)))
      ...((_snapshots[entry.id] ?? _empty(entry))['accounts'] as List)]});
  Map<String, dynamic> _empty(ApiAccount entry) {
    final currency = (entry.provider == BalanceProvider.deepseek || entry.provider == BalanceProvider.kimi || entry.provider == BalanceProvider.zhipu || entry.provider.isCloud) ? 'CNY' : (entry.provider == BalanceProvider.openrouter || entry.provider == BalanceProvider.openai) ? 'USD' : entry.currency;
    return {'schemaVersion': 1, 'generatedAt': DateTime.now().toUtc().toIso8601String(), 'accounts': [{
      'id': '${entry.id}_${currency.toLowerCase()}', 'provider': entry.provider.name,
      'label': '${entry.name} · $currency', 'lastSuccessAt': null,
      'metrics': [{'key': entry.provider == BalanceProvider.aliyun ? 'available_credit' : 'available', 'kind': 'money', 'state': 'unknown', 'value': null, 'unit': currency}],
    }]};
  }
  Future<void> initialize({bool query = true}) async {
    try {
      final raw = await _store.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1) throw const FormatException();
        final entries = (data['accounts'] as List).map((e) => ApiAccount.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (entries.length > 20 || entries.map((e) => e.id).toSet().length != entries.length) throw const FormatException();
        _entries = entries;
        final selected = data['widgetAccountIds'];
        if (selected != null && (selected is! List || selected.any((id) => id is! String))) throw const FormatException();
        final oldSelected = data['widgetAccountId'] as String?;
        _widgetAccountIds = (selected == null ? (oldSelected == null ? entries.map((e) => e.id).toList() : [oldSelected]) : List<String>.from(selected as List))
          .where((id) => entries.any((e) => e.id == id)).toSet().toList();
        final interval = data['refreshMinutes'] ?? 5;
        if (interval is! int || interval < 0 || interval > 1440) throw const FormatException();
        refreshMinutes = interval;
        backgroundRefresh = data['backgroundRefresh'] == true;
      }
    } catch (_) { storageFailed = true; error = '无法读取已保存账户。为避免覆盖原数据，暂时不能更改账户，请重启应用重试。'; }
    ready = true; _emit();
    if (query && connected) await refresh();
  }
  void restoreSnapshot(String? source) {
    if (source == null) return;
    try {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      DemoCase.fromJson({...raw, 'name': 'cached'});
      for (final entry in _entries) {
        final matching = (raw['accounts'] as List).where((item) => item['provider'] == entry.provider.name &&
          (item['metrics'] as List).isNotEmpty && item['id'] == '${entry.id}_${(item['metrics'][0]['unit'] as String).toLowerCase()}').toList();
        if (matching.isNotEmpty) _snapshots[entry.id] = {...raw, 'accounts': matching};
      }
    } catch (_) { /* Ignore invalid snapshots, never the encrypted account configuration. */ }
  }
  String _serialize(List<ApiAccount> entries, String? selected, {int? minutes, bool? background, List<String>? selectedIds}) => jsonEncode({
    'version': 1, 'backgroundRefresh': background ?? backgroundRefresh, 'refreshMinutes': minutes ?? refreshMinutes, 'widgetAccountId': selected, 'widgetAccountIds': selectedIds ?? _widgetAccountIds, 'accounts': entries.map((e) => e.toJson()).toList(),
  });
  Future<bool> save(ApiAccount candidate) async {
    if (busy || !ready || storageFailed || _disposed) return false;
    busy = true; error = null; _emit();
    try {
      candidate.validate();
      final next = [..._entries];
      final index = next.indexWhere((e) => e.id == candidate.id);
      if (index < 0 && next.length >= 20) throw const DeepSeekFailure('最多保存 20 个账户。', 'provider_unavailable');
      final snapshot = await _api.fetch(candidate);
      if (index < 0) { next.add(candidate); } else { next[index] = candidate; }
      final selected = index < 0 ? [..._widgetAccountIds, candidate.id] : [..._widgetAccountIds];
      await _store.write(_serialize(next, selected.isEmpty ? null : selected.first, selectedIds: selected));
      _entries = next; _widgetAccountIds = selected; _snapshots[candidate.id] = snapshot; errors.remove(candidate.id);
      return true;
    } on DeepSeekFailure catch (failure) { error = failure.message; return false; }
    catch (_) { error = '本机保存失败，原有账户未更改。'; return false; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
  Future<void> refresh() async {
    if (busy || !ready || storageFailed || !connected || _disposed) return;
    _refreshTimer?.cancel();
    busy = true;
    var lease = false;
    if (_store is AndroidAccountsStore) {
      try { lease = await const MethodChannel('quota_hub/refresh').invokeMethod<bool>('acquire') ?? false; } catch (_) { lease = false; }
      if (!lease) { busy = false; _scheduleRefresh(reset: true); _emit(); return; }
    }
    busy = true; error = null; _emit();
    await Future.wait(_entries.map((entry) async {
      try { _snapshots[entry.id] = await _api.fetch(entry); errors.remove(entry.id); }
      catch (caught) {
        final failure = caught is DeepSeekFailure ? caught : const DeepSeekFailure('更新失败，请稍后重试。', 'provider_unavailable');
        errors[entry.id] = failure.message;
        final snapshot = _snapshots[entry.id] ?? _empty(entry);
        for (final account in snapshot['accounts'] as List) {
          for (final metric in account['metrics'] as List) {
            metric['state'] = metric['value'] == null ? 'error' : 'stale'; metric['errorCode'] = failure.code;
          }
        }
        _snapshots[entry.id] = snapshot;
      }
    }));
    if (lease) {
      try { await const MethodChannel('quota_hub/refresh').invokeMethod<void>('release'); } catch (_) { /* Native lease is also released on activity teardown. */ }
    }
    busy = false; _scheduleRefresh(reset: true); _emit();
  }
  Future<bool> remove(String id) async {
    if (busy || !ready || storageFailed || _disposed) return false;
    busy = true; error = null; _emit();
    try {
      final next = _entries.where((e) => e.id != id).toList();
      final selected = _widgetAccountIds.where((item) => item != id).toList();
      await _store.write(_serialize(next, selected.isEmpty ? null : selected.first, selectedIds: selected));
      _entries = next; _widgetAccountIds = selected; _snapshots.remove(id); errors.remove(id);
      return true;
    } catch (_) { error = '移除失败，请重试。'; return false; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
  Future<void> setWidgetSelected(String id, bool selected) async {
    if (_disposed || busy || !ready || storageFailed || !_entries.any((e) => e.id == id)) return;
    busy = true; error = null; _emit();
    try {
      final next = [..._widgetAccountIds.where((item) => item != id), if (selected) id];
      await _store.write(_serialize(_entries, next.isEmpty ? null : next.first, selectedIds: next));
      _widgetAccountIds = next;
    } catch (_) { error = '组件勾选保存失败，原选择未更改。'; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
  Future<void> selectAllWidgets(bool selected) async {
    if (_disposed || busy || !ready || storageFailed) return;
    busy = true; error = null; _emit();
    try {
      final next = selected ? _entries.map((e) => e.id).toList() : <String>[];
      await _store.write(_serialize(_entries, next.isEmpty ? null : next.first, selectedIds: next));
      _widgetAccountIds = next;
    } catch (_) { error = '组件勾选保存失败，原选择未更改。'; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
  Future<void> selectWidget(String id) async {
    if (_disposed || busy || storageFailed || !_entries.any((e) => e.id == id)) return;
    busy = true; error = null; _emit();
    try { await _store.write(_serialize(_entries, id, selectedIds: [id])); _widgetAccountIds = [id]; }
    catch (_) { error = '组件账户设置保存失败，请重试。'; }
    finally { busy = false; _scheduleRefresh(); _emit(); }
  }
}
