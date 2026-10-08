import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_accounts.dart';
import 'deepseek_connection.dart';

/// Organization costs are spending, never the remaining prepaid balance.
Future<Map<String, dynamic>> fetchOpenAiCosts(http.Client client, ApiAccount account, DateTime now) async {
  final start = DateTime.utc(now.year, now.month);
  final query = <String, String>{
    'start_time': '${start.millisecondsSinceEpoch ~/ 1000}',
    'end_time': '${now.millisecondsSinceEpoch ~/ 1000}',
    'bucket_width': '1d', 'limit': '31',
  };
  var total = '0';
  final cursors = <String>{};
  // A malformed or cycling pagination response must not publish a partial total.
  for (var page = 0; page < 40; page++) {
    final request = http.Request('GET', account.uri.replace(queryParameters: query))
      ..followRedirects = false
      ..headers.addAll({'Authorization': 'Bearer ${account.key}', 'Accept': 'application/json'});
    final response = await (() async => http.Response.fromStream(await client.send(request)))()
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const DeepSeekFailure('OpenAI 费用查询需要组织 Admin API Key，请检查密钥和权限。', 'unauthorized');
    }
    if (response.statusCode == 429) throw const DeepSeekFailure('查询过频，请稍后重试。', 'rate_limited');
    if (response.statusCode != 200) throw const DeepSeekFailure('OpenAI 费用暂时无法查询，请稍后重试。', 'provider_unavailable');
    final data = jsonDecode(response.body);
    if (data is! Map || data['error'] != null || data['object'] != 'page' ||
        data['data'] is! List || data['has_more'] is! bool) throw const FormatException();
    for (final bucket in data['data'] as List) {
      if (bucket is! Map || bucket['object'] != 'bucket' || bucket['results'] is! List) throw const FormatException();
      for (final result in bucket['results'] as List) {
        if (result is! Map || result['object'] != 'organization.costs.result' ||
            result['amount'] is! Map || result['amount']['currency'] != 'usd') throw const FormatException();
        total = decimalDifference(total, decimalDifference('0', result['amount']['value']));
      }
    }
    if (data['has_more'] == false) {
      final stamp = now.toIso8601String();
      return {'schemaVersion': 1, 'generatedAt': stamp, 'accounts': [{
        'id': '${account.id}_usd', 'provider': 'openai',
        'label': '${account.name} · USD · ${now.year}-${now.month.toString().padLeft(2, '0')} 费用（UTC），余额未知',
        'lastSuccessAt': stamp, 'metrics': [
          {'key': 'available', 'kind': 'money', 'state': 'unknown', 'value': null, 'unit': 'USD'},
          {'key': 'month_spent', 'kind': 'money', 'state': 'ok', 'value': total, 'unit': 'USD'},
        ],
      }]};
    }
    final next = data['next_page'];
    if (next is! String || next.isEmpty || next.length > 4096 || !cursors.add(next)) throw const FormatException();
    query['page'] = next;
  }
  throw const DeepSeekFailure('OpenAI 费用分页未完成，未显示不完整金额。', 'provider_unavailable');
}
