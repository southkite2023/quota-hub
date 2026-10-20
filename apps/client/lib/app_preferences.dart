import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

/// UI preferences never contain provider credentials. The lock flag is kept in
/// secure storage separately, so a corrupt preference file cannot disable it.
class AppPreferences extends ChangeNotifier {
  AppPreferences({
    FlutterSecureStorage? security,
    LocalAuthentication? auth,
    Future<String?> Function()? readPreferences,
    Future<void> Function(String)? writePreferences,
    Map<String, dynamic> initialValues = const {},
  }) : security =
           security ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(
               accountName: 'com.yuashie.astracct.settings',
               usesDataProtectionKeychain: false,
             ),
           ),
       auth = auth ?? LocalAuthentication(),
       _readPreferences = readPreferences,
       _writePreferences = writePreferences,
       _values = {...initialValues};
  static AppPreferences instance = AppPreferences();
  final FlutterSecureStorage security;
  final LocalAuthentication auth;
  final Future<String?> Function()? _readPreferences;
  final Future<void> Function(String)? _writePreferences;
  Future<void>? _writes;
  Future<void> _persist(Map<String, dynamic> value) => _writePreferences != null
      ? _writePreferences(jsonEncode(value))
      : _store.setString(key, jsonEncode(value));
  late final SharedPreferencesAsync _store = SharedPreferencesAsync();
  static const key = 'astracct.ui.v2';
  static const lockKey = 'astracct.app-lock.v1';
  Map<String, dynamic> _values;
  bool locked = false, lockEnabled = false, authenticating = false;
  bool hidden = false, loading = false;
  String? error;
  bool get dark => themeMode == ThemeMode.dark;
  ThemeMode get themeMode => switch (_values['theme']) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  String get language => ['zh', 'en'].contains(_values['language'])
      ? _values['language'] as String
      : 'system';
  Locale? get locale => language == 'system' ? null : Locale(language);
  bool get autoHide => _values['autoHide'] == true;
  bool get highContrast => _values['highContrast'] == true;
  bool get reduceMotion => _values['reduceMotion'] == true;
  bool get rememberWindow => _values['rememberWindow'] != false;
  bool get startMinimized => _values['startMinimized'] == true;
  bool get keepRunning => _values['keepRunning'] != false;
  bool get hideAmounts => hidden || locked || loading;
  Map<String, dynamic>? get window => _values['window'] is Map
      ? Map<String, dynamic>.from(_values['window'] as Map)
      : null;
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  Future<void> load() async {
    loading = true;
    error = null;
    try {
      // Always read the security flag before showing the application.
      final policy = await security.read(key: lockKey);
      if (policy != null && !['enabled', 'disabled'].contains(policy))
        throw const FormatException('Invalid lock policy');
      lockEnabled = policy == 'enabled';
      locked = lockEnabled;
    } catch (_) {
      locked = true;
      error = '无法读取应用锁设置，请重试。';
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final raw = await (_readPreferences?.call() ?? _store.getString(key));
      if (raw != null)
        _values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      hidden = _values['hidden'] == true;
    } catch (_) {
      error = '通用设置读取失败，已使用默认外观；账户和应用锁不受影响。';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _change(
    Map<String, dynamic> Function(Map<String, dynamic>) change, {
    bool updateHidden = false,
  }) {
    Future<void> apply() async {
      final next = change({..._values});
      await _persist(next);
      _values = next;
      if (updateHidden) hidden = next['hidden'] == true;
      notifyListeners();
    }

    late final Future<void> operation;
    operation =
        (_writes == null
                ? apply()
                : _writes!.catchError((Object _) {}).then((_) => apply()))
            .whenComplete(() {
              if (identical(_writes, operation)) _writes = null;
            });
    _writes = operation;
    return operation;
  }

  Future<void> set(String name, Object? value) => _change(
    (current) => {...current, name: value},
    updateHidden: name == 'hidden',
  );
  Future<void> toggleHidden() async {
    if (locked) return;
    await _change(
      (current) => {...current, 'hidden': !hidden},
      updateHidden: true,
    );
  }

  void conceal() {
    if (autoHide || lockEnabled) hidden = true;
    if (lockEnabled) locked = true;
    if (hidden && _values['hidden'] != true) {
      set('hidden', true).catchError((Object _) {
        error = '隐私设置保存失败，当前金额仍保持隐藏。';
      });
    }
    notifyListeners();
  }

  Future<bool> authenticate(String reason) async {
    if (authenticating) return false;
    authenticating = true;
    notifyListeners();
    try {
      if (!await auth.isDeviceSupported()) {
        error = '此设备未配置系统身份验证，请先设置系统密码或生物识别。';
        return false;
      }
      final accepted = await auth.authenticate(localizedReason: reason);
      if (!accepted)
        error = '验证已取消，可再次尝试。';
      else
        error = null;
      return accepted;
    } catch (_) {
      error = '系统身份验证暂不可用，请检查系统安全设置后重试。';
      return false;
    } finally {
      authenticating = false;
      notifyListeners();
    }
  }

  Future<bool> setLock(bool enabled, String reason) async {
    if (!await authenticate(reason)) return false;
    // Commit before changing the active policy. Never unlock on a write error.
    await security.write(key: lockKey, value: enabled ? 'enabled' : 'disabled');
    lockEnabled = enabled;
    notifyListeners();
    return true;
  }

  Future<void> unlock(String reason) async {
    if (error == '无法读取应用锁设置，请重试。') {
      await load();
      return;
    }
    if (await authenticate(reason)) {
      locked = false;
      notifyListeners();
    }
  }

  Future<void> resetAppearance() => _change(
    (current) => current
      ..remove('theme')
      ..remove('language')
      ..remove('highContrast')
      ..remove('reduceMotion'),
  );
}
