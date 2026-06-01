import 'log_manager.dart';
import 'theme_manager.dart';
import 'locale_manager.dart';
import 'coord_manager.dart';
import 'strava_setting.dart';
import 'onelap_login_page.dart';
import 'onelap_manager.dart';
import 'igp_login_page.dart';
import 'igp_manager.dart';
import 'garmin_login_page.dart';
import 'garmin_manager.dart';
import 'keep_login_page.dart';
import 'keep_manager.dart';
import 'app_state.dart';
import 'extension.dart';
import 'package:flutter/material.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

Widget _buildThirdPartyLetterIcon({
  required String letter,
  required Color color,
}) {
  return Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      letter,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppState appState = GetIt.I<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            theme,
            AppLocalizations.of(context)!.generalSection,
          ),
          AnimatedBuilder(
            animation: ThemeManager(),
            builder: (context, _) {
              final themeMode = ThemeManager().themeMode;
              String themeSubtitle = AppLocalizations.of(context)!.themeSystem;
              if (themeMode == ThemeMode.light) {
                themeSubtitle = AppLocalizations.of(context)!.themeLight;
              }
              if (themeMode == ThemeMode.dark) {
                themeSubtitle = AppLocalizations.of(context)!.themeDark;
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(
                    Icons.palette_outlined,
                    color: Color(0xFFFC4C02),
                  ),
                  title: Text(AppLocalizations.of(context)!.themeTitle),
                  subtitle: Text(themeSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(context),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: LocaleManager(),
            builder: (context, _) {
              final locale = LocaleManager().locale;
              String languageSubtitle = AppLocalizations.of(
                context,
              )!.languageSystem;
              if (locale?.languageCode == 'en') {
                languageSubtitle = AppLocalizations.of(context)!.languageEn;
              }
              if (locale?.languageCode == 'zh') {
                languageSubtitle = AppLocalizations.of(context)!.languageZh;
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.language, color: Color(0xFFFC4C02)),
                  title: Text(AppLocalizations.of(context)!.languageTitle),
                  subtitle: Text(languageSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(context),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.api, color: Color(0xFFFC4C02)),
              title: Text("Strava API"),
              subtitle: Text(AppLocalizations.of(context)!.stravaLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final bool shouldDisconnect =
                    await StravaConfigUtils.showStravaConfigDialog(context);
                if (shouldDisconnect) {
                  if (!context.mounted) return;
                  context.showToast(
                    AppLocalizations.of(context)!.stravaChangeTip,
                  );
                  appState.setConnected(false);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: CoordManager(),
            builder: (context, _) {
              final bool isEnabled = CoordManager().gcjCorrection == true;
              final title = AppLocalizations.of(context)!.coordCorrection;
              final subtitle = AppLocalizations.of(context)!.coordCorrectionTip;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  secondary: Icon(
                    isEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: Color(0xFFFC4C02),
                  ),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  value: isEnabled,
                  onChanged: (bool value) {
                    CoordManager().setGcjCorrection(value);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            theme,
            AppLocalizations.of(context)!.thirdPartySync,
          ),
          AnimatedBuilder(
            animation: Listenable.merge([OneLapManager(), LocaleManager()]),
            builder: (context, _) {
              final isConnected = OneLapManager().username != null;
              final subtitle = isConnected
                  ? OneLapManager().username!
                  : AppLocalizations.of(context)!.thirdSyncSubtitle(
                      AppLocalizations.of(context)!.oneLap,
                      AppLocalizations.of(context)!.ride,
                    );

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: _buildThirdPartyLetterIcon(
                    letter: 'W',
                    color: const Color(0xFF0054FB),
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.thirdSyncTitle(AppLocalizations.of(context)!.oneLap),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      if (isConnected) const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OneLapLoginPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: Listenable.merge([IGPManager(), LocaleManager()]),
            builder: (context, _) {
              final isConnected = IGPManager().username != null;
              final subtitle = isConnected
                  ? IGPManager().username!
                  : AppLocalizations.of(context)!.thirdSyncSubtitle(
                      AppLocalizations.of(context)!.iGPS,
                      AppLocalizations.of(context)!.ride,
                    );

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: _buildThirdPartyLetterIcon(
                    letter: 'I',
                    color: const Color(0xFFFD3C1F),
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.thirdSyncTitle(AppLocalizations.of(context)!.iGPS),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      if (isConnected) const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IGPLoginPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: Listenable.merge([GarminManager(), LocaleManager()]),
            builder: (context, _) {
              final isConnected = GarminManager().username != null;
              final subtitle = isConnected
                  ? GarminManager().username!
                  : AppLocalizations.of(context)!.thirdSyncSubtitle(
                      AppLocalizations.of(context)!.garmin,
                      AppLocalizations.of(context)!.sport,
                    );

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: _buildThirdPartyLetterIcon(
                    letter: 'G',
                    color: const Color(0xFF11AEED),
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.thirdSyncTitle(AppLocalizations.of(context)!.garmin),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      if (isConnected) const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GarminLoginPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: Listenable.merge([KeepManager(), LocaleManager()]),
            builder: (context, _) {
              final isConnected = KeepManager().username != null;
              final subtitle = isConnected
                  ? KeepManager().username!
                  : AppLocalizations.of(context)!.thirdSyncSubtitle(
                      AppLocalizations.of(context)!.keep,
                      AppLocalizations.of(context)!.sport,
                    );

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: _buildThirdPartyLetterIcon(
                    letter: 'K',
                    color: const Color(0xFF483E5F),
                  ),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.thirdSyncTitle(AppLocalizations.of(context)!.keep),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      if (isConnected) const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KeepLoginPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            theme,
            AppLocalizations.of(context)!.diagnosticsSection,
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: Color(0xFFFC4C02),
              ),
              title: Text(AppLocalizations.of(context)!.activityLogsTitle),
              subtitle: Text(
                AppLocalizations.of(context)!.activityLogsSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivityLogPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            theme,
            AppLocalizations.of(context)!.aboutSection,
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Color(0xFFFC4C02),
                  ),
                  title: Text(AppLocalizations.of(context)!.versionTitle),
                  trailing: Text(AppUpgrader.currentVersion),
                  onTap: () {
                    AppUpgrader.checkUpgrade(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: Color(0xFFFC4C02)),
                  title: Text(AppLocalizations.of(context)!.openSourceTitle),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    launchUrl(
                      Uri.parse("https://github.com/xqdoo00o/strava_auto"),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return const _ThemeDialog();
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return const _LanguageDialog();
      },
    );
  }
}

class _ThemeDialog extends StatelessWidget {
  const _ThemeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.selectThemeTitle),
      content: RadioGroup<ThemeMode>(
        groupValue: ThemeManager().themeMode,
        onChanged: (value) {
          if (value != null) {
            ThemeManager().setThemeMode(value);
            Navigator.pop(context);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(
              context,
              AppLocalizations.of(context)!.themeSystem,
              ThemeMode.system,
            ),
            _buildOption(
              context,
              AppLocalizations.of(context)!.themeLight,
              ThemeMode.light,
            ),
            _buildOption(
              context,
              AppLocalizations.of(context)!.themeDark,
              ThemeMode.dark,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancelButton),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, String label, ThemeMode mode) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: mode,
      activeColor: const Color(0xFFFC4C02),
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.selectLanguageTitle),
      content: RadioGroup<String?>(
        groupValue: LocaleManager().locale?.languageCode,
        onChanged: (value) {
          LocaleManager().setLocale(value != null ? Locale(value) : null);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(
              context,
              AppLocalizations.of(context)!.languageSystem,
              null,
            ),
            _buildOption(
              context,
              AppLocalizations.of(context)!.languageEn,
              const Locale('en'),
            ),
            _buildOption(
              context,
              AppLocalizations.of(context)!.languageZh,
              const Locale('zh'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancelButton),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, String label, Locale? locale) {
    return RadioListTile<String?>(
      title: Text(label),
      value: locale?.languageCode,
      activeColor: const Color(0xFFFC4C02),
    );
  }
}

class ActivityLogPage extends StatelessWidget {
  const ActivityLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logManager = LogManager();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.activityLogsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppLocalizations.of(context)!.clearLogsTooltip,
            onPressed: () {
              logManager.clearLogs();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: logManager,
        builder: (context, _) {
          final logs = logManager.logs;

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: theme.disabledColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noLogsAvailable,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: log.isError
                        ? theme.colorScheme.error.withValues(alpha: 0.2)
                        : theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                color: log.isError
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
                    : theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          log.isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 20,
                          color: log.isError
                              ? theme.colorScheme.error
                              : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: log.isError
                                    ? theme.colorScheme.error
                                    : theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(log.timestamp),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.hintColor,
                                fontFamily: 'Monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} "
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }
}
