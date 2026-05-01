import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'coord_fixer.dart';
import 'package:cross_file/cross_file.dart';

class OneLapService {
  static const String _loginUrl = kIsWeb
      ? '/proxy/onelap/login'
      : 'https://www.onelap.cn/api/login';
  static const String _baseUrl = kIsWeb
      ? '/proxy/onelap/otm'
      : 'https://otm.onelap.cn';
  static const String _activityListUrl = '$_baseUrl/api/otm/ride_record/list';
  static const String _activityListDetailUrl =
      '$_baseUrl/api/otm/ride_record/analysis/';
  static const String _otmUrl =
      '$_baseUrl/api/otm/ride_record/analysis/fit_content/';
  static const String _secretKey = 'fe9f8382418fcdeb136461cac6acae7b';

  String? _token;
  set token(String value) {
    _token = value;
  }

  bool get isLoggedIn => _token != null;

  // Helper for MD5
  String _md5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<Map<String, dynamic>> login(String account, String password) async {
    final nonce = const Uuid().v4().replaceAll('-', '').substring(16);
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final passwordMd5 = _md5(password);

    // Sign: MD5(account=...&nonce=...&password=MD5(pwd)&timestamp=...&key=...)
    final signStr =
        "account=$account&nonce=$nonce&password=$passwordMd5&timestamp=$timestamp&key=$_secretKey";
    final sign = _md5(signStr);

    final headers = {
      'nonce': nonce,
      'timestamp': timestamp,
      'sign': sign,
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({'account': account, 'password': passwordMd5});

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        dynamic responseData = data;
        if (data is Map && data.containsKey('data')) {
          responseData = data['data'];
        }

        if (responseData is List && responseData.isNotEmpty) {
          final loginData = responseData[0];
          final token = loginData['token'];

          _token = token;
          return {'success': true, 'token': _token};
        } else {
          return {
            'success': false,
            'message': 'Invalid response format: $data',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getActivities(
    DateTime? lastSyncDate,
  ) async {
    if (_token == null) throw Exception('Not logged in');
    var lastFormattedDate = "";
    if (lastSyncDate != null) {
      lastFormattedDate = lastSyncDate.toIso8601String().split("T").first;
    }
    List<Map<String, dynamic>> activities = [];
    bool hasMore = true;
    int page = 1;
    while (hasMore) {
      final response = await http.post(
        Uri.parse(_activityListUrl),
        headers: {'Authorization': _token!, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "page": page,
          "limit": 20,
          if (lastFormattedDate.isNotEmpty) "start_date": lastFormattedDate,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final rawData = data['data'];
          if (rawData == null) break;
          final list = (rawData['list'] as List?) ?? [];
          activities.addAll(list.map((e) => e as Map<String, dynamic>));
          hasMore = rawData['pagination']['has_more'] ?? false;
          if (hasMore) page++;
        }
      } else {
        throw Exception('Failed to get activities: ${response.statusCode}');
      }
    }
    for (var activity in activities) {
      final response = await http.get(
        Uri.parse(_activityListDetailUrl + activity['id'].toString()),
        headers: {'Authorization': _token!},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final detail = data['data']["ridingRecord"];
          if (detail != null && detail['fileKey'] != null) {
            activity['fileKey'] = detail['fileKey'];
          }
        }
      }
    }
    return activities;
  }

  Future<XFile> downloadFit(String fileKey, String savePath) async {
    final response = await http.get(
      Uri.parse(_otmUrl + base64Encode(utf8.encode(fileKey))),
      headers: {'Authorization': _token!},
    );
    if (response.statusCode == 200) {
      final bytes = await CoordFixer.processFitBytes(response.bodyBytes);
      final XFile xfile;
      if (kIsWeb) {
        xfile = XFile.fromData(bytes, name: savePath);
      } else {
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        xfile = XFile(file.path);
      }
      return xfile;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  }
}
