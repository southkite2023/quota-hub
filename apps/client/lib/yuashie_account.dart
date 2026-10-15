import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AccountFailure implements Exception {
  const AccountFailure(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class YuashieAccount extends ChangeNotifier {
  YuashieAccount({
    http.Client? client,
    FlutterSecureStorage? storage,
    Future<bool> Function(Uri)? openBrowser,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? sessionStorage,
       _openBrowser =
           openBrowser ??
           ((uri) => launchUrl(
             uri,
             mode: LaunchMode.externalApplication,
             webOnlyWindowName: '_blank',
           ));
  // Direct-distribution macOS builds have no shared-keychain provisioning profile.
  // Use the encrypted login keychain with a dedicated service for account sessions.
  static const sessionStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: 'com.yuashie.astracct.identity',
      usesDataProtectionKeychain: false,
    ),
  );
  static final shared = YuashieAccount();
  static const origin = 'https://yuashie.cn';
  static const _storageKey = 'yuashie_login_session_v1';
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<bool> Function(Uri) _openBrowser;
  Map<String, dynamic>? user, config;
  String? _token, error;
  bool ready = false, busy = false, waitingForBrowser = false;
  Uri? browserUrl;
  int _flow = 0;
  Future<void>? _initializing;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    try {
      final headers = <String, String>{
        'Origin': origin,
        'Accept': 'application/json',
      };
      if (body != null) headers['Content-Type'] = 'application/json';
      if (authenticated && _token != null)
        headers['Authorization'] = 'Bearer $_token';
      final uri = Uri.parse('$origin/api$path');
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode >= 400)
        throw AccountFailure(
          decoded['message'] is String
              ? decoded['message'] as String
              : '账号服务暂不可用。',
          response.statusCode,
        );
      return decoded;
    } on AccountFailure {
      rethrow;
    } on TimeoutException {
      throw const AccountFailure('连接超时，请稍后重试。');
    } on FormatException {
      throw const AccountFailure('账号服务正在更新，请稍后重试。');
    } catch (_) {
      throw const AccountFailure('无法连接账号服务，请检查网络。');
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    error = null;
    try {
      config = await _request('/auth/config');
      _token = await _storage.read(key: _storageKey);
      if (_token != null) {
        try {
          user =
              (await _request('/auth/me', authenticated: true))['user']
                  as Map<String, dynamic>;
        } on AccountFailure catch (e) {
          if (e.status == 401) {
            await _storage.delete(key: _storageKey);
            _token = null;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      error = e is AccountFailure ? e.message : '无法读取安全登录凭证，请重试。';
    }
    ready = true;
    _initializing = null;
    notifyListeners();
  }

  Future<void> _accept(Map<String, dynamic> result) async {
    final token = result['token'];
    final account = result['user'];
    if (token is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token) ||
        account is! Map<String, dynamic>)
      throw const AccountFailure('登录响应不完整，请重试。');
    try {
      await _storage.write(key: _storageKey, value: token);
    } catch (_) {
      throw const AccountFailure('无法安全保存登录凭证，请检查系统安全存储。');
    }
    _token = token;
    user = account;
  }

  Future<bool> login(String identifier, String password) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _accept(
        await _request(
          '/auth/native/login',
          body: {'identifier': identifier.trim(), 'password': password},
        ),
      );
      return true;
    } catch (e) {
      error = e is AccountFailure ? e.message : '登录失败，请重试。';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> browserLogin({String? provider, bool register = false}) async {
    if (busy) return;
    final flow = ++_flow;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final random = Random.secure();
      final verifier = base64Url
          .encode(List<int>.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      final challenge = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');
      final result = await _request(
        '/auth/app/requests',
        body: {'challenge': challenge},
      );
      final id = result['id'];
      if (id is! String || !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id))
        throw const AccountFailure('登录请求无效。');
      final redirect = '/auth/approve?request=$id';
      final uri = provider != null
          ? Uri.parse(
              '$origin/api/auth/oauth/$provider/start',
            ).replace(queryParameters: {'redirect': redirect})
          : Uri.parse(
              '$origin/${register ? 'register' : 'login'}',
            ).replace(queryParameters: {'redirect': redirect});
      if (flow != _flow) return;
      browserUrl = uri;
      waitingForBrowser = true;
      notifyListeners();
      if (!await _openBrowser(uri))
        throw const AccountFailure('无法打开系统浏览器，请检查默认浏览器后重试。');
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      while (flow == _flow && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (flow != _flow) return;
        final exchange = await _request(
          '/auth/app/exchange',
          body: {'id': id, 'verifier': verifier},
        );
        if (flow != _flow) return;
        if (exchange['pending'] == true) continue;
        await _accept(exchange);
        return;
      }
      if (flow == _flow) throw const AccountFailure('登录已超时，请重新发起。');
    } catch (e) {
      if (flow == _flow)
        error = e is AccountFailure ? e.message : '授权登录失败，请重试。';
    } finally {
      if (flow == _flow) {
        busy = false;
        waitingForBrowser = false;
        browserUrl = null;
        notifyListeners();
      }
    }
  }

  void cancelBrowserLogin() {
    ++_flow;
    busy = false;
    waitingForBrowser = false;
    browserUrl = null;
    error = null;
    notifyListeners();
  }

  Future<void> reopenBrowser() async {
    if (browserUrl != null) await _openBrowser(browserUrl!);
  }

  Future<void> openPasswordHelp() async {
    await _openBrowser(Uri.parse('$origin/forgot-password'));
  }

  Future<void> openSecurity() async {
    await _openBrowser(Uri.parse('$origin/auth/security'));
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      try {
        await _request('/auth/logout', body: {}, authenticated: true);
      } on AccountFailure catch (e) {
        if (e.status != 401) rethrow;
      }
      await _storage.delete(key: _storageKey);
      _token = null;
      user = null;
    } catch (e) {
      error = e is AccountFailure ? e.message : '无法清除登录凭证，请重试。';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    ++_flow;
    _client.close();
    super.dispose();
  }
}
