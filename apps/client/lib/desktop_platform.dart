import 'package:flutter/foundation.dart';

bool get isDesktopClient => !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS);
