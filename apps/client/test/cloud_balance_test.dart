import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quota_hub/api_accounts.dart';
import 'package:quota_hub/aliyun_balance.dart';
import 'package:quota_hub/tencent_balance.dart';
import 'package:quota_hub/deepseek_connection.dart';
import 'package:quota_hub/snapshot.dart';

const aliyun = ApiAccount(id: 'cloud', provider: BalanceProvider.aliyun, name: '阿里云账户', key: 'testSecret', accessKeyId: 'testId');
const tencent = ApiAccount(id: 'cloud2', provider: BalanceProvider.tencent, name: '腾讯云账户', key: 'testSecret', accessKeyId: 'testId');
http.Response ali(Map<String, dynamic> data) => http.Response(jsonEncode({'Success': true, 'Code': '200', 'Data': data}), 200);
void main() {
  test('TC3 signature matches independent Python HMAC fixture', () {
    expect(tencentAuthorization('testId', 'testSecret', 1790294400), endsWith('Signature=744d7d2a45fcd9bcf9fc3dea49bc19a3b73f76fe196babeef49b04d71def5b5f'));
  });
  test('RPC signature matches independent Python HMAC fixture with reserved characters', () {
    expect(aliyunSignature({'Action': 'QueryAccountBalance', 'AccessKeyId': 'testId',
      'SignatureNonce': "a b+!*'()~", 'Timestamp': '2026-09-25T00:00:00Z'}, 'testSecret'), 'VR4bGkIODStKgnKoXUHq81hWOaU=');
  });
  test('Aliyun signs fixed endpoint, exact amounts, no credentials in snapshot', () async {
    final nonces = <String>{};
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.url.host, 'business.aliyuncs.com'); expect(r.url.scheme, 'https');
      expect(r.followRedirects, false); expect(r.url.queryParameters['Action'], 'QueryAccountBalance');
      expect(r.url.queryParameters['Signature'], aliyunSignature(r.url.queryParameters, 'testSecret'));
      expect(r.url.toString(), isNot(contains('testSecret')));
      nonces.add(r.url.queryParameters['SignatureNonce']!);
      return ali({'Currency': 'CNY', 'AvailableAmount': '1,234.50', 'AvailableCashAmount': '-0.01'});
    }));
    final result = await api.fetch(aliyun); await api.fetch(aliyun);
    final parsed = DemoCase.fromJson({...result, 'name': 'test'});
    expect(parsed.accounts.single.metrics.map((m) => m.value), ['1234.50', '-0.01']);
    expect(nonces.length, 2);
    expect(jsonEncode(result), isNot(contains('testSecret'))); expect(jsonEncode(result), isNot(contains('testId')));
  });
  test('missing optional cash stays unknown, zero stays zero', () async {
    final result = await BalanceApi(clientFactory: () => MockClient((_) async => ali({'Currency': 'CNY', 'AvailableAmount': '0.00'}))).fetch(aliyun);
    expect(result['accounts'][0]['metrics'][0]['value'], '0.00');
    expect(result['accounts'][0]['metrics'][1]['state'], 'unknown');
  });
  for (final data in [<String, dynamic>{'Currency': 'CNY'}, {'Currency': 'TOKEN', 'AvailableAmount': '1'}, {'Currency': 'CNY', 'AvailableAmount': '1,23.00'}]) {
    test('rejects malformed cloud amount $data', () async {
      await expectLater(BalanceApi(clientFactory: () => MockClient((_) async => ali(data))).fetch(aliyun), throwsA(isA<DeepSeekFailure>()));
    });
  }
  test('permission response cannot become balance or expose provider message', () async {
    final api = BalanceApi(clientFactory: () => MockClient((_) async => http.Response('{"Success":false,"Code":"NoPermission","Message":"testSecret","Data":{"AvailableAmount":"999"}}', 400)));
    await expectLater(api.fetch(aliyun), throwsA(isA<DeepSeekFailure>().having((e) => e.code, 'code', 'unauthorized').having((e) => e.message, 'safe', isNot(contains('testSecret')))));
  });
  test('Tencent sends signed POST and converts fractional cents without rounding', () async {
    final api = BalanceApi(clientFactory: () => MockClient((r) async {
      expect(r.method, 'POST'); expect(r.body, '{}'); expect(r.followRedirects, false);
      expect(r.url.host, 'billing.tencentcloudapi.com'); expect(r.headers['X-TC-Action'], 'DescribeAccountBalance');
      expect(r.headers['Authorization'], tencentAuthorization('testId', 'testSecret', int.parse(r.headers['X-TC-Timestamp']!)));
      return http.Response('{"Response":{"RealBalance":12345.6,"CashAccountBalance":-1,"PresentAccountBalance":0}}', 200);
    }));
    final result = await api.fetch(tencent);
    expect(result['accounts'][0]['metrics'].map((m) => m['value']), ['123.456', '-0.01', '0.00']);
    expect(jsonEncode(result), isNot(contains('testSecret')));
  });
  test('Tencent auth failures and missing real balance are errors', () async {
    for (final body in ['{"Response":{"Error":{"Code":"AuthFailure.SignatureFailure","Message":"testSecret"}}}', '{"Response":{"Balance":999}}']) {
      await expectLater(BalanceApi(clientFactory: () => MockClient((_) async => http.Response(body, 200))).fetch(tencent), throwsA(isA<DeepSeekFailure>()));
    }
  });
  test('old account format stays readable and cloud credentials round trip', () {
    expect(ApiAccount.fromJson({'id': 'old', 'provider': 'deepseek', 'name': 'old', 'key': 'fake'}).accessKeyId, '');
    expect(ApiAccount.fromJson(aliyun.toJson()).accessKeyId, 'testId');
    expect(() => const ApiAccount(id: 'bad', provider: BalanceProvider.aliyun, name: 'bad', key: 'fake').validate(), throwsA(isA<DeepSeekFailure>()));
  });
}
