import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/account_settings.dart';
import 'package:quota_hub/app_settings.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/desktop_dashboard.dart';
import 'package:quota_hub/desktop_window.dart';
import 'package:quota_hub/macos_menu_bar.dart';
import 'android_dashboard_test.dart' as mobile;
import 'desktop_test.dart' as desktop;
import 'macos_menu_test.dart' show MenuHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'sidebar stays fixed through account editing, settings subpages and tab changes',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = await mobile.manager();
      final window = DesktopWindowController(host: desktop.WindowHost());
      await tester.pumpWidget(
        MaterialApp(
          theme: AstracctTheme.light(),
          home: DesktopDashboard(accounts: accounts, window: window),
        ),
      );
      await tester.pumpAndSettle();
      final sidebar = find.byKey(const ValueKey('dashboard-sidebar'));
      final bounds = tester.getRect(sidebar);
      await tester.tap(find.byKey(const ValueKey('dashboard-destination-1')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSettings), findsOneWidget);
      expect(tester.getRect(sidebar), bounds);
      await tester.tap(find.text('编辑').first);
      await tester.pumpAndSettle();
      expect(find.byType(AccountEditor), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '尚未保存的账户名称');
      await tester.tap(find.byKey(const ValueKey('dashboard-destination-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('通用'));
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettings), findsOneWidget);
      expect(tester.getRect(sidebar), bounds);
      await tester.tap(find.byKey(const ValueKey('dashboard-destination-1')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '尚未保存的账户名称',
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-destination-0')));
      await tester.pumpAndSettle();
      expect(find.text('仪表盘'), findsNWidgets(2));
      expect(find.text('概览'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      accounts.dispose();
      window.dispose();
    },
  );
  testWidgets(
    'all DeepSeek metrics have inline menu selection, with single selection, clearing and failure recovery',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = await mobile.manager();
      final host = MenuHost();
      final menu = MacMenuController(host: host);
      final window = DesktopWindowController(host: desktop.WindowHost());
      await tester.pumpWidget(
        MaterialApp(
          theme: AstracctTheme.light(),
          home: DesktopDashboard(
            accounts: accounts,
            window: window,
            menu: menu,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('赠送余额'), findsNWidgets(2));
      expect(find.text('现金余额'), findsNWidgets(2));
      final bonus = menu.choices.firstWhere(
        (c) =>
            c.account.provider == 'deepseek' &&
            c.metricKey == 'bonus' &&
            c.metric.unit == 'USD',
      );
      final cash = menu.choices.firstWhere(
        (c) =>
            c.account.provider == 'deepseek' &&
            c.metricKey == 'cash' &&
            c.metric.unit == 'USD',
      );
      Finder box(MenuBalance choice) =>
          find.byKey(ValueKey('menu-metric-${choice.id}'));
      await tester.ensureVisible(box(bonus));
      await tester.tap(box(bonus));
      await tester.pumpAndSettle();
      expect(host.saved, bonus.id);
      expect(host.updates.last['title'], '2.50 USD');
      host.failSave = true;
      await tester.ensureVisible(box(cash));
      await tester.tap(box(cash));
      await tester.pumpAndSettle();
      expect(menu.selected, bonus.id);
      host.failSave = false;
      await tester.tap(box(cash));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(box(bonus)).value, false);
      expect(host.updates.last['title'], '10.00 USD');
      await tester.tap(box(cash));
      await tester.pumpAndSettle();
      expect(host.saved, '');
      expect(host.updates.last['title'], '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      accounts.dispose();
      menu.dispose();
      window.dispose();
    },
  );
}
