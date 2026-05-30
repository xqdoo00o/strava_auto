import 'dart:convert';
import 'dart:io';

import 'log_manager.dart';
import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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

  final http.Client _client;
  final bool isCn;

  GarminService({http.Client? client, this.isCn = false})
    : _client = client ?? http.Client();

  String? _token;
  String? _refreshToken;
  String? _diClientId;

  String get _domain => isCn ? 'garmin.cn' : 'garmin.com';
  String get _webProxyPrefix => isCn ? '/proxy/garmin-cn' : '/proxy/garmin';
  String get _ssoBaseUrl => 'https://sso.$_domain';
  String get _diTokenUrl => kIsWeb
      ? '$_webProxyPrefix/diauth/di-oauth2-service/oauth/token'
      : 'https://diauth.$_domain/di-oauth2-service/oauth/token';
  String get _connectApiBaseUrl =>
      kIsWeb ? '$_webProxyPrefix/connect' : 'https://connectapi.$_domain';
  String get _iosServiceUrl => 'https://mobile.integration.$_domain/gcm/ios';

  set token(String value) {
    _token = value;
  }

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get diClientId => _diClientId;
  bool get isLoggedIn => _token != null;

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
      final ticket = await _requestServiceTicket(email, password);
      final tokenData = await _exchangeServiceTicket(
        ticket,
        serviceUrl: _iosServiceUrl,
      );

      return _completeLoginWithTokenData(tokenData);
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
      final response = await _client
          .post(
            Uri.parse(_diTokenUrl),
            headers: _nativeHeaders({
              'Authorization': _buildBasicAuth(clientId),
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Cache-Control': 'no-cache',
            }),
            body: {
              'grant_type': 'refresh_token',
              'client_id': clientId,
              'refresh_token': refreshToken,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        throw Exception('Garmin token refresh rate limited');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Garmin token refresh failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = _decodeJsonMap(response.body);
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
    final response = await _client
        .get(Uri.parse(url), headers: authHeaders)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Garmin authentication failed or token expired');
    }
    if (response.statusCode == 429) {
      throw Exception('Garmin profile request rate limited');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP Error: ${response.statusCode} ${response.body}');
    }

    return _decodeJsonMap(response.body);
  }

  Future<String> _requestServiceTicket(String email, String password) async {
    final uri = Uri.parse('$_ssoBaseUrl/mobile/api/login').replace(
      queryParameters: {
        'clientId': _iosClientId,
        'locale': 'en-US',
        'service': _iosServiceUrl,
      },
    );

    final response = await _client
        .post(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) '
                'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Origin': _ssoBaseUrl,
          },
          body: jsonEncode({
            'username': email,
            'password': password,
            'rememberMe': true,
            'captchaToken': '',
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) {
      throw Exception('Garmin login rate limited, please try again later');
    }

    final data = _decodeJsonMap(response.body);
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
        throw Exception(
          'Garmin account requires MFA; MFA is not implemented yet',
        );
      default:
        final error = data['error'];
        if (error is Map && error['status-code'] == '429') {
          throw Exception('Garmin login rate limited, please try again later');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'HTTP Error: ${response.statusCode} ${response.body}',
          );
        }
        throw Exception('Garmin login failed: $data');
    }
  }

  Future<Map<String, dynamic>> _exchangeServiceTicket(
    String ticket, {
    required String serviceUrl,
  }) async {
    Map<String, dynamic>? lastError;

    for (final clientId in _diClientIds) {
      final response = await _client
          .post(
            Uri.parse(_diTokenUrl),
            headers: _nativeHeaders({
              'Authorization': _buildBasicAuth(clientId),
              'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Cache-Control': 'no-cache',
            }),
            body: {
              'client_id': clientId,
              'service_ticket': ticket,
              'grant_type': _diGrantType,
              'service_url': serviceUrl,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        throw Exception('Garmin token exchange rate limited');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastError = {
          'client_id': clientId,
          'statusCode': response.statusCode,
          'body': response.body,
        };
        continue;
      }

      final data = _decodeJsonMap(response.body);
      if (data['access_token'] is String) {
        data['client_id'] = clientId;
        return data;
      }

      lastError = {'client_id': clientId, 'body': data};
    }

    throw Exception('Garmin token exchange failed: $lastError');
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
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
      final uri = Uri.parse(
        '$_connectApiBaseUrl/activitylist-service/activities/search/activities',
      ).replace(queryParameters: queryParameters);

      final response = await _client
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401) {
        throw Exception('Garmin authentication failed or token expired');
      }
      if (response.statusCode == 429) {
        throw Exception('Garmin activities request rate limited');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP Error: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body);
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
    final uri = Uri.parse(
      '$_connectApiBaseUrl/download-service/files/activity/$activityId',
    );
    final response = await _client
        .get(uri, headers: {...authHeaders, 'Accept': '*/*'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Garmin authentication failed or token expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Garmin activity file not found: $activityId');
    }
    if (response.statusCode == 429) {
      throw Exception('Garmin activity file request rate limited');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP Error: ${response.statusCode} ${response.body}');
    }
    final fileName =
        response.headers['content-disposition']
            ?.split('filename=')
            .last
            .replaceAll('"', '') ??
        '$activityId.fit';
    return (
      bytes: response.bodyBytes,
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
