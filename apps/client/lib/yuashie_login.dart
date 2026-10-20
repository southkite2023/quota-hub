import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'yuashie_account.dart';

class YuashieAccountCard extends StatefulWidget {
  const YuashieAccountCard({super.key, this.account});
  final YuashieAccount? account;
  @override
  State<YuashieAccountCard> createState() => _YuashieAccountCardState();
}

class _YuashieAccountCardState extends State<YuashieAccountCard> {
  late final account = widget.account ?? YuashieAccount.shared;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: account,
    builder: (context, _) => Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          child: Icon(
            account.user == null
                ? Icons.person_outline
                : Icons.verified_user_outlined,
          ),
        ),
        title: Text(account.user?['displayName'] as String? ?? '登录 Yuashie 账号'),
        subtitle: AppText(
          account.user == null ? '与 yuashie.cn 共用账号' : '账号已登录 · 管理登录与安全设置',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => YuashieLoginPage(account: account),
          ),
        ),
      ),
    ),
  );
}

class YuashieLoginPage extends StatefulWidget {
  const YuashieLoginPage({super.key, required this.account});
  final YuashieAccount account;
  @override
  State<YuashieLoginPage> createState() => _YuashieLoginPageState();
}

class _YuashieLoginPageState extends State<YuashieLoginPage> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController(),
      _password = TextEditingController();
  bool _obscure = true;
  YuashieAccount get account => widget.account;
  @override
  void initState() {
    super.initState();
    account.initialize();
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (account.config?['captcha'] != null) {
      _password.clear();
      await account.browserLogin();
    } else if (await account.login(_identifier.text, _password.text)) {
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Yuashie 账号')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: account,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                AppText(
                  'YUASHIE ACCOUNT',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 20),
                AppText(
                  account.user == null
                      ? '欢迎回来'
                      : '你好，${account.user!['displayName']}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const AppText('一个账号，连接 AstrAcct 与 yuashie.cn。'),
                const SizedBox(height: 28),
                if (account.user != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: AppText('@${account.user!['username']}'),
                    subtitle: const AppText('Yuashie 统一账号'),
                  ),
                  const AppText('余额账户配置仍保存在本机。登录不会自动上传 API Key 或订阅链接。'),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: account.openSecurity,
                    icon: const Icon(Icons.security_outlined),
                    label: const AppText('账号安全与第三方绑定'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: account.busy ? null : account.logout,
                    child: const AppText('退出登录'),
                  ),
                ] else ...[
                  if (account.config?['captchaRequired'] != true)
                    AutofillGroup(
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _identifier,
                              enabled: !account.busy,
                              autofillHints: const [AutofillHints.username],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.tr('邮箱 / 手机号'),
                                hintText: context.tr('请输入邮箱或已验证的手机号'),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (s) => s == null || s.trim().isEmpty
                                  ? '请输入账号'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _password,
                              enabled: !account.busy,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!account.busy) _login();
                              },
                              decoration: InputDecoration(
                                labelText: context.tr('密码'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  tooltip: context.tr(
                                    _obscure ? '显示密码' : '隐藏密码',
                                  ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (s) =>
                                  s == null || s.isEmpty ? '请输入密码' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    account.busy ||
                                        !account.ready ||
                                        account.config == null
                                    ? null
                                    : _login,
                                child: AppText(
                                  account.busy
                                      ? '请稍候…'
                                      : account.config?['captcha'] != null
                                      ? '前往安全登录'
                                      : '登录',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (account.config?['captchaRequired'] == true) ...[
                    FilledButton(
                      onPressed: account.busy
                          ? null
                          : () => account.browserLogin(),
                      child: const AppText('登录 Yuashie 账号'),
                    ),
                    const SizedBox(height: 12),
                    const AppText('在安全登录页输入邮箱／手机号和密码，完成验证后即可返回软件。'),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: account.busy
                            ? null
                            : () => account.browserLogin(register: true),
                        child: const AppText('注册账号'),
                      ),
                      TextButton(
                        onPressed: account.openPasswordHelp,
                        child: const AppText('忘记密码？'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: AppText('其他方式登录'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (final provider in const [
                        ('qq', 'QQ'),
                        ('github', 'GitHub'),
                        ('google', 'Google'),
                      ])
                        OutlinedButton(
                          onPressed:
                              !account.busy && _providerEnabled(provider.$1)
                              ? () =>
                                    account.browserLogin(provider: provider.$1)
                              : null,
                          child: AppText(
                            '${provider.$2}${_providerEnabled(provider.$1) ? '' : ' · 待开通'}',
                          ),
                        ),
                    ],
                  ),
                ],
                if (account.waitingForBrowser) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  const AppText('请在浏览器完成登录并点击“确认登录”，然后返回这里。'),
                  TextButton(
                    onPressed: account.reopenBrowser,
                    child: const AppText('重新打开登录页'),
                  ),
                  TextButton(
                    onPressed: account.cancelBrowserLogin,
                    child: const AppText('取消本次登录'),
                  ),
                ],
                if (account.error != null) ...[
                  const SizedBox(height: 16),
                  AppText(
                    account.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (!account.busy)
                    TextButton(
                      onPressed: account.initialize,
                      child: const AppText('重新连接账号服务'),
                    ),
                ],
                const SizedBox(height: 28),
                AppText(
                  '手机号验证、邮箱验证与密码找回待接入发送服务。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  bool _providerEnabled(String id) =>
      (account.config?['providers'] as List<dynamic>? ?? []).any(
        (p) => p is Map && p['id'] == id && p['enabled'] == true,
      );
}
