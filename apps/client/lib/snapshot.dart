import 'dart:convert';

enum MetricState { ok, unknown, stale, error }

class Metric {
  const Metric({required this.key, required this.kind, required this.state, required this.value, required this.unit, this.errorCode});

  final String key;
  final String kind;
  final MetricState state;
  final String? value;
  final String unit;
  final String? errorCode;

  factory Metric.fromJson(Map<String, dynamic> json, DateTime? lastSuccessAt) {
    _onlyKeys(json, {'key', 'kind', 'state', 'value', 'unit', 'errorCode'});
    final key = json['key'];
    final kind = json['kind'];
    final stateName = json['state'];
    final unit = json['unit'];
    final value = json['value'];
    final errorCode = json['errorCode'];
    if (key is! String || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key) ||
        kind is! String || !{'money', 'traffic', 'expiry'}.contains(kind) ||
        stateName is! String || unit is! String ||
        !(value == null || value is String) ||
        !(errorCode == null || errorCode is String)) {
      throw const FormatException('Invalid metric fields');
    }
    final state = MetricState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => throw const FormatException('Unknown metric state'),
    );
    final known = state == MetricState.ok || state == MetricState.stale;
    if (known && (value == null || lastSuccessAt == null) ||
        !known && value != null ||
        (state == MetricState.stale || state == MetricState.error) && errorCode == null ||
        (state == MetricState.ok || state == MetricState.unknown) && errorCode != null) {
      throw const FormatException('Metric value does not match its state');
    }
    if (errorCode != null && !{'timeout', 'unauthorized', 'rate_limited', 'provider_unavailable', 'stale_cache'}.contains(errorCode)) {
      throw const FormatException('Unknown error code');
    }
    if (kind == 'money' && (!RegExp(r'^[A-Z]{3}$').hasMatch(unit) ||
        value != null && !RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$').hasMatch(value)) ||
        kind == 'traffic' && (unit != 'byte' || value != null && !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) ||
        kind == 'expiry' && (unit != 'datetime' || value != null && DateTime.tryParse(value) == null)) {
      throw const FormatException('Invalid metric unit or value');
    }
    return Metric(key: key, kind: kind, state: state, value: value, unit: unit, errorCode: errorCode);
  }

  String get displayValue {
    if (state == MetricState.unknown) return '未知';
    if (state == MetricState.error) return '暂不可用';
    final raw = value!;
    if (kind == 'money') {
      final parts = raw.split('.');
      final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
      return '${parts[0]}.$fraction $unit';
    }
    if (kind == 'traffic') {
      final scaled = (BigInt.parse(raw) * BigInt.from(100)) ~/ BigInt.from(1073741824);
      return '${scaled ~/ BigInt.from(100)}.${(scaled % BigInt.from(100)).toString().padLeft(2, '0')} GiB';
    }
    final time = DateTime.parse(raw).toLocal();
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class Account {
  const Account({required this.id, required this.provider, required this.label, required this.lastSuccessAt, required this.metrics});
  final String id;
  final String provider;
  final String label;
  final DateTime? lastSuccessAt;
  final List<Metric> metrics;

  factory Account.fromJson(Map<String, dynamic> json) {
    _onlyKeys(json, {'id', 'provider', 'label', 'lastSuccessAt', 'metrics'});
    final id = json['id'];
    final provider = json['provider'];
    final label = json['label'];
    final timestamp = json['lastSuccessAt'];
    final items = json['metrics'];
    if (id is! String || provider is! String || label is! String || items is! List || items.isEmpty ||
        !(timestamp == null || timestamp is String)) {
      throw const FormatException('Invalid account fields');
    }
    final lastSuccessAt = timestamp == null ? null : DateTime.tryParse(timestamp);
    if (timestamp != null && lastSuccessAt == null) throw const FormatException('Invalid last success time');
    final metrics = items.map((item) => Metric.fromJson(_map(item), lastSuccessAt)).toList();
    if (metrics.map((item) => item.key).toSet().length != metrics.length) throw const FormatException('Duplicate metric key');
    return Account(id: id, provider: provider, label: label, lastSuccessAt: lastSuccessAt, metrics: metrics);
  }
}

class DemoCase {
  const DemoCase({required this.name, required this.generatedAt, required this.accounts});
  final String name;
  final DateTime generatedAt;
  final List<Account> accounts;

  factory DemoCase.fromJson(Map<String, dynamic> json) {
    _onlyKeys(json, {'name', 'schemaVersion', 'generatedAt', 'accounts'});
    final name = json['name'];
    final stamp = json['generatedAt'];
    final items = json['accounts'];
    if (json['schemaVersion'] != 1 || name is! String || stamp is! String || items is! List) {
      throw const FormatException('Unsupported snapshot');
    }
    final generatedAt = DateTime.tryParse(stamp);
    if (generatedAt == null) throw const FormatException('Invalid snapshot time');
    final accounts = items.map((item) => Account.fromJson(_map(item))).toList();
    if (accounts.map((item) => item.id).toSet().length != accounts.length) throw const FormatException('Duplicate account id');
    return DemoCase(name: name, generatedAt: generatedAt, accounts: accounts);
  }
}

List<DemoCase> parseDemoCases(String source) {
  final json = jsonDecode(source);
  if (json is! List) throw const FormatException('Expected demo cases');
  return json.map((item) => DemoCase.fromJson(_map(item))).toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException('Expected object');
  return value;
}

void _onlyKeys(Map<String, dynamic> map, Set<String> keys) {
  if (map.keys.any((key) => !keys.contains(key))) throw const FormatException('Unexpected snapshot field');
}
