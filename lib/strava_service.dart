import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:archive/archive.dart';
import "stub_logic.dart" if (dart.library.js_interop) "web_logic.dart";

class StravaService {
  static const String _authUrl = 'https://www.strava.com/oauth/authorize';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';
  static const String _uploadUrl = 'https://www.strava.com/api/v3/uploads';
  static const String _redirectUri = 'starvaauto://localhost';
  final storage = const FlutterSecureStorage();
  String? clientId;
  String? clientSecret;

  String? accessToken;
  String? refreshToken;
  int? expiresAt;

  Future<void> init() async {
    clientId = await storage.read(key: 'client_id');
    clientSecret = await storage.read(key: 'client_secret');

    accessToken = await storage.read(key: 'access_token');
    refreshToken = await storage.read(key: 'refresh_token');
    expiresAt = int.parse(await storage.read(key: 'expires_at') ?? '0');
  }

  bool get isAuthenticated {
    if (accessToken == null || expiresAt == null) return false;
    // 如果过期了，认为还是“认证”过的，但在请求时会刷新
    return true;
  }

  bool get hasCredentials => clientId != null && clientSecret != null;

  Uri getAuthorizationUrl() {
    if (!hasCredentials) {
      throw Exception('Client ID/Secret not configured in secrets.dart');
    }
    if (kIsWeb) {
      final String currentUri = getRedirectURI();
      return Uri.parse(
        '$_authUrl?client_id=$clientId&response_type=code&redirect_uri=$currentUri&approval_prompt=force&scope=activity:write',
      );
    } else {
      return Uri.parse(
        '$_authUrl?client_id=$clientId&response_type=code&redirect_uri=$_redirectUri&approval_prompt=force&scope=activity:write',
      );
    }
  }

  Future<bool> handleAuthCallback(Uri uri) async {
    if (uri.queryParameters.containsKey('error')) {
      throw Exception('Auth error: ${uri.queryParameters['error']}');
    }
    if (uri.queryParameters.containsKey('code')) {
      final code = uri.queryParameters['code'];
      return await _exchangeToken(code!);
    }
    return false;
  }

  Future<bool> _exchangeToken(String code) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveTokens(data);
      return true;
    } else {
      throw Exception('Token exchange failed: ${response.body}');
    }
  }

  Future<void> _refreshToken() async {
    if (refreshToken == null) throw Exception('No refresh token');
    final response = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveTokens(data);
    } else {
      // Token refresh failed, maybe logout?
      throw Exception('Failed to refresh token');
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    accessToken = data['access_token'];
    refreshToken = data['refresh_token'];
    expiresAt = data['expires_at'];

    await storage.write(key: 'access_token', value: accessToken!);
    await storage.write(key: 'refresh_token', value: refreshToken!);
    await storage.write(key: 'expires_at', value: expiresAt!.toString());
  }

  Future<bool> saveCredentials(String clientId, String clientSecret) async {
    final bool credentialsChanged =
        (this.clientId != clientId || this.clientSecret != clientSecret);
    if (this.clientId != null && credentialsChanged) {
      logout();
    }
    this.clientId = clientId == "" ? null : clientId;
    this.clientSecret = clientSecret == "" ? null : clientSecret;
    if (clientId != "") {
      await storage.write(key: 'client_id', value: clientId);
    } else {
      await storage.delete(key: 'client_id');
    }
    if (clientSecret != "") {
      await storage.write(key: 'client_secret', value: clientSecret);
    } else {
      await storage.delete(key: 'client_secret');
    }
    return credentialsChanged;
  }

  Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'expires_at');
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
  }

  Future<String> uploadStravaFile(XFile file, String sportType) async {
    if (!isAuthenticated) throw Exception('Not authenticated');

    // Check expiration
    if (DateTime.now().millisecondsSinceEpoch / 1000 > expiresAt!) {
      await _refreshToken();
    }

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.headers['Authorization'] = 'Bearer $accessToken';

    final fileBytes = await file.readAsBytes();
    final compressedBytes = GZipEncoder().encodeBytes(fileBytes);
    final index = file.name.lastIndexOf('.');
    var ext = file.name.substring(index + 1).toLowerCase();
    final fileName = '${file.name.substring(0, index)}.$ext';
    ext = '$ext.gz';
    request.files.add(
      http.MultipartFile.fromBytes('file', compressedBytes, filename: fileName),
    );

    request.fields['data_type'] = ext;
    if (sportType != 'Default') {
      request.fields['sport_type'] = sportType;
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return 'Upload successful! Upload ID: ${data['id']}';
    } else {
      // Strava might return 409 for duplicate activity
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception('Upload failed: ${data['error']}');
      } else if (data['message'] != null) {
        throw Exception('Upload failed: ${data['message']}');
      }
      throw Exception('Upload failed with status ${response.statusCode}');
    }
  }
}
