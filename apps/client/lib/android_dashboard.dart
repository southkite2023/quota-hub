import 'package:flutter/material.dart';

import 'account_settings.dart';
import 'api_accounts.dart';
import 'app_theme.dart';
import 'balance_summary.dart';
import 'snapshot.dart';

Color categoryAccent(BalanceCategory category) => switch (category) {
  BalanceCategory.ai => AstracctTheme.aiAccent,
  BalanceCategory.cloud => AstracctTheme.cloudAccent,
  BalanceCategory.nodes => AstracctTheme.nodesAccent,
};

/// Native mobile presentation. Querying, storage and widget sync remain in Dashboard.
class AndroidDashboard extends StatefulWidget {
  const AndroidDashboard({
    super.key,
    required this.accounts,
    required this.hideMoney,
    required this.onToggleMoney,
    required this.onSettings,
    this.selectedAccountId,
    this.widgetError,
  });
  final ApiAccounts accounts;
  final bool hideMoney;
  final VoidCallback onToggleMoney, onSettings;
  final String? selectedAccountId, widgetError;

  @override
  State<AndroidDashboard> createState() => _AndroidDashboardState();
}

class _AndroidDashboardState extends State<AndroidDashboard> {
  BalanceCategory? _filter;
  final _cardKeys = <String, GlobalKey>{};
  String? _revealed;
  bool get _editable =>
      widget.accounts.ready &&
      !widget.accounts.busy &&
      !widget.accounts.storageFailed;

