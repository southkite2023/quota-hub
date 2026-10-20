import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'account_settings.dart';
import 'api_accounts.dart';
import 'app_preferences.dart';
import 'app_activity.dart';
import 'app_update_card.dart';
import 'desktop_runtime.dart';
import 'desktop_platform.dart';
import 'refresh_settings.dart';
import 'yuashie_login.dart';
import 'maintenance_stub.dart'
    if (dart.library.io) 'maintenance_io.dart'
    as maintenance;

Future<void> openAppLink(BuildContext context, String target) async {
  try {
    if (!await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('browser unavailable');
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('无法打开页面，请检查默认浏览器后重试。')));
  }
}

class SettingsCenter extends StatelessWidget {
  const SettingsCenter({
    super.key,
    required this.accounts,
    this.desktop = false,
  });
  final ApiAccounts accounts;
  final bool desktop;
  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: '设置',
    children: [
      const YuashieAccountCard(),
      _entry(
        context,
        Icons.tune,
        '通用',
        '刷新、启动与窗口行为',
        GeneralSettings(accounts: accounts, desktop: desktop),
      ),
      _entry(
        context,
        Icons.palette_outlined,
        '外观与无障碍',
        '主题、语言、对比度与动画',
        const AppearanceSettings(),
      ),
      if (!kIsWeb)
        _entry(
          context,
          Icons.account_balance_wallet_outlined,
          '余额账户',
          '添加、编辑及小组件选择',
          AccountSettings(connection: accounts, desktop: desktop),
        ),
      _entry(
        context,
        Icons.security_outlined,
        '账户与安全',
        '登录管理与应用锁',
        const SecuritySettings(),
      ),
      _entry(
        context,
        Icons.privacy_tip_outlined,
        '隐私与本机管理',
        '金额保护、权限和临时文件',
        PrivacySettings(accounts: accounts),
      ),
      _entry(
        context,
        Icons.help_outline,
        '帮助与反馈',
        '使用指南、常见问题和问题反馈',
        const HelpSettings(),
      ),
      _entry(
        context,
        Icons.info_outline,
        '关于星账',
        '版本、更新日志与开源许可',
        const AboutSettings(),
      ),
    ],
  );
  Widget _entry(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: AppText(title),
      subtitle: AppText(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context, page),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(title)),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> settingsAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('操作未完成，原有配置已保留，请重试。')));
  }
}

