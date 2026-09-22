import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android widget handoff; other platforms keep using the in-app demo only.
class WidgetBridge {
  static const _channel = MethodChannel('quota_hub/widget');
  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void listen(void Function(String accountId) openAccount) {
    if (!_android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openAccount' && call.arguments is String) {
        openAccount(call.arguments as String);
      }
    });
  }

  static Future<String?> initialAccount() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<String>('getWidgetAccount');
    } on PlatformException catch (error) {
      debugPrint('Widget target unavailable: ${error.code}');
      return null;
    }
  }

  static Future<bool> savedHideMoney() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('getHideMoney') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Widget privacy setting unavailable: ${error.code}');
      return false;
    }
  }

  static Future<void> showScenario(String scenario, {required bool hideMoney}) async {
    if (!_android) return;
    final raw = jsonDecode(await rootBundle.loadString('assets/cases.json')) as List<dynamic>;
    Map<String, dynamic> named(String name) => Map<String, dynamic>.from(
          raw.firstWhere((item) => item['name'] == name) as Map,
        );
    final normal = named('normal');
    final accounts = List<dynamic>.from(normal['accounts'] as List);
    accounts.add((named('zero')['accounts'] as List).first);
    if (scenario == 'stale') accounts[0] = (named('stale')['accounts'] as List).first;
    if (scenario == 'unknown') accounts[1] = (named('unknown')['accounts'] as List).first;
    if (scenario == 'first_failure') accounts[2] = (named('first_failure')['accounts'] as List).first;
    final snapshot = jsonEncode({
      'schemaVersion': 1,
      'generatedAt': normal['generatedAt'],
      'accounts': accounts,
    });
    try {
      await _channel.invokeMethod<void>('saveSnapshot', {
        'snapshot': snapshot,
        'hideMoney': hideMoney,
      });
    } on PlatformException catch (error) {
      debugPrint('Widget snapshot unavailable: ${error.code}');
    }
  }
}
