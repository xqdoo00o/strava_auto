import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'extension.dart';
import 'log_manager.dart';
import 'l10n/generated/app_localizations.dart';

class AppUpgrader {
  static const String currentVersion = "0.9.7";
  static const String repoUrl =
      "https://api.github.com/repos/xqdoo00o/strava_auto/releases/latest";
  static int compareVersion(String newVersion) {
    List<int> v1Parts = currentVersion.split('.').map(int.parse).toList();
    List<int> v2Parts = newVersion.split('.').map(int.parse).toList();
    int maxLength = v1Parts.length > v2Parts.length
        ? v1Parts.length
        : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      int v1Value = i < v1Parts.length ? v1Parts[i] : 0;
      int v2Value = i < v2Parts.length ? v2Parts[i] : 0;
      if (v1Value > v2Value) return -1;
      if (v1Value < v2Value) return 1;
    }
    return 0;
  }

  static Future<void> checkUpgrade(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final response = await http.get(Uri.parse(repoUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('tag_name')) {
          final latestVersion = data['tag_name'] as String;
          if (compareVersion(latestVersion) == 1) {
            String latestNote = data['body'] ?? '';
            if (data.containsKey('assets') &&
                (data['assets'] as List).isNotEmpty) {
              final downloadUrl =
                  data['assets'][0]['browser_download_url'] as String;
              if (context.mounted) {
                _showUpgradeDialog(
                  context,
                  latestVersion,
                  latestNote,
                  downloadUrl,
                );
              }
            }
          } else {
            if (context.mounted) {
              context.showToast(
                AppLocalizations.of(context)!.alreadyLatestVersion,
              );
            }
          }
        }
      }
    } catch (e) {
      LogManager().addLog("Check update failed: $e");
    }
  }

  static void _showUpgradeDialog(
    BuildContext context,
    String version,
    String note,
    String downloadUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.findNewVersion),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.versionNO),
                  subtitle: Text(version),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  title: Text(l10n.changelog),
                  subtitle: Text(note),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(l10n.cancelButton),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text(l10n.updateNow),
              onPressed: () {
                launchUrl(
                  Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication,
                );
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
