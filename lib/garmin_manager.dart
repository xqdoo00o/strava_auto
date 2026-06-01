import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage.dart';
import 'garmin_service.dart';
import 'strava_service.dart';
import 'extension.dart';
import 'log_manager.dart';

class GarminManager extends ChangeNotifier {
  static final GarminManager _instance = GarminManager._internal();
  factory GarminManager() => _instance;
  GarminManager._internal();

  final _storage = AppStorage();
  final _service = GarminService(isCn: true);
  final _stravaService = GetIt.I<StravaService>();

  static const run = 'running';
  static const ride = 'cycling';
  DateTime? _lastSyncDate;
  DateTime? get lastSyncDate => _lastSyncDate;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _username;
  String? get username => _username;

  String _sportType = run;
  String get sportType => _sportType;

  String? _token;
  int? _tokenExp;
  String? _refreshToken;
  int? _refreshTokenExp;
  Map<String, dynamic> _tokens = {};

  Future<void> init() async {
    await _storage.init();
    await _initDate();
    _username = await _storage.read(key: 'garmin_username');
    final tokens = await _storage.read(key: 'garmin_tokens');
    if (tokens != null) {
      _tokens = jsonDecode(tokens);
      _token = _tokens['garmin_token'];
      _tokenExp = _tokens['garmin_token_exp'];
      _refreshToken = _tokens['garmin_refresh_token'];
      _refreshTokenExp = _tokens['garmin_refresh_token_exp'];
    }
    final storedSportType = await _storage.read(key: 'garmin_sport_type');
    _sportType = storedSportType == ride ? ride : run;
    notifyListeners();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt('garmin_last_sync_time');

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
      'garmin_last_sync_time',
      lastSyncDate.millisecondsSinceEpoch ~/ 1000,
    );
    _lastSyncDate = lastSyncDate;
    notifyListeners();
  }

  Future<void> setSportType(String sportType) async {
    if (sportType != run && sportType != ride) return;
    _sportType = sportType;
    notifyListeners();
    await _storage.write(key: 'garmin_sport_type', value: sportType);
  }

  void writeToken(String token) {
    _token = token;
    _tokenExp = getJWTTOkenExp(token);
    _tokens['garmin_token'] = token;
    _tokens['garmin_token_exp'] = _tokenExp;
  }

  void writeRefreshToken(String? token, int exp, String? clientId) {
    _refreshTokenExp = exp;
    _tokens['garmin_refresh_token_exp'] = exp;
    if (token != null) {
      _refreshToken = token;
      _tokens['garmin_refresh_token'] = token;
    }
    if (clientId != null) {
      _tokens['garmin_client_id'] = clientId;
    }
  }

  Future<void> saveToken() async {
    await _storage.write(key: 'garmin_tokens', value: jsonEncode(_tokens));
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'garmin_username', value: username);
        await _storage.write(key: 'garmin_password', value: password);
        _username = username;
        writeToken(result['token']);
        writeRefreshToken(
          result['refreshToken'],
          result['refreshExpire'],
          result['clientId'],
        );
        await saveToken();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      LogManager().addLog("Garmin Login Error: $e", isError: true);
      return false;
    }
  }

  Future<bool> loginWithServiceTicket(
    String serviceTicket, {
    required String serviceUrl,
  }) async {
    try {
      final result = await _service.loginWithServiceTicket(
        serviceTicket,
        serviceUrl: serviceUrl,
      );
      if (result['success'] == true) {
        final username = await _getGarminAccountName();
        await _storage.write(key: 'garmin_username', value: username);
        await _storage.delete(key: 'garmin_password');
        _username = username;
        writeToken(result['token']);
        writeRefreshToken(
          result['refreshToken'],
          result['refreshExpire'],
          result['clientId'],
        );
        await saveToken();

        notifyListeners();
        return true;
      }
      LogManager().addLog(
        "Garmin Web Login Failed: ${result['message'] ?? 'Unknown error'}",
        isError: true,
      );
      return false;
    } catch (e) {
      LogManager().addLog("Garmin Web Login Error: $e", isError: true);
      return false;
    }
  }

  Future<String> _getGarminAccountName() async {
    try {
      final account = await _service.getCurrentUserProfileBase();
      return account;
    } catch (e) {
      LogManager().addLog(
        "Garmin Web Login: Failed to fetch profile: $e",
        isError: true,
      );
    }
    return 'Garmin';
  }

  Future<void> logout() async {
    await _storage.delete(key: 'garmin_username');
    await _storage.delete(key: 'garmin_password');
    await _storage.delete(key: 'garmin_tokens');
    _username = null;
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

    // running: 跑步 cycling: 骑行 swimming: 游泳
    final sportType = _sportType;
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
        final refreshResult = await _service.refresh(
          _refreshToken!,
          _tokens['garmin_client_id'],
        );
        if (refreshResult['success'] != true) {
          LogManager().addLog("Garmin Sync Failed: Refresh error.");
          throw Exception(
            "Login failed: ${refreshResult['message'] ?? 'Unknown error'}",
          );
        }
        writeToken(refreshResult['token']);
        writeRefreshToken(
          refreshResult['refreshToken'],
          refreshResult['refreshExpire'],
          refreshResult['clientId'],
        );
        await saveToken();
      } else {
        // 1. Get credentials
        final username = await _storage.read(key: 'garmin_username');
        final password = await _storage.read(key: 'garmin_password');

        if (username == null || password == null) {
          LogManager().addLog("Garmin Sync Skipped: No credentials.");
          throw Exception("No credentials found. Please login again.");
        }

        // 2. Login
        LogManager().addLog("Garmin Sync: Logging in...");
        final loginResult = await _service.login(username, password);
        if (loginResult['success'] != true) {
          LogManager().addLog("Garmin Sync Failed: Login error.");
          throw Exception(
            "Login failed: ${loginResult['message'] ?? 'Unknown error'}",
          );
        }
        writeToken(loginResult['token']);
        writeRefreshToken(
          loginResult['refreshToken'],
          loginResult['refreshExpire'],
          loginResult['clientId'],
        );
        await saveToken();
      }

      // 3. Fetch list
      LogManager().addLog("Garmin Sync: Fetching activities...");
      final newActivities = await _service.getActivities(
        sportType,
        lastSyncDate,
      );

      if (newActivities.isEmpty) {
        LogManager().addLog("Garmin Sync: No new activities.");
        await _saveLastSyncDate(DateTime.now());
        return 0;
      } else {
        LogManager().addLog(
          "Garmin Sync: Found ${newActivities.length} new activities.",
        );
      }

      // 5. Download & Upload
      String dirPath = "";
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        dirPath = directory.path;
      }

      for (var activity in newActivities.reversed) {
        String fileKey = activity['id'];
        final activityId = activity['id'];

        try {
          LogManager().addLog("Downloading $fileKey...");
          final file = await _service.downloadSportFile(activityId, dirPath);
          fileKey = file.name;
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
      await _saveLastSyncDate(DateTime.now());
      return syncedCount;
    } catch (e) {
      LogManager().addLog("Garmin Sync Error: $e", isError: true);
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
