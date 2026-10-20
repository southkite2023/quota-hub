import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_update.dart';
import 'app_activity.dart';
import 'update_installer_stub.dart'
    if (dart.library.io) 'update_installer_io.dart'
    as installer;

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key});
  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  bool _busy = false;
  String _status = '从 yuashie.cn 获取当前平台最新公开测试版';
  AppRelease? _release;
  String? _download;
  double? _progress;
  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = '正在检查更新…';
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await findAppUpdate(info.version);
      if (!mounted) return;
      setState(() {
        _release = release;
        _download = null;
        _status = release == null
            ? '当前 v${info.version} 已是此平台最新版本'
            : 'v${info.version} → v${release.version} · ${(release.bytes / 1000000).toStringAsFixed(2)} MB · 公开测试版';
      });
    } catch (_) {
      if (mounted) setState(() => _status = '检查失败，请重试，或打开官网下载。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    if (UpdateActivity.busy && !_busy) return;
    final release = _release!;
    if (_download == null) {
      setState(() {
        _busy = true;
        UpdateActivity.busy = true;
        _status = '正在从服务器下载安装包…';
        _progress = 0;
      });
      try {
        _download = await installer.downloadUpdate(release, (value) {
          if (mounted) setState(() => _progress = value);
        });
        if (mounted) setState(() => _status = '下载完成，SHA-256 校验通过。点击安装继续。');
      } catch (_) {
        if (mounted) setState(() => _status = '下载或校验失败，请重试。');
      } finally {
        UpdateActivity.busy = false;
        if (mounted)
          setState(() {
            _busy = false;
            UpdateActivity.busy = false;
            _progress = null;
          });
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('安装更新？'),
        content: AppText(
          defaultTargetPlatform == TargetPlatform.android
              ? '将打开系统安装确认。如需授权“允许此来源安装”，完成后返回并再次点击安装。本机账户数据会保留。'
              : '应用将退出，替换当前程序后重新打开。请先完成账户编辑。本机账户数据会保留；旧程序会备份在同一目录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('安装'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      UpdateActivity.busy = true;
    });
    try {
      await installer.installUpdate(_download!, release);
      if (mounted) setState(() => _status = '请在系统页面完成安装；如取消可再次点击安装。');
    } catch (_) {
      if (mounted) setState(() => _status = '安装尚未完成。请检查系统安装权限或目录写入权限，然后重试。');
    } finally {
      UpdateActivity.busy = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('应用更新'),
          const SizedBox(height: 8),
          AppText(_status),
          if (_progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            AppText('${(_progress! * 100).toStringAsFixed(0)}%'),
          ],
          if (_release != null && _release!.notes.isNotEmpty)
            ExpansionTile(
              title: const AppText('更新说明'),
              children: [AppText(_release!.notes)],
            ),
          Wrap(
            spacing: 12,
            children: [
              if (!kIsWeb && updatePlatform != null)
                TextButton(
                  onPressed: _busy ? null : _check,
                  child: const AppText('检查更新'),
                ),
              if (_release != null)
                FilledButton(
                  onPressed: _busy ? null : _downloadAndInstall,
                  child: AppText(_download == null ? '下载更新' : '安装更新'),
                ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://yuashie.cn/projects/001/download'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const AppText('官网下载'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
