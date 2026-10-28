import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'credential_store_stub.dart'
    if (dart.library.io) 'credential_store_io.dart'
    as platform;

abstract class CredentialStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class SystemCredentialStore implements CredentialStore {
  SystemCredentialStore(this.storage);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read({required String key}) => storage.read(key: key);
  @override
  Future<void> write({required String key, required String value}) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete({required String key}) => storage.delete(key: key);
}

CredentialStore credentialStore(
  String namespace,
  FlutterSecureStorage legacy,
) => platform.createCredentialStore(namespace, SystemCredentialStore(legacy));
