import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'garmin_manager.dart';
import 'garmin_web_sso_panel_stub.dart'
    if (dart.library.js_interop) 'garmin_web_sso_panel.dart';
import 'third_party_login_page.dart';

class GarminLoginPage extends StatelessWidget {
  const GarminLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = GarminManager();

    return ThirdPartyLoginPage(
      platformName: (l10n) => l10n.garmin,
      sportName: (l10n) => l10n.ride,
      accountLabel: (l10n) => l10n.accountLabel,
      listenable: manager,
      username: () => manager.username,
      lastSyncDate: () => manager.lastSyncDate,
      init: manager.init,
      login: manager.login,
      logout: manager.logout,
      setLastSyncDate: manager.setLastSyncDate,
      syncNow: manager.syncNow,
      customLoginContentBuilder: kIsWeb
          ? (context) => GarminWebSsoPanel(manager: manager)
          : null,
    );
  }
}
