import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_preferences.dart';

/// Source-key catalog keeps provider/user values outside localization.
String translate(BuildContext context, String source) => translateValue(
  source,
  Localizations.of<AppCatalog>(context, AppCatalog)?.english == true,
);
String systemText(String source) => translateValue(
  source,
  (AppPreferences.instance.locale ?? PlatformDispatcher.instance.locale)
          .languageCode ==
      'en',
);
String translateValue(String source, bool english) {
  if (!english) return source;
  final exact = _english[source];
  if (exact != null) return exact;
  final refresh = RegExp(r'^每 (\d+) 分钟$').firstMatch(source);
  if (refresh != null) return 'Every ${refresh[1]} minutes';
  if (source.startsWith('上次成功：')) return 'Last success: ${source.substring(5)}';
  if (source.startsWith('自动刷新：每 '))
    return source
        .replaceFirst('自动刷新：每 ', 'Auto refresh: every ')
        .replaceFirst(' 分钟', ' minutes');
  if (source.startsWith('运行期间每 '))
    return source
        .replaceFirst('运行期间每 ', 'Refresh every ')
        .replaceFirst(' 分钟自动刷新', ' minutes while running');
  if (source.startsWith('移除 ') && source.endsWith('？'))
    return 'Remove ${source.substring(3, source.length - 1)}?';
  if (source.startsWith('已清理 '))
    return source
        .replaceFirst('已清理 ', 'Cleared ')
        .replaceFirst(' 临时文件。', ' of temporary files.');
  if (source.startsWith('上次成功值 · '))
    return 'Last known value · ${_english[source.substring(8)] ?? source.substring(8)}';
  return source;
}

extension AppTranslation on BuildContext {
  String tr(String value) => translate(this, value);
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) => Text(
    context.tr(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel == null ? null : context.tr(semanticsLabel!),
  );
}

