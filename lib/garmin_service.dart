import 'dart:convert';
import 'dart:io';

import 'log_manager.dart';
import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import "stub_logic.dart" if (dart.library.js_interop) "web_logic.dart";

class GarminMfaRequiredException implements Exception {
  const GarminMfaRequiredException();

  @override
  String toString() => 'Garmin account requires MFA';
}

class GarminService {
  static const String _iosClientId = 'GCM_IOS_DARK';
  static const String _diGrantType =
      'https://connectapi.garmin.com/di-oauth2-service/oauth/grant/service_ticket';
  static const List<String> _diClientIds = [
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI',
    'GARMIN_CONNECT_MOBILE_IOS_DI',
  ];
  // static const List<String> activityTypes = [
  //   'cycling',
  //   'running',
  //   'swimming',
  //   'multi_sport',
  //   'fitness_equipment',
  //   'hiking',
  //   'walking',
  //   'other',
  // ];

  final Dio _dio;
  final bool isCn;

  GarminService({Dio? dio, this.isCn = false})
    : _dio = dio ?? Dio(BaseOptions(validateStatus: (_) => true)) {
    _dio.options.validateStatus = (_) => true;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cookieHeader = _cookieHeaderFromJar();
          if (cookieHeader != null && !options.headers.containsKey('Cookie')) {
            options.headers['Cookie'] = cookieHeader;
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _mergeCookiesFromHeaders(response.headers);
          handler.next(response);
        },
        onError: (error, handler) {
          final response = error.response;
          if (response != null) {
            _mergeCookiesFromHeaders(response.headers);
          }
          handler.next(error);
        },
      ),
    );
  }

  String? _token;
  String? _refreshToken;
  String? _diClientId;
  final Map<String, String> _cookies = {};
  bool _mfaRequired = false;
  String? _mfaMethod;
  Map<String, String>? _mfaLoginParams;
  Map<String, String>? _mfaPostHeaders;

  String get _domain => isCn ? 'garmin.cn' : 'garmin.com';
  String get _webProxyPrefix => isCn ? '/proxy/garmin-cn' : '/proxy/garmin';
  String get _ssoBaseUrl => 'https://sso.$_domain';
  String get _diTokenUrl => shouldUseWebProxy()
      ? '$_webProxyPrefix/diauth/di-oauth2-service/oauth/token'
      : 'https://diauth.$_domain/di-oauth2-service/oauth/token';
  String get _connectApiBaseUrl => shouldUseWebProxy()
      ? '$_webProxyPrefix/connect'
      : 'https://connectapi.$_domain';
  String get _iosServiceUrl => 'https://mobile.integration.$_domain/gcm/ios';

  set token(String value) {
    _token = value;
  }

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get diClientId => _diClientId;
  bool get isLoggedIn => _token != null;
  bool get mfaRequired => _mfaRequired;
  String? get mfaMethod => _mfaMethod;

  Map<String, String> get authHeaders {
    if (_token == null) throw Exception('Not logged in');
    return {
      ..._nativeHeaders(),
      'Authorization': 'Bearer $_token',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      _clearMfaContext();
      _cookies.clear();
      final ticket = await _requestServiceTicket(email, password);
      final tokenData = await _exchangeServiceTicket(
        ticket,
        serviceUrl: _iosServiceUrl,
      );

      return _completeLoginWithTokenData(tokenData);
    } on GarminMfaRequiredException catch (e) {
      return {'success': false, 'mfaRequired': true, 'message': e.toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeMfaLogin(String mfaCode) async {
    try {
      final ticket = await _verifyMfaCode(mfaCode);
      final tokenData = await _exchangeServiceTicket(
        ticket,
        serviceUrl: _iosServiceUrl,
      );
      final result = _completeLoginWithTokenData(tokenData);
      if (result['success'] == true) {
        _clearMfaContext();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginWithServiceTicket(
    String ticket, {
    required String serviceUrl,
  }) async {
    try {
      final tokenData = await _exchangeServiceTicket(
        ticket,
        serviceUrl: serviceUrl,
      );
      return _completeLoginWithTokenData(tokenData);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Map<String, dynamic> _completeLoginWithTokenData(
    Map<String, dynamic> tokenData,
  ) {
    _token = tokenData['access_token'] as String?;
    _refreshToken = tokenData['refresh_token'] as String?;
    final refreshTokenExp = tokenData['refresh_token_expires_in'] != null
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (tokenData['refresh_token_expires_in'] as int)
        : 0;
    _diClientId =
        _extractClientIdFromJwt(_token) ?? tokenData['client_id'] as String?;

    if (_token == null || _token!.isEmpty) {
      return {
        'success': false,
        'message': 'Invalid token response: $tokenData',
      };
    }

    return {
      'success': true,
      'token': _token,
      'refreshToken': _refreshToken,
      'refreshExpire': refreshTokenExp,
      'clientId': _diClientId,
    };
  }

  Future<Map<String, dynamic>> refresh(
    String refreshToken,
    String clientId,
  ) async {
    try {
      final response = await _dio.post(
        _diTokenUrl,
        options: Options(
          headers: _nativeHeaders({
            'Authorization': _buildBasicAuth(clientId),
            'Accept': 'application/json',
            'Content-Type': Headers.formUrlEncodedContentType,
            'Cache-Control': 'no-cache',
          }),
        ),
        data: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 429) {
        throw Exception('Garmin token refresh rate limited');
      }
      if (!_isSuccessful(response.statusCode)) {
        throw Exception(
          'Garmin token refresh failed: ${response.statusCode} ${response.data}',
        );
      }

      final data = _decodeJsonMap(response.data);
      return _completeLoginWithTokenData(data);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String> getCurrentUserProfileBase() async {
    final userProfileBase = await _getJsonMap(
      '$_connectApiBaseUrl/userprofile-service/userprofile/userProfileBase',
    );
    // final firstName = userProfileBase['firstName']?.toString();
    final email = userProfileBase['emailAddress']?.toString();
    final phoneNumber = userProfileBase['phoneNumber']?.toString();

    return (email != null && email.isNotEmpty)
        ? email
        : (phoneNumber != null && phoneNumber.isNotEmpty ? phoneNumber : '');
  }

  Future<Map<String, dynamic>> _getJsonMap(String url) async {
    final response = await _dio.get(
      url,
      options: Options(headers: authHeaders),
    );
    if (response.statusCode == 401) {
      throw Exception('Garmin authentication failed or token expired');
    }
    if (response.statusCode == 429) {
      throw Exception('Garmin profile request rate limited');
    }
    if (!_isSuccessful(response.statusCode)) {
      throw Exception('HTTP Error: ${response.statusCode} ${response.data}');
    }

    return _decodeJsonMap(response.data);
  }

  Future<String> _requestServiceTicket(String email, String password) async {
    final loginParams = {
      'clientId': _iosClientId,
      'locale': 'en-US',
      'service': _iosServiceUrl,
    };
    final loginHeaders = {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': Headers.jsonContentType,
      'Origin': _ssoBaseUrl,
    };

    final response = await _dio.post(
      '$_ssoBaseUrl/mobile/api/login',
      queryParameters: loginParams,
      options: Options(headers: loginHeaders),
      data: {
        'username': email,
        'password': password,
        'rememberMe': true,
        'captchaToken': '',
      },
    );

    if (response.statusCode == 429) {
      throw Exception('Garmin login rate limited, please try again later');
    }

    final data = _decodeJsonMap(response.data);
    final responseStatus = data['responseStatus'];
    final responseType = responseStatus is Map
        ? responseStatus['type'] as String?
        : null;

    switch (responseType) {
      case 'SUCCESSFUL':
        final ticket = data['serviceTicketId'] as String?;
        if (ticket == null || ticket.isEmpty) {
          throw Exception('Garmin login succeeded but no service ticket found');
        }
        return ticket;
      case 'INVALID_USERNAME_PASSWORD':
        throw Exception('Invalid Garmin email or password');
      case 'MFA_REQUIRED':
        _storeMfaContext(
          data: data,
          loginParams: loginParams,
          postHeaders: loginHeaders,
        );
        throw const GarminMfaRequiredException();
      default:
        final error = data['error'];
        if (error is Map && error['status-code'] == '429') {
          throw Exception('Garmin login rate limited, please try again later');
        }
        if (!_isSuccessful(response.statusCode)) {
          throw Exception(
            'HTTP Error: ${response.statusCode} ${response.data}',
          );
        }
        throw Exception('Garmin login failed: $data');
    }
  }

  Future<String> _verifyMfaCode(String mfaCode) async {
    if (!_mfaRequired || _mfaLoginParams == null || _mfaPostHeaders == null) {
      throw Exception('No Garmin MFA challenge is pending');
    }

    final mfaJson = {
      'mfaMethod': _mfaMethod ?? 'email',
      'mfaVerificationCode': mfaCode,
      'rememberMyBrowser': true,
      'reconsentList': [],
      'mfaSetup': false,
    };

    final endpoint = '$_ssoBaseUrl/mobile/api/mfa/verifyCode';
    final response = await _dio.post(
      endpoint,
      queryParameters: _mfaLoginParams,
      options: Options(headers: _mfaPostHeaders),
      data: mfaJson,
    );

    if (response.statusCode == 429) {
      throw Exception('Garmin MFA verification rate limited');
    }

    final data = _decodeJsonMap(response.data);
    final error = data['error'];
    if (error is Map && error['status-code'] == '429') {
      throw Exception('Garmin MFA verification rate limited');
    }

    final responseStatus = data['responseStatus'];
    final responseType = responseStatus is Map
        ? responseStatus['type'] as String?
        : null;
    if (responseType == 'SUCCESSFUL') {
      final ticket = data['serviceTicketId'] as String?;
      if (ticket == null || ticket.isEmpty) {
        throw Exception('Garmin MFA succeeded but no service ticket found');
      }
      return ticket;
    }

    throw Exception('Garmin MFA verification failed: $data');
  }

  void _storeMfaContext({
    required Map<String, dynamic> data,
    required Map<String, String> loginParams,
    required Map<String, String> postHeaders,
  }) {
    final customerMfaInfo = data['customerMfaInfo'];
    _mfaMethod = customerMfaInfo is Map
        ? customerMfaInfo['mfaLastMethodUsed']?.toString()
        : null;
    _mfaLoginParams = Map<String, String>.from(loginParams);
    _mfaPostHeaders = Map<String, String>.from(postHeaders);
    _mfaRequired = true;
  }

  void _clearMfaContext() {
    _mfaRequired = false;
    _mfaMethod = null;
    _mfaLoginParams = null;
    _mfaPostHeaders = null;
  }

  void _mergeCookiesFromHeaders(Headers headers) {
    final setCookieHeaders = headers.map.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .expand((entry) => entry.value);
    for (final setCookieHeader in setCookieHeaders) {
      for (final cookie in _splitSetCookieHeader(setCookieHeader)) {
        final cookiePair = cookie.split(';').first.trim();
        final separatorIndex = cookiePair.indexOf('=');
        if (separatorIndex <= 0) continue;
        final name = cookiePair.substring(0, separatorIndex);
        final value = cookiePair.substring(separatorIndex + 1);
        if (value.isEmpty) {
          _cookies.remove(name);
        } else {
          _cookies[name] = value;
        }
      }
    }
  }

  String? _cookieHeaderFromJar() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  List<String> _splitSetCookieHeader(String setCookieHeader) {
    return setCookieHeader.split(RegExp(r", (?=[A-Za-z0-9_!#$%&'*+.^`|~-]+=)"));
  }

  bool _isSuccessful(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  Future<Map<String, dynamic>> _exchangeServiceTicket(
    String ticket, {
    required String serviceUrl,
  }) async {
    Map<String, dynamic>? lastError;

    for (final clientId in _diClientIds) {
      final response = await _dio.post(
        _diTokenUrl,
        options: Options(
          headers: _nativeHeaders({
            'Authorization': _buildBasicAuth(clientId),
            'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
            'Content-Type': Headers.formUrlEncodedContentType,
            'Cache-Control': 'no-cache',
          }),
        ),
        data: {
          'client_id': clientId,
          'service_ticket': ticket,
          'grant_type': _diGrantType,
          'service_url': serviceUrl,
        },
      );

      if (response.statusCode == 429) {
        throw Exception('Garmin token exchange rate limited');
      }

      if (!_isSuccessful(response.statusCode)) {
        lastError = {
          'client_id': clientId,
          'statusCode': response.statusCode,
          'body': response.data,
        };
        continue;
      }

      final data = _decodeJsonMap(response.data);
      if (data['access_token'] is String) {
        data['client_id'] = clientId;
        return data;
      }

      lastError = {'client_id': clientId, 'body': data};
    }

    throw Exception('Garmin token exchange failed: $lastError');
  }

  Map<String, dynamic> _decodeJsonMap(dynamic body) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid JSON response: $body');
  }

  String _buildBasicAuth(String clientId) {
    return 'Basic ${base64Encode(utf8.encode('$clientId:'))}';
  }

  Map<String, String> _nativeHeaders([Map<String, String>? extra]) {
    return {
      'User-Agent': 'GCM-Android-5.23',
      'X-Garmin-User-Agent':
          'com.garmin.android.apps.connectmobile/5.23; ; '
          'Google/sdk_gphone64_arm64/google; Android/33; Dalvik/2.1.0',
      'X-Garmin-Paired-App-Version': '10861',
      'X-Garmin-Client-Platform': 'Android',
      'X-App-Ver': '10861',
      'X-Lang': 'en',
      'X-GCExperience': 'GC5',
      'Accept-Language': 'en-US,en;q=0.9',
      ...?extra,
    };
  }

  String? _extractClientIdFromJwt(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map && payload['client_id'] != null) {
        return payload['client_id'].toString();
      }
    } catch (e) {
      LogManager().addLog(
        'Failed to extract client_id from JWT, error: $e',
        isError: true,
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getActivities(
    String sportType,
    DateTime? lastSyncDate,
  ) async {
    int start = 0;
    final List<Map<String, dynamic>> allActivities = [];
    final queryParameters = {
      'start': start.toString(),
      'limit': '20',
      'activityType': sportType,
      if (lastSyncDate != null)
        'startDate': lastSyncDate.toIso8601String().split('T').first,
    };
    while (true) {
      final response = await _dio.get(
        '$_connectApiBaseUrl/activitylist-service/activities/search/activities',
        queryParameters: queryParameters,
        options: Options(headers: authHeaders),
      );
      if (response.statusCode == 401) {
        throw Exception('Garmin authentication failed or token expired');
      }
      if (response.statusCode == 429) {
        throw Exception('Garmin activities request rate limited');
      }
      if (!_isSuccessful(response.statusCode)) {
        throw Exception('HTTP Error: ${response.statusCode} ${response.data}');
      }

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (decoded == null || decoded is! List) break;
      allActivities.addAll(
        decoded.map((e) => {'id': e['activityId'].toString()}),
      );
      if (decoded.length < 20) break;
      start += 20;
      queryParameters['start'] = start.toString();
    }
    return allActivities;
  }

  Future<({Uint8List bytes, String extension})> downloadActivityFile(
    String activityId,
  ) async {
    final response = await _dio.get<List<int>>(
      '$_connectApiBaseUrl/download-service/files/activity/$activityId',
      options: Options(
        headers: {...authHeaders, 'Accept': '*/*'},
        responseType: ResponseType.bytes,
      ),
    );

    if (response.statusCode == 401) {
      throw Exception('Garmin authentication failed or token expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Garmin activity file not found: $activityId');
    }
    if (response.statusCode == 429) {
      throw Exception('Garmin activity file request rate limited');
    }
    if (!_isSuccessful(response.statusCode)) {
      throw Exception('HTTP Error: ${response.statusCode} ${response.data}');
    }
    final fileName =
        response.headers
            .value('content-disposition')
            ?.split('filename=')
            .last
            .replaceAll('"', '') ??
        '$activityId.fit';
    return (
      bytes: Uint8List.fromList(response.data ?? const []),
      extension: fileName.split('.').last.toLowerCase(),
    );
  }

  Future<XFile> downloadSportFile(String activityId, String savePath) async {
    final downloadFile = await downloadActivityFile(activityId);
    final activityFile = downloadFile.extension == 'zip'
        ? _extractActivityFile(downloadFile.bytes)
        : downloadFile;
    final outputName = '${activityId.trim()}.${activityFile.extension}';
    savePath = p.join(savePath, outputName);
    final XFile xfile;
    if (kIsWeb) {
      xfile = XFile.fromData(activityFile.bytes, name: savePath);
    } else {
      final file = File(savePath);
      await file.writeAsBytes(activityFile.bytes);
      xfile = XFile(file.path);
    }
    return xfile;
  }

  ({Uint8List bytes, String extension}) _extractActivityFile(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final activityFile = archive.files.where((file) => file.isFile).firstOrNull;

    if (activityFile == null) {
      throw Exception('Downloaded zip does not contain a file');
    }

    return (
      bytes: Uint8List.fromList(activityFile.content as List<int>),
      extension: activityFile.name.split('.').last.toLowerCase(),
    );
  }
}
