import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_accounts.dart';

/// Desktop-only vault. Android continues to use its existing Keystore channel.
class DesktopAccountsStore implements AccountsStore {
  DesktopAccountsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          mOptions: MacOsOptions(
            accountName: 'com.yuashie.astracct.desktop',
            usesDataProtectionKeychain: false,
          ),
        );
  final FlutterSecureStorage _storage;
  static const accountsKey = 'astracct.desktop.accounts.v1';

  @override
  Future<String?> read() => _storage.read(key: accountsKey);
  @override
  Future<void> write(String value) => _storage.write(key: accountsKey, value: value);
}
