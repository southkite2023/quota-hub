import 'package:flutter/material.dart';
import 'api_accounts.dart';
import 'deepseek_connection.dart';

const _catalog = <({String id, String label, BalanceProvider? provider, String note})>[
  (id: 'deepseek', label: 'DeepSeek', provider: BalanceProvider.deepseek, note: 'API Key 查询可用、赠送与充值余额。'),
  (id: 'siliconflow', label: '硅基流动 · 待适配', provider: null, note: '官方公告：原 /user/info 接口于 2026-08-14 停用。等待确认替代余额接口后启用。'),
  (id: 'openrouter', label: 'OpenRouter', provider: BalanceProvider.openrouter, note: '账户余额需要 Management Key；普通模型调用 Key 可能没有权限。显示购买额度减去已用额度（USD）。'),
  (id: 'aliyun', label: '阿里云 · 云账户余额', provider: BalanceProvider.aliyun, note: '查询阿里云中国站整个账户的可用额度和现金余额，含百炼等服务共用的费用账户；不是百炼专属额度。请使用仅授予余额查询权限的 RAM 用户 AccessKey（bss:DescribeAcccount），不要填写模型 API Key。'),
  (id: 'oneapi', label: 'OneAPI 兼容接口', provider: BalanceProvider.oneapi, note: '填写站点根地址（不含 /v1）。站点需开放兼容账单接口并使用货币计费。返回的可能是令牌额度，不等于整个账户余额。请按站点选择币种。'),
  (id: 'zhipu', label: '智谱 · 待适配', provider: null, note: '尚未确认可用的官方账户余额接口。Coding 套餐额度与现金余额需分别适配。'),
  (id: 'kimi', label: 'Kimi · 待适配', provider: null, note: '余额与 Coding 套餐额度需分别核对，目前不发送查询请求。'),
  (id: 'openai', label: 'OpenAI · 待适配', provider: null, note: '已确认的官方 Costs API 查询费用，不代表剩余余额。余额查询尚未适配。'),
  (id: 'tencent', label: '腾讯云 · 云账户余额', provider: BalanceProvider.tencent, note: '查询腾讯云中国站可用、现金和赠送余额（人民币）。使用仅授予余额查询权限的 CAM 子用户 SecretId 和 SecretKey。'),
  (id: 'custom', label: '其他 · 自定义余额接口', provider: BalanceProvider.custom, note: '仅支持 HTTPS GET、Bearer Key 和 JSON 数值字段。需使用平台提供的余额接口；对话接口兼容不代表余额接口兼容。'),
];

