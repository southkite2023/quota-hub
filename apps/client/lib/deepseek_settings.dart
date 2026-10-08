import 'package:flutter/material.dart';
import 'deepseek_connection.dart';

class DeepSeekSettings extends StatefulWidget {
  const DeepSeekSettings({super.key, required this.connection});
  final DeepSeekConnection connection;
  @override
  State<DeepSeekSettings> createState() => _DeepSeekSettingsState();
}

class _DeepSeekSettingsState extends State<DeepSeekSettings> {
  final _key = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() { _key.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.connection,
    builder: (context, _) {
      final connection = widget.connection;
      final enabled = connection.ready && !connection.busy;
      return PopScope(
        canPop: !connection.busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('连接 DeepSeek')),
          body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: 16),
            Text('在这里查看你的 API 余额', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('填写 DeepSeek 开放平台的 API Key，即可查询可用余额、赠送余额和充值余额。'),
            const SizedBox(height: 12),
            Chip(label: Text(connection.connected ? '已连接 · Key 已在本机加密保存' : '尚未连接')),
            const SizedBox(height: 20),
            TextField(
              controller: _key, enabled: enabled, obscureText: _obscure,
              autocorrect: false, enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: connection.connected ? '替换 API Key' : 'API Key',
                hintText: '粘贴你的 API Key', border: const OutlineInputBorder(),
                helperText: connection.connected ? '留空则保留原有 Key；验证成功后才替换。' : '在 platform.deepseek.com 的 API keys 页面创建。',
                helperMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示 API Key' : '隐藏 API Key',
                  onPressed: enabled ? () => setState(() => _obscure = !_obscure) : null,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Key 仅加密保存在这台手机，并发送至 DeepSeek 官方接口查询余额。此功能不会发起模型对话。卸载应用后需要重新设置。'),
            const SizedBox(height: 20),
            if (connection.error != null) Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(connection.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            FilledButton.icon(
              onPressed: enabled ? () async {
                FocusScope.of(context).unfocus();
                final saved = await connection.connect(_key.text);
                if (!context.mounted || !saved) return;
                _key.clear();
                Navigator.of(context).pop();
              } : null,
              icon: connection.busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link),
              label: Text(connection.busy ? '正在处理…' : '验证并保存'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: enabled ? () async {
                final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                  title: const Text('移除 DeepSeek 账户？'),
                  content: const Text('将删除本机保存的 Key 和组件余额。不会删除 DeepSeek 平台账户或撤销平台上的 Key。'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('移除'))],
                ));
                if (confirmed != true) return;
                final removed = await connection.disconnect();
                if (!context.mounted || !removed) return;
                _key.clear();
                Navigator.of(context).pop();
              } : null,
              child: const Text('移除本机账户与余额'),
            ),
          ])),
        ),
      );
    },
  );
}
