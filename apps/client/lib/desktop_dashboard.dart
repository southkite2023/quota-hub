import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  late final ApiAccounts _accounts = widget.accounts ?? ApiAccounts(store: DesktopAccountsStore());
  late final DesktopWindowController _window = widget.window ?? DesktopWindowController();
  bool _hideMoney = false;
  late final MacMenuController? _menu = widget.menu ?? (supportsMacMenuBar ? MacMenuController() : null);

  void _syncMenu() => _menu?.update(_accounts.accounts, hidden: _hideMoney, storageFailed: _accounts.storageFailed);
  Future<void> _menuAction(String action, Object? value) async {
    switch (action) {
      case 'open': await _window.setFloating(false);
      case 'refresh': if (_accounts.ready && !_accounts.busy && !_accounts.storageFailed) await _accounts.refresh();
      case 'privacy': _togglePrivacy();
      case 'selection': if (value is String) await _selectMenu(value);
    }
  }

  @override
  void initState() {
    super.initState();
    // Desktop focus changes must not stop polling while the floating window runs.
    _accounts.setForeground(true);
    if (!_accounts.ready) unawaited(_accounts.initialize());
    _accounts.addListener(_syncMenu);
    _menu?.addListener(_menuChanged);
    if (_menu != null) unawaited(_menu.initialize(_menuAction).then((_) => _syncMenu()));
  }
  @override
  void dispose() {
    _accounts.removeListener(_syncMenu);
    _menu?.removeListener(_menuChanged);
    if (widget.menu == null) _menu?.dispose();
    if (widget.accounts == null) _accounts.dispose();
    else _accounts.setForeground(false);
    if (widget.window == null) _window.dispose();
    super.dispose();
  }

  Future<void> _settings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AccountSettings(connection: _accounts, desktop: true)));
  }
  void _togglePrivacy() { setState(() => _hideMoney = !_hideMoney); _syncMenu(); }
  void _menuChanged() { if (mounted) setState(() {}); }
  Future<void> _selectMenu(String id) async { await _menu?.select(id); _syncMenu(); }

  List<Account> get _selected => DemoCase.fromJson({
    ...jsonDecode(_accounts.widgetRaw) as Map<String, dynamic>, 'name': 'desktop',
  }).accounts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_accounts, _window]),
    builder: (context, _) => _window.floating ? _floating() : _dashboard(),
  );

  Widget _dashboard() => Scaffold(
    appBar: AppBar(title: const Text('星账 Astracct'), actions: [
      IconButton(tooltip: _hideMoney ? '显示金额' : '隐藏金额',
        onPressed: _togglePrivacy, icon: Icon(_hideMoney ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
      IconButton(tooltip: '刷新余额', onPressed: _accounts.ready && !_accounts.busy && !_accounts.storageFailed ? _accounts.refresh : null,
        icon: const Icon(Icons.refresh)),
      IconButton(tooltip: '打开余额悬浮窗', onPressed: _accounts.ready && !_window.busy ? () => _window.setFloating(true) : null,
        icon: const Icon(Icons.picture_in_picture_alt_outlined)),
    ]),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('账户余额', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('各账户和币种分别显示。在账户设置中勾选悬浮窗要显示的余额。'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        FilledButton.icon(onPressed: _accounts.ready ? _settings : null,
          icon: const Icon(Icons.settings_outlined), label: const Text('管理 / 添加余额账户')),
        OutlinedButton.icon(onPressed: _accounts.ready && !_window.busy ? () => _window.setFloating(true) : null,
          icon: const Icon(Icons.picture_in_picture_alt_outlined), label: const Text('打开余额悬浮窗')),
      ]),
      const SizedBox(height: 16),
      if (_menu != null) ...[
        const Text('macOS 菜单栏 · 左键打开，右键切换余额；关闭窗口后继续刷新。'),
        DropdownButton<String>(
          isExpanded: true,
          hint: const Text('菜单栏显示'),
          value: _menu.choices.any((c) => c.id == _menu.selected) ? _menu.selected : '',
          items: [const DropdownMenuItem(value: '', child: Text('仅显示图标')),
            for (final choice in _menu.choices) DropdownMenuItem(value: choice.id, child: Text(choice.label, overflow: TextOverflow.ellipsis))],
          onChanged: _menu.ready ? (id) { if (id != null) unawaited(_selectMenu(id)); } : null,
        ),
        if (_menu.error != null) Text(_menu.error!, style: const TextStyle(color: AstracctTheme.error)),
        OutlinedButton.icon(onPressed: () => _window.close(), icon: const Icon(Icons.power_settings_new), label: const Text('退出星账')),
        const SizedBox(height: 12),
      ],
      if (!_accounts.ready || _accounts.busy) const LinearProgressIndicator(),
      if (_accounts.error != null) Text(_accounts.error!, style: const TextStyle(color: AstracctTheme.error)),
      if (_window.error != null) Text(_window.error!, style: const TextStyle(color: AstracctTheme.error)),
      Text(_accounts.refreshMinutes == 0 ? '自动刷新已关闭' : '运行期间每 ${_accounts.refreshMinutes} 分钟自动刷新'),
      const SizedBox(height: 12),
      if (_accounts.ready && _accounts.entries.isEmpty && !_accounts.storageFailed)
        const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('尚未添加账户。添加并验证后即可查看真实余额。'))),
      for (final entry in _accounts.entries)
        if (_accounts.errors[entry.id] != null)
          Text('${entry.name}：${_accounts.errors[entry.id]}', style: const TextStyle(color: AstracctTheme.error)),
      for (final account in _accounts.accounts) BalanceSummary(account: account, hideMoney: _hideMoney),
      const SizedBox(height: 16),
      const Text('悬浮窗可拖动、切换置顶和隐藏金额。退出应用后刷新停止；睡眠和断网可能延迟。'),
    ]),
  );

  Widget _floating() => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): () { unawaited(_window.setFloating(false)); }},
    child: Focus(autofocus: true, child: Scaffold(body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
        Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => unawaited(_window.drag()),
          child: const Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Text('星账', style: TextStyle(fontWeight: FontWeight.w600))),
        )),
        _tool(_hideMoney ? '显示金额' : '隐藏金额', _hideMoney ? Icons.visibility_off_outlined : Icons.visibility_outlined, _togglePrivacy),
        _tool(_window.pinned ? '取消置顶' : '窗口置顶', _window.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          _window.busy ? null : () => _window.togglePin()),
        _tool('刷新余额', Icons.refresh, _accounts.busy || _accounts.storageFailed ? null : _accounts.refresh),
        _tool('返回主界面', Icons.open_in_full, _window.busy ? null : () => _window.setFloating(false)),
        _tool('退出应用', Icons.close, () => _window.close()),
      ])),
      if (_accounts.busy) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), children: [
        if (_window.error != null) Text(_window.error!, style: const TextStyle(color: AstracctTheme.error)),
        if (_accounts.error != null) Text(_accounts.error!, style: const TextStyle(color: AstracctTheme.error)),
        if (_selected.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('尚未选择余额。返回主界面，在账户设置中勾选“显示在悬浮窗”。')),
        for (final entry in _accounts.entries.where((e) => _accounts.widgetAccountIds.contains(e.id)))
          if (_accounts.errors[entry.id] != null)
            Text('${entry.name}：${_accounts.errors[entry.id]}', style: const TextStyle(color: AstracctTheme.error)),
        for (final account in _selected) BalanceSummary(account: account, hideMoney: _hideMoney),
      ])),
    ])))),
  );

  Widget _tool(String tooltip, IconData icon, VoidCallback? action) => IconButton(
    tooltip: tooltip, onPressed: action, icon: Icon(icon, size: 18),
    constraints: const BoxConstraints.tightFor(width: 36, height: 40),
    padding: EdgeInsets.zero,
  );
}
