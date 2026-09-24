import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'api_accounts.dart';
import 'deepseek_connection.dart';

String tencentAuthorization(String id, String secret, int timestamp) {
  const host = 'billing.tencentcloudapi.com';
  const headers = 'content-type;host;x-tc-action';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toIso8601String().substring(0, 10);
  final scope = '$date/billing/tc3_request';
  final canonical = 'POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:$host\nx-tc-action:describeaccountbalance\n\n$headers\n${sha256.convert(utf8.encode('{}'))}';
  final toSign = 'TC3-HMAC-SHA256\n$timestamp\n$scope\n${sha256.convert(utf8.encode(canonical))}';
  List<int> sign(List<int> key, String text) => Hmac(sha256, key).convert(utf8.encode(text)).bytes;
  final dateKey = sign(utf8.encode('TC3$secret'), date);
  final serviceKey = sign(dateKey, 'billing');
  final signingKey = sign(serviceKey, 'tc3_request');
  final signature = Hmac(sha256, signingKey).convert(utf8.encode(toSign));
  return 'TC3-HMAC-SHA256 Credential=$id/$scope, SignedHeaders=$headers, Signature=$signature';
}

Future<Map<String, dynamic>> fetchTencentBalance(http.Client client, ApiAccount account) async {
  final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final request = http.Request('POST', Uri.https('billing.tencentcloudapi.com', '/'))
    ..followRedirects = false
    ..headers.addAll({
      'Content-Type': 'application/json; charset=utf-8', 'X-TC-Action': 'DescribeAccountBalance',
      'X-TC-Version': '2018-07-09', 'X-TC-Timestamp': '$timestamp',
      'Authorization': tencentAuthorization(account.accessKeyId, account.key, timestamp),
    })
    ..body = '{}';
  final response = await (() async => http.Response.fromStream(await client.send(request)))()
      .timeout(const Duration(seconds: 12));
  if (response.statusCode == 429) throw const DeepSeekFailure('腾讯云查询过频，请稍后重试。', 'rate_limited');
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw const DeepSeekFailure('请检查腾讯云密钥和余额查询权限。', 'unauthorized');
  }
  if (response.statusCode != 200) throw const DeepSeekFailure('腾讯云暂时无法查询，请稍后重试。', 'provider_unavailable');
  final body = jsonDecode(response.body);
  if (body is! Map || body['Response'] is! Map) throw const FormatException();
  final data = body['Response'] as Map;
  if (data['Error'] != null) {
    final error = data['Error'];
    final code = error is Map ? error['Code']?.toString() ?? '' : '';
    if (code.startsWith('RequestLimitExceeded')) throw const DeepSeekFailure('腾讯云查询过频，请稍后重试。', 'rate_limited');
    if (code.startsWith('AuthFailure') || code.startsWith('UnauthorizedOperation')) {
      throw const DeepSeekFailure('请检查腾讯云 SecretId、SecretKey、余额查询权限和手机时间。', 'unauthorized');
    }
    throw const DeepSeekFailure('腾讯云未返回有效余额，请稍后重试。', 'provider_unavailable');
  }
  final metrics = <Map<String, dynamic>>[];
  for (final field in {'available': 'RealBalance', 'cash_balance': 'CashAccountBalance', 'bonus': 'PresentAccountBalance'}.entries) {
    final value = data[field.value];
    metrics.add({'key': field.key, 'kind': 'money', 'state': value == null ? 'unknown' : 'ok',
      'value': value == null ? null : decimalHundredth(value), 'unit': 'CNY'});
  }
  if (metrics.first['state'] != 'ok') throw const FormatException();
  final now = DateTime.now().toUtc().toIso8601String();
  return {'schemaVersion': 1, 'generatedAt': now, 'accounts': [{
    'id': '${account.id}_cny', 'provider': 'tencent', 'label': '${account.name} · CNY · 云账户',
    'lastSuccessAt': now, 'metrics': metrics,
  }]};
}
