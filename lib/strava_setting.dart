import 'package:flutter/material.dart';
import 'strava_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:get_it/get_it.dart';

class StravaConfigUtils {
  static Future<bool> showStravaConfigDialog(BuildContext context) async {
    final StravaService stravaService = GetIt.I<StravaService>();
    final TextEditingController idController = TextEditingController(
      text: stravaService.clientId ?? '',
    );
    final TextEditingController secretController = TextEditingController(
      text: stravaService.clientSecret ?? '',
    );

    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Strava API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.stravaId),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: secretController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.stravaSecret),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = idController.text.trim();
              final secret = secretController.text.trim();

              final bool disconnected = await stravaService.saveCredentials(
                id,
                secret,
              );
              if (!context.mounted) return;
              Navigator.pop(context, disconnected);
            },
            child: Text(AppLocalizations.of(context)!.confirmButton),
          ),
        ],
      ),
    );

    return success ?? false;
  }
}
