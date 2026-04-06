import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

// Duplicate service logic here to make it self-contained for background tasks if needed,
// or just import the service. Importing is better.
import 'keep_service.dart';
import 'strava_service.dart';
import 'log_manager.dart';

class KeepManager extends ChangeNotifier {
  static final KeepManager _instance = KeepManager._internal();
  factory KeepManager() => _instance;
  KeepManager._internal();

  final _storage = const FlutterSecureStorage();
  final _service = KeepService();
  final _stravaService = GetIt.I<StravaService>();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _username;
  String? get username => _username;

  Future<void> init() async {
    _username = await _storage.read(key: 'keep_username');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'keep_username', value: username);
        await _storage.write(key: 'keep_password', value: password);
        _username = username;

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      LogManager().addLog("Keep Login Error: $e", isError: true);
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'keep_username');
    await _storage.delete(key: 'keep_password');
    _username = null;
    notifyListeners();
  }

  Future<int> syncNow(DateTime? lastSyncDate) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    // running: 跑步 cycling: 骑行
    final sportType = "running";
    int syncedCount = 0;
    try {
      // 1. Get credentials
      final username = await _storage.read(key: 'keep_username');
      final password = await _storage.read(key: 'keep_password');

      if (username == null || password == null) {
        LogManager().addLog("Keep Sync Skipped: No credentials.");
        throw Exception("No credentials found. Please login again.");
      }

      // 2. Login
      LogManager().addLog("Keep Sync: Logging in...");
      final loginResult = await _service.login(username, password);
      if (loginResult['success'] != true) {
        LogManager().addLog("Keep Sync Failed: Login error.");
        throw Exception(
          "Login failed: ${loginResult['msg'] ?? 'Unknown error'}",
        );
      }

      // 3. Fetch list
      LogManager().addLog("Keep Sync: Fetching activities...");
      final newActivities = await _service.getActivities(
        sportType,
        lastSyncDate,
      );

      if (newActivities.isEmpty) {
        LogManager().addLog("Keep Sync: No new activities.");
        return 0;
      } else {
        LogManager().addLog(
          "Keep Sync: Found ${newActivities.length} new activities.",
        );
      }

      // 5. Download & Upload
      String dirPath = "";
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        dirPath = "${directory.path}/";
      }

      for (var activity in newActivities.reversed) {
        final fileKey = activity['fileName'];
        final activityId = activity['id'];

        try {
          LogManager().addLog("Downloading $fileKey...");
          final savePath = '$dirPath$fileKey';
          final file = await _service.getActivityData(
            activityId,
            savePath,
            sportType,
          );

          LogManager().addLog("Uploading $fileKey to Strava...");
          await _stravaService.uploadStravaFile(file, 'Default');

          syncedCount++;

          // Cleanup
          if (!kIsWeb) {
            if (await File(file.path).exists()) await File(file.path).delete();
          }
        } catch (e) {
          LogManager().addLog("Failed to sync $fileKey: $e", isError: true);
        }
      }
      return syncedCount;
    } catch (e) {
      LogManager().addLog("Keep Sync Error: $e", isError: true);
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
