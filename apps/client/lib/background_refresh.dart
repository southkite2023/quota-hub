import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'api_accounts.dart';

class _ReadOnlyAccounts implements AccountsStore {
  _ReadOnlyAccounts(this.value);
  final String value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) => throw UnsupportedError('Background configuration is read-only');
}

Future<String> refreshInBackground(String configuration, String? snapshot, {BalanceApi? api}) async {
  final accounts = ApiAccounts(store: _ReadOnlyAccounts(configuration), api: api);
  try {
    await accounts.initialize(query: false);
    if (accounts.storageFailed) throw const FormatException('Invalid account configuration');
    accounts.restoreSnapshot(snapshot);
    await accounts.refresh();
    return accounts.raw;
  } finally { accounts.dispose(); }
}

void startBalanceService() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('quota_hub/background');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'refresh') throw MissingPluginException();
    final args = Map<String, dynamic>.from(call.arguments as Map);
    return refreshInBackground(args['configuration'] as String, args['snapshot'] as String?);
  });
  channel.invokeMethod<void>('ready');
}
