import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<int> clearUpdateCache() async {
  final root = Directory(
    '${(await getTemporaryDirectory()).path}/astracct-updates',
  );
  // Delete only regular files in our update-download directory. Do not traverse
  // links, touch the vault, or remove a running installer's extracted directory.
  if (!await root.exists() || await FileSystemEntity.isLink(root.path))
    return 0;
  var bytes = 0;
  await for (final entry in root.list(followLinks: false)) {
    if (entry is File) {
      bytes += await entry.length();
      await entry.delete();
    }
  }
  return bytes;
}
