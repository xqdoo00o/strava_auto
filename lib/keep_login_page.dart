import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'keep_manager.dart';
import 'l10n/generated/app_localizations.dart';
import 'third_party_login_page.dart';

class KeepLoginPage extends StatelessWidget {
  const KeepLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = KeepManager();

    return ThirdPartyLoginPage(
      platformName: (l10n) => l10n.keep,
      sportName: (l10n) => l10n.sport,
      accountLabel: (l10n) => l10n.phoneLabel,
      listenable: manager,
      username: () => manager.username,
      lastSyncDate: () => manager.lastSyncDate,
      init: manager.init,
      login: manager.login,
      logout: manager.logout,
      setLastSyncDate: manager.setLastSyncDate,
      syncNow: manager.syncNow,
      additionalContentBuilder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final isCycling = manager.sportType == KeepManager.ride;
        return PopupMenuButton<String>(
          tooltip: isCycling ? l10n.ride : l10n.run,
          padding: EdgeInsets.zero,
          menuPadding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(12),
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: KeepManager.run,
              padding: EdgeInsets.zero,
              height: 40,
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
              value: KeepManager.ride,
              padding: EdgeInsets.zero,
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bike_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text(l10n.ride),
                ],
              ),
            ),
          ],
          onSelected: manager.setSportType,
          child: Container(
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
    );
  }
}
