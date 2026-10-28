import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quota_hub/app_localizations.dart';
import 'package:quota_hub/app_preferences.dart';
import 'package:quota_hub/app_security_gate.dart';
import 'package:quota_hub/app_settings.dart';
import 'package:quota_hub/app_theme.dart';
import 'package:quota_hub/desktop_runtime.dart';
import 'package:quota_hub/unsaved_changes.dart';
import 'package:quota_hub/maintenance_io.dart';

class DeviceAuth extends LocalAuthentication {
  bool accepted = true;
  @override
  Future<bool> isDeviceSupported() async => true;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async => accepted;
}

class FailedSecurity extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic wOptions,
    dynamic mOptions,
    dynamic webOptions,
  }) async => throw StateError('unavailable');
}

class FailedSecurityWrite extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic wOptions,
    dynamic mOptions,
    dynamic webOptions,
  }) async => throw StateError('unavailable');
}

Widget shell(
  Widget child, {
  bool dark = false,
  Locale locale = const Locale('zh'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: const [
    ...GlobalMaterialLocalizations.delegates,
    AppCatalog.delegate,
  ],
  theme: dark ? AstracctTheme.dark() : AstracctTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'concurrent UI writes preserve each setting and reset keeps privacy and app lock',
    () async {
      String? stored;
      final prefs = AppPreferences(
        security: const FlutterSecureStorage(),
        readPreferences: () async => stored,
        writePreferences: (raw) async {
          stored = raw;
        },
      );
      await prefs.load();
      await Future.wait([
        prefs.set('theme', 'dark'),
        prefs.set('language', 'en'),
        prefs.set('autoHide', true),
      ]);
      final restored = AppPreferences(
        security: const FlutterSecureStorage(),
        readPreferences: () async => stored,
        writePreferences: (_) async {},
      );
      await restored.load();
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.language, 'en');
      expect(restored.autoHide, true);
      await restored.resetAppearance();
      expect(restored.themeMode, ThemeMode.system);
      expect(restored.autoHide, true);
      prefs.dispose();
      restored.dispose();
    },
  );

  test('write failures retain previous preference values', () async {
    var fail = false;
    final prefs = AppPreferences(
      security: const FlutterSecureStorage(),
      writePreferences: (_) async {
        if (fail) throw StateError('disk full');
      },
    );
    await prefs.set('theme', 'light');
    fail = true;
    await expectLater(prefs.set('theme', 'dark'), throwsStateError);
    expect(prefs.themeMode, ThemeMode.light);
    fail = false;
    await prefs.set('language', 'en');
    expect(prefs.language, 'en');
    prefs.dispose();
  });

  test(
    'app lock restores locked, cancellation stays locked and failed storage cannot disable it',
    () async {
      final auth = DeviceAuth();
      final prefs = AppPreferences(
        security: const FlutterSecureStorage(),
        auth: auth,
        writePreferences: (_) async {},
        readPreferences: () async => null,
      );
      await prefs.load();
      expect(await prefs.setLock(true, 'test'), true);
      prefs.conceal();
      expect(prefs.locked, true);
      auth.accepted = false;
      await prefs.unlock('test');
      expect(prefs.locked, true);
      auth.accepted = true;
      await prefs.unlock('test');
      expect(prefs.locked, false);
      final restored = AppPreferences(
        security: const FlutterSecureStorage(),
        auth: auth,
        readPreferences: () async => null,
        writePreferences: (_) async {},
      );
      await restored.load();
      expect(restored.locked, true);
      final failed = AppPreferences(
        security: FailedSecurityWrite(),
        auth: auth,
      );
      failed.lockEnabled = true;
      await expectLater(failed.setLock(false, 'test'), throwsStateError);
      expect(failed.lockEnabled, true);
      prefs.dispose();
      restored.dispose();
      failed.dispose();
    },
  );

  test(
    'security read failure fails closed, malformed appearance cannot bypass app lock',
    () async {
      final failed = AppPreferences(security: FailedSecurity());
      await failed.load();
      expect(failed.locked, true);
      expect(failed.error, isNotNull);
      FlutterSecureStorage.setMockInitialValues({
        AppPreferences.lockKey: 'enabled',
      });
      final prefs = AppPreferences(
        security: const FlutterSecureStorage(),
        readPreferences: () async => '{broken',
        writePreferences: (_) async {},
      );
      await prefs.load();
      expect(prefs.locked, true);
      expect(prefs.themeMode, ThemeMode.system);
      failed.dispose();
      prefs.dispose();
    },
  );

  test(
    'diagnostics whitelist cannot expose arbitrary preferences or credentials',
    () async {
      final prefs = AppPreferences(
        security: const FlutterSecureStorage(),
        writePreferences: (_) async {},
      );
      await prefs.set('secret', 'fake-secret-not-for-export');
      final result = diagnosticSummary(
        PackageInfo(
          appName: 'Astracct',
          packageName: 'test',
          version: '2.0.0',
          buildNumber: '19',
        ),
        prefs,
      );
      expect(jsonDecode(result)['version'], '2.0.0');
      expect(result, isNot(contains('fake-secret')));
      expect(result, isNot(contains('secret')));
      prefs.dispose();
    },
  );

  test('off-screen bounds move into visible work area', () {
    final rect = visibleWindow(
      const Rect.fromLTWH(-2400, -100, 900, 680),
      const Rect.fromLTWH(0, 24, 1440, 876),
    );
    expect(rect.left, 0);
    expect(rect.top, 24);
    expect(rect.width, 900);
    final huge = visibleWindow(
      const Rect.fromLTWH(10000, 10000, 8000, 4000),
      const Rect.fromLTWH(0, 0, 1280, 800),
    );
    expect(huge, const Rect.fromLTWH(0, 0, 1280, 800));
  });

  test(
    'download cleanup preserves account files, nested directories and linked targets',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'astracct-cleanup-test-',
      );
      try {
        final vault = File('${temporary.path}/accounts.json');
        await vault.writeAsString('synthetic-vault');
        final root = await Directory(
          '${temporary.path}/astracct-updates',
        ).create();
        final download = File('${root.path}/update.zip');
        await download.writeAsBytes([1, 2, 3]);
        final nested = await Directory('${root.path}/installer').create();
        await File('${nested.path}/keep').writeAsString('active helper');
        await Link('${root.path}/linked-vault').create(vault.path);
        expect(await clearUpdateDirectory(root), 3);
        expect(await download.exists(), false);
        expect(await vault.readAsString(), 'synthetic-vault');
        expect(await File('${nested.path}/keep').exists(), true);
        expect(await Link('${root.path}/linked-vault').exists(), true);
        final alias = Link('${temporary.path}/root-alias');
        await alias.create(root.path);
        expect(await clearUpdateDirectory(Directory(alias.path)), 0);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'lock screen excludes protected content and focus until verified',
    (tester) async {
      AppPreferences.instance.locked = true;
      await tester.pumpWidget(
        shell(
          const AppSecurityGate(
            child: Scaffold(body: Text('protected account')),
          ),
        ),
      );
      expect(find.text('protected account'), findsNothing);
      expect(find.text('星账已锁定'), findsOneWidget);
      AppPreferences.instance.locked = false;
      AppPreferences.instance.conceal();
      await tester.pump();
      expect(find.text('protected account'), findsOneWidget);
    },
  );

  testWidgets(
    'dirty route blocks back, keeps input and discards only after confirmation',
    (tester) async {
      var dirty = true;
      var canLeave = false;
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => UnsavedChanges(
                      dirty: () => dirty,
                      canLeave: () => canLeave,
                      child: const Scaffold(
                        appBar: null,
                        body: Text('editor contents'),
                      ),
                    ),
                  ),
                ),
                child: const Text('open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsNothing);
      expect(find.text('editor contents'), findsOneWidget);
      canLeave = true;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.text('editor contents'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.text('editor contents'), findsNothing);
      dirty = false;
    },
  );

  testWidgets('appearance controls persist and settings render in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(const AppearanceSettings(), locale: const Locale('en')),
    );
    expect(find.text('Appearance & accessibility'), findsOneWidget);
    expect(find.text('Increase contrast'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pump();
    expect(AppPreferences.instance.highContrast, true);
    expect(find.text('外观与无障碍'), findsNothing);
  });

  testWidgets(
    'settings pages fit narrow screens at large font sizes in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      for (final dark in [false, true]) {
        for (final locale in [const Locale('zh'), const Locale('en')]) {
          for (final page in [
            const AppearanceSettings(),
            const SecuritySettings(),
            const HelpSettings(),
            const AboutSettings(),
          ]) {
            PackageInfo.setMockInitialValues(
              appName: 'Astracct',
              packageName: 'test',
              version: '2.0.0',
              buildNumber: '19',
              buildSignature: '',
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: shell(page, dark: dark, locale: locale, scale: 2),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.runtimeType} $dark $locale',
            );
          }
        }
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: shell(
            const AppearanceSettings(),
            dark: true,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.environment['ASTRACCT_SETTINGS_PREVIEW'] != null) {
        await tester.runAsync(() async {
          final font = FontLoader('PreviewSans')
            ..addFont(
              File(
                '/System/Library/Fonts/Supplemental/Arial.ttf',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
          await font.load();
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: shell(
              Theme(
                data: AstracctTheme.dark().copyWith(
                  textTheme: AstracctTheme.dark().textTheme.apply(
                    fontFamily: 'PreviewSans',
                  ),
                ),
                child: const AppearanceSettings(),
              ),
              dark: true,
              locale: const Locale('en'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('build/general-settings-preview');
          await folder.create(recursive: true);
          await File(
            '${folder.path}/appearance-dark-en.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
