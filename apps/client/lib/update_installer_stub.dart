import 'app_update.dart';

Future<String> downloadUpdate(
  AppRelease release,
  void Function(double) progress,
) => throw UnsupportedError('请刷新网页版获取更新');
Future<void> installUpdate(String path, AppRelease release) =>
    throw UnsupportedError('请刷新网页版获取更新');
