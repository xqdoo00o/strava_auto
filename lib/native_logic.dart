import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:win32_registry/win32_registry.dart';
import 'log_manager.dart';

void clearURLParameter() {}
String getRedirectURI() {
  return '';
}

Future<void> registerDesktopCustomProtocol() async {
  final scheme = 'stravaauto';

  if (Platform.isWindows) {
    String appPath = Platform.resolvedExecutable;
    String protocolRegKey = 'Software\\Classes\\$scheme';
    RegistryValue protocolRegValue = RegistryValue.string('URL Protocol', '');
    String protocolCmdRegKey = 'shell\\open\\command';
    RegistryValue protocolCmdRegValue = RegistryValue.string(
      '',
      '"$appPath" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  } else if (Platform.isLinux) {
    String appPath =
        Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
    String desktopContent =
        """
[Desktop Entry]
Name=Strava Auto
Comment=Automate your Strava data
Exec=$appPath %u
Icon=com.upstrava
StartupWMClass=com.upstrava
Type=Application
Terminal=false
MimeType=x-scheme-handler/$scheme;
Categories=Utility;
""";
    String homeDir = Platform.environment['HOME'] ?? "";
    if (homeDir.isEmpty) return;
    File iconFile = File(
      p.join(homeDir, '.local/share/icons', 'com.upstrava.png'),
    );
    File desktopFile = File(
      p.join(homeDir, '.local/share/applications', 'com.upstrava.desktop'),
    );

    try {
      if (!await iconFile.exists()) {
        await iconFile.parent.create(recursive: true);
        ByteData data = await rootBundle.load('assets/icon.png');
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await iconFile.writeAsBytes(bytes);
      }
      if (!await desktopFile.parent.exists()) {
        await desktopFile.parent.create(recursive: true);
      }
      await desktopFile.writeAsString(desktopContent);
    } catch (e) {
      LogManager().addLog('Protocol Error: $e', isError: true);
    }
  }
}
