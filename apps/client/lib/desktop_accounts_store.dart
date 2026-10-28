import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_accounts.dart';
import 'credential_store.dart';

/// macOS uses local credentials; other desktop platforms retain system storage.
class DesktopAccountsStore implements AccountsStore {
  DesktopAccountsStore({FlutterSecureStorage? storage})
    : _storage = storage != null
          ? SystemCredentialStore(storage)
          : credentialStore(
              'accounts',
              const FlutterSecureStorage(
                mOptions: MacOsOptions(
                  accountName: 'com.yuashie.astracct.desktop',
                  usesDataProtectionKeychain: false,
                ),
              ),
            );
  final CredentialStore _storage;
  static const accountsKey = 'astracct.desktop.accounts.v1';

  @override
  Future<String?> read() => _storage.read(key: accountsKey);
  @override
  Future<void> write(String value) =>
      _storage.write(key: accountsKey, value: value);
}
