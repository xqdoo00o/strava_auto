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
      lastSyncTimeKey: 'igp_last_sync_time',
      username: () => manager.username,
      init: manager.init,
      login: manager.login,
      logout: manager.logout,
      syncNow: manager.syncNow,
    );
  }
}
