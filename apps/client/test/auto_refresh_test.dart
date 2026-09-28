import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/background_refresh.dart';

class Store implements AccountsStore {
  String? value;
  bool fail = false;
  Store({int? minutes}) : value = jsonEncode({'version': 1, if (minutes != null) 'refreshMinutes': minutes,
    'accounts': [const ApiAccount(id: 'router', provider: BalanceProvider.openrouter, name: 'router', key: 'secret').toJson()]});
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async { if (fail) throw StateError('failure'); value = data; }
}
http.Response response() => http.Response('{"data":{"total_credits":10,"total_usage":2}}', 200);
void main() {
  test('default five minutes, one-minute setting, disable, and dispose cancel timers', () {
    fakeAsync((time) {
      var calls = 0;
      final store = Store();
      final manager = ApiAccounts(store: store, now: time.getClock(DateTime(2026)).now,
        api: BalanceApi(clientFactory: () => MockClient((_) async { calls++; return response(); })));
      manager.setForeground(true); manager.initialize(); time.flushMicrotasks();
      expect(manager.refreshMinutes, 5); expect(calls, 1);
      time.elapse(const Duration(minutes: 4, seconds: 59)); expect(calls, 1);
      time.elapse(const Duration(seconds: 1)); expect(calls, 2);
      manager.setRefreshMinutes(1); time.flushMicrotasks();
      time.elapse(const Duration(minutes: 1)); expect(calls, 3);
      expect(jsonDecode(store.value!)['refreshMinutes'], 1);
      manager.setRefreshMinutes(0); time.flushMicrotasks();
      time.elapse(const Duration(hours: 1)); expect(calls, 3);
      manager.setRefreshMinutes(1); time.flushMicrotasks(); manager.dispose();
      time.elapse(const Duration(minutes: 5)); expect(calls, 3);
    });
  });
  test('pause cancels UI polling; overdue resume performs one catch-up, not a burst', () {
    fakeAsync((time) {
      var calls = 0;
      final manager = ApiAccounts(store: Store(minutes: 1), now: time.getClock(DateTime(2026)).now,
        api: BalanceApi(clientFactory: () => MockClient((_) async { calls++; return response(); })));
      manager.setForeground(true); manager.initialize(); time.flushMicrotasks();
      manager.setForeground(false); time.elapse(const Duration(minutes: 20)); expect(calls, 1);
      manager.setForeground(true); time.elapse(Duration.zero); expect(calls, 2);
      time.elapse(const Duration(seconds: 59)); expect(calls, 2);
      manager.dispose();
    });
  });
  test('slow refresh and manual refresh cannot overlap; failed save preserves interval', () {
    fakeAsync((time) {
      var calls = 0;
      final pending = Completer<http.Response>();
      final store = Store(minutes: 1);
      final manager = ApiAccounts(store: store, now: time.getClock(DateTime(2026)).now,
        api: BalanceApi(clientFactory: () => MockClient((_) { calls++; return calls == 2 ? pending.future : Future.value(response()); })));
      manager.setForeground(true); manager.initialize(); time.flushMicrotasks();
      time.elapse(const Duration(minutes: 1)); manager.refresh(); time.flushMicrotasks(); expect(calls, 2);
      pending.complete(response()); time.flushMicrotasks();
      store.fail = true; manager.setRefreshMinutes(5); time.flushMicrotasks();
      expect(manager.refreshMinutes, 1);
      time.elapse(const Duration(minutes: 1)); expect(calls, 3);
      manager.dispose();
    });
  });
  test('empty accounts stop polling and corrupt storage does not poll', () {
    fakeAsync((time) {
      var calls = 0;
      final manager = ApiAccounts(store: Store(minutes: 1), now: time.getClock(DateTime(2026)).now,
        api: BalanceApi(clientFactory: () => MockClient((_) async { calls++; return response(); })));
      manager.setForeground(true); manager.initialize(); time.flushMicrotasks();
      manager.remove('router'); time.flushMicrotasks(); time.elapse(const Duration(minutes: 5)); expect(calls, 1);
      expect(manager.nextRefreshAt, null); manager.dispose();
      final bad = ApiAccounts(store: Store(minutes: -1)); bad.setForeground(true); bad.initialize(); time.flushMicrotasks();
      expect(bad.storageFailed, true); expect(time.pendingTimers, isEmpty); bad.dispose();
    });
  });
  test('settings round trip and invalid intervals rejected', () async {
    final store = Store(); final manager = ApiAccounts(store: store);
    await manager.initialize(query: false);
    expect(await manager.setRefreshMinutes(-1), false); expect(await manager.setRefreshMinutes(1441), false);
    expect(await manager.setRefreshMinutes(7), true); expect(await manager.setBackgroundRefresh(true), true);
    final restored = ApiAccounts(store: store); await restored.initialize(query: false);
    expect(restored.refreshMinutes, 7); expect(restored.backgroundRefresh, true);
    manager.dispose(); restored.dispose();
  });
  test('background refresh uses same adapter and preserves stale balance without credentials', () async {
    final config = Store(minutes: 1).value!;
    final good = await refreshInBackground(config, null, api: BalanceApi(clientFactory: () => MockClient((_) async => response())));
    final stale = await refreshInBackground(config, good, api: BalanceApi(clientFactory: () => MockClient((_) async => http.Response('secret', 403))));
    final data = jsonDecode(stale);
    expect(data['accounts'][0]['metrics'][0]['value'], '8');
    expect(data['accounts'][0]['metrics'][0]['state'], 'stale');
    expect(stale, isNot(contains('secret')));
    expect(jsonDecode(config).containsKey('snapshot'), false);
  });
}
