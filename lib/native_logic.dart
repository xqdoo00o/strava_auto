import 'dart:io';
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
Type=Application
Terminal=false
MimeType=x-scheme-handler/$scheme;
Categories=Utility;
""";
    String homeDir = Platform.environment['HOME'] ?? "";
    if (homeDir.isEmpty) return;
    File desktopFile = File(
      p.join(homeDir, '.local/share/applications', 'strava_auto.desktop'),
    );
    try {
      if (!await desktopFile.parent.exists()) {
        await desktopFile.parent.create(recursive: true);
      }
      await desktopFile.writeAsString(desktopContent);
      await Process.run('update-desktop-database', [
        p.dirname(desktopFile.path),
      ]);
    } catch (e) {
      LogManager().addLog('Protocol Error: $e', isError: true);
    }
  }
}
