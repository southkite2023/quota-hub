import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quota_hub/app_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    AppPreferences.instance = AppPreferences(
      initialValues: const {'language': 'zh'},
      readPreferences: () async => null,
      writePreferences: (_) async {},
    );
  });
  await testMain();
}
