import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import 'strava_service.dart';
import 'l10n/generated/app_localizations.dart';

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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Strava API'),
            TextButton.icon(
              onPressed: () async {
                final Uri url = Uri.parse(
                  'https://www.strava.com/settings/api',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                AppLocalizations.of(context)!.createStrava,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.stravaId,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: secretController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.stravaSecret,
              ),
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
