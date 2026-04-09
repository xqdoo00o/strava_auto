// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsTitle => '设置';

  @override
  String get generalSection => '通用';

  @override
  String get themeTitle => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get selectThemeTitle => '选择主题';

  @override
  String get languageTitle => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEn => '英文';

  @override
  String get languageZh => '中文';

  @override
  String get selectLanguageTitle => '选择语言';

  @override
  String get coordCorrection => '坐标纠偏';

  @override
  String get coordCorrectionTip => '上传文件后如坐标偏移可开启';

  @override
  String get logoutConfirmationTitle => '断开连接？';

  @override
  String get logoutConfirmationMessage => '确定要断开与 Strava 的连接吗？';

  @override
  String get confirmButton => '确定';

  @override
  String get defaultStr => '默认';

  @override
  String get run => '跑步';

  @override
  String get ride => '骑行';

  @override
  String get stravaChangeTip => 'Strava API 变更，请重新连接 Strava 账号。';

  @override
  String get privacyPolicyTitle => '隐私政策';

  @override
  String get agreeButton => '同意';

  @override
  String get disagreeButton => '不同意';

  @override
  String get cancelButton => '取消';

  @override
  String get experimentalSection => '实验性功能';

  @override
  String get oneLap => '顽鹿';

  @override
  String get iGPS => '迹驰';

  @override
  String get keep => 'Keep';

  @override
  String get allActivities => '全部历史活动';

  @override
  String get postActivities => '起的活动';

  @override
  String get clearDate => '清除日期（同步全部活动）';

  @override
  String thirdSyncTitle(Object aThirdName) {
    return '$aThirdName同步';
  }

  @override
  String thirdSyncSubtitle(Object aThirdName, Object sportName) {
    return '同步$aThirdName$sportName记录到 Strava';
  }

  @override
  String thirdLoginTitle(Object aThirdName) {
    return '连接$aThirdName';
  }

  @override
  String thirdLoginDescription(Object aThirdName, Object sportName) {
    return '连接您的$aThirdName账号以同步$sportName活动到 Strava。';
  }

  @override
  String get alreadyLatestVersion => '已是最新版本';

  @override
  String get findNewVersion => '发现新版本';

  @override
  String get changelog => '更新内容';

  @override
  String get versionNO => '版本号';

  @override
  String get updateNow => '立即更新';

  @override
  String get phoneLabel => '手机号';

  @override
  String get accountLabel => '账号 / 手机号';

  @override
  String get passwordLabel => '密码';

  @override
  String get connectSyncButton => '连接';

  @override
  String get reconnectButton => '重新连接';

  @override
  String get disconnectAccountButton => '断开账号';

  @override
  String loginSuccess(Object aThirdName) {
    return '成功连接$aThirdName！';
  }

  @override
  String get loginFailed => '登录失败，请检查账号密码。';

  @override
  String get diagnosticsSection => '诊断';

  @override
  String get activityLogsTitle => '活动日志';

  @override
  String get activityLogsSubtitle => '查看应用事件和错误';

  @override
  String get aboutSection => '关于';

  @override
  String get versionTitle => '版本';

  @override
  String get openSourceTitle => '开源';

  @override
  String get clearLogsTooltip => '清除日志';

  @override
  String get noLogsAvailable => '暂无日志';

  @override
  String get finalizingConnection => '正在完成连接...';

  @override
  String get connectedSuccess => '成功连接到 Strava！';

  @override
  String get authFailed => '授权失败，请检查日志。';

  @override
  String connectionError(String error) {
    return '连接错误：$error';
  }

  @override
  String cannotAccessFile(String path) {
    return '无法访问文件：$path';
  }

  @override
  String get uploadSuccess => '上传成功！';

  @override
  String get uploadFailed => '上传失败，请检查日志。';

  @override
  String uploadFileSuccess(String fileName) {
    return '成功上传 $fileName！';
  }

  @override
  String uploadFileFailed(String fileName) {
    return '上传 $fileName 失败';
  }

  @override
  String get settingsTooltip => '设置';

  @override
  String get disconnectTooltip => '断开连接';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusNotConnected => '未连接';

  @override
  String get statusReady => '准备上传活动';

  @override
  String get statusPleaseConnect => '请先连接到 Strava';

  @override
  String get connectButton => '连接到 Strava';

  @override
  String get uploadFileButton => '上传文件';

  @override
  String get uploadFileHint => '选择 FIT 文件上传';

  @override
  String get uploadActivityTitle => '上传活动？';

  @override
  String get uploadNowButton => '立即上传';

  @override
  String get pleaseConnectFirst => '请先连接到 Strava。';

  @override
  String get readyToSync => '准备同步活动';

  @override
  String get connectToStart => '连接到 Strava 开始';

  @override
  String get connectShort => '连接';

  @override
  String get unlockUpload => '请连接以解锁上传';

  @override
  String get uploading => '正在上传...';

  @override
  String get tapToSelect => '点击选择 .FIT .TCX .GPX文件';

  @override
  String get orShare => '或从其他应用分享';

  @override
  String get syncNowButton => '立即同步';

  @override
  String get syncingMessage => '正在同步...';

  @override
  String syncSuccessMessage(int count) {
    return '同步完成！已同步 $count 个活动。';
  }

  @override
  String get syncFailedMessage => '同步失败，请检查日志。';
}
