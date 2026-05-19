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
    final appPath = Platform.resolvedExecutable;
    final protocolRegKey = 'Software\\Classes\\$scheme';
    final protocolRegValue = RegistryValue.string('URL Protocol', '');
    final protocolCmdRegKey = 'shell\\open\\command';
    final protocolCmdRegValue = RegistryValue.string('', '"$appPath" "%1"');

    RegistryKey? regKey;
    RegistryKey? commandKey;
    try {
      regKey = Registry.currentUser.createKey(protocolRegKey);
      regKey.createValue(protocolRegValue);
      commandKey = regKey.createKey(protocolCmdRegKey);
      commandKey.createValue(protocolCmdRegValue);
    } catch (e) {
      LogManager().addLog('Protocol Error: $e', isError: true);
    } finally {
      commandKey?.close();
      regKey?.close();
    }
  } else if (Platform.isLinux) {
    final appPath =
        Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
    final escapedAppPath = appPath
        .replaceAll(r'\', r'\\\\')
        .replaceAll('"', r'\\"')
        .replaceAll(r'$', r'\\$');
    final desktopContent =
        """
[Desktop Entry]
Name=Strava Auto
Comment=Automate your Strava data
Exec="$escapedAppPath" %u
Icon=com.upstrava
StartupWMClass=com.upstrava
Type=Application
Terminal=false
MimeType=x-scheme-handler/$scheme;
Categories=Utility;
""";
    final homeDir = Platform.environment['HOME'] ?? "";
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
