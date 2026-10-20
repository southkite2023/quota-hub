Future<bool> startupEnabled() async => false;
Future<void> configureStartup(bool enabled) async =>
    throw UnsupportedError('desktop only');
