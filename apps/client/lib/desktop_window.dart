import 'package:flutter/material.dart';
import 'macos_menu_bar.dart';
import 'package:window_manager/window_manager.dart';

abstract interface class DesktopWindowHost {
  Future<Rect> bounds();
  Future<void> apply({required bool floating, required Rect bounds, required bool pinned});
  Future<void> pin(bool value);
  Future<void> drag();
  Future<void> close();
}

class NativeDesktopWindow implements DesktopWindowHost {
  static Future<void> initialize() async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(const WindowOptions(
      size: Size(900, 680), minimumSize: Size(640, 420),
      center: true, title: '星账 Astracct',
    ), () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Future<Rect> bounds() => windowManager.getBounds();
  @override
  Future<void> apply({required bool floating, required Rect bounds, required bool pinned}) async {
    if (await windowManager.isMaximized()) await windowManager.unmaximize();
    await windowManager.setMinimumSize(floating ? const Size(320, 180) : const Size(640, 420));
    await windowManager.setTitleBarStyle(
      floating ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !floating,
    );
    await windowManager.setBounds(bounds);
    await windowManager.setAlwaysOnTop(pinned);
    await windowManager.show();
  }
  @override
  Future<void> pin(bool value) => windowManager.setAlwaysOnTop(value);
  @override
  Future<void> drag() => windowManager.startDragging();
  @override
  Future<void> close() => supportsMacMenuBar
      ? macMenuChannel.invokeMethod<void>('quit') : windowManager.close();
}

class DesktopWindowController extends ChangeNotifier {
  DesktopWindowController({DesktopWindowHost? host}) : _host = host ?? NativeDesktopWindow();
  final DesktopWindowHost _host;
  bool floating = false, pinned = false, busy = false;
  String? error;
  Rect? _dashboardBounds;

  Future<void> setFloating(bool value) async {
    if (busy || value == floating) return;
    busy = true; error = null; notifyListeners();
    Rect? previous;
    final oldFloating = floating, oldPinned = pinned;
    try {
      previous = await _host.bounds();
      if (value) _dashboardBounds = previous;
      final next = value
          ? Rect.fromLTWH(previous.left, previous.top, 360, 320)
          : _dashboardBounds ?? Rect.fromLTWH(previous.left, previous.top, 900, 680);
      await _host.apply(floating: value, bounds: next, pinned: value);
      floating = value;
      pinned = value;
    } catch (_) {
      // A partially applied native change must not strand the user in compact mode.
      if (previous != null) {
        try { await _host.apply(floating: oldFloating, bounds: previous, pinned: oldPinned); }
        catch (_) {
          // Keep the compact recovery/exit controls visible if native rollback failed.
          floating = true;
          error = '窗口恢复失败，请通过悬浮窗按钮返回或退出。';
        }
      }
      error ??= '窗口切换失败，请重试。';
    } finally { busy = false; notifyListeners(); }
  }

  Future<void> togglePin() async {
    if (busy) return;
    busy = true; error = null; notifyListeners();
    try { await _host.pin(!pinned); pinned = !pinned; }
    catch (_) { error = '置顶设置失败，请重试。'; }
    finally { busy = false; notifyListeners(); }
  }
  Future<void> drag() async {
    try { await _host.drag(); } catch (_) { error = '无法拖动窗口。'; notifyListeners(); }
  }
  Future<void> close() async {
    try { await _host.close(); } catch (_) { error = '关闭窗口失败，请重试。'; notifyListeners(); }
  }
}
