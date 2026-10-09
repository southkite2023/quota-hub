import 'package:http/http.dart' as http;

import 'deepseek_connection.dart';

/// Fetches usage metadata only. Never stores, displays or logs a subscription URL.
/// Subscription links commonly carry bearer-equivalent tokens in their query string.
Future<Map<String, dynamic>> fetchNodeSubscription(
  http.Client client, {
  required String id,
  required String name,
  required Uri endpoint,
  required DateTime now,
}) async {
  final request = http.Request('GET', endpoint)
    ..followRedirects = false
    ..headers.addAll({'Accept': '*/*', 'User-Agent': 'Clash'});
  final response = await client.send(request).timeout(const Duration(seconds: 12));

  // The subscription body may contain private proxy/server configurations.
  // It is neither required for balance queries nor written to any snapshot.
  await response.stream.listen((_) {}).cancel();

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw const DeepSeekFailure('订阅链接无效、已撤销或无权访问。', 'unauthorized');
  }
  if (response.statusCode == 429) {
    throw const DeepSeekFailure('节点订阅查询过于频繁，请稍后重试。', 'rate_limited');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const DeepSeekFailure('订阅查询失败，请检查订阅地址；不会自动跟随跳转。', 'provider_unavailable');
  }

  final headers = {
    for (final entry in response.headers.entries) entry.key.toLowerCase(): entry.value,
  };
  final raw = headers['subscription-userinfo'] ?? headers['x-subscription-userinfo'];
  if (raw == null || raw.isEmpty) {
    throw const DeepSeekFailure('此订阅未提供可读取的流量响应头，请联系服务商或使用其他余额接口。', 'provider_unavailable');
  }

  try {
    final fields = <String, String>{};
    for (final field in raw.split(RegExp(r'[;,]'))) {
      final equals = field.indexOf('=');
      if (equals <= 0) continue;
      fields[field.substring(0, equals).trim().toLowerCase()] =
          field.substring(equals + 1).trim();
    }
    BigInt bytes(String key) {
      final value = fields[key];
      if (value == null || !RegExp(r'^[0-9]{1,20}$').hasMatch(value)) {
        throw const FormatException('Invalid traffic metadata');
      }
      final parsed = BigInt.parse(value);
      if (parsed > BigInt.parse('18446744073709551615')) {
        throw const FormatException('Traffic metadata out of range');
      }
      return parsed;
    }

    final upload = bytes('upload');
    final download = bytes('download');
    final total = bytes('total');
    final used = upload + download;
    final remaining = total > used ? total - used : BigInt.zero;
    // Some providers use total=0 to mean unlimited, so no known remaining quota can be inferred.
    final totalKnown = total > BigInt.zero;

    DateTime? expiry;
    final expiryRaw = fields['expire'];
    if (expiryRaw != null && expiryRaw != '0') {
      if (!RegExp(r'^[0-9]{1,12}$').hasMatch(expiryRaw)) {
        throw const FormatException('Invalid subscription expiry');
      }
      final seconds = int.parse(expiryRaw);
      if (seconds < 1 || seconds > 253402300799) {
        throw const FormatException('Subscription expiry out of range');
      }
      expiry = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }

    final timestamp = now.toUtc().toIso8601String();
    return {
      'schemaVersion': 1,
      'generatedAt': timestamp,
      'accounts': [{
        'id': '${id}_byte',
        'provider': 'subscription',
        'label': name,
        'lastSuccessAt': timestamp,
        'metrics': [
          {'key': 'remaining', 'kind': 'traffic', 'state': totalKnown ? 'ok' : 'unknown',
            'value': totalKnown ? remaining.toString() : null, 'unit': 'byte'},
          {'key': 'used', 'kind': 'traffic', 'state': 'ok', 'value': used.toString(), 'unit': 'byte'},
          {'key': 'total', 'kind': 'traffic', 'state': totalKnown ? 'ok' : 'unknown',
            'value': totalKnown ? total.toString() : null, 'unit': 'byte'},
          {'key': 'expires_at', 'kind': 'expiry', 'state': expiry == null ? 'unknown' : 'ok',
            'value': expiry?.toIso8601String(), 'unit': 'datetime'},
        ],
      }],
    };
  } on FormatException {
    throw const DeepSeekFailure('订阅流量信息格式异常，无法计算剩余流量。', 'provider_unavailable');
  }
}