class GeneralSettings extends StatelessWidget {
  const GeneralSettings({
    super.key,
    required this.accounts,
    required this.desktop,
  });
  final ApiAccounts accounts;
  final bool desktop;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      return SettingsPage(
        title: '通用',
        children: [
          if (!kIsWeb) RefreshSettings(accounts: accounts, desktop: desktop),
          if (kIsWeb) const AppText('网页端刷新由浏览器管理。'),
          if (desktop) ...[
            SwitchListTile(
              title: const AppText('开机启动'),
              subtitle: const AppText('登录系统后自动启动星账，默认关闭'),
              value: DesktopRuntime.instance.autostart,
              onChanged: (value) => settingsAction(context, () async {
                await DesktopRuntime.instance.setAutostart(value);
                await prefs.set(
                  'startupChanged',
                  DateTime.now().toIso8601String(),
                );
              }),
            ),
            SwitchListTile(
              title: const AppText('启动时最小化'),
              subtitle: const AppText('在菜单栏或系统托盘中运行'),
              value: prefs.startMinimized,
              onChanged: (v) =>
                  settingsAction(context, () => prefs.set('startMinimized', v)),
            ),
            SwitchListTile(
              title: const AppText('关闭窗口后继续运行'),
              subtitle: const AppText('通过菜单栏或托盘的“退出星账”彻底退出'),
              value: prefs.keepRunning,
              onChanged: (v) =>
                  settingsAction(context, () => prefs.set('keepRunning', v)),
            ),
            SwitchListTile(
              title: const AppText('记住窗口位置和大小'),
              subtitle: const AppText('下次打开时恢复；显示器变化时自动移回可见区域'),
              value: prefs.rememberWindow,
              onChanged: (v) =>
                  settingsAction(context, () => prefs.set('rememberWindow', v)),
            ),
            const ListTile(
              title: AppText('键盘快捷键'),
              subtitle: AppText(
                'Ctrl / ⌘ + ,：设置\nCtrl / ⌘ + R：刷新\nCtrl / ⌘ + Shift + H：隐藏或显示金额\nEsc：退出悬浮模式',
              ),
            ),
          ],
        ],
      );
    },
  );
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      return SettingsPage(
        title: '外观与无障碍',
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('theme-${prefs.themeMode.name}'),
            initialValue: prefs.themeMode.name,
            decoration: InputDecoration(labelText: context.tr('主题')),
            items: const [
              DropdownMenuItem(value: 'system', child: AppText('跟随系统')),
              DropdownMenuItem(value: 'light', child: AppText('浅色')),
              DropdownMenuItem(value: 'dark', child: AppText('深色')),
            ],
            onChanged: (v) =>
                settingsAction(context, () => prefs.set('theme', v)),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('language-${prefs.language}'),
            initialValue: prefs.language,
            decoration: InputDecoration(labelText: context.tr('语言 / Language')),
            items: const [
              DropdownMenuItem(value: 'system', child: AppText('跟随系统')),
              DropdownMenuItem(value: 'zh', child: AppText('简体中文')),
              DropdownMenuItem(value: 'en', child: AppText('English')),
            ],
            onChanged: (v) =>
                settingsAction(context, () => prefs.set('language', v)),
          ),
          SwitchListTile(
            title: const AppText('增强对比度'),
            value: prefs.highContrast,
            onChanged: (v) =>
                settingsAction(context, () => prefs.set('highContrast', v)),
          ),
          SwitchListTile(
            title: const AppText('减少动画'),
            subtitle: const AppText('也会遵循系统的减少动态效果设置'),
            value: prefs.reduceMotion,
            onChanged: (v) =>
                settingsAction(context, () => prefs.set('reduceMotion', v)),
          ),
          const ListTile(
            title: AppText('文字大小'),
            subtitle: AppText('跟随系统字体大小。支持读屏和 Tab 键导航，状态同时使用文字说明。'),
          ),
        ],
      );
    },
  );
}

class SecuritySettings extends StatelessWidget {
  const SecuritySettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      return SettingsPage(
        title: '账户与安全',
        children: [
          const YuashieAccountCard(),
          SwitchListTile(
            title: const AppText('应用锁'),
            subtitle: const AppText('打开应用或离开后返回时，使用系统密码、指纹或面容验证'),
            value: prefs.lockEnabled,
            onChanged: kIsWeb || prefs.authenticating
                ? null
                : (v) => settingsAction(context, () async {
                    await prefs.setLock(v, context.tr('验证身份以更改星账应用锁'));
                  }),
          ),
          if (kIsWeb) const AppText('网页版暂不提供系统应用锁。'),
          if (prefs.error != null) AppText(prefs.error!),
          const AppText('应用锁保护此应用的界面访问。桌面小组件独立显示，请按需要隐藏金额或移除小组件。'),
          const AppText('余额凭据保存在本机安全存储。Yuashie 登录仅用于账号服务，不会自动上传余额密钥。'),
        ],
      );
    },
  );
}

class PrivacySettings extends StatefulWidget {
  const PrivacySettings({super.key, required this.accounts});
  final ApiAccounts accounts;
  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  Map<dynamic, dynamic>? _permission;
  bool _working = false;
  String? _status;
  Future<void> _permissions() async {
    await widget.accounts.readBackgroundStatus();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final state = await const MethodChannel(
          'astracct/system',
        ).invokeMapMethod('permissions');
        if (mounted) setState(() => _permission = state);
      } catch (_) {
        if (mounted) setState(() => _status = '无法读取系统权限，请打开系统设置查看。');
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _permissions();
  }

