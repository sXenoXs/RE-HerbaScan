// When dart:io is available (mobile, desktop): report desktop platforms.

import 'dart:io' show Platform;

bool isDesktop() =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
