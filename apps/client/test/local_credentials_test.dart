import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/credential_store.dart';
import 'package:quota_hub/credential_store_io.dart';

class LegacyStore implements CredentialStore {
  final values = <String, String>{'token': 'synthetic-old-token'};
  int reads = 0;
  bool fail = false;
  @override
  Future<String?> read({required String key}) async {
    reads++;
    if (fail) throw StateError('Migration denied');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
  @override
  Future<void> delete({required String key}) async => values.remove(key);
}

void main() {
  late Directory root;
  late LegacyStore legacy;
  LocalCredentialStore store() => LocalCredentialStore(
    namespace: 'identity',
    legacy: legacy,
    directory: root,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('astracct-credentials-test-');
    legacy = LegacyStore();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'migrates once, persists after restart and logout cannot resurrect legacy token',
    () async {
      expect(await store().read(key: 'token'), 'synthetic-old-token');
      legacy.fail = true;
      expect(await store().read(key: 'token'), 'synthetic-old-token');
      await store().delete(key: 'token');
      expect(await store().read(key: 'token'), isNull);
      expect(legacy.reads, 1);
      await store().write(key: 'token', value: 'synthetic-new-token');
      expect(await store().read(key: 'token'), 'synthetic-new-token');
    },
  );
  test(
    'denied migration does not create or overwrite local credentials',
    () async {
      legacy.fail = true;
      await expectLater(store().read(key: 'token'), throwsStateError);
      expect(await File('${root.path}/identity.json').exists(), false);
      legacy.fail = false;
      expect(await store().read(key: 'token'), 'synthetic-old-token');
    },
  );
  test(
    'corrupt credentials fail closed and survive attempted writes',
    () async {
      final file = File('${root.path}/identity.json');
      await file.writeAsString('{broken');
      await expectLater(
        store().write(key: 'token', value: 'replacement'),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{broken');
    },
  );
  test(
    'concurrent instances preserve distinct keys and new writes never read keychain',
    () async {
      await Future.wait(
        List.generate(
          12,
          (i) => store().write(key: 'key-$i', value: 'synthetic-$i'),
        ),
      );
      final data =
          jsonDecode(await File('${root.path}/identity.json').readAsString())
              as Map;
      expect((data['values'] as Map).length, 12);
      expect(legacy.reads, 0);
      if (!Platform.isWindows) {
        final fileMode =
            (await File('${root.path}/identity.json').stat()).mode & 0x1ff;
        final dirMode = (await root.stat()).mode & 0x1ff;
        expect(fileMode, 0x180); // 0600
        expect(dirMode, 0x1c0); // 0700
      }
    },
  );
  test(
    'refuses symlink credential files without changing their targets',
    () async {
      final target = File('${root.path}/outside.json');
      await target.writeAsString('untouched');
      await Link('${root.path}/identity.json').create(target.path);
      await expectLater(
        store().write(key: 'token', value: 'replacement'),
        throwsStateError,
      );
      expect(await target.readAsString(), 'untouched');
    },
  );
}
