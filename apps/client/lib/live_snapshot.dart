import 'dart:convert';

import 'package:http/http.dart' as http;

import 'snapshot.dart';

const snapshotUrl = String.fromEnvironment('QUOTA_HUB_URL');
const readToken = String.fromEnvironment('QUOTA_HUB_READ_TOKEN');
bool get liveConfigured => snapshotUrl.startsWith('https://') && readToken.isNotEmpty;

Future<(Account, String)> fetchDeepSeek() async {
  if (!liveConfigured) throw const FormatException('Missing HTTPS endpoint and read token');
  final response = await http.get(Uri.parse('$snapshotUrl/api/v1/snapshot'), headers: {
    'Authorization': 'Bearer $readToken', 'Accept': 'application/json',
  }).timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) throw const FormatException('Snapshot request failed');
  final raw = jsonDecode(response.body);
  if (raw is! Map<String, dynamic>) throw const FormatException('Invalid snapshot');
  final snapshot = DemoCase.fromJson({...raw, 'name': 'live'});
  final account = snapshot.accounts.firstWhere((item) => item.provider == 'deepseek' && item.metrics.any((metric) => metric.key == 'available'));
  return (account, response.body);
}
