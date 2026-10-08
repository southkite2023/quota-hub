import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/deepseek_settings.dart';

class TestStore implements KeyStore {
  String? key;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> save(String value) async { key = value; }
  @override
  Future<void> remove() async { key = null; }
}

void main() {
  testWidgets('enter key, verify, save and return to dashboard', (tester) async {
    final store = TestStore();
    final connection = DeepSeekConnection(store: store, api: DeepSeekApi(clientFactory: () => MockClient((_) async => http.Response(jsonEncode({
      'is_available': true,
      'balance_infos': [{'currency': 'CNY', 'total_balance': '12.50', 'granted_balance': '2.50', 'topped_up_balance': '10'}],
    }), 200))));
    await connection.initialize();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DeepSeekSettings(connection: connection))),
      child: const Text('设置入口'),
    )))));
    await tester.tap(find.text('设置入口'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, true);
    await tester.enterText(find.byType(TextField), 'fake-personal-key');
    await tester.ensureVisible(find.text('验证并保存'));
    await tester.tap(find.text('验证并保存'));
    await tester.pumpAndSettle();
    expect(store.key, 'fake-personal-key');
    expect(connection.accounts.first.metrics.first.value, '12.50');
    expect(find.text('设置入口'), findsOneWidget);
    expect(find.byType(DeepSeekSettings), findsNothing);
  });
}