const _english = <String, String>{
  "设置": "Settings",
  "通用": "General",
  "刷新、启动与窗口行为": "Refresh, startup and windows",
  "外观与无障碍": "Appearance & accessibility",
  "主题、语言、对比度与动画": "Theme, language, contrast and motion",
  "余额账户": "Balance accounts",
  "添加、编辑及小组件选择": "Add, edit and select widget accounts",
  "账户与安全": "Account & security",
  "登录管理与应用锁": "Sign-in and app lock",
  "隐私与本机管理": "Privacy & local storage",
  "金额保护、权限和临时文件": "Privacy, permissions and temporary files",
  "帮助与反馈": "Help & feedback",
  "使用指南、常见问题和问题反馈": "Guides, FAQs and feedback",
  "关于星账": "About Astracct",
  "版本、更新日志与开源许可": "Version, release notes and licenses",
  "操作未完成，原有配置已保留，请重试。":
      "Could not complete the action. Your previous settings were retained. Try again.",
  "无法打开页面，请检查默认浏览器后重试。":
      "Could not open the page. Check your default browser and try again.",
  "开机启动": "Launch at login",
  "登录系统后自动启动星账，默认关闭":
      "Start Astracct when you sign in to your computer. Off by default.",
  "启动时最小化": "Start minimized",
  "在菜单栏或系统托盘中运行": "Run in the menu bar or system tray",
  "关闭窗口后继续运行": "Keep running when the window closes",
  "通过菜单栏或托盘的“退出星账”彻底退出":
      "Choose Quit Astracct from the menu bar or tray to exit",
  "记住窗口位置和大小": "Remember window position and size",
  "下次打开时恢复；显示器变化时自动移回可见区域":
      "Restore next time; keep the window visible when displays change",
  "键盘快捷键": "Keyboard shortcuts",
  "Ctrl / ⌘ + ,：设置\nCtrl / ⌘ + R：刷新\nCtrl / ⌘ + Shift + H：隐藏或显示金额\nEsc：退出悬浮模式":
      "Ctrl / ⌘ + ,: Settings\nCtrl / ⌘ + R: Refresh\nCtrl / ⌘ + Shift + H: Toggle amounts\nEsc: Leave floating mode",
  "主题": "Theme",
  "跟随系统": "System",
  "浅色": "Light",
  "深色": "Dark",
  "语言 / Language": "Language",
  "跟随系统 / System": "System",
  "简体中文": "简体中文",
  "增强对比度": "Increase contrast",
  "减少动画": "Reduce motion",
  "也会遵循系统的减少动态效果设置": "Also respects your system's reduced motion setting",
  "文字大小": "Text size",
  "跟随系统字体大小。支持读屏和 Tab 键导航，状态同时使用文字说明。":
      "Uses your system text size. Supports screen readers and Tab navigation; statuses include text labels.",
  "应用锁": "App lock",
  "打开应用或离开后返回时，使用系统密码、指纹或面容验证":
      "Verify with your system password, fingerprint or face when opening or returning to the app",
  "验证身份以更改星账应用锁": "Verify your identity to change the Astracct app lock",
  "网页版暂不提供系统应用锁。": "System authentication is unavailable on the web.",
  "应用锁保护此应用的界面访问。桌面小组件独立显示，请按需要隐藏金额或移除小组件。":
      "App lock protects access to the app interface. Home screen widgets are separate; hide amounts or remove widgets as needed.",
  "余额凭据保存在本机安全存储。Yuashie 登录仅用于账号服务，不会自动上传余额密钥。":
      "Balance credentials stay in local secure storage. Signing in to Yuashie does not upload balance keys.",
  "无法读取系统权限，请打开系统设置查看。": "Could not read permissions. Check system settings.",
  "清理下载临时文件？": "Clear temporary downloads?",
  "仅删除已下载的更新包和未完成的下载。账户、密钥、登录状态和余额缓存都会保留。之后安装更新需要重新下载。":
      "Deletes update downloads and partial downloads only. Accounts, keys, sign-in and balance cache are retained. Updates must be downloaded again.",
  "取消": "Cancel",
  "清理": "Clear",
  "部分临时文件正在使用，请稍后重试。": "Some temporary files are in use. Try again later.",
  "离开应用时隐藏金额": "Hide amounts when leaving the app",
  "返回后需要手动显示；不会自动恢复明文": "Amounts remain hidden until you choose to show them",
  "联网与存储说明": "Network & storage",
  "余额查询连接所选服务商；登录连接 yuashie.cn；更新连接官网下载服务。密钥不进入诊断信息。当前应用不包含广告或行为分析上报。":
      "Balance queries contact your selected provider. Sign-in and updates contact yuashie.cn. Diagnostics exclude keys. The app contains no advertising or behavioral analytics.",
  "隐私政策": "Privacy policy",
  "服务协议": "Terms of service",
  "系统权限": "System permissions",
  "已允许": "Allowed",
  "未允许": "Not allowed",
  "不受限制": "Unrestricted",
  "受系统管理": "Managed by system",
  "后台运行状态": "Background status",
  "应用运行时刷新；退出、睡眠和网络中断会影响更新。":
      "Refreshes while running. Quitting, sleep and network outages affect updates.",
  "后台刷新未开启": "Background refresh is off",
  "打开系统设置": "Open system settings",
  "重新检查权限": "Check permissions again",
  "清理下载临时文件": "Clear temporary downloads",
  "恢复默认外观？": "Reset appearance?",
  "重置主题、语言、对比度和动画。不会删除账户、密钥或更改应用锁。":
      "Resets theme, language, contrast and motion. Accounts, keys and app lock are retained.",
  "恢复默认": "Reset",
  "恢复默认外观": "Reset appearance",
  "诊断信息预览": "Diagnostic preview",
  "关闭": "Close",
  "已复制，可自行粘贴到反馈中。": "Copied. You can paste it into your feedback.",
  "复制诊断信息": "Copy diagnostics",
  "使用指南": "User guide",
  "是否必须登录？": "Do I need to sign in?",
  "本机余额查询无需登录 Yuashie 账号。登录不会自动同步余额账户和密钥。":
      "Local balance queries do not require a Yuashie account. Signing in does not sync balance accounts or keys.",
  "为什么关闭窗口后仍在运行？": "Why is the app running after I close the window?",
  "桌面端可在“通用”设置中更改关闭行为。选择菜单栏或托盘的“退出星账”即可完全退出。":
      "Change the close behavior in General settings. Choose Quit Astracct from the menu bar or tray to exit.",
  "后台刷新为什么会停止？": "Why does background refresh stop?",
  "系统省电、权限、睡眠和断网均可能延迟刷新。在“隐私与本机管理”查看状态，在“通用”重新开启后台刷新。":
      "Power saving, permissions, sleep and network outages can delay refresh. Check Privacy & local storage for status and General to restart background refresh.",
  "应用锁验证失败怎么办？": "What if app lock authentication fails?",
  "确认系统已配置密码或生物识别，解除系统验证锁定后重试。应用不提供绕过系统身份验证的解锁方式。":
      "Configure a system password or biometrics and resolve any system authentication lockout, then retry. The app cannot bypass system verification.",
  "反馈时应该提供什么？": "What should I include in feedback?",
  "描述操作步骤、预期结果和实际结果，可附诊断摘要。请勿发送密钥、订阅完整链接、密码或含隐私的截图。":
      "Include steps, expected behavior and actual behavior. You may include the diagnostic summary. Never send keys, full subscription URLs, passwords or private screenshots.",
  "问题反馈与建议": "Report a problem or suggestion",
  "预览并复制诊断信息": "Preview & copy diagnostics",
  "星账 Astracct": "Astracct",
  "开发者：Yuashie · 公开测试版": "Developer: Yuashie · Public beta",
  "当前版本": "Current version",
  "无法读取版本信息": "Version information unavailable",
  "正在读取…": "Loading…",
  "更新日志": "Release notes",
  "官方网站": "Official website",
  "开源代码 · MIT": "Source code · MIT",
  "第三方开源许可": "Third-party licenses",
  "星账已锁定": "Astracct is locked",
  "验证身份以打开星账": "Verify your identity to open Astracct",
  "验证并解锁": "Verify & unlock",
  "放弃未保存的修改？": "Discard unsaved changes?",
  "继续编辑可保留输入；放弃后将无法恢复。":
      "Continue editing to keep your input. Discarded changes cannot be recovered.",
  "继续编辑": "Keep editing",
  "放弃修改": "Discard changes",
  "自定义刷新时间": "Custom refresh interval",
  "间隔（分钟）": "Interval (minutes)",
  "1–1440 分钟": "1–1440 minutes",
  "请输入 1–1440 之间的整数": "Enter a whole number between 1 and 1440",
  "保存": "Save",
  "自动刷新": "Auto refresh",
  "刷新间隔": "Refresh interval",
  "关闭自动刷新": "Turn off auto refresh",
  "自定义时间": "Custom interval",
  "后台继续刷新": "Continue refreshing in background",
  "显示常驻通知，增加耗电；可在通知中停止":
      "Shows a persistent notification and uses more battery. Stop from the notification.",
  "重新开启后台刷新": "Restart background refresh",
  "默认每 5 分钟更新全部账户。应用运行时，切换到其他程序或悬浮窗仍会刷新；退出应用后停止，睡眠或断网可能延迟。":
      "Refreshes all accounts every 5 minutes by default while running, including floating mode. Stops on quit; sleep and network outages may delay updates.",
  "默认每 5 分钟更新所有账户。后台与锁屏时会尽量按设定间隔刷新，省电模式、断网或系统限制可能延迟；Android 15 及以上可能在后台运行约 6 小时后停止。强制停止或重启手机后需打开应用。":
      "Refreshes all accounts every 5 minutes by default. Background updates are best effort and may be delayed by system or network restrictions. Android 15+ may stop the service after about 6 hours. Reopen the app after force stop or reboot.",
  "显示金额": "Show amounts",
  "隐藏金额": "Hide amounts",
  "刷新余额": "Refresh balances",
  "打开余额悬浮窗": "Open floating balances",
  "账户余额": "Account balances",
  "各账户和币种分别显示。在账户设置中勾选悬浮窗要显示的余额。":
      "Accounts and currencies are shown separately. Select floating-window accounts in account settings.",
  "管理 / 添加余额账户": "Manage / add accounts",
  "macOS 菜单栏 · 左键打开，右键切换余额；关闭行为可在通用设置中修改。":
      "Menu bar: click to open, right-click to select a balance. Change close behavior in General.",
  "菜单栏显示": "Menu bar display",
  "仅显示图标": "Icon only",
  "退出星账": "Quit Astracct",
  "自动刷新已关闭": "Auto refresh is off",
  "尚未添加账户。添加并验证后即可查看真实余额。":
      "No accounts yet. Add and verify an account to see its balance.",
  "悬浮窗可拖动、切换置顶和隐藏金额。退出应用后刷新停止；睡眠和断网可能延迟。":
      "Drag the floating window, pin it or hide amounts. Refresh stops on quit; sleep and network outages may delay it.",
  "星账": "Astracct",
  "取消置顶": "Unpin window",
  "窗口置顶": "Keep on top",
  "返回主界面": "Back to main window",
  "退出应用": "Quit app",
  "尚未选择余额。返回主界面，在账户设置中勾选“显示在悬浮窗”。":
      "No balances selected. Return to the main window and select Show in floating window in account settings.",
  "删除本机凭据与余额，其他账户不受影响。":
      "Deletes local credentials and balances for this account. Other accounts are unaffected.",
  "移除": "Remove",
  "余额账户设置": "Balance account settings",
  "你的余额，": "Your balances,",
  "一眼看清。": "at a glance.",
  "连接服务商，集中查看每个账户的余额。\n凭据在本机加密保存，账户与币种分别展示。":
      "Connect providers to view your accounts together.\nCredentials are encrypted locally. Accounts and currencies stay separate.",
  "添加余额账户": "Add balance account",
  "已添加账户": "Accounts added",
  "账户种类": "Account types",
  "最近更新": "Last updated",
  "全部": "All",
  "还没有余额账户。点击「添加余额账户」开始连接。":
      "No balance accounts yet. Choose Add balance account to get started.",
  "该种类暂无账户": "No accounts in this category",
  "管理账户、小组件与刷新设置": "Manage accounts, widgets & settings",
  "数据保存在本机。主界面显示全部账户，小组件显示勾选账户；不跨账户或币种求和。":
      "Data stays on this device. The main screen shows all accounts; widgets show selected accounts. Accounts and currencies are not summed.",
  "已从桌面组件打开对应账户": "Opened this account from a widget",
  "尚无成功记录": "No successful queries yet",
  "编辑": "Edit",
  "让余额井然有序": "Keep balances organized",
  "管理查询、账户和展示方式。": "Manage queries, accounts and display options.",
  "多平台、多账户，余额分别显示。凭据在本机加密保存。":
      "Balances are separate across providers and accounts. Credentials are encrypted locally.",
  "主界面显示全部账户；勾选要放入悬浮窗的账户。":
      "The main window shows all accounts. Select accounts for the floating window.",
  "主界面显示全部账户；勾选要放入小组件的账户，可上下滑动查看全部余额。":
      "The main screen shows all accounts. Select accounts for the scrollable home screen widget.",
  "全部勾选": "Select all",
  "全部取消": "Deselect all",
  "尚未添加余额账户。选择余额种类和服务商，验证后即可查看余额。":
      "No accounts yet. Choose a category and provider, then verify your credentials.",
  "显示在悬浮窗": "Show in floating window",
  "显示在桌面小组件": "Show in home screen widget",
  "编辑余额账户": "Edit balance account",
  "连接你的余额": "Connect your balances",
  "更新账户连接": "Update account connection",
  "选择种类与服务商，验证成功后保存到本机。":
      "Choose a category and provider. Credentials are saved locally after verification.",
  "余额种类": "Balance category",
  "服务商": "Provider",
  "账户名称": "Account name",
  "例如：工作账户": "For example: Work",
  "HTTPS 订阅链接": "HTTPS subscription URL",
  "站点根地址": "Site base URL",
  "完整余额接口地址": "Full balance API URL",
  "粘贴 Clash / 小火箭的 HTTPS 订阅链接": "Paste an HTTPS subscription URL",
  "完整链接仅存于本机安全存储，默认隐藏令牌。":
      "The full URL stays in local secure storage. Tokens are hidden by default.",
  "显示订阅链接": "Show subscription URL",
  "隐藏订阅链接": "Hide subscription URL",
  "余额字段路径": "Balance field path",
  "平台余额币种": "Balance currency",
  "按平台实际单位填写，例如 USD 或 CNY":
      "Use the provider's actual currency, such as USD or CNY",
  "Secret 仅用于本机签名，不随请求发送。暂不支持临时 STS 凭据。":
      "The secret only signs requests locally. Temporary STS credentials are not supported.",
  "仅向所选平台发送，查询账单不会调用模型。":
      "Sent only to the selected provider. Balance queries do not call models.",
  "留空保留原凭据；更换平台、地址或密钥 ID 后需重新输入。":
      "Leave blank to keep existing credentials. Re-enter after changing provider, URL or key ID.",
  "显示 Key": "Show key",
  "隐藏 Key": "Hide key",
  "正在验证…": "Verifying…",
  "验证并保存": "Verify & save",
  "此项暂不收集 Key，也不会用演示数字冒充账户余额。":
      "This provider is not available yet. No keys are collected or demo balances substituted.",
  "可用余额": "Available balance",
  "可用额度": "Available credit",
  "现金余额": "Cash balance",
  "赠送余额": "Bonus balance",
  "充值余额": "Top-up balance",
  "累计购买额度": "Purchased credits",
  "已用额度": "Credits used",
  "本月费用（UTC）": "Month-to-date cost (UTC)",
  "代金券余额": "Voucher balance",
  "冻结余额": "Frozen balance",
  "剩余流量": "Remaining traffic",
  "已使用流量": "Traffic used",
  "套餐总流量": "Total traffic",
  "到期时间": "Expires",
  "已过期": "Expired",
  "正常": "Current",
  "未知": "Unknown",
  "缓存已过期": "Stale cache",
  "查询失败": "Query failed",
  "暂无可用余额": "No balance available",
  "连接超时": "Connection timed out",
  "授权失败": "Authorization failed",
  "请求过频": "Too many requests",
  "服务不可用": "Service unavailable",
  "更新失败": "Update failed",
  "无法读取应用锁设置，请重试。": "Could not read app lock settings. Try again.",
  "通用设置读取失败，已使用默认外观；账户和应用锁不受影响。":
      "Could not read preferences. Default appearance is used; accounts and app lock are unaffected.",
  "此设备未配置系统身份验证，请先设置系统密码或生物识别。":
      "Set up a system password or biometrics before enabling app lock.",
  "验证已取消，可再次尝试。": "Verification canceled. You can try again.",
  "系统身份验证暂不可用，请检查系统安全设置后重试。":
      "System authentication is unavailable. Check your system security settings and retry.",
  "登录 Yuashie 账号": "Sign in to Yuashie",
  "与 yuashie.cn 共用账号": "Use your yuashie.cn account",
  "账号已登录 · 管理登录与安全设置": "Signed in · Manage sign-in & security",
  "Yuashie 账号": "Yuashie account",
  "欢迎回来": "Welcome back",
  "一个账号，连接 AstrAcct 与 yuashie.cn。": "One account for Astracct and yuashie.cn.",
  "Yuashie 统一账号": "Yuashie account",
  "余额账户配置仍保存在本机。登录不会自动上传 API Key 或订阅链接。":
      "Balance accounts stay on this device. Signing in does not upload API keys or subscription URLs.",
  "账号安全与第三方绑定": "Account security & connected sign-ins",
  "退出登录": "Sign out",
  "邮箱 / 手机号": "Email / phone number",
  "请输入邮箱或已验证的手机号": "Enter an email or verified phone number",
  "请输入账号": "Enter your account",
  "密码": "Password",
  "显示密码": "Show password",
  "隐藏密码": "Hide password",
  "请输入密码": "Enter your password",
  "请稍候…": "Please wait…",
  "前往安全登录": "Open secure sign-in",
  "登录": "Sign in",
  "在安全登录页输入邮箱／手机号和密码，完成验证后即可返回软件。":
      "Enter your email or phone and password on the secure sign-in page, then return to the app.",
  "注册账号": "Create account",
  "忘记密码？": "Forgot password?",
  "其他方式登录": "Other sign-in options",
  "请在浏览器完成登录并点击“确认登录”，然后返回这里。":
      "Complete sign-in in your browser, confirm authorization, then return here.",
  "重新打开登录页": "Reopen sign-in page",
  "取消本次登录": "Cancel sign-in",
  "重新连接账号服务": "Reconnect account service",
  "手机号验证、邮箱验证与密码找回待接入发送服务。":
      "Verification and password recovery depend on the account server configuration.",
  "从 yuashie.cn 获取当前平台最新公开测试版":
      "Checks yuashie.cn for the latest public beta for this platform",
  "正在检查更新…": "Checking for updates…",
  "检查失败，请重试，或打开官网下载。":
      "Could not check for updates. Retry or open the download page.",
  "正在从服务器下载安装包…": "Downloading the update…",
  "下载完成，SHA-256 校验通过。点击安装继续。":
      "Download complete and SHA-256 verified. Choose Install to continue.",
  "下载或校验失败，请重试。": "Download or verification failed. Try again.",
  "安装更新？": "Install update?",
  "将打开系统安装确认。如需授权“允许此来源安装”，完成后返回并再次点击安装。本机账户数据会保留。":
      "The system installer will open. If requested, allow installation from this source, return and choose Install again. Local accounts are retained.",
  "应用将退出，替换当前程序后重新打开。请先完成账户编辑。本机账户数据会保留；旧程序会备份在同一目录。":
      "The app will quit, update and reopen. Finish editing accounts first. Local account data is retained; the old app is backed up beside the installation.",
  "安装": "Install",
  "请在系统页面完成安装；如取消可再次点击安装。":
      "Complete installation in the system dialog. If canceled, choose Install again.",
  "安装尚未完成。请检查系统安装权限或目录写入权限，然后重试。":
      "Installation is incomplete. Check installation permissions or folder access, then retry.",
  "应用更新": "App updates",
  "更新说明": "Release notes",
  "检查更新": "Check for updates",
  "下载更新": "Download update",
  "安装更新": "Install update",
  "官网下载": "Official downloads",
  "确认查询站点": "Confirm provider",
  "验证连接": "Verify connection",
  "AI 订阅": "AI accounts",
  "云服务器": "Cloud accounts",
  "节点订阅": "Traffic subscriptions",
};

class AppCatalog {
  const AppCatalog(this.english);
  final bool english;
  static const delegate = AppCatalogDelegate();
}

class AppCatalogDelegate extends LocalizationsDelegate<AppCatalog> {
  const AppCatalogDelegate();
  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<AppCatalog> load(Locale locale) =>
      SynchronousFuture(AppCatalog(locale.languageCode == 'en'));
  @override
  bool shouldReload(AppCatalogDelegate old) => false;
}
