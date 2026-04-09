import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

// Duplicate service logic here to make it self-contained for background tasks if needed,
// or just import the service. Importing is better.
import 'igp_service.dart';
import 'strava_service.dart';
import 'extension.dart';
import 'log_manager.dart';

class IGPManager extends ChangeNotifier {
  static final IGPManager _instance = IGPManager._internal();
  factory IGPManager() => _instance;
  IGPManager._internal();

  final _storage = const FlutterSecureStorage();
  final _service = IGPService();
  final _stravaService = GetIt.I<StravaService>();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _username;
  String? get username => _username;

  String? _token;
  int? _tokenExp;

  Future<void> init() async {
    _username = await _storage.read(key: 'igp_username');
    _token = await _storage.read(key: 'igp_token');
    _tokenExp = int.parse(await _storage.read(key: 'igp_token_exp') ?? "0");
    notifyListeners();
  }

  Future writeToken(String token) async {
    _token = token;
    await _storage.write(key: 'igp_token', value: _token);
    _tokenExp = getJWTTOkenExp(_token!);
    await _storage.write(key: 'igp_token_exp', value: _tokenExp!.toString());
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'igp_username', value: username);
        await _storage.write(key: 'igp_password', value: password);
        _username = username;
        await writeToken(result['token']);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      LogManager().addLog("iGPSPORT Login Error: $e", isError: true);
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'igp_username');
    await _storage.delete(key: 'igp_password');
    await _storage.delete(key: 'igp_token');
    await _storage.delete(key: 'igp_token_exp');
    _username = null;
    _token = null;
    _tokenExp = null;
    notifyListeners();
  }

  Future<int> syncNow(DateTime? lastSyncDate) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;

    try {
      final nowTime =
          DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch ~/
          1000;
      // 1. Get credentials
      if (_token != null && _tokenExp != null && _tokenExp! > nowTime) {
        _service.token = _token!;
      } else {
        final username = await _storage.read(key: 'igp_username');
        final password = await _storage.read(key: 'igp_password');

        if (username == null || password == null) {
          LogManager().addLog("iGPSPORT Sync Skipped: No credentials.");
          throw Exception("No credentials found. Please login again.");
        }

        // 2. Login
        LogManager().addLog("iGPSPORT Sync: Logging in...");
        final loginResult = await _service.login(username, password);
        if (loginResult['success'] != true) {
          LogManager().addLog("iGPSPORT Sync Failed: Login error.");
          throw Exception(
            "Login failed: ${loginResult['msg'] ?? 'Unknown error'}",
          );
        }
        await writeToken(loginResult['token']);
      }

      // 3. Fetch list
      LogManager().addLog("iGPSPORT Sync: Fetching activities...");
      final newActivities = await _service.getActivities(lastSyncDate);

      if (newActivities.isEmpty) {
        LogManager().addLog("iGPSPORT Sync: No new activities.");
        return 0;
      } else {
        LogManager().addLog(
          "iGPSPORT Sync: Found ${newActivities.length} new activities.",
        );
      }

      // 5. Download & Upload
      String dirPath = "";
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        dirPath = "${directory.path}/";
      }

      for (var activity in newActivities.reversed) {
        final durl = activity['downloadUrl'];
        final fileName = activity['fileName'];

        try {
          LogManager().addLog("Downloading $fileName...");
          final savePath = '$dirPath$fileName';
          final file = await _service.downloadFit(durl, savePath);

          LogManager().addLog("Uploading $fileName to Strava...");
          await _stravaService.uploadStravaFile(file, 'Default');

          syncedCount++;

          // Cleanup
          if (!kIsWeb) {
            if (await File(file.path).exists()) await File(file.path).delete();
          }
        } catch (e) {
          LogManager().addLog("Failed to sync $fileName: $e", isError: true);
        }
      }
      return syncedCount;
    } catch (e) {
      LogManager().addLog("iGPSPORT Sync Error: $e", isError: true);
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
