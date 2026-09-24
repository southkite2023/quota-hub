import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/account_settings.dart';

class MemoryVault implements AccountsStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { data = value; }
}
void main() {
  testWidgets('OpenRouter can be selected and saved as an independent account', (tester) async {
    final manager = ApiAccounts(store: MemoryVault(), api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"data":{"total_credits":10,"total_usage":2}}', 200))));
    await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: AccountSettings(connection: manager)));
    await tester.tap(find.text('添加 API 账户')); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRouter').last); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工作 OpenRouter');
    await tester.enterText(find.byType(TextField).last, 'fake-management-key');
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, true);
    await tester.ensureVisible(find.text('验证并保存')); await tester.tap(find.text('验证并保存')); await tester.pumpAndSettle();
    expect(manager.entries.single.provider, BalanceProvider.openrouter);
    expect(manager.entries.single.name, '工作 OpenRouter');
    expect(find.text('工作 OpenRouter'), findsOneWidget);
  });
  testWidgets('unavailable provider explains limitation without collecting a key', (tester) async {
    final manager = ApiAccounts(store: MemoryVault()); await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: AccountEditor(connection: manager)));
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('硅基流动 · 待适配').last); await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('验证并保存'), findsNothing);
    expect(find.textContaining('2026-08-14'), findsOneWidget);
  });
}
