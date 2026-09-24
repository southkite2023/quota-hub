import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'deepseek_connection.dart';
import 'snapshot.dart';

enum BalanceProvider { deepseek, openrouter, oneapi, custom }

extension ProviderLabel on BalanceProvider {
  String get label => switch (this) {
    BalanceProvider.deepseek => 'DeepSeek',
    BalanceProvider.openrouter => 'OpenRouter',
    BalanceProvider.oneapi => 'OneAPI 兼容接口',
    BalanceProvider.custom => '自定义余额接口',
  };
}

/// Configuration stays inside the encrypted vault. Never put this object in a snapshot.
class ApiAccount {
  const ApiAccount({required this.id, required this.provider, required this.name,
    required this.key, this.endpoint = '', this.balancePath = 'data.balance', this.currency = 'USD'});
  final String id, name, key, endpoint, balancePath, currency;
  final BalanceProvider provider;
  Uri get uri => switch (provider) {
    BalanceProvider.deepseek => Uri.https('api.deepseek.com', '/user/balance'),
    BalanceProvider.openrouter => Uri.https('openrouter.ai', '/api/v1/credits'),
    BalanceProvider.oneapi || BalanceProvider.custom => Uri.parse(endpoint),
  };
  void validate() {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id) || name.trim().isEmpty || name.length > 60) {
      throw const DeepSeekFailure('请填写账户名称（最多 60 字）。', 'provider_unavailable');
    }
    if (key.isEmpty || key.length > 4096 || RegExp(r'\s|[^\x21-\x7E]').hasMatch(key)) {
      throw const DeepSeekFailure('请填写完整 API Key，不要包含空格或换行。', 'unauthorized');
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
  Map<String, dynamic> toJson() => {'id': id, 'provider': provider.name, 'name': name,
    'key': key, 'endpoint': endpoint, 'balancePath': balancePath, 'currency': currency};
  factory ApiAccount.fromJson(Map<String, dynamic> json) {
    final account = ApiAccount(id: json['id'] as String,
      provider: BalanceProvider.values.byName(json['provider'] as String),
      name: json['name'] as String, key: json['key'] as String,
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

class BalanceApi {
  BalanceApi({http.Client Function()? clientFactory}) : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  Future<Map<String, dynamic>> fetch(ApiAccount account) async {
    account.validate();
    if (account.provider == BalanceProvider.deepseek) {
      return _identify(await DeepSeekApi(clientFactory: _factory).balance(account.key), account);
    }
    final client = _factory();
    try {
      if (account.provider == BalanceProvider.oneapi) return await _oneApi(client, account);
      final request = http.Request('GET', account.uri)..followRedirects = false
        ..headers.addAll({'Authorization': 'Bearer ${account.key}', 'Accept': 'application/json'});
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
        'label': '${account.name} · $currency', 'lastSuccessAt': now, 'metrics': metrics,
      }]};
    } on DeepSeekFailure { rethrow; }
    on TimeoutException { throw const DeepSeekFailure('连接超时，请重试。', 'timeout'); }
    on FormatException { throw const DeepSeekFailure('未找到有效余额，请检查接口和字段路径。', 'provider_unavailable'); }
    catch (_) { throw const DeepSeekFailure('无法连接平台，请检查网络和接口设置。', 'provider_unavailable'); }
    finally { client.close(); }
  }
  Future<Map<String, dynamic>> _oneApi(http.Client client, ApiAccount account) async {
    final base = account.endpoint.replaceFirst(RegExp(r'/+$'), '');
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
  ApiAccounts({AccountsStore? store, BalanceApi? api}) : _store = store ?? AndroidAccountsStore(), _api = api ?? BalanceApi();
  final AccountsStore _store;
  final BalanceApi _api;
  List<ApiAccount> _entries = [];
  final Map<String, Map<String, dynamic>> _snapshots = {};
  final Map<String, String> errors = {};
  String? widgetAccountId;
  bool ready = false, busy = false, storageFailed = false;
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
  Map<String, dynamic> _empty(ApiAccount entry) {
    final currency = entry.provider == BalanceProvider.deepseek ? 'CNY' : entry.provider == BalanceProvider.openrouter ? 'USD' : entry.currency;
    return {'schemaVersion': 1, 'generatedAt': DateTime.now().toUtc().toIso8601String(), 'accounts': [{
      'id': '${entry.id}_${currency.toLowerCase()}', 'provider': entry.provider.name,
      'label': '${entry.name} · $currency', 'lastSuccessAt': null,
      'metrics': [{'key': 'available', 'kind': 'money', 'state': 'unknown', 'value': null, 'unit': currency}],
    }]};
  }
  Future<void> initialize() async {
    try {
      final raw = await _store.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1) throw const FormatException();
        final entries = (data['accounts'] as List).map((e) => ApiAccount.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (entries.length > 20 || entries.map((e) => e.id).toSet().length != entries.length) throw const FormatException();
        _entries = entries;
        widgetAccountId = data['widgetAccountId'] as String?;
      }
    } catch (_) { storageFailed = true; error = '无法读取已保存账户。为避免覆盖原数据，暂时不能更改账户，请重启应用重试。'; }
    ready = true; notifyListeners();
    if (connected) await refresh();
  }
  String _serialize(List<ApiAccount> entries, String? selected) => jsonEncode({
    'version': 1, 'widgetAccountId': selected, 'accounts': entries.map((e) => e.toJson()).toList(),
  });
  Future<bool> save(ApiAccount candidate) async {
    if (busy || !ready || storageFailed) return false;
    busy = true; error = null; notifyListeners();
    try {
      candidate.validate();
      final next = [..._entries];
      final index = next.indexWhere((e) => e.id == candidate.id);
      if (index < 0 && next.length >= 20) throw const DeepSeekFailure('最多保存 20 个账户。', 'provider_unavailable');
      final snapshot = await _api.fetch(candidate);
      if (index < 0) { next.add(candidate); } else { next[index] = candidate; }
      final selected = widgetAccountId ?? candidate.id;
      await _store.write(_serialize(next, selected));
      _entries = next; widgetAccountId = selected; _snapshots[candidate.id] = snapshot; errors.remove(candidate.id);
      return true;
    } on DeepSeekFailure catch (failure) { error = failure.message; return false; }
    catch (_) { error = '本机保存失败，原有账户未更改。'; return false; }
    finally { busy = false; notifyListeners(); }
  }
  Future<void> refresh() async {
    if (busy || !connected) return;
    busy = true; error = null; notifyListeners();
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
    busy = false; notifyListeners();
  }
  Future<bool> remove(String id) async {
    if (busy || !ready || storageFailed) return false;
    busy = true; error = null; notifyListeners();
    try {
      final next = _entries.where((e) => e.id != id).toList();
      final selected = widgetAccountId == id ? (next.isEmpty ? null : next.first.id) : widgetAccountId;
      await _store.write(_serialize(next, selected));
      _entries = next; widgetAccountId = selected; _snapshots.remove(id); errors.remove(id);
      return true;
    } catch (_) { error = '移除失败，请重试。'; return false; }
    finally { busy = false; notifyListeners(); }
  }
  Future<void> selectWidget(String id) async {
    if (busy || storageFailed || !_entries.any((e) => e.id == id)) return;
    busy = true; error = null; notifyListeners();
    try { await _store.write(_serialize(_entries, id)); widgetAccountId = id; }
    catch (_) { error = '组件账户设置保存失败，请重试。'; }
    finally { busy = false; notifyListeners(); }
  }
}
