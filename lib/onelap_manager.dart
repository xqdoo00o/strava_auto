import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

// Duplicate service logic here to make it self-contained for background tasks if needed,
// or just import the service. Importing is better.
import 'onelap_service.dart';
import 'strava_service.dart';
import 'log_manager.dart';

class OneLapManager extends ChangeNotifier {
  static final OneLapManager _instance = OneLapManager._internal();
  factory OneLapManager() => _instance;
  OneLapManager._internal();

  final _storage = const FlutterSecureStorage();
  final _service = OneLapService();
  final _stravaService = GetIt.I<StravaService>();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _username;
  String? get username => _username;

  Future<void> init() async {
    _username = await _storage.read(key: 'onelap_username');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'onelap_username', value: username);
        await _storage.write(key: 'onelap_password', value: password);
        _username = username;

        // Initial sync of existing activities (mark as synced without uploading)
        await _markAllAsSynced();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      LogManager().addLog("OneLap Login Error: $e", isError: true);
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'onelap_username');
    await _storage.delete(key: 'onelap_password');
    _username = null;
    notifyListeners();
  }

  Future<void> _markAllAsSynced() async {
    try {
      final activities = await _service.getActivities();
      final prefs = await SharedPreferences.getInstance();
      final List<String> syncedIds = activities
          .map((e) => e['fileKey'].toString())
          .toList();
      await prefs.setStringList('onelap_synced_ids', syncedIds);
      LogManager().addLog(
        "Marked ${syncedIds.length} OneLap activities as synced.",
      );
    } catch (e) {
      LogManager().addLog("Failed to mark initial sync: $e", isError: true);
    }
  }

  Future<int> syncNow() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;

    try {
      // 1. Get credentials
      final username = await _storage.read(key: 'onelap_username');
      final password = await _storage.read(key: 'onelap_password');

      if (username == null || password == null) {
        LogManager().addLog("OneLap Sync Skipped: No credentials.");
        throw Exception("No credentials found. Please login again.");
      }

      // 2. Login
      LogManager().addLog("OneLap Sync: Logging in...");
      final loginResult = await _service.login(username, password);
      if (loginResult['success'] != true) {
        LogManager().addLog("OneLap Sync Failed: Login error.");
        throw Exception(
          "Login failed: ${loginResult['msg'] ?? 'Unknown error'}",
        );
      }

      // 3. Fetch list
      LogManager().addLog("OneLap Sync: Fetching activities...");
      final activities = await _service.getActivities();

      // 4. Compare with local
      final prefs = await SharedPreferences.getInstance();
      final syncedIds = prefs.getStringList('onelap_synced_ids') ?? [];
      final newActivities = activities
          .where((a) => !syncedIds.contains(a['fileKey']))
          .toList();

      if (newActivities.isEmpty) {
        LogManager().addLog("OneLap Sync: No new activities.");
        return 0;
      }

      LogManager().addLog(
        "OneLap Sync: Found ${newActivities.length} new activities.",
      );

      // 5. Download & Upload
      String dirPath = "";
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        dirPath = "${directory.path}/";
      }

      for (var activity in newActivities) {
        final fileKey = activity['fileKey'];
        final downloadUrl = activity['durl'];

        try {
          LogManager().addLog("Downloading $fileKey...");
          final savePath = '$dirPath$fileKey';
          final file = await _service.downloadFit(downloadUrl, savePath);

          LogManager().addLog("Uploading $fileKey to Strava...");
          await _stravaService.uploadStravaFile(file, 'Default');

          // Mark as synced
          syncedIds.add(fileKey);
          await prefs.setStringList('onelap_synced_ids', syncedIds);

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
      LogManager().addLog("OneLap Sync Error: $e", isError: true);
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
