import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'snapshot.dart';

class DeepSeekFailure implements Exception {
  const DeepSeekFailure(this.message, this.code);
  final String message;
  final String code;
}

abstract class KeyStore {
  Future<String?> read();
  Future<void> save(String key);
  Future<void> remove();
}

class AndroidKeyStore implements KeyStore {
  static const _channel = MethodChannel('quota_hub/deepseek');
  @override
  Future<String?> read() => _channel.invokeMethod<String>('readKey');
  @override
  Future<void> save(String key) => _channel.invokeMethod<void>('saveKey', key);
  @override
  Future<void> remove() => _channel.invokeMethod<void>('removeKey');
}

class DeepSeekApi {
  DeepSeekApi({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;

  Future<Map<String, dynamic>> balance(String key) async {
    final client = _clientFactory();
    try {
      final request = http.Request('GET', Uri.https('api.deepseek.com', '/user/balance'))
        ..followRedirects = false
        ..headers.addAll({'Authorization': 'Bearer $key', 'Accept': 'application/json'});
      final response = await (() async => http.Response.fromStream(await client.send(request)))()
          .timeout(const Duration(seconds: 12));
      switch (response.statusCode) {
        case 200:
          break;
        case 401:
        case 403:
          throw const DeepSeekFailure('API Key 无效或已失效，请重新设置。', 'unauthorized');
        case 429:
          throw const DeepSeekFailure('查询过于频繁，请稍后重试。', 'rate_limited');
        default:
          throw const DeepSeekFailure('DeepSeek 暂时无法查询，请稍后重试。', 'provider_unavailable');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['is_available'] is! bool ||
          data['balance_infos'] is! List || (data['balance_infos'] as List).isEmpty) {
        throw const FormatException();
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final accounts = <Map<String, dynamic>>[];
      final currencies = <String>{};
      for (final item in data['balance_infos'] as List) {
        if (item is! Map<String, dynamic> || !{'CNY', 'USD'}.contains(item['currency']) ||
            !currencies.add(item['currency'] as String)) throw const FormatException();
        final currency = item['currency'] as String;
        final metrics = <Map<String, dynamic>>[];
        for (final pair in [('available', 'total_balance'), ('bonus', 'granted_balance'), ('cash', 'topped_up_balance')]) {
          final amount = item[pair.$2];
          if (amount is! String || !RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$').hasMatch(amount)) {
            throw const FormatException();
          }
          metrics.add({'key': pair.$1, 'kind': 'money', 'state': 'ok', 'value': amount, 'unit': currency});
        }
        accounts.add({'id': 'deepseek_${currency.toLowerCase()}', 'provider': 'deepseek',
          'label': '我的 DeepSeek · $currency${data['is_available'] == false ? ' · 当前不可调用 API' : ''}',
          'lastSuccessAt': now, 'metrics': metrics});
      }
      // The widget shows the first currency; prefer CNY, never add different currencies.
      accounts.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      return {'schemaVersion': 1, 'generatedAt': now, 'accounts': accounts};
    } on DeepSeekFailure {
      rethrow;
    } on TimeoutException {
      throw const DeepSeekFailure('连接超时，请检查网络后重试。', 'timeout');
    } on FormatException {
      throw const DeepSeekFailure('余额数据格式异常，请稍后重试。', 'provider_unavailable');
    } catch (_) {
      throw const DeepSeekFailure('网络连接失败，请检查网络后重试。', 'provider_unavailable');
    } finally {
      client.close();
    }
  }
}

class DeepSeekConnection extends ChangeNotifier {
  DeepSeekConnection({KeyStore? store, DeepSeekApi? api})
      : _store = store ?? AndroidKeyStore(), _api = api ?? DeepSeekApi();
  final KeyStore _store;
  final DeepSeekApi _api;
  String? _key;
  Map<String, dynamic>? _snapshot;
  bool ready = false;
  bool busy = false;
  String? error;
  bool get connected => _key != null;
  String get raw => jsonEncode(_snapshot ?? emptySnapshot());
  List<Account> get accounts => DemoCase.fromJson({...(_snapshot ?? emptySnapshot()), 'name': 'personal'}).accounts;

  static Map<String, dynamic> emptySnapshot() => {
    'schemaVersion': 1, 'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'accounts': [{'id': 'deepseek_cny', 'provider': 'deepseek', 'label': '尚未连接 DeepSeek',
      'lastSuccessAt': null, 'metrics': [{'key': 'available', 'kind': 'money', 'state': 'unknown', 'value': null, 'unit': 'CNY'}]}],
  };

  Future<void> initialize() async {
    try { _key = await _store.read(); } catch (_) {
      error = '无法读取本机凭据，请重新设置或移除账户。';
    }
    ready = true;
    notifyListeners();
    if (connected) await refresh();
  }

  Future<bool> connect(String input) async {
    if (busy || !ready) return false;
    final key = input.trim();
    if (key.isEmpty || key.length > 4096 || RegExp(r'\s|[^\x21-\x7E]').hasMatch(key)) {
      error = '请填写完整的 API Key，不要包含空格或换行。';
      notifyListeners();
      return false;
    }
    busy = true; error = null; notifyListeners();
    try {
      final snapshot = await _api.balance(key);
      try { await _store.save(key); } catch (_) {
        throw const DeepSeekFailure('本机安全保存失败，请重试。原有账户未更改。', 'provider_unavailable');
      }
      _key = key; _snapshot = snapshot;
      return true;
    } on DeepSeekFailure catch (failure) {
      error = failure.message;
      return false;
    } finally { busy = false; notifyListeners(); }
  }

  Future<void> refresh() async {
    if (busy || _key == null) return;
    busy = true; error = null; notifyListeners();
    try { _snapshot = await _api.balance(_key!); }
    on DeepSeekFailure catch (failure) {
      error = failure.message;
      final snapshot = _snapshot ?? emptySnapshot();
      if (_snapshot == null) (snapshot['accounts'] as List).first['label'] = '我的 DeepSeek · CNY';
      for (final account in snapshot['accounts'] as List) {
        for (final metric in account['metrics'] as List) {
          metric['state'] = metric['value'] == null ? 'error' : 'stale';
          metric['errorCode'] = failure.code;
        }
      }
      _snapshot = snapshot;
    } finally { busy = false; notifyListeners(); }
  }

  Future<bool> disconnect() async {
    if (busy || !ready) return false;
    busy = true; error = null; notifyListeners();
    try {
      await _store.remove();
      _key = null; _snapshot = null;
      return true;
    } catch (_) {
      error = '移除失败，请重试。';
      return false;
    } finally { busy = false; notifyListeners(); }
  }
}
