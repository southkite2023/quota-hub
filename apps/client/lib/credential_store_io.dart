import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'credential_store.dart';

CredentialStore createCredentialStore(
  String namespace,
  CredentialStore legacy,
) => Platform.isMacOS
    ? LocalCredentialStore(namespace: namespace, legacy: legacy)
    : legacy;

/// Local plaintext credentials, protected by owner-only filesystem permissions.
/// A missing key is migrated once. Null tombstones prevent logout from importing it again.
class LocalCredentialStore implements CredentialStore {
  LocalCredentialStore({
    required this.namespace,
    required this.legacy,
    this.directory,
  });
  final String namespace;
  final CredentialStore legacy;
  final Directory? directory;
  static final Map<String, Future<void>> _queues = {};

  Future<Directory> _root() async {
    if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(namespace))
      throw StateError('Invalid credential namespace');
    final root =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/credentials',
        );
    final type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw StateError('Invalid credential directory');
    }
    await root.create(recursive: true);
    await _private(root.path, '700');
    return root;
  }

  Future<void> _private(String path, String mode) async {
    if (!Platform.isWindows) {
      final result = await Process.run('/bin/chmod', [mode, path]);
      if (result.exitCode != 0)
        throw FileSystemException('Cannot protect credential storage');
    }
  }

  Future<T> _access<T>(
    Future<T> Function(File, Map<String, dynamic>) action,
  ) async {
    final root = await _root();
    final file = File('${root.path}/$namespace.json');
    final previous = _queues[file.path] ?? Future<void>.value();
    final operation = previous.catchError((_) {}).then((_) async {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('Invalid credential file');
      }
      Map<String, dynamic> values = {};
      if (type == FileSystemEntityType.file) {
        await _private(file.path, '600');
        final data = jsonDecode(await file.readAsString());
        if (data is! Map || data['version'] != 1 || data['values'] is! Map) {
          throw const FormatException('Invalid credential storage');
        }
        values = Map<String, dynamic>.from(data['values'] as Map);
        if (values.values.any((v) => v != null && v is! String)) {
          throw const FormatException('Invalid credential value');
        }
      }
      return action(file, values);
    });
    final completed = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queues[file.path] = completed;
    try {
      return await operation;
    } finally {
      if (identical(_queues[file.path], completed)) _queues.remove(file.path);
    }
  }

  Future<void> _save(File file, Map<String, dynamic> values) async {
    final suffix = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final temp = File('${file.path}.$suffix.tmp');
    try {
      await temp.create(exclusive: true);
      // Set permissions before any secret is written.
      await _private(temp.path, '600');
      await temp.writeAsString(
        jsonEncode({'version': 1, 'values': values}),
        flush: true,
      );
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  @override
  Future<String?> read({required String key}) => _access((file, values) async {
    if (!values.containsKey(key)) {
      // Existing installations may show one system authorization during migration.
      // Failure is propagated; never replace unreadable credentials with an empty store.
      values[key] = await legacy.read(key: key);
      await _save(file, values);
    }
    return values[key] as String?;
  });
  @override
  Future<void> write({required String key, required String value}) =>
      _access((file, values) async {
        values[key] = value;
        await _save(file, values);
      });
  @override
  Future<void> delete({required String key}) => _access((file, values) async {
    values[key] = null;
    await _save(file, values);
  });
}
