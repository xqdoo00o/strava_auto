import 'dart:io';
import 'package:win32_registry/win32_registry.dart';

void clearURLParameter() {}
String getRedirectURI() {
  return '';
}

void registerCustomProtocol() {
  final scheme = 'stravaauto';
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
}
