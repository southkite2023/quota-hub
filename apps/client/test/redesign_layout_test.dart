import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/android_dashboard.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/desktop_dashboard.dart';
import 'package:quota_hub/desktop_window.dart';
import 'package:quota_hub/app_settings.dart';
import 'android_dashboard_test.dart' as mobile;
import 'desktop_test.dart' as desktop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final wide in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        '${wide ? 'desktop' : 'mobile'} ${dark ? 'dark' : 'light'} navigation and layout',
        (tester) async {
          tester.view.physicalSize = wide
              ? const Size(1180, 820)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final accounts = await mobile.manager();
          addTearDown(accounts.dispose);
          final window = DesktopWindowController(host: desktop.WindowHost());
          addTearDown(window.dispose);
          final folder = Platform.environment['ASTRACCT_REDESIGN_PREVIEW'];
          if (folder != null) {
            await tester.runAsync(() async {
              await (FontLoader('MaterialIcons')..addFont(
                    rootBundle.load('fonts/MaterialIcons-Regular.otf'),
                  ))
                  .load();
              for (final font in [
                ('PreviewSans', '/System/Library/Fonts/Supplemental/Arial.ttf'),
                ('PreviewCJK', '/System/Library/Fonts/Hiragino Sans GB.ttc'),
              ]) {
                final loader = FontLoader(font.$1)
                  ..addFont(
                    File(
                      font.$2,
                    ).readAsBytes().then((b) => ByteData.sublistView(b)),
                  );
                await loader.load();
              }
            });
          }
          final boundary = GlobalKey();
          final base = dark ? AstracctTheme.dark() : AstracctTheme.light();
          final theme = folder == null
              ? base
              : base.copyWith(
                  textTheme: base.textTheme.apply(
                    fontFamily: 'PreviewSans',
                    fontFamilyFallback: ['PreviewCJK'],
                  ),
                );
          final previewTheme = folder == null
              ? theme
              : theme.copyWith(
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                      fontFamily: 'PreviewSans',
                      fontFamilyFallback: ['PreviewCJK'],
                    ),
                  ),
                );
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: previewTheme,
                debugShowCheckedModeBanner: false,
                home: wide
                    ? DesktopDashboard(accounts: accounts, window: window)
                    : AndroidDashboard(
                        accounts: accounts,
                        hideMoney: false,
                        onToggleMoney: () {},
                        onSettings: () {},
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('账户状态'), findsOneWidget);
          if (wide) {
            expect(find.byType(NavigationBar), findsNothing);
            expect(find.text('Astracct'), findsOneWidget);
          } else {
            expect(find.byType(NavigationBar), findsOneWidget);
          }
          if (folder != null) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(folder).create(recursive: true);
              await File(
                '$folder/${wide ? 'desktop' : 'mobile'}-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          // Navigation is wired to the existing account-management flow.
          await tester.tap(find.text('余额账户').last);
          await tester.pumpAndSettle();
          expect(find.byType(Scaffold), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('settings uses shared surfaces at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AstracctTheme.dark(),
        home: const AppearanceSettings(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
