import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/refresh_settings.dart';

class Preferences implements AccountsStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async { data = value; }
}
void main() {
  testWidgets('one minute and custom interval persist through settings controls', (tester) async {
    final store = Preferences(); final manager = ApiAccounts(store: store);
    await manager.initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListenableBuilder(listenable: manager,
      builder: (context, child) => ListView(children: [RefreshSettings(accounts: manager)])))));
    await tester.tap(find.byType(DropdownButtonFormField<int>)); await tester.pumpAndSettle();
    await tester.tap(find.text('每 1 分钟').last); await tester.pumpAndSettle();
    expect(manager.refreshMinutes, 1); expect(store.data, contains('"refreshMinutes":1'));
    await tester.tap(find.text('自定义时间')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0'); await tester.tap(find.text('保存')); await tester.pumpAndSettle();
    expect(find.text('请输入 1–1440 之间的整数'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7'); await tester.tap(find.text('保存')); await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400)); await tester.pumpAndSettle();
    expect(manager.refreshMinutes, 7); expect(find.text('每 7 分钟'), findsOneWidget);
    manager.dispose();
  });
}