  void _edit([ApiAccount? account]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AccountEditor(connection: widget.accounts, account: account),
    ),
  );

  @override
  void didUpdateWidget(AndroidDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAccountId != widget.selectedAccountId) {
      _filter = null;
      _revealed = null;
    }
  }

  Future<void> _remove(ApiAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('移除 ${account.name}？'),
        content: const Text('删除本机凭据与余额，其他账户不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.accounts.remove(account.id);
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.accounts;
    final snapshots = connection.accounts;
    final visible = connection.entries
        .where((entry) => _filter == null || entry.category == _filter)
        .toList();
    final latest = snapshots
        .map((a) => a.lastSuccessAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (previous, date) =>
              previous == null || date.isAfter(previous) ? date : previous,
        );
    final selected = widget.selectedAccountId;
    if (selected != null && selected != _revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _cardKeys[selected]?.currentContext;
        if (target != null) {
          _revealed = selected;
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AstracctTheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '星账 Astracct',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ANDROID APP',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      color: AstracctTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '余额账户设置',
            onPressed: widget.onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: connection.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEEECFF),
                            Color(0xFFE5F0FF),
                            Color(0xFFD9F3EC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AstracctTheme.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASTRACCT / ANDROID',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: AstracctTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '你的余额，',
                            style: TextStyle(
                              fontSize: 40,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            '一眼看清。',
                            style: TextStyle(
                              fontSize: 40,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AstracctTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '连接服务商，集中查看每个账户的余额。\n凭据在本机加密保存，账户与币种分别展示。',
                            style: TextStyle(
                              color: AstracctTheme.muted,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _editable ? () => _edit() : null,
                            icon: const Icon(Icons.add),
                            label: const Text('添加余额账户'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              connection.refreshMinutes == 0
                                  ? '自动刷新已关闭'
                                  : '自动刷新：每 ${connection.refreshMinutes} 分钟',
                              style: const TextStyle(
                                color: AstracctTheme.muted,
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  connection.ready &&
                                      !connection.busy &&
                                      !connection.storageFailed
                                  ? connection.refresh
                                  : null,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('刷新余额'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!connection.ready || connection.busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (connection.error != null) _Notice(connection.error!),
                    if (widget.widgetError != null)
                      _Notice(widget.widgetError!),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final tiles = [
                          _Stat(
                            label: '已添加账户',
                            value: '${connection.entries.length}',
                            color: const Color(0xFFEEEDFF),
                          ),
                          _Stat(
                            label: '账户种类',
                            value:
                                '${connection.entries.map((a) => a.category).toSet().length}',
                            color: const Color(0xFFE6F8F2),
                          ),
                          _Stat(
                            label: '最近更新',
                            value: latest == null
                                ? '—'
                                : '${latest.toLocal().month}/${latest.toLocal().day}',
                            color: const Color(0xFFFFF2E8),
                          ),
                        ];
                        // Stack for large accessibility fonts instead of squeezing labels.
                        final stacked =
                            MediaQuery.textScalerOf(context).scale(14) > 21;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tile in tiles)
                              SizedBox(
                                width: stacked
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 16) / 3,
                                child: tile,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          '余额账户',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onToggleMoney,
                          icon: Icon(
                            widget.hideMoney
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          label: Text(widget.hideMoney ? '显示金额' : '隐藏金额'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in <BalanceCategory?>[
                          null,
                          ...BalanceCategory.values,
                        ])
                          ChoiceChip(
                            label: Text(
                              category?.label ?? '全部',
                              style: TextStyle(
                                color: _filter == category
                                    ? Colors.white
                                    : AstracctTheme.muted,
                              ),
                            ),
                            selected: _filter == category,
                            onSelected: (_) =>
                                setState(() => _filter = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (visible.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 20,
                          ),
                          child: Text(
                            connection.entries.isEmpty
                                ? '还没有余额账户。点击「添加余额账户」开始连接。'
                                : '该种类暂无账户',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AstracctTheme.muted),
                          ),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 650 &&
                                MediaQuery.textScalerOf(context).scale(14) <= 21
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 14) /
                            columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final entry in visible)
                              for (final snapshot in snapshots.where(
                                (a) =>
                                    a.id ==
                                    '${entry.id}_${a.metrics.first.unit.toLowerCase()}',
                              ))
                                SizedBox(
                                  width: width,
                                  child: MobileAccountCard(
                                    key: _cardKeys.putIfAbsent(
                                      snapshot.id,
                                      GlobalKey.new,
                                    ),
                                    entry: entry,
                                    account: snapshot,
                                    hideMoney: widget.hideMoney,
                                    selected: snapshot.id == selected,
                                    error: connection.errors[entry.id],
                                    onEdit: _editable
                                        ? () => _edit(entry)
                                        : null,
                                    onRemove: _editable
                                        ? () => _remove(entry)
                                        : null,
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    TextButton.icon(
                      onPressed: widget.onSettings,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('管理账户、小组件与刷新设置'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '数据保存在本机。主界面显示全部账户，小组件显示勾选账户；不跨账户或币种求和。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.8,
                        color: AstracctTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileAccountCard extends StatelessWidget {
  const MobileAccountCard({
    super.key,
    required this.entry,
    required this.account,
    required this.hideMoney,
    this.selected = false,
    this.error,
    this.onEdit,
    this.onRemove,
  });
  final ApiAccount entry;
  final Account account;
  final bool hideMoney, selected;
  final String? error;
  final VoidCallback? onEdit, onRemove;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected ? AstracctTheme.primary : AstracctTheme.border,
        width: selected ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 4, color: categoryAccent(entry.category)),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AstracctTheme.muted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                entry.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.provider.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(account.label, style: Theme.of(context).textTheme.bodySmall),
              if (selected)
                const Text(
                  '已从桌面组件打开对应账户',
                  style: TextStyle(color: AstracctTheme.success),
                ),
              const SizedBox(height: 22),
              // Keep every metric and state; OpenAI costs never become a balance.
              for (final metric in account.metrics) ...[
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.copyWith(
                      titleMedium: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(
                            fontSize:
                                {
                                  'available',
                                  'available_credit',
                                  'month_spent',
                                }.contains(metric.key)
                                ? 28
                                : 16,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: AstracctTheme.ink,
                          ),
                    ),
                  ),
                  child: MetricLine(metric: metric, hideMoney: hideMoney),
                ),
                const SizedBox(height: 14),
              ],
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: AstracctTheme.error),
                ),
              const Divider(color: AstracctTheme.border),
              const SizedBox(height: 6),
              Text(
                account.lastSuccessAt == null
                    ? '尚无成功记录'
                    : '上次成功：${_time(account.lastSuccessAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: onEdit, child: const Text('编辑')),
                  TextButton(onPressed: onRemove, child: const Text('移除')),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _time(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(message, style: const TextStyle(color: AstracctTheme.error)),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AstracctTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AstracctTheme.muted),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
