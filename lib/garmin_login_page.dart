import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'garmin_manager.dart';
import 'garmin_web_sso_panel_stub.dart'
    if (dart.library.js_interop) 'garmin_web_sso_panel.dart';
import 'l10n/generated/app_localizations.dart';
import 'third_party_login_page.dart';

class GarminLoginPage extends StatelessWidget {
  const GarminLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = GarminManager();

    return ThirdPartyLoginPage(
      platformName: (l10n) => l10n.garmin,
      sportName: (l10n) => l10n.sport,
      accountLabel: (l10n) => l10n.accountLabel,
      listenable: manager,
      username: () => manager.username,
      lastSyncDate: () => manager.lastSyncDate,
      init: manager.init,
      login: manager.login,
      loginWithMfa: manager.loginWithMfa,
      mfaRequired: () => manager.mfaRequired,
      mfaMethod: () => manager.mfaMethod,
      loginError: () => manager.lastLoginError,
      logout: manager.logout,
      setLastSyncDate: manager.setLastSyncDate,
      syncNow: manager.syncNow,
      additionalContentBuilder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final isCycling = manager.sportType == GarminManager.ride;
        final collapsedButtonKey = GlobalKey();
        return PopupMenuButton<String>(
          tooltip: isCycling ? l10n.ride : l10n.run,
          padding: EdgeInsets.zero,
          menuPadding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(12),
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
          itemBuilder: (context) {
            final menuItemHeight =
                collapsedButtonKey.currentContext?.size?.height ??
                kMinInteractiveDimension;
            return [
              PopupMenuItem(
                value: GarminManager.run,
                padding: EdgeInsets.zero,
                height: menuItemHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_run_rounded, size: 20),
                    const SizedBox(width: 6),
                    Text(l10n.run),
                  ],
                ),
              ),
              PopupMenuItem(
                value: GarminManager.ride,
                padding: EdgeInsets.zero,
                height: menuItemHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_bike_rounded, size: 20),
                    const SizedBox(width: 6),
                    Text(l10n.ride),
                  ],
                ),
              ),
            ];
          },
          onSelected: manager.setSportType,
          child: Container(
            key: collapsedButtonKey,
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(0xFF5B8296),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCycling
                      ? Icons.directions_bike_rounded
                      : Icons.directions_run_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: EdgeInsets.only(bottom: kIsWeb ? 2.0 : 0.0),
                  child: Text(
                    isCycling ? l10n.ride : l10n.run,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      customLoginContentBuilder: kIsWeb
          ? (context) => GarminWebSsoPanel(manager: manager)
          : null,
    );
  }
}
