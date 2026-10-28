import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Persistent overview navigation adapts at a content-driven breakpoint.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.body,
    required this.onAccounts,
    required this.onSettings,
    this.actions = const [],
  });
  final Widget body;
  final VoidCallback onAccounts, onSettings;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) < 24;
      final colors = Theme.of(context).colorScheme;
      final content = Scaffold(
        appBar: AppBar(title: const AppText('概览'), actions: actions),
        body: body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) {
                  if (index == 1) onAccounts();
                  if (index == 2) onSettings();
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard_rounded),
                    label: context.tr('概览'),
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
      );
      if (!wide) return content;
      return Scaffold(
        body: Row(
          children: [
            Container(
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
                      _destination(
                        context,
                        Icons.dashboard_rounded,
                        '概览',
                        true,
                        () {},
                      ),
                      const SizedBox(height: 6),
                      _destination(
                        context,
                        Icons.account_balance_wallet_outlined,
                        '余额账户',
                        false,
                        onAccounts,
                      ),
                      const SizedBox(height: 6),
                      _destination(
                        context,
                        Icons.tune_rounded,
                        '设置',
                        false,
                        onSettings,
                      ),
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
        ),
      );
    },
  );
  Widget _destination(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        selected: selected,
        selectedColor: colors.onPrimaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, size: 21),
        title: AppText(label),
        onTap: onTap,
      ),
    );
  }
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
