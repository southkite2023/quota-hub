import 'yuashie_account.dart';
import 'dashboard_shell.dart';

import 'dart:async';
import 'dart:convert';

import 'app_preferences.dart';
import 'app_settings.dart';
import 'desktop_runtime.dart';

import 'package:flutter/material.dart';

import 'app_localizations.dart';

import 'package:flutter/services.dart';

import 'api_accounts.dart';
import 'account_settings.dart';
import 'app_theme.dart';
import 'balance_summary.dart';
import 'desktop_accounts_store.dart';
import 'desktop_window.dart';
import 'snapshot.dart';
import 'macos_menu_bar.dart';

class DesktopDashboard extends StatefulWidget {
  const DesktopDashboard({super.key, this.accounts, this.window, this.menu});
  final ApiAccounts? accounts;
  final DesktopWindowController? window;
  final MacMenuController? menu;
  @override
  State<DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends State<DesktopDashboard> {
  late final ApiAccounts _accounts =
      widget.accounts ??
      ApiAccounts(
        store: DesktopAccountsStore(),
        uploadParameters: YuashieAccount.shared.saveParameters,
        identity: YuashieAccount.shared,
      );
  late final DesktopWindowController _window =
      widget.window ?? DesktopWindowController();
  bool get _hideMoney => AppPreferences.instance.hideAmounts;
  late final MacMenuController? _menu =
      widget.menu ?? (supportsMacMenuBar ? MacMenuController() : null);

  void _syncMenu() => _menu?.update(
    AppPreferences.instance.locked ? [] : _accounts.accounts,
    hidden: _hideMoney,
    storageFailed: _accounts.storageFailed,
  );
  Future<void> _menuAction(String action, Object? value) async {
    switch (action) {
      case 'open':
        await _window.setFloating(false);
      case 'quitRequested':
        await DesktopRuntime.instance.requestQuit();
      case 'refresh':
        if (_accounts.ready && !_accounts.busy && !_accounts.storageFailed)
          await _accounts.refresh();
      case 'privacy':
        await _togglePrivacy();
      case 'selection':
        if (value is String) await _selectMenu(value);
    }
  }

  @override
  void initState() {
    super.initState();
    // Desktop focus changes must not stop polling while the floating window runs.
    AppPreferences.instance.addListener(_privacyChanged);
    DesktopRuntime.instance.openDashboard = () => _window.setFloating(false);
    DesktopRuntime.instance.openSettings = _settings;
    DesktopRuntime.instance.refresh = _accounts.refresh;
    _window.addListener(_windowChanged);
    _accounts.setForeground(true);
    if (!_accounts.ready) unawaited(_accounts.initialize());
    _accounts.addListener(_syncMenu);
    _menu?.addListener(_menuChanged);
    if (_menu != null)
      unawaited(_menu.initialize(_menuAction).then((_) => _syncMenu()));
  }

  @override
  void dispose() {
    AppPreferences.instance.removeListener(_privacyChanged);
    _window.removeListener(_windowChanged);
    DesktopRuntime.instance.openDashboard = null;
    DesktopRuntime.instance.openSettings = null;
    DesktopRuntime.instance.refresh = null;
    _accounts.removeListener(_syncMenu);
    _menu?.removeListener(_menuChanged);
    if (widget.menu == null) _menu?.dispose();
    if (widget.accounts == null)
      _accounts.dispose();
    else
      _accounts.setForeground(false);
    if (widget.window == null) _window.dispose();
    super.dispose();
  }

  final _shell = GlobalKey<DashboardShellState>();

  Future<void> _settings() async {
    if (_shell.currentState case final state?) {
      state.openDestination(2);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsCenter(accounts: _accounts, desktop: true),
      ),
    );
  }

  Future<void> _togglePrivacy() =>
      settingsAction(context, AppPreferences.instance.toggleHidden);

  void _privacyChanged() {
    if (mounted) setState(() {});
    _syncMenu();
  }

  void _windowChanged() {
    DesktopRuntime.instance.floating = _window.floating;
  }