  Future<void> _systemSettings() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await settingsAction(
        context,
        () => const MethodChannel(
          'astracct/system',
        ).invokeMethod<void>('openSettings'),
      );
    } else if (isDesktopClient) {
      await openAppLink(
        context,
        defaultTargetPlatform == TargetPlatform.windows
            ? 'ms-settings:notifications'
            : 'x-apple.systempreferences:com.apple.preference.security',
      );
    }
  }

  Future<void> _clean() async {
    if (_working || UpdateActivity.busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('清理下载临时文件？'),
        content: const AppText(
          '仅删除已下载的更新包和未完成的下载。账户、密钥、登录状态和余额缓存都会保留。之后安装更新需要重新下载。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('清理'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || UpdateActivity.busy) return;
    setState(() => _working = true);
    UpdateActivity.busy = true;
    try {
      final bytes = await maintenance.clearUpdateCache();
      if (mounted)
        setState(
          () =>
              _status = '已清理 ${(bytes / 1048576).toStringAsFixed(2)} MB 临时文件。',
        );
    } catch (_) {
      if (mounted) setState(() => _status = '部分临时文件正在使用，请稍后重试。');
    } finally {
      UpdateActivity.busy = false;
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      AppPreferences.instance,
      UpdateActivity.changes,
    ]),
    builder: (context, _) {
      final prefs = AppPreferences.instance;
      return SettingsPage(
        title: '隐私与本机管理',
        children: [
          SwitchListTile(
            title: const AppText('离开应用时隐藏金额'),
            subtitle: const AppText('返回后需要手动显示；不会自动恢复明文'),
            value: prefs.autoHide,
            onChanged: (v) =>
                settingsAction(context, () => prefs.set('autoHide', v)),
          ),
          const ListTile(
            title: AppText('联网与存储说明'),
            subtitle: AppText(
              '余额查询连接所选服务商；登录连接 yuashie.cn；更新连接官网下载服务。密钥不进入诊断信息。当前应用不包含广告或行为分析上报。',
            ),
          ),
          ListTile(
            title: const AppText('隐私政策'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openAppLink(context, 'https://yuashie.cn/privacy'),
          ),
          ListTile(
            title: const AppText('服务协议'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openAppLink(context, 'https://yuashie.cn/terms'),
          ),
          if (_permission != null)
            ListTile(
              title: const AppText('系统权限'),
              subtitle: AppText(
                '通知权限：${_permission!['notifications'] == true ? '已允许' : '未允许'}\n电池优化：${_permission!['batteryUnrestricted'] == true ? '不受限制' : '受系统管理'}',
              ),
            ),
          ListenableBuilder(
            listenable: widget.accounts,
            builder: (context, _) => ListTile(
              title: const AppText('后台运行状态'),
              subtitle: AppText(
                isDesktopClient
                    ? '应用运行时刷新；退出、睡眠和网络中断会影响更新。'
                    : widget.accounts.backgroundStatus ?? '后台刷新未开启',
              ),
            ),
          ),
          if (!kIsWeb)
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _systemSettings,
                  child: const AppText('打开系统设置'),
                ),
                TextButton(
                  onPressed: _permissions,
                  child: const AppText('重新检查权限'),
                ),
              ],
            ),
          if (!kIsWeb)
            OutlinedButton.icon(
              onPressed: _working || UpdateActivity.busy ? null : _clean,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const AppText('清理下载临时文件'),
            ),
          OutlinedButton(
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const AppText('恢复默认外观？'),
                  content: const AppText('重置主题、语言、对比度和动画。不会删除账户、密钥或更改应用锁。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const AppText('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const AppText('恢复默认'),
                    ),
                  ],
                ),
              );
              if (yes == true && context.mounted)
                await settingsAction(context, prefs.resetAppearance);
            },
            child: const AppText('恢复默认外观'),
          ),
          if (_status != null) AppText(_status!),
        ],
      );
    },
  );
}

