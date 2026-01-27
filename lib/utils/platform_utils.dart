import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get isWeb => kIsWeb;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isLinux => !kIsWeb && Platform.isLinux;
}
