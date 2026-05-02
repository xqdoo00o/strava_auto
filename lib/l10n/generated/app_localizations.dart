import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @generalSection.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get generalSection;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @selectThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectThemeTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageZh;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguageTitle;

  /// No description provided for @coordCorrection.
  ///
  /// In en, this message translates to:
  /// **'Coord Correction'**
  String get coordCorrection;

  /// No description provided for @coordCorrectionTip.
  ///
  /// In en, this message translates to:
  /// **'If coordinate offset occurs after uploading the file, enable pls.'**
  String get coordCorrectionTip;

  /// No description provided for @logoutConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect?'**
  String get logoutConfirmationTitle;

  /// No description provided for @logoutConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect from Strava?'**
  String get logoutConfirmationMessage;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @defaultStr.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultStr;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @ride.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get ride;

  /// No description provided for @stravaId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get stravaId;

  /// No description provided for @stravaSecret.
  ///
  /// In en, this message translates to:
  /// **'Client Secret'**
  String get stravaSecret;

  /// No description provided for @stravaLabel.
  ///
  /// In en, this message translates to:
  /// **'Client ID/Secret'**
  String get stravaLabel;

  /// No description provided for @stravaChangeTip.
  ///
  /// In en, this message translates to:
  /// **'Strava API changes: Please reconnect your Strava account.'**
  String get stravaChangeTip;

  /// No description provided for @noValidFiles.
  ///
  /// In en, this message translates to:
  /// **'No Vaild Files Found'**
  String get noValidFiles;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @agreeButton.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agreeButton;

  /// No description provided for @disagreeButton.
  ///
  /// In en, this message translates to:
  /// **'Disagree'**
  String get disagreeButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @experimentalSection.
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get experimentalSection;

  /// No description provided for @oneLap.
  ///
  /// In en, this message translates to:
  /// **'OneLap'**
  String get oneLap;

  /// No description provided for @iGPS.
  ///
  /// In en, this message translates to:
  /// **'iGPSPORT'**
  String get iGPS;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @allActivities.
  ///
  /// In en, this message translates to:
  /// **'All Activities'**
  String get allActivities;

  /// No description provided for @postActivities.
  ///
  /// In en, this message translates to:
  /// **'Post-Activities'**
  String get postActivities;

  /// No description provided for @clearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear Date (Sync All Activities)'**
  String get clearDate;

  /// No description provided for @thirdSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'{aThirdName} Sync'**
  String thirdSyncTitle(Object aThirdName);

  /// No description provided for @thirdSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync {aThirdName} {sportName} activities to Strava'**
  String thirdSyncSubtitle(Object aThirdName, Object sportName);

  /// No description provided for @thirdLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect {aThirdName}'**
  String thirdLoginTitle(Object aThirdName);

  /// No description provided for @thirdLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect your {aThirdName} account to sync {sportName} activities to Strava.'**
  String thirdLoginDescription(Object aThirdName, Object sportName);

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyLatestVersion;

  /// No description provided for @findNewVersion.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get findNewVersion;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @versionNO.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionNO;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account / Phone'**
  String get accountLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @connectSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectSyncButton;

  /// No description provided for @reconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnectButton;

  /// No description provided for @disconnectAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Account'**
  String get disconnectAccountButton;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected to {aThirdName} successfully!'**
  String loginSuccess(Object aThirdName);

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials.'**
  String get loginFailed;

  /// No description provided for @diagnosticsSection.
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTICS'**
  String get diagnosticsSection;

  /// No description provided for @activityLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Logs'**
  String get activityLogsTitle;

  /// No description provided for @activityLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View application events and errors'**
  String get activityLogsSubtitle;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutSection;

  /// No description provided for @versionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionTitle;

  /// No description provided for @openSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get openSourceTitle;

  /// No description provided for @clearLogsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogsTooltip;

  /// No description provided for @noLogsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get noLogsAvailable;

  /// No description provided for @finalizingConnection.
  ///
  /// In en, this message translates to:
  /// **'Finalizing connection...'**
  String get finalizingConnection;

  /// No description provided for @connectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected to Strava successfully!'**
  String get connectedSuccess;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authorization failed. Check logs.'**
  String get authFailed;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error: {error}'**
  String connectionError(String error);

  /// No description provided for @cannotAccessFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot access file: {path}'**
  String cannotAccessFile(String path);

  /// No description provided for @uploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful!'**
  String get uploadSuccess;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check logs.'**
  String get uploadFailed;

  /// No description provided for @uploadFileSuccess.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {fileName} successfully!'**
  String uploadFileSuccess(String fileName);

  /// No description provided for @uploadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload {fileName}'**
  String uploadFileFailed(String fileName);

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @disconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectTooltip;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get statusNotConnected;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to upload activities'**
  String get statusReady;

  /// No description provided for @statusPleaseConnect.
  ///
  /// In en, this message translates to:
  /// **'Please connect to Strava to start'**
  String get statusPleaseConnect;

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect to Strava'**
  String get connectButton;

  /// No description provided for @uploadFileButton.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFileButton;

  /// No description provided for @uploadFileHint.
  ///
  /// In en, this message translates to:
  /// **'Select a FIT file to upload'**
  String get uploadFileHint;

  /// No description provided for @uploadActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Activity?'**
  String get uploadActivityTitle;

  /// No description provided for @uploadNowButton.
  ///
  /// In en, this message translates to:
  /// **'Upload Now'**
  String get uploadNowButton;

  /// No description provided for @pleaseConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Please connect to Strava first.'**
  String get pleaseConnectFirst;

  /// No description provided for @readyToSync.
  ///
  /// In en, this message translates to:
  /// **'Ready to sync activities'**
  String get readyToSync;

  /// No description provided for @connectToStart.
  ///
  /// In en, this message translates to:
  /// **'Connect to Strava to start'**
  String get connectToStart;

  /// No description provided for @connectShort.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectShort;

  /// No description provided for @unlockUpload.
  ///
  /// In en, this message translates to:
  /// **'Please connect to unlock upload'**
  String get unlockUpload;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to Select .FIT .TCX .GPX File'**
  String get tapToSelect;

  /// No description provided for @orShare.
  ///
  /// In en, this message translates to:
  /// **'or share from other apps'**
  String get orShare;

  /// No description provided for @orDrag.
  ///
  /// In en, this message translates to:
  /// **'or drop files here'**
  String get orDrag;

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNowButton;

  /// No description provided for @syncingMessage.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncingMessage;

  /// No description provided for @syncSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync completed! {count} activities synced.'**
  String syncSuccessMessage(int count);

  /// No description provided for @syncFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Check logs.'**
  String get syncFailedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
