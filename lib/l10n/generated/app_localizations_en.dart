// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get generalSection => 'GENERAL';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get selectThemeTitle => 'Select Theme';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => 'Chinese';

  @override
  String get selectLanguageTitle => 'Select Language';

  @override
  String get coordCorrection => 'Path Correction';

  @override
  String get coordCorrectionTip => 'Turn on to correct movement path offsets.';

  @override
  String get logoutConfirmationTitle => 'Disconnect?';

  @override
  String logoutConfirmationMessage(Object aThirdName) {
    return 'Are you sure you want to disconnect from $aThirdName?';
  }

  @override
  String get confirmButton => 'Confirm';

  @override
  String get defaultStr => 'Default';

  @override
  String get run => 'Run';

  @override
  String get ride => 'Ride';

  @override
  String get sport => 'Sport';

  @override
  String get createStrava => 'Create API';

  @override
  String get stravaId => 'Client ID';

  @override
  String get stravaSecret => 'Client Secret';

  @override
  String get stravaLabel => 'Client ID/Secret';

  @override
  String get stravaUploadMethodTitle => 'Strava Sync Method';

  @override
  String get stravaUploadMethodApi => 'Strava API';

  @override
  String get stravaUploadMethodApiSubtitle => 'Sync through API tokens';

  @override
  String get stravaUploadMethodWebView => 'WebView';

  @override
  String get stravaUploadMethodWebViewSubtitle =>
      'Log in inside Strava WebView and sync through the JS bridge';

  @override
  String get stravaChangeTip =>
      'Strava API changes: Please reconnect your Strava account.';

  @override
  String get noValidFiles => 'No Vaild Files Found';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get agreeButton => 'Agree';

  @override
  String get disagreeButton => 'Disagree';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get thirdPartySync => 'Fitness Platform Sync';

  @override
  String get syncPlatforms => 'Fitness Platforms';

  @override
  String get oneLap => 'OneLap';

  @override
  String get iGPS => 'iGPSPORT';

  @override
  String get garmin => 'Garmin';

  @override
  String get keep => 'Keep';

  @override
  String get allActivities => 'All Activities';

  @override
  String get postActivities => 'Post-Activities';

  @override
  String get clearDate => 'Clear Date (Sync All Activities)';

  @override
  String thirdSyncTitle(Object aThirdName) {
    return '$aThirdName Sync';
  }

  @override
  String thirdSyncSubtitle(Object aThirdName, Object sportName) {
    return 'Sync $aThirdName $sportName activities to Strava';
  }

  @override
  String thirdLoginTitle(Object aThirdName) {
    return 'Connect $aThirdName';
  }

  @override
  String thirdLoginDescription(Object aThirdName, Object sportName) {
    return 'Connect your $aThirdName account to sync $sportName activities to Strava.';
  }

  @override
  String get alreadyLatestVersion => 'Already up to date';

  @override
  String get findNewVersion => 'New version available';

  @override
  String get changelog => 'Changelog';

  @override
  String get versionNO => 'Version';

  @override
  String get updateNow => 'Update Now';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get accountLabel => 'Account / Phone';

  @override
  String get passwordLabel => 'Password';

  @override
  String get connectSyncButton => 'Connect';

  @override
  String get reconnectButton => 'Reconnect';

  @override
  String get disconnectAccountButton => 'Disconnect Account';

  @override
  String loginSuccess(Object aThirdName) {
    return 'Connected to $aThirdName successfully!';
  }

  @override
  String get loginFailed => 'Login failed. Please check your credentials.';

  @override
  String get diagnosticsSection => 'DIAGNOSTICS';

  @override
  String get activityLogsTitle => 'Activity Logs';

  @override
  String get activityLogsSubtitle => 'View application events and errors';

  @override
  String get aboutSection => 'ABOUT';

  @override
  String get versionTitle => 'Version';

  @override
  String get openSourceTitle => 'Open Source';

  @override
  String get clearLogsTooltip => 'Clear Logs';

  @override
  String get noLogsAvailable => 'No logs available';

  @override
  String get finalizingConnection => 'Finalizing connection...';

  @override
  String get connectedSuccess => 'Connected to Strava successfully!';

  @override
  String get authFailed => 'Authorization failed. Check logs.';

  @override
  String connectionError(String error) {
    return 'Connection Error: $error';
  }

  @override
  String cannotAccessFile(String path) {
    return 'Cannot access file: $path';
  }

  @override
  String get uploadSuccess => 'Upload successful!';

  @override
  String get uploadFailed => 'Upload failed. Check logs.';

  @override
  String uploadFileSuccess(String fileName) {
    return 'Uploaded $fileName successfully!';
  }

  @override
  String uploadFileFailed(String fileName) {
    return 'Failed to upload $fileName';
  }

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get disconnectTooltip => 'Disconnect';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusNotConnected => 'Not Connected';

  @override
  String get statusReady => 'Ready to upload activities';

  @override
  String get statusPleaseConnect => 'Please connect to Strava to start';

  @override
  String get connectButton => 'Connect to Strava';

  @override
  String get uploadFileButton => 'Upload File';

  @override
  String get uploadFileHint => 'Select a FIT file to upload';

  @override
  String get uploadActivityTitle => 'Upload Activity?';

  @override
  String get uploadNowButton => 'Upload Now';

  @override
  String get pleaseConnectFirst => 'Please connect to Strava first.';

  @override
  String get webViewLoginRequired =>
      'Please sign in in the Strava WebView first.';

  @override
  String get stravaWebViewTitle => 'Strava WebView';

  @override
  String get stravaWebViewLoginHint =>
      'Sign in to Strava here, then swipe right to return.';

  @override
  String get stravaWebViewUnsupported =>
      'WebView sync is not available on Web. Use the Strava API instead.';

  @override
  String get webViewEnvTitle => 'WebView Runtime Required';

  @override
  String webViewEnvMsg(Object aWebViewRuntime) {
    return 'The $aWebViewRuntime Runtime was not detected on current system, Built-in WebView login page cannot be opened.\nOpen the link below to download and install it, then restart the app.';
  }

  @override
  String webViewEnvLink(Object aWebViewRuntime) {
    return 'Download $aWebViewRuntime Runtime';
  }

  @override
  String get readyToSync => 'Ready to sync activities';

  @override
  String get connectToStart => 'Connect to Strava to start';

  @override
  String get connectShort => 'Connect';

  @override
  String get unlockUpload => 'Please connect to unlock upload';

  @override
  String get uploading => 'Uploading...';

  @override
  String get tapToSelect => 'Tap to Select .FIT .TCX .GPX File';

  @override
  String get orShare => 'or share from other apps';

  @override
  String get orDrag => 'or drop files here';

  @override
  String get syncNowButton => 'Sync Now';

  @override
  String get syncingMessage => 'Syncing...';

  @override
  String syncSuccessMessage(int count) {
    return 'Sync completed! $count activities synced.';
  }

  @override
  String get syncFailedMessage => 'Sync failed. Check logs.';
}
