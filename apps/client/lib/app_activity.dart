import 'package:flutter/foundation.dart';

abstract final class UpdateActivity {
  static final changes = ValueNotifier(false);
  static bool get busy => changes.value;
  static set busy(bool value) => changes.value = value;
}
