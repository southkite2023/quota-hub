import 'package:flutter/material.dart';
import 'api_accounts.dart';

class RefreshSettings extends StatelessWidget {
  const RefreshSettings({super.key, required this.accounts, this.desktop = false});
  final ApiAccounts accounts;
  final bool desktop;
  Future<void> _custom(BuildContext context) async {
    final controller = TextEditingController(text: '${accounts.refreshMinutes == 0 ? 5 : accounts.refreshMinutes}');
    String? error;
    final minutes = await showDialog<int>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('自定义刷新时间'),
      content: TextField(controller: controller, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: '间隔（分钟）', helperText: '1–1440 分钟', errorText: error)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () {
          final value = int.tryParse(controller.text.trim());
          if (value == null || value < 1 || value > 1440) { setState(() => error = '请输入 1–1440 之间的整数'); return; }
          Navigator.pop(context, value);
        }, child: const Text('保存'))],
    )));
    // Dispose after the dialog route has finished its exit transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (minutes != null) await accounts.setRefreshMinutes(minutes);
  }
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('自动刷新', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(key: ValueKey(accounts.refreshMinutes), initialValue: accounts.refreshMinutes,
        decoration: const InputDecoration(labelText: '刷新间隔'),
        items: [for (final value in {0, 1, 5, 15, 30, 60, accounts.refreshMinutes}.toList()..sort())
          DropdownMenuItem(value: value, child: Text(value == 0 ? '关闭自动刷新' : '每 $value 分钟'))],
        onChanged: accounts.busy || !accounts.ready || accounts.storageFailed ? null : (value) => accounts.setRefreshMinutes(value!)),
      TextButton(onPressed: accounts.busy || !accounts.ready || accounts.storageFailed ? null : () => _custom(context), child: const Text('自定义时间')),
      if (!desktop) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('后台继续刷新'),
        subtitle: const Text('显示常驻通知，增加耗电；可在通知中停止'), value: accounts.backgroundRefresh,
        onChanged: accounts.busy || !accounts.ready || accounts.storageFailed || accounts.refreshMinutes == 0 ? null : accounts.setBackgroundRefresh),
      if (!desktop && accounts.backgroundStatus != null) Text(accounts.backgroundStatus!),
      if (!desktop && accounts.backgroundRefresh) TextButton(onPressed: accounts.busy || accounts.refreshMinutes == 0 ? null : () => accounts.setBackgroundRefresh(true), child: const Text('重新开启后台刷新')),
      Text(desktop ? '默认每 5 分钟更新全部账户。应用运行时，切换到其他程序或悬浮窗仍会刷新；退出应用后停止，睡眠或断网可能延迟。' : '默认每 5 分钟更新所有账户。后台与锁屏时会尽量按设定间隔刷新，省电模式、断网或系统限制可能延迟；Android 15 及以上可能在后台运行约 6 小时后停止。强制停止或重启手机后需打开应用。'),
    ],
  )));
}
