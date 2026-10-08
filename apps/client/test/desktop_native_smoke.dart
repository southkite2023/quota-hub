// Run only on CI / developer machines: no real accounts or API calls.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:window_manager/window_manager.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/desktop_window.dart';
import 'package:quota_hub/macos_menu_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage(mOptions: MacOsOptions(
    accountName: 'com.yuashie.astracct.desktop', usesDataProtectionKeychain: false,
  ));
  final key = 'astracct.desktop.smoke.$pid';
  try {
    await NativeDesktopWindow.initialize();
    runApp(MaterialApp(theme: AstracctTheme.light(), home: const Scaffold(body: Text('Astracct native window smoke test'))));
    final host = NativeDesktopWindow();
    final original = await host.bounds();
    await host.apply(floating: true, bounds: Rect.fromLTWH(original.left, original.top, 360, 320), pinned: true);
    if (!await windowManager.isAlwaysOnTop()) throw StateError('Floating window not pinned');
    final size = await windowManager.getSize();
    if ((size.width - 360).abs() > 4 || (size.height - 320).abs() > 4) throw StateError('Floating window dimensions incorrect: $size');
    await host.pin(false);
    if (await windowManager.isAlwaysOnTop()) throw StateError('Unpin failed');
    await host.apply(floating: false, bounds: original, pinned: false);
    final restored = await host.bounds();
    if ((restored.width - original.width).abs() > 4 || (restored.height - original.height).abs() > 4) throw StateError('Main window bounds not restored');
    await storage.write(key: key, value: 'synthetic-smoke-value');
    if (await storage.read(key: key) != 'synthetic-smoke-value') throw StateError('Native secure storage round trip failed');
    await storage.delete(key: key);
    if (await storage.read(key: key) != null) throw StateError('Native secure storage delete failed');
    if (Platform.isMacOS) {
      final menu = NativeMacMenuHost();
      await menu.initialize((_, _) async {});
      await menu.update({'title': '9.00 USD', 'tooltip': 'synthetic menu check', 'selected': '', 'hidden': false, 'choices': <Map<String, String>>[]});
      final status = await macMenuChannel.invokeMapMethod<String, dynamic>('inspect');
      if (status?['installed'] != true || status?['title'] != '9.00 USD') throw StateError('Native status item missing');
      if (!await windowManager.isPreventClose()) throw StateError('Menu mode must keep running on window close');
      await windowManager.close();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await windowManager.isVisible()) throw StateError('Close should hide the window');
      await windowManager.show();
      if (!await windowManager.isVisible()) throw StateError('Hidden window could not reopen');
      menu.dispose();
      stdout.writeln('ASTRACCT_MAC_MENU_SMOKE_PASS: NSStatusItem title, close hides, reopen');
    }
    stdout.writeln('ASTRACCT_DESKTOP_SMOKE_PASS: window size, pin, restore, native vault write/read/delete');
    exit(0);
  } catch (error) {
    stderr.writeln('ASTRACCT_DESKTOP_SMOKE_FAIL: $error');
    try { await storage.delete(key: key); } catch (_) {}
    exit(1);
  }
}
