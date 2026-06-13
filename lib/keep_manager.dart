import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Duplicate service logic here to make it self-contained for background tasks if needed,
// or just import the service. Importing is better.
import 'app_storage.dart';
import 'keep_service.dart';
import 'strava_service.dart';
import 'extension.dart';
import 'log_manager.dart';

class KeepManager extends ChangeNotifier {
  static final KeepManager _instance = KeepManager._internal();
  factory KeepManager() => _instance;
  KeepManager._internal();

  final _storage = AppStorage();
  final _service = KeepService();
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

  Map<String, dynamic> _tokens = {};

  Future<void> init() async {
    await _storage.init();
    final prefs = await SharedPreferences.getInstance();
    final storedSportType = prefs.getString('keep_sport_type');
    _sportType = storedSportType == ride ? ride : run;
    await _initDate();

    _username = await _storage.read(key: 'keep_username');
    final tokens = await _storage.read(key: 'keep_tokens');
    if (tokens != null) {
      _tokens = jsonDecode(tokens);
      _token = _tokens['keep_token'];
      _tokenExp = _tokens['keep_token_exp'];
    }
    notifyListeners();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt('keep_last_${_sportType}_sync_time');

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
      'keep_last_${_sportType}_sync_time',
      lastSyncDate.millisecondsSinceEpoch ~/ 1000,
    );
    _lastSyncDate = lastSyncDate;
    notifyListeners();
  }

  void writeToken(String key, String token) {
    _token = token;
    _tokenExp = getJWTTOkenExp(token);
    _tokens['keep_$key'] = token;
    _tokens['keep_${key}_exp'] = _tokenExp;
  }

  Future<void> saveToken() async {
    await _storage.write(key: 'keep_tokens', value: jsonEncode(_tokens));
  }

  Future<void> setSportType(String sportType) async {
    if (sportType != run && sportType != ride) return;
    _sportType = sportType;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('keep_sport_type', sportType);
    await _initDate();
  }

  Future<bool> login(String username, String password) async {
    try {
      final result = await _service.login(username, password);
      if (result['success'] == true) {
        // Save credentials securely
        await _storage.write(key: 'keep_username', value: username);
        await _storage.write(key: 'keep_password', value: password);
        _username = username;
        writeToken('token', result['token']);
        await saveToken();

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
    await _storage.delete(key: 'keep_tokens');
    _username = null;
    _token = null;
    _tokenExp = null;
    _tokens.clear();
    notifyListeners();
  }

  Future<int> syncNow() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    // running: 跑步 cycling: 骑行 training: 游泳锻炼等其他
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
      } else {
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
            "Login failed: ${loginResult['message'] ?? 'Unknown error'}",
          );
        }
        writeToken('token', loginResult['token']);
        await saveToken();
      }

      // 3. Fetch list
      LogManager().addLog("Keep Sync: Fetching activities...");
      final newActivities = await _service.getActivities(
        sportType,
        _lastSyncDate,
      );

      if (newActivities.isEmpty) {
        LogManager().addLog("Keep Sync: No new activities.");
        await _saveLastSyncDate(DateTime.now());
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
        dirPath = directory.path;
      }

      for (var activity in newActivities.reversed) {
        final fileKey = activity['fileName'];
        final activityId = activity['id'];

        try {
          LogManager().addLog("Downloading $fileKey...");
          final savePath = p.join(dirPath, fileKey);
          final file = await _service.downloadSportFile(
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
      await _saveLastSyncDate(DateTime.now());
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