/// Whitelist, rather than redact arbitrary logs. Never accept vault contents,
/// raw errors, account labels, endpoint URLs or session information here.
String diagnosticSummary(PackageInfo info, AppPreferences prefs) =>
    const JsonEncoder.withIndent('  ').convert({
      'application': 'Astracct',
      'version': info.version,
      'build': info.buildNumber,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'theme': prefs.themeMode.name,
      'language': prefs.language,
      'highContrast': prefs.highContrast,
      'reduceMotion': prefs.reduceMotion,
    });

class HelpSettings extends StatelessWidget {
  const HelpSettings({super.key});
  Future<void> _diagnostics(BuildContext context) async {
    await settingsAction(context, () async {
      final info = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      final text = diagnosticSummary(info, AppPreferences.instance);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('诊断信息预览'),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AppText('已复制，可自行粘贴到反馈中。')),
                  );
                }
              },
              child: const AppText('复制诊断信息'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: '帮助与反馈',
    children: [
      ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: const AppText('使用指南'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () =>
            openAppLink(context, 'https://yuashie.cn/projects/001/guide'),
      ),
      const ExpansionTile(
        title: AppText('是否必须登录？'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: AppText('本机余额查询无需登录 Yuashie 账号。登录不会自动同步余额账户和密钥。'),
          ),
        ],
      ),
      const ExpansionTile(
        title: AppText('为什么关闭窗口后仍在运行？'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: AppText('桌面端可在“通用”设置中更改关闭行为。选择菜单栏或托盘的“退出星账”即可完全退出。'),
          ),
        ],
      ),
      const ExpansionTile(
        title: AppText('后台刷新为什么会停止？'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: AppText(
              '系统省电、权限、睡眠和断网均可能延迟刷新。在“隐私与本机管理”查看状态，在“通用”重新开启后台刷新。',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: AppText('应用锁验证失败怎么办？'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: AppText('确认系统已配置密码或生物识别，解除系统验证锁定后重试。应用不提供绕过系统身份验证的解锁方式。'),
          ),
        ],
      ),
      const ExpansionTile(
        title: AppText('反馈时应该提供什么？'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: AppText('描述操作步骤、预期结果和实际结果，可附诊断摘要。请勿发送密钥、订阅完整链接、密码或含隐私的截图。'),
          ),
        ],
      ),
      FilledButton.icon(
        onPressed: () => openAppLink(context, 'https://yuashie.cn/feedback'),
        icon: const Icon(Icons.feedback_outlined),
        label: const AppText('问题反馈与建议'),
      ),
      OutlinedButton(
        onPressed: () => _diagnostics(context),
        child: const AppText('预览并复制诊断信息'),
      ),
    ],
  );
}

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: '关于星账',
    children: [
      const ListTile(
        leading: Icon(Icons.auto_awesome_outlined),
        title: AppText('星账 Astracct'),
        subtitle: AppText('开发者：Yuashie · 公开测试版'),
      ),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, result) => ListTile(
          title: const AppText('当前版本'),
          subtitle: AppText(
            result.hasData
                ? '${result.data!.version} (${result.data!.buildNumber})'
                : result.hasError
                ? '无法读取版本信息'
                : '正在读取…',
          ),
        ),
      ),
      const AppUpdateCard(),
      ListTile(
        title: const AppText('更新日志'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openAppLink(
          context,
          'https://github.com/southkite2023/quota-hub/blob/main/CHANGELOG.md',
        ),
      ),
      ListTile(
        title: const AppText('官方网站'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openAppLink(context, 'https://yuashie.cn/projects/001'),
      ),
      ListTile(
        title: const AppText('开源代码 · MIT'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () =>
            openAppLink(context, 'https://github.com/southkite2023/quota-hub'),
      ),
      ListTile(
        title: const AppText('第三方开源许可'),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'Astracct',
          applicationLegalese: 'Yuashie · MIT License',
        ),
      ),
    ],
  );
}