  Future<void> _manageAccounts() async {
    if (_shell.currentState case final state?) {
      state.openDestination(1);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountSettings(connection: _accounts, desktop: true),
      ),
    );
  }

  void _shortcutRefresh() {
    if (_accounts.ready && !_accounts.busy && !AppPreferences.instance.locked)
      unawaited(_accounts.refresh());
  }

  void _menuChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectMenu(String id) async {
    await _menu?.select(id);
    _syncMenu();
  }

  List<Account> get _selected => DemoCase.fromJson({
    ...jsonDecode(_accounts.widgetRaw) as Map<String, dynamic>,
    'name': 'desktop',
  }).accounts;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      for (final meta in [false, true]) ...{
        SingleActivator(
          LogicalKeyboardKey.comma,
          control: !meta,
          meta: meta,
        ): () {
          unawaited(_settings());
        },
        SingleActivator(LogicalKeyboardKey.keyR, control: !meta, meta: meta):
            _shortcutRefresh,
        SingleActivator(
          LogicalKeyboardKey.keyH,
          control: !meta,
          meta: meta,
          shift: true,
        ): _togglePrivacy,
      },
    },
    child: Focus(
      autofocus: true,
      child: ListenableBuilder(
        listenable: Listenable.merge([_accounts, _window]),
        builder: (context, _) => _window.floating ? _floating() : _dashboard(),
      ),
    ),
  );

  Widget _dashboard() => DashboardShell(
    key: _shell,
    accountsBuilder: (_) =>
        AccountSettings(connection: _accounts, desktop: true),
    settingsBuilder: (_) => SettingsCenter(accounts: _accounts, desktop: true),
    onAccounts: _manageAccounts,
    onSettings: _settings,
    actions: [
      IconButton(
        tooltip: context.tr(_hideMoney ? '显示金额' : '隐藏金额'),
        onPressed: _togglePrivacy,
        icon: Icon(
          _hideMoney
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
      IconButton(
        tooltip: context.tr('刷新余额'),
        onPressed:
            _accounts.ready && !_accounts.busy && !_accounts.storageFailed
            ? _accounts.refresh
            : null,
        icon: const Icon(Icons.refresh),
      ),
      IconButton(
        tooltip: context.tr('设置'),
        onPressed: _settings,
        icon: const Icon(Icons.settings_outlined),
      ),
      IconButton(
        tooltip: context.tr('打开余额悬浮窗'),
        onPressed: _accounts.ready && !_window.busy
            ? () => _window.setFloating(true)
            : null,
        icon: const Icon(Icons.picture_in_picture_alt_outlined),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        OverviewStatusCard(
          count: _accounts.entries.length,
          busy: _accounts.busy,
          storageFailed: _accounts.storageFailed,
          onAdd: _accounts.ready && !_accounts.storageFailed
              ? _manageAccounts
              : null,
        ),
        const SizedBox(height: 8),
        AppText('各账户和币种分别显示。在账户设置中勾选悬浮窗要显示的余额。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _accounts.ready ? _manageAccounts : null,
              icon: const Icon(Icons.settings_outlined),
              label: AppText('管理 / 添加余额账户'),
            ),
            OutlinedButton.icon(
              onPressed: _accounts.ready && !_window.busy
                  ? () => _window.setFloating(true)
                  : null,
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              label: AppText('打开余额悬浮窗'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_menu != null) ...[
          AppText('macOS 菜单栏 · 左键打开，右键切换余额；关闭窗口收起至菜单栏；通过菜单退出。'),
          AppText('勾选下方数据行，将该项显示在菜单栏；取消勾选后仅显示图标。'),
          if (_menu.error != null)
            AppText(
              _menu.error!,
              style: TextStyle(color: AstracctTheme.errorFor(context)),
            ),
          OutlinedButton.icon(
            onPressed: () => DesktopRuntime.instance.requestQuit(),
            icon: const Icon(Icons.power_settings_new),
            label: AppText('退出星账'),
          ),
          const SizedBox(height: 12),
        ],
        if (!_accounts.ready || _accounts.busy) const LinearProgressIndicator(),
        if (DesktopRuntime.instance.error != null)
          AppText(DesktopRuntime.instance.error!),
        if (_accounts.error != null)
          AppText(
            _accounts.error!,
            style: TextStyle(color: AstracctTheme.errorFor(context)),
          ),
        if (_window.error != null)
          AppText(
            _window.error!,
            style: TextStyle(color: AstracctTheme.errorFor(context)),
          ),
        AppText(
          _accounts.refreshMinutes == 0
              ? '自动刷新已关闭'
              : '运行期间每 ${_accounts.refreshMinutes} 分钟自动刷新',
        ),
        const SizedBox(height: 12),
        if (_accounts.ready &&
            _accounts.entries.isEmpty &&
            !_accounts.storageFailed)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: AppText('尚未添加账户。添加并验证后即可查看真实余额。'),
            ),
          ),
        for (final entry in _accounts.entries)
          if (_accounts.errors[entry.id] != null)
            AppText(
              '${entry.name}：${_accounts.errors[entry.id]}',
              style: TextStyle(color: AstracctTheme.errorFor(context)),
            ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 680 &&
                    MediaQuery.textScalerOf(context).scale(14) < 24
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final account in _accounts.accounts)
                  SizedBox(
                    width: width,
                    child: BalanceSummary(
                      account: account,
                      hideMoney: _hideMoney,
                      metricTrailing: _menu == null
                          ? null
                          : (metric) {
                              final choice = MenuBalance(account, metric);
                              return Tooltip(
                                message: context.tr('显示在菜单栏'),
                                child: Checkbox(
                                  key: ValueKey('menu-metric-${choice.id}'),
                                  semanticLabel:
                                      '${context.tr('显示在菜单栏')} · ${choice.label}',
                                  value: _menu.selected == choice.id,
                                  onChanged:
                                      _menu.ready && !_accounts.storageFailed
                                      ? (checked) => _selectMenu(
                                          checked == true ? choice.id : '',
                                        )
                                      : null,
                                ),
                              );
                            },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppText('悬浮窗可拖动、切换置顶和隐藏金额。退出应用后刷新停止；睡眠和断网可能延迟。'),
      ],
    ),
  );

  Widget _floating() => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        unawaited(_window.setFloating(false));
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => unawaited(_window.drag()),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 4,
                          ),
                          child: AppText(
                            '星账',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    _tool(
                      _hideMoney ? '显示金额' : '隐藏金额',
                      _hideMoney
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      _togglePrivacy,
                    ),
                    _tool(
                      _window.pinned ? '取消置顶' : '窗口置顶',
                      _window.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      _window.busy ? null : () => _window.togglePin(),
                    ),
                    _tool(
                      '刷新余额',
                      Icons.refresh,
                      _accounts.busy || _accounts.storageFailed
                          ? null
                          : _accounts.refresh,
                    ),
                    _tool(
                      '返回主界面',
                      Icons.open_in_full,
                      _window.busy ? null : () => _window.setFloating(false),
                    ),
                    _tool('最小化', Icons.close, () => _window.close()),
                  ],
                ),
              ),
              if (_accounts.busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    if (_window.error != null)
                      AppText(
                        _window.error!,
                        style: TextStyle(
                          color: AstracctTheme.errorFor(context),
                        ),
                      ),
                    if (_accounts.error != null)
                      AppText(
                        _accounts.error!,
                        style: TextStyle(
                          color: AstracctTheme.errorFor(context),
                        ),
                      ),
                    if (_selected.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: AppText('尚未选择余额。返回主界面，在账户设置中勾选“显示在悬浮窗”。'),
                      ),
                    for (final entry in _accounts.entries.where(
                      (e) => _accounts.widgetAccountIds.contains(e.id),
                    ))
                      if (_accounts.errors[entry.id] != null)
                        AppText(
                          '${entry.name}：${_accounts.errors[entry.id]}',
                          style: TextStyle(
                            color: AstracctTheme.errorFor(context),
                          ),
                        ),
                    for (final account in _selected)
                      BalanceSummary(
                        account: account,
                        hideMoney: _hideMoney,
                        showAllMetrics: false,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tool(String tooltip, IconData icon, VoidCallback? action) =>
      IconButton(
        tooltip: context.tr(tooltip),
        onPressed: action,
        icon: Icon(icon, size: 18),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
      );
}
