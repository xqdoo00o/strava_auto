import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Duplicate service logic here to make it self-contained for background tasks if needed,
// or just import the service. Importing is better.
import 'app_storage.dart';
import 'onelap_service.dart';
import 'strava_service.dart';
import 'extension.dart';
import 'log_manager.dart';

class OneLapManager extends ChangeNotifier {
  static final OneLapManager _instance = OneLapManager._internal();
  factory OneLapManager() => _instance;
  OneLapManager._internal();

  final _storage = AppStorage();
  final _service = OneLapService();
  final _stravaService = GetIt.I<StravaService>();
  DateTime? _lastSyncDate;
  DateTime? get lastSyncDate => _lastSyncDate;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _username;
  String? get username => _username;

  String? _token;
  int? _tokenExp;

  String? _refreshToken;
  int? _refreshTokenExp;

  Map<String, dynamic> _tokens = {};

  Future<void> init() async {
    await _storage.init();
    await _initDate();
    _username = await _storage.read(key: 'onelap_username');
    final tokens = await _storage.read(key: 'onelap_tokens');
    if (tokens != null) {
      _tokens = jsonDecode(tokens);
      _token = _tokens['onelap_token'];
      _tokenExp = _tokens['onelap_token_exp'];
      _refreshToken = _tokens['onelap_refresh_token'];
      _refreshTokenExp = _tokens['onelap_refresh_token_exp'];
    }
    notifyListeners();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt('onelap_last_sync_time');

    if (lastSyncTime != null && lastSyncTime > 0) {
      _lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncTime * 1000);
    } else {
      _lastSyncDate = DateTime.now();
    }
  }

  Future<void> setLastSyncDate(DateTime? lastSyncDate) async {
    _lastSyncDate = lastSyncDate;
    notifyListeners();
  }

  Future<void> _saveLastSyncDate(DateTime lastSyncDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'onelap_last_sync_time',
      lastSyncDate.millisecondsSinceEpoch ~/ 1000,
    );
    _lastSyncDate = lastSyncDate;
    notifyListeners();
  }

  void writeToken(String key, String token) {
    _token = token;
    _tokenExp = getJWTTOkenExp(token);
    _tokens['onelap_$key'] = token;
    _tokens['onelap_${key}_exp'] = _tokenExp;
  }

  Future<void> saveToken() async {
    await _storage.write(key: 'onelap_tokens', value: jsonEncode(_tokens));
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'onelap_username', value: username);
        await _storage.write(key: 'onelap_password', value: password);
        _username = username;
        writeToken('token', result['token']);
        writeToken('refresh_token', result['refreshToken']);
        await saveToken();

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
    await _storage.delete(key: 'onelap_tokens');
    _token = null;
    _tokenExp = null;
    _refreshToken = null;
    _refreshTokenExp = null;
    _tokens.clear();
    notifyListeners();
  }

  Future<int> syncNow() async {
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
      } else if (_refreshToken != null &&
          _refreshTokenExp != null &&
          _refreshTokenExp! > nowTime) {
        final refreshResult = await _service.refresh(_refreshToken!);
        if (refreshResult['success'] != true) {
          LogManager().addLog("OneLap Sync Failed: Refresh error.");
          throw Exception(
            "Refresh failed: ${refreshResult['message'] ?? 'Unknown error'}",
          );
        }
        writeToken('token', refreshResult['token']);
        await saveToken();
      } else {
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
            "Login failed: ${loginResult['message'] ?? 'Unknown error'}",
          );
        }
        writeToken('token', loginResult['token']);
        writeToken('refresh_token', loginResult['refreshToken']);
        await saveToken();
      }

      // 3. Fetch list
      LogManager().addLog("OneLap Sync: Fetching activities...");
      final newActivities = await _service.getActivities(_lastSyncDate);

      if (newActivities.isEmpty) {
        LogManager().addLog("OneLap Sync: No new activities.");
        await _saveLastSyncDate(DateTime.now());
        return 0;
      } else {
        LogManager().addLog(
          "OneLap Sync: Found ${newActivities.length} new activities.",
        );
      }

      // 5. Download & Upload
      String dirPath = "";
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        dirPath = directory.path;
      }

      for (var activity in newActivities.reversed) {
        final fileKey = activity['fileKey'];
        final fileName = fileKey.split('/').last;

        try {
          LogManager().addLog("Downloading $fileName...");
          final savePath = p.join(dirPath, fileName);
          final file = await _service.downloadFit(fileKey, savePath);

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
      await _saveLastSyncDate(DateTime.now());
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
