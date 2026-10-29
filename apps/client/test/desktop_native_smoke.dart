import 'package:quota_hub/credential_store.dart';
// Run only on CI / developer machines: no real accounts or API calls.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:window_manager/window_manager.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/app_preferences.dart';
import 'package:quota_hub/desktop_runtime.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quota_hub/yuashie_account.dart';
import 'package:quota_hub/desktop_window.dart';
import 'package:quota_hub/macos_menu_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = credentialStore(
    'accounts',
    const FlutterSecureStorage(
      mOptions: MacOsOptions(
        accountName: 'com.yuashie.astracct.desktop',
        usesDataProtectionKeychain: false,
      ),
    ),
  );
  final key = 'astracct.desktop.smoke.$pid';
  final identityKey = 'astracct.identity.smoke.$pid';
  try {
    await NativeDesktopWindow.initialize();
    AppPreferences.instance = AppPreferences(
      readPreferences: () async => null,
      writePreferences: (_) async {},
    );
    await AppPreferences.instance.set('rememberWindow', false);
    await DesktopRuntime.instance.initialize();
    runApp(
      MaterialApp(
        theme: AstracctTheme.light(),
        home: const Scaffold(body: Text('Astracct native window smoke test')),
      ),
    );
    final host = NativeDesktopWindow();
    final original = await host.bounds();
    await host.apply(
      floating: true,
      bounds: Rect.fromLTWH(original.left, original.top, 360, 320),
      pinned: true,
    );
    if (!await windowManager.isAlwaysOnTop())
      throw StateError('Floating window not pinned');
    final size = await windowManager.getSize();
    if ((size.width - 360).abs() > 4 || (size.height - 320).abs() > 4)
      throw StateError('Floating window dimensions incorrect: $size');
    await host.pin(false);
    if (await windowManager.isAlwaysOnTop()) throw StateError('Unpin failed');
    await host.apply(floating: false, bounds: original, pinned: false);
    final restored = await host.bounds();
    if ((restored.width - original.width).abs() > 4 ||
        (restored.height - original.height).abs() > 4)
      throw StateError('Main window bounds not restored');
    await storage.write(key: key, value: 'synthetic-smoke-value');
    if (await storage.read(key: key) != 'synthetic-smoke-value')
      throw StateError('Native secure storage round trip failed');
    await storage.delete(key: key);
    if (await storage.read(key: key) != null)
      throw StateError('Native secure storage delete failed');
    // Test the production login vault separately; unique keys preserve user sessions.
    final identityStorage = credentialStore(
      'identity',
      YuashieAccount.sessionStorage,
    );
    await identityStorage.write(
      key: identityKey,
      value: 'synthetic-session-only',
    );
    if (await identityStorage.read(key: identityKey) !=
        'synthetic-session-only')
      throw StateError('Native login keychain round trip failed');
    await identityStorage.delete(key: identityKey);
    if (await identityStorage.read(key: identityKey) != null)
      throw StateError('Native login keychain delete failed');
    final settingsKey = 'astracct.settings.smoke.$pid';
    await AppPreferences.instance.security.write(
      key: settingsKey,
      value: 'synthetic-policy',
    );
    if (await AppPreferences.instance.security.read(key: settingsKey) !=
        'synthetic-policy')
      throw StateError('Settings vault round trip failed');
    await AppPreferences.instance.security.delete(key: settingsKey);
    await LocalAuthentication().isDeviceSupported();
    if (Platform.isWindows && !DesktopRuntime.instance.trayReady)
      throw StateError('Windows tray unavailable');
    stdout.writeln(
      'ASTRACCT_SETTINGS_SMOKE_PASS: settings vault, authentication plugin and desktop runtime',
    );
    stdout.writeln(
      'ASTRACCT_IDENTITY_VAULT_SMOKE_PASS: login session write/read/delete',
    );
    if (Platform.isMacOS) {
      final menu = NativeMacMenuHost();
      await menu.initialize((_, _) async {});
      await menu.update({
        'title': '9.00 USD',
        'tooltip': 'synthetic menu check',
        'selected': '',
        'hidden': false,
        'choices': <Map<String, String>>[],
      });
      final status = await macMenuChannel.invokeMapMethod<String, dynamic>(
        'inspect',
      );
      if (status?['installed'] != true || status?['title'] != '9.00 USD')
        throw StateError('Native status item missing');
      if (!await windowManager.isPreventClose())
        throw StateError('Menu mode must keep running on window close');
      await windowManager.close();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await windowManager.isVisible())
        throw StateError('Close should hide the window');
      final hiddenStatus = await macMenuChannel.invokeMapMethod<String, dynamic>('inspect');
      if (hiddenStatus?['installed'] != true || hiddenStatus?['dockVisible'] != false)
        throw StateError('Close must keep status item and hide Dock');
      await macMenuChannel.invokeMethod<void>('reopen');
      if (!await windowManager.isVisible())
        throw StateError('Hidden window could not reopen');
      final reopenedStatus = await macMenuChannel.invokeMapMethod<String, dynamic>('inspect');
      if (reopenedStatus?['dockVisible'] != true) throw StateError('Reopen must restore Dock');
      menu.dispose();
      stdout.writeln(
        'ASTRACCT_MAC_MENU_SMOKE_PASS: NSStatusItem title, close hides, reopen',
      );
    }
    stdout.writeln(
      'ASTRACCT_DESKTOP_SMOKE_PASS: window size, pin, restore, native vault write/read/delete',
    );
    exit(0);
  } catch (error) {
    stderr.writeln('ASTRACCT_DESKTOP_SMOKE_FAIL: $error');
    try {
      await storage.delete(key: key);
    } catch (_) {}
    try {
      await YuashieAccount.sessionStorage.delete(key: identityKey);
    } catch (_) {}
    exit(1);
  }
}
