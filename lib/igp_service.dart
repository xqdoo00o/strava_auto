import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cross_file/cross_file.dart';
// import 'coord_fixer.dart';

class IGPService {
  static const String _baseUrl = 'https://prod.zh.igpsport.com/service/';
  static const String _loginUrl = '${_baseUrl}auth/account/login';
  static const String _activityBaseUrl =
      '${_baseUrl}web-gateway/web-analyze/activity/';
  static const String _activityListUrl = '${_activityBaseUrl}queryMyActivity';
  static const String _downloadUrl = '${_activityBaseUrl}getDownloadUrl/';

  String? _token;
  set token(String value) {
    _token = value;
  }

  bool get isLoggedIn => _token != null;

  Future<Map<String, dynamic>> login(String account, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appId': "igpsport-web",
          "username": account,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        dynamic responseData = data;
        if (data is Map && data.containsKey('data')) {
          responseData = data['data'];
        }
        if (responseData is Map && responseData['access_token'] != null) {
          final token = responseData['access_token'];

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
    Map<String, dynamic> queryParameters = {
      'pageNo': '1',
      'pageSize': '10',
      // reqType 1 bike 2 run
      'reqType': '1',
      'sort': '1',
      'sortType': '1',
    };
    if (lastFormattedDate.isNotEmpty) {
      queryParameters['beginTime'] = lastFormattedDate;
    }
    while (hasMore) {
      queryParameters["pageNo"] = page.toString();
      final response = await http.get(
        Uri.parse(_activityListUrl).replace(queryParameters: queryParameters),
        headers: {'Authorization': "Bearer ${_token!}"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final rawData = data['data'];
          if (rawData == null) break;
          final list = (rawData['rows'] as List?) ?? [];
          activities.addAll(list.map((e) => e as Map<String, dynamic>));
          hasMore = rawData['totalPage'] > rawData['pageNo'];
          if (hasMore) page++;
        }
      } else {
        throw Exception('Failed to get activities: ${response.statusCode}');
      }
    }
    for (var activity in activities) {
      final response = await http.get(
        Uri.parse(_downloadUrl + activity['rideId'].toString()),
        headers: {'Authorization': "Bearer ${_token!}"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final durl = (data['data'] as String?) ?? '';
          if (durl.isNotEmpty) {
            activity['downloadUrl'] = durl;
            if (activity['title'] != null) {
              activity['fileName'] = activity['title'].isNotEmpty
                  ? '${activity['startTime']}${activity['title']}.fit'
                  : durl.split("/").last;
            }
          }
        }
      }
    }
    return activities;
  }

  Future<XFile> downloadFit(String url, String savePath) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // For future fit coord fix
      // final bytes = await CoordFixer.processFitBytes(response.bodyBytes);
      final XFile xfile;
      if (kIsWeb) {
        xfile = XFile.fromData(response.bodyBytes, name: savePath);
      } else {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        xfile = XFile(file.path);
      }
      return xfile;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  }
}
