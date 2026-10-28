import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Navigation remains outside the content navigator, including settings subpages.
class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.body,
    required this.onAccounts,
    required this.onSettings,
    this.actions = const [],
    this.accountsBuilder,
    this.settingsBuilder,
  });
  final Widget body;
  final VoidCallback onAccounts, onSettings;
  final List<Widget> actions;
  final WidgetBuilder? accountsBuilder, settingsBuilder;
  @override
  State<DashboardShell> createState() => DashboardShellState();
}

class DashboardShellState extends State<DashboardShell> {
  int _selected = 0;
  final _visited = <int>{0};
  final _revision = ValueNotifier(0);
  void openDestination(int index) {
    if (index == 1 && widget.accountsBuilder == null) {
      widget.onAccounts();
      return;
    }
    if (index == 2 && widget.settingsBuilder == null) {
      widget.onSettings();
      return;
    }
    setState(() {
      _selected = index;
      _visited.add(index);
    });
  }

  @override
  void didUpdateWidget(DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revision.value++;
  }

  @override
  void dispose() {
    _revision.dispose();
    super.dispose();
  }

  Widget _page(BuildContext context, int index) => switch (index) {
    1 => widget.accountsBuilder!(context),
    2 => widget.settingsBuilder!(context),
    _ => Scaffold(
      appBar: AppBar(title: const AppText('仪表盘'), actions: widget.actions),
      body: widget.body,
    ),
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) < 24;
      final colors = Theme.of(context).colorScheme;
      final embedded =
          widget.accountsBuilder != null || widget.settingsBuilder != null;
      final content = embedded
          ? IndexedStack(
              index: _selected,
              children: [
                for (var index = 0; index < 3; index++)
                  if (!_visited.contains(index))
                    const SizedBox()
                  else
                    ExcludeFocus(
                      excluding: _selected != index,
                      child: TickerMode(
                        enabled: _selected == index,
                        child: Navigator(
                          key: ValueKey(index),
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (context) => ValueListenableBuilder<int>(
                              valueListenable: _revision,
                              builder: (context, _, _) => _page(context, index),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            )
          : _page(context, _selected);
      return Scaffold(
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: openDestination,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard_rounded),
                    label: context.tr('仪表盘'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: context.tr('余额账户'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.tune_rounded),
                    label: context.tr('设置'),
                  ),
                ],
              ),
        body: wide
            ? Row(
                children: [
                  Container(
                    key: const ValueKey('dashboard-sidebar'),
                    width: 208,
                    color: colors.surfaceContainer,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 20, 0, 28),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text(
                                      'Astracct',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final (index, icon, label) in [
                              (0, Icons.dashboard_rounded, '仪表盘'),
                              (
                                1,
                                Icons.account_balance_wallet_outlined,
                                '余额账户',
                              ),
                              (2, Icons.tune_rounded, '设置'),
                            ]) ...[
                              Material(
                                color: _selected == index
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: ListTile(
                                  key: ValueKey('dashboard-destination-$index'),
                                  selected: _selected == index,
                                  selectedColor: colors.onPrimaryContainer,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  leading: Icon(icon, size: 21),
                                  title: AppText(label),
                                  onTap: () => openDestination(index),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: AppText(
                                '星账 · 各账户独立展示',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      );
    },
  );
}

class OverviewStatusCard extends StatelessWidget {
  const OverviewStatusCard({
    super.key,
    required this.count,
    required this.busy,
    required this.storageFailed,
    required this.onAdd,
  });
  final int count;
  final bool busy, storageFailed;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.monitor_heart_outlined, size: 19),
                      const AppText('账户状态'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: storageFailed
                              ? colors.errorContainer
                              : colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AppText(
                          storageFailed
                              ? '存储不可用'
                              : busy
                              ? '正在刷新'
                              : '本机管理',
                          style: TextStyle(
                            fontSize: 12,
                            color: storageFailed
                                ? colors.onErrorContainer
                                : colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppText(
                    '$count 个余额账户',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    '各账户与币种分别展示',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onAdd,
              tooltip: context.tr('添加余额账户'),
              padding: const EdgeInsets.all(20),
              iconSize: 30,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
