import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:archive/archive.dart';
import 'app_storage.dart';
import "stub_logic.dart" if (dart.library.js_interop) "web_logic.dart";
import 'strava_webview_bridge_native.dart'
    if (dart.library.js_interop) 'strava_webview_bridge_web.dart';

enum StravaUploadMode { api, webView }

class StravaService extends ChangeNotifier {
  static const String _authUrl = 'https://www.strava.com/oauth/authorize';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';
  static const String _uploadUrl = 'https://www.strava.com/api/v3/uploads';
  static const String _redirectUri = 'stravaauto://localhost';
  static const String _uploadModeKey = 'strava_upload_mode';

  StravaService({StravaWebViewBridge? webViewBridge})
    : _webViewBridge = webViewBridge;

  final _storage = AppStorage();
  final StravaWebViewBridge? _webViewBridge;
  String? clientId;
  String? clientSecret;
  StravaUploadMode _uploadMode = StravaUploadMode.api;

  String? accessToken;
  String? refreshToken;
  int? expiresAt;

  StravaUploadMode get uploadMode => _uploadMode;
  bool get isWebViewUploadSupported => !shouldUseWebProxy();

  Future<void> init() async {
    await _storage.init();

    clientId = await _storage.read(key: 'client_id');
    clientSecret = await _storage.read(key: 'client_secret');
    final storedUploadMode = await _storage.read(key: _uploadModeKey);
    _uploadMode = storedUploadMode == StravaUploadMode.webView.name
        ? StravaUploadMode.webView
        : StravaUploadMode.api;

    accessToken = await _storage.read(key: 'access_token');
    refreshToken = await _storage.read(key: 'refresh_token');
    expiresAt = int.parse(await _storage.read(key: 'expires_at') ?? '0');
  }

  bool get isAuthenticated {
    if (accessToken == null || expiresAt == null) return false;
    // 如果过期了，认为还是“认证”过的，但在请求时会刷新
    return true;
  }

  bool get hasCredentials => clientId != null && clientSecret != null;

  bool get isReadyForUpload {
    if (_uploadMode == StravaUploadMode.webView) {
      return _webViewBridge?.isLoggedIn == true;
    }
    return isAuthenticated;
  }

  Future<void> setUploadMode(StravaUploadMode uploadMode) async {
    if (uploadMode == StravaUploadMode.webView && !isWebViewUploadSupported) {
      throw Exception('WebView upload is not available in this environment');
    }
    if (_uploadMode == uploadMode) return;
    _uploadMode = uploadMode;
    await _storage.write(key: _uploadModeKey, value: uploadMode.name);
    notifyListeners();
  }

  Uri getAuthorizationUrl() {
    if (!hasCredentials) {
      throw Exception('Client ID/Secret not configured in secrets.dart');
    }
    return Uri.parse(_authUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': _authorizationRedirectUri,
        'approval_prompt': 'force',
        'scope': 'activity:write',
      },
    );
  }

  String get _authorizationRedirectUri {
    if (!kIsWeb) return _redirectUri;
    if (isChromeExtension()) return 'web%2B$_redirectUri';
    return getRedirectURI();
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

    await _storage.write(key: 'access_token', value: accessToken!);
    await _storage.write(key: 'refresh_token', value: refreshToken!);
    await _storage.write(key: 'expires_at', value: expiresAt!.toString());
    notifyListeners();
  }

  Future<bool> saveCredentials(String clientId, String clientSecret) async {
    final bool credentialsChanged =
        (this.clientId != clientId || this.clientSecret != clientSecret);
    if (this.clientId != null && credentialsChanged) {
      await logout();
    }
    this.clientId = clientId == "" ? null : clientId;
    this.clientSecret = clientSecret == "" ? null : clientSecret;
    if (clientId != "") {
      await _storage.write(key: 'client_id', value: clientId);
    } else {
      await _storage.delete(key: 'client_id');
    }
    if (clientSecret != "") {
      await _storage.write(key: 'client_secret', value: clientSecret);
    } else {
      await _storage.delete(key: 'client_secret');
    }
    return credentialsChanged;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'expires_at');
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    notifyListeners();
  }

  Future<String> uploadStravaFile(XFile file, String sportType) async {
    if (_uploadMode == StravaUploadMode.webView) {
      final bridge = _webViewBridge;
      if (bridge == null) {
        throw Exception('Strava WebView bridge is not available');
      }
      return bridge.uploadStravaFile(file);
    }

    if (!isAuthenticated) throw Exception('Not authenticated');

    final refreshThreshold =
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
        1000;
    if (refreshThreshold > expiresAt!) {
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
    try {
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
    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }
}
