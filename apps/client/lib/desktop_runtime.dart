import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'app_preferences.dart';
import 'app_localizations.dart';
import 'desktop_platform.dart';
import 'unsaved_changes.dart';
import 'macos_menu_bar.dart';
import 'desktop_startup_stub.dart'
    if (dart.library.io) 'desktop_startup_io.dart'
    as startup;

Rect visibleWindow(Rect requested, Rect display) {
  final width = requested.width
      .clamp(math.min(640.0, display.width), display.width)
      .toDouble();
  final height = requested.height
      .clamp(math.min(420.0, display.height), display.height)
      .toDouble();
  return Rect.fromLTWH(
    requested.left
        .clamp(
          display.left,
          display.right - (width < display.width ? width : display.width),
        )
        .toDouble(),
    requested.top
        .clamp(
          display.top,
          display.bottom - (height < display.height ? height : display.height),
        )
        .toDouble(),
    width,
    height,
  );
}

class DesktopRuntime extends ChangeNotifier with WindowListener, TrayListener {
  DesktopRuntime._();
  static final instance = DesktopRuntime._();
  bool ready = false, autostart = false, floating = false, trayReady = false;
  bool _closing = false;
  String? error;
  Timer? _saveTimer;
  Future<void> Function()? openDashboard, openSettings, refresh;

  Future<void> initialize() async {
    if (!isDesktopClient) return;
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      autostart = await startup.startupEnabled();
    } catch (_) {
      error = '无法读取开机启动状态。';
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        trayManager.addListener(this);
        await trayManager.setIcon('assets/tray.ico');
        await trayManager.setToolTip('星账 Astracct');
        await _updateTrayMenu();
        trayReady = true;
      } catch (_) {
        error = '系统托盘初始化失败，关闭窗口时将最小化到任务栏。';
      }
    } else {
      trayReady = true;
    }
    try {
      final saved = AppPreferences.instance.window;
      if (AppPreferences.instance.rememberWindow && saved != null) {
        final displays = await screenRetriever.getAllDisplays();
        final requested = Rect.fromLTWH(
          (saved['x'] as num).toDouble(),
          (saved['y'] as num).toDouble(),
          (saved['width'] as num).toDouble(),
          (saved['height'] as num).toDouble(),
        );
        if (requested.isFinite && displays.isNotEmpty) {
          final areas = displays
              .map(
                (d) =>
                    (d.visiblePosition ?? Offset.zero) &
                    (d.visibleSize ?? d.size),
              )
              .toList();
          final display = areas.firstWhere(
            (area) => area.overlaps(requested),
            orElse: () => areas.first,
          );
          await windowManager.setMinimumSize(
            Size(math.min(640, display.width), math.min(420, display.height)),
          );
          await windowManager.setBounds(visibleWindow(requested, display));
        }
      }
    } catch (_) {
      error ??= '窗口位置无法恢复，已使用默认位置。';
    }
    AppPreferences.instance.addListener(_languageChanged);
    ready = true;
    if (AppPreferences.instance.startMinimized && trayReady)
      await minimizeToTray();
  }

  String? _lastLanguage;
  void _languageChanged() {
    final current = systemText('设置');
    if (current == _lastLanguage ||
        !trayReady ||
        defaultTargetPlatform != TargetPlatform.windows)
      return;
    _lastLanguage = current;
    _updateTrayMenu().catchError((Object _) {
      error = '托盘菜单更新失败。';
    });
  }

  Future<void> _updateTrayMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: systemText('打开星账')),
          MenuItem(key: 'settings', label: systemText('设置')),
          MenuItem(key: 'refresh', label: systemText('刷新')),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: systemText('退出星账')),
        ],
      ),
    );
  }

  Future<void> setAutostart(bool value) async {
    await startup.configureStartup(value);
    autostart = await startup.startupEnabled();
    if (autostart != value) throw StateError('Startup setting was not applied');
    notifyListeners();
  }

  Future<void> minimizeToTray() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await macMenuChannel.invokeMethod<void>('minimizeToMenuBar');
    } else if (trayReady) {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<void> reveal() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await macMenuChannel.invokeMethod<void>('reopen');
    } else {
      await windowManager.setSkipTaskbar(false);
    }
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
    await openDashboard?.call();
  }

  Future<void> requestQuit() async {
    if (_closing) return;
    if (!AppPreferences.instance.locked &&
        await EditSession.beforeClose?.call() == false)
      return;
    _closing = true;
    try {
      await _saveBounds();
    } catch (_) {
      error = '窗口位置保存失败。';
    }
    try {
      await windowManager.setPreventClose(false);
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await macMenuChannel.invokeMethod<void>('quit');
      } else {
        await windowManager.destroy();
      }
    } catch (_) {
      _closing = false;
      error = '无法退出应用，请重试。';
      await windowManager.setPreventClose(true);
    }
  }

  Future<void> _saveBounds() async {
    if (!ready ||
        floating ||
        !AppPreferences.instance.rememberWindow ||
        await windowManager.isMinimized() ||
        await windowManager.isMaximized())
      return;
    final rect = await windowManager.getBounds();
    await AppPreferences.instance.set('window', {
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await _saveBounds();
      } catch (_) {
        error = '窗口位置保存失败。';
      }
    });
  }

  @override
  void onWindowMoved() => _scheduleSave();
  @override
  void onWindowResized() => _scheduleSave();
  @override
  void onWindowBlur() {
    if (!AppPreferences.instance.authenticating)
      AppPreferences.instance.conceal();
  }

  @override
  void onWindowClose() => unawaited(closeToTray());

  Future<void> closeToTray() async {
    if (_closing) return;
    if (await EditSession.beforeClose?.call() == false) return;
    {
      AppPreferences.instance.conceal();
      try {
        await _saveBounds();
      } catch (_) {
        error = '窗口位置保存失败。';
      }
      await minimizeToTray();
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(reveal());
  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());
  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'open':
        unawaited(reveal());
      case 'settings':
        unawaited(
          reveal().then((_) async {
            if (!AppPreferences.instance.locked) await openSettings?.call();
          }),
        );
      case 'refresh':
        if (!AppPreferences.instance.locked) unawaited(refresh?.call());
      case 'quit':
        unawaited(requestQuit());
    }
  }
}
