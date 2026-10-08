import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'api_accounts.dart';
import 'deepseek_connection.dart';

// BSS RPC signature v1: RFC 3986 encoding, sorted parameters, HMAC-SHA1.
String _encode(String value) => Uri.encodeComponent(value).replaceAll('!', '%21')
    .replaceAll("'", '%27').replaceAll('(', '%28').replaceAll(')', '%29').replaceAll('*', '%2A');
String aliyunSignature(Map<String, String> parameters, String secret) {
  final keys = parameters.keys.where((k) => k != 'Signature').toList()..sort();
  final query = keys.map((k) => '${_encode(k)}=${_encode(parameters[k]!)}').join('&');
  final toSign = 'GET&%2F&${_encode(query)}';
  return base64Encode(Hmac(sha1, utf8.encode('$secret&')).convert(utf8.encode(toSign)).bytes);
}

String _amount(Object? value) {
  if (value is! String || !RegExp(r'^-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]+)?$').hasMatch(value)) {
    throw const FormatException();
  }
  return decimalValue(value.replaceAll(',', ''));
}

Future<Map<String, dynamic>> fetchAliyunBalance(http.Client client, ApiAccount account) async {
  final random = Random.secure();
  final parameters = <String, String>{
    'Action': 'QueryAccountBalance', 'Version': '2017-12-14', 'Format': 'JSON',
    'AccessKeyId': account.accessKeyId, 'SignatureMethod': 'HMAC-SHA1', 'SignatureVersion': '1.0',
    'Timestamp': DateTime.now().toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z'),
    'SignatureNonce': List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
  };
  parameters['Signature'] = aliyunSignature(parameters, account.key);
  final query = parameters.entries.map((e) => '${_encode(e.key)}=${_encode(e.value)}').join('&');
  final request = http.Request('GET', Uri.parse('https://business.aliyuncs.com/?$query'))
    ..followRedirects = false
    ..headers['Accept'] = 'application/json';
  final response = await (() async => http.Response.fromStream(await client.send(request)))()
      .timeout(const Duration(seconds: 12));
  if (response.statusCode == 429) throw const DeepSeekFailure('阿里云查询过频，请稍后重试。', 'rate_limited');
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw const DeepSeekFailure('请检查阿里云 AccessKey 和余额查询权限。', 'unauthorized');
  }
  if (response.statusCode >= 300 && response.statusCode < 400 || response.statusCode >= 500) {
    throw const DeepSeekFailure('阿里云暂时无法查询，请稍后重试。', 'provider_unavailable');
  }
  final body = jsonDecode(response.body);
  if (body is! Map) throw const FormatException();
  if (response.statusCode != 200 || body['Success'] != true || body['Code']?.toString() != '200') {
    final code = body['Code']?.toString() ?? '';
    if (code.contains('Throttl')) throw const DeepSeekFailure('阿里云查询过频，请稍后重试。', 'rate_limited');
    if (code.contains('Time') || code.contains('Signature')) {
      throw const DeepSeekFailure('阿里云签名验证失败，请检查 Secret，并将手机时间设为自动。', 'unauthorized');
    }
    if (code.contains('AccessKey') || code.contains('Auth') || code.contains('Permission') || code.contains('Forbidden')) {
      throw const DeepSeekFailure('请检查阿里云 AccessKey 和余额查询权限（bss:DescribeAcccount）。', 'unauthorized');
    }
    throw const DeepSeekFailure('阿里云未返回有效余额，请确认中国站费用账户可用。', 'provider_unavailable');
  }
  final data = body['Data'];
  if (data is! Map || !['CNY', 'USD', 'JPY'].contains(data['Currency'])) throw const FormatException();
  final currency = data['Currency'] as String;
  final now = DateTime.now().toUtc().toIso8601String();
  final metrics = <Map<String, dynamic>>[];
  for (final field in {'available_credit': 'AvailableAmount', 'cash_balance': 'AvailableCashAmount'}.entries) {
    final value = data[field.value];
    metrics.add({'key': field.key, 'kind': 'money', 'state': value == null ? 'unknown' : 'ok',
      'value': value == null ? null : _amount(value), 'unit': currency});
  }
  if (metrics.every((m) => m['state'] == 'unknown')) throw const FormatException();
  return {'schemaVersion': 1, 'generatedAt': now, 'accounts': [{
    'id': '${account.id}_${currency.toLowerCase()}', 'provider': 'aliyun',
    'label': '${account.name} · $currency · 云账户', 'lastSuccessAt': now, 'metrics': metrics,
  }]};
}
