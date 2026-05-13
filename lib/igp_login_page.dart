import 'package:flutter/material.dart';

import 'igp_manager.dart';
import 'third_party_login_page.dart';

class IGPLoginPage extends StatelessWidget {
  const IGPLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = IGPManager();

    return ThirdPartyLoginPage(
      platformName: (l10n) => l10n.iGPS,
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
    );
  }
}
