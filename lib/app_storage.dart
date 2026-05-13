import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static final AppStorage _instance = AppStorage._internal();
  factory AppStorage() => _instance;
  AppStorage._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _sharedPreferences;

  bool get _shouldUseSharedPreferences =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> init() async {
    if (_shouldUseSharedPreferences) {
      _sharedPreferences ??= await SharedPreferences.getInstance();
    }
  }

  SharedPreferences get _prefs {
    if (_sharedPreferences == null) {
      throw StateError('AppStorage.init() must be called before use on macOS.');
    }
    return _sharedPreferences!;
  }

  Future<String?> read({required String key}) async {
    if (_shouldUseSharedPreferences) {
      return _prefs.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    if (_shouldUseSharedPreferences) {
      await _prefs.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    if (_shouldUseSharedPreferences) {
      await _prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }
}
