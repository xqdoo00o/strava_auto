import 'package:flutter/material.dart';

import 'keep_manager.dart';
import 'third_party_login_page.dart';

class KeepLoginPage extends StatelessWidget {
  const KeepLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = KeepManager();

    return ThirdPartyLoginPage(
      platformName: (l10n) => l10n.keep,
      sportName: (l10n) => l10n.run,
      accountLabel: (l10n) => l10n.phoneLabel,
      lastSyncTimeKey: 'keep_last_sync_time',
      username: () => manager.username,
      init: manager.init,
      login: manager.login,
      logout: manager.logout,
      syncNow: manager.syncNow,
    );
  }
}