class AccountSettings extends StatelessWidget {
  const AccountSettings({super.key, required this.connection});
  final ApiAccounts connection;
  void _edit(BuildContext context, [ApiAccount? account]) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AccountEditor(connection: connection, account: account)));
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: connection, builder: (context, _) => Scaffold(
    appBar: AppBar(title: const Text('余额账户')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('多平台、多账户，余额分别显示。凭据在本机加密保存。'),
      const SizedBox(height: 16),
      if (connection.error != null) Text(connection.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (connection.busy) const LinearProgressIndicator(),
      for (final account in connection.entries) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(account.name, style: Theme.of(context).textTheme.titleMedium),
          Text(account.provider.label),
          if (connection.errors[account.id] != null) Text(connection.errors[account.id]!),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: connection.busy ? null : () => _edit(context, account), child: const Text('编辑')),
            TextButton(onPressed: connection.busy ? null : () => connection.selectWidget(account.id),
              child: Text(connection.widgetAccountId == account.id ? '正在桌面组件显示' : '显示到桌面组件')),
            TextButton(onPressed: connection.busy ? null : () async {
              final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                title: Text('移除 ${account.name}？'), content: const Text('删除本机凭据与余额，其他账户不受影响。'),
                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('移除'))],
              ));
              if (confirmed == true) await connection.remove(account.id);
            }, child: const Text('移除')),
          ]),
        ],
      ))),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: connection.ready && !connection.busy && !connection.storageFailed ? () => _edit(context) : null,
        icon: const Icon(Icons.add), label: const Text('添加 余额账户')),
    ])),
  ));
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({super.key, required this.connection, this.account});
  final ApiAccounts connection;
  final ApiAccount? account;
  @override
  State<AccountEditor> createState() => _AccountEditorState();
}
class _AccountEditorState extends State<AccountEditor> {
  final _key = TextEditingController();
  late final _accessKeyId = TextEditingController(text: widget.account?.accessKeyId ?? '');
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _endpoint = TextEditingController(text: widget.account?.endpoint ?? '');
  late final _path = TextEditingController(text: widget.account?.balancePath ?? 'data.balance');
  late final _currency = TextEditingController(text: widget.account?.currency ?? 'USD');
  late String _choice = widget.account?.provider.name ?? 'deepseek';
  bool _obscure = true;
  String? _error;
  @override
  void dispose() { for (final controller in [_key, _accessKeyId, _name, _endpoint, _path, _currency]) { controller.dispose(); } super.dispose(); }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final provider = _catalog.firstWhere((c) => c.id == _choice).provider;
    if (provider == null) return;
    final old = widget.account;
    final custom = provider == BalanceProvider.custom || provider == BalanceProvider.oneapi;
    final endpoint = custom ? _endpoint.text.trim().replaceFirst(RegExp(r'/+$'), '') : '';
    final canReuse = old != null && old.provider == provider && old.endpoint == endpoint &&
      (!provider.isCloud || old.accessKeyId == _accessKeyId.text.trim());
    final candidate = ApiAccount(id: old?.id ?? 'account_${DateTime.now().microsecondsSinceEpoch}',
      provider: provider, name: _name.text.trim().isEmpty ? provider.label : _name.text.trim(),
      key: _key.text.trim().isEmpty && canReuse ? old.key : _key.text.trim(), endpoint: endpoint,
      accessKeyId: provider.isCloud ? _accessKeyId.text.trim() : '',
      balancePath: _path.text.trim(), currency: _currency.text.trim().toUpperCase());
    try { candidate.validate(); } on DeepSeekFailure catch (failure) { setState(() => _error = failure.message); return; }
    if (custom) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('确认查询站点'),
        content: Text('将向以下地址发送此账户的 Key：\n${candidate.uri}\n\n请确认这是你要连接的平台。'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('验证连接'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    final saved = await widget.connection.save(candidate);
    if (!mounted) return;
    if (saved) { _key.clear(); Navigator.pop(context); }
    else { setState(() => _error = widget.connection.error); }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.connection, builder: (context, _) {
    final choice = _catalog.firstWhere((c) => c.id == _choice);
    final supported = choice.provider != null;
    final enabled = widget.connection.ready && !widget.connection.busy && !widget.connection.storageFailed;
    final custom = choice.provider == BalanceProvider.custom;
    final cloud = choice.provider?.isCloud ?? false;
    final tencent = choice.provider == BalanceProvider.tencent;
    final oneapi = choice.provider == BalanceProvider.oneapi;
    return PopScope(canPop: !widget.connection.busy, child: Scaffold(
      appBar: AppBar(title: Text(widget.account == null ? '添加 余额账户' : '编辑 余额账户')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
        DropdownButtonFormField<String>(initialValue: _choice, isExpanded: true,
          decoration: const InputDecoration(labelText: '服务商', border: OutlineInputBorder()),
          items: [for (final item in _catalog) DropdownMenuItem(value: item.id, child: Text(item.label))],
          onChanged: enabled ? (value) => setState(() { _choice = value!; _key.clear(); _accessKeyId.clear(); _error = null; }) : null),
        const SizedBox(height: 16), Text(choice.note), const SizedBox(height: 20),
        if (supported) ...[
          TextField(controller: _name, enabled: enabled, maxLength: 60, decoration: const InputDecoration(labelText: '账户名称', hintText: '例如：工作账户', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          if (custom || oneapi) ...[
            TextField(controller: _endpoint, enabled: enabled, autocorrect: false, keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: oneapi ? '站点根地址' : '完整余额接口地址', hintText: oneapi ? 'https://你的站点' : 'https://你的平台/api/balance', border: const OutlineInputBorder())),
            const SizedBox(height: 16),
            if (custom) ...[
              TextField(controller: _path, enabled: enabled, autocorrect: false, decoration: const InputDecoration(labelText: '余额字段路径', hintText: 'data.balance', border: OutlineInputBorder())),
              const SizedBox(height: 16),
            ],
            TextField(controller: _currency, enabled: enabled, maxLength: 3, textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '平台余额币种', helperText: '按平台实际单位填写，例如 USD 或 CNY', border: OutlineInputBorder())),
            const SizedBox(height: 16),
          ],
          if (cloud) ...[
            TextField(controller: _accessKeyId, enabled: enabled, autocorrect: false, enableSuggestions: false,
              decoration: InputDecoration(labelText: tencent ? 'SecretId' : 'AccessKey ID', border: const OutlineInputBorder())),
            const SizedBox(height: 16),
          ],
          TextField(controller: _key, enabled: enabled, obscureText: _obscure, autocorrect: false, enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(labelText: cloud ? (tencent ? 'SecretKey' : 'AccessKey Secret') : choice.provider == BalanceProvider.openrouter ? 'Management Key' : 'API Key',
              helperText: widget.account == null ? (cloud ? 'Secret 仅用于本机签名，不随请求发送。暂不支持临时 STS 凭据。' : '仅向所选平台发送，查询余额不会调用模型。') : '留空保留原凭据；更换平台、地址或密钥 ID 后需重新输入。', helperMaxLines: 3,
              border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _obscure ? '显示 Key' : '隐藏 Key',
                onPressed: enabled ? () => setState(() => _obscure = !_obscure) : null,
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(onPressed: enabled ? _save : null, child: Text(widget.connection.busy ? '正在验证…' : '验证并保存')),
        ] else const Text('此项暂不收集 Key，也不会用演示数字冒充账户余额。'),
      ])),
    ));
  });
}
