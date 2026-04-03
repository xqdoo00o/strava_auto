import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'coord_fixer.dart';
import 'package:cross_file/cross_file.dart';

class OneLapService {
  static const String _loginUrl = 'https://www.onelap.cn/api/login';
  static const String _activityListUrl = 'https://u.onelap.cn/analysis/list';
  static const String _otmUrl =
      'https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/';
  static const String _secretKey = 'fe9f8382418fcdeb136461cac6acae7b';

  String? _cookie;
  String? _token;

  bool get isLoggedIn => _cookie != null;

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
        // The API returns a JSON array or object? User example says: JSONObject loginData = data.getJSONObject(0);
        // But user provided Java snippet: `JSONObject loginData = data.getJSONObject(0);` implies `data` is an array?
        // Wait, user provided snippet: `String loginJson = HttpClientUtil.doPostJson(...)`
        // Then `JSONObject loginData = data.getJSONObject(0);` - this part is a bit ambiguous in user's text ("解析登录返回的数据").
        // Usually such APIs return {code: 0, msg: "success", data: [...]} or just [...]
        // I'll assume standard response wrapper or direct array based on user's "data.getJSONObject(0)".

        // Let's print response body for debugging if we could, but here I have to implement based on assumption.
        // Assuming response structure: { code: 0, data: [{ token: ..., refresh_token: ..., userinfo: { uid: ... } }] }
        // OR directly [{ token: ... }]

        // Safest approach: check type of `data`.

        dynamic responseData = data;
        if (data is Map && data.containsKey('data')) {
          responseData = data['data'];
        }

        if (responseData is List && responseData.isNotEmpty) {
          final loginData = responseData[0];
          final token = loginData['token'];
          final refreshToken = loginData['refresh_token'];
          final uid = loginData['userinfo']['uid'].toString();

          // Construct Cookie
          _cookie = "ouid=$uid; XSRF-TOKEN=$token; OTOKEN=$refreshToken";
          _token = token;
          return {'success': true, 'cookie': _cookie};
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

  Future<List<Map<String, dynamic>>> getActivities() async {
    if (_cookie == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse(_activityListUrl),
        headers: {'Cookie': _cookie!},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // User example: JSONArray myActivities = myActivitiesData.getJSONArray("data");
        if (data is Map && data.containsKey('data')) {
          final list = data['data'] as List;
          return list.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching activities: $e');
    }
  }

  Future<XFile> downloadFit(String url, String fileKey, String savePath) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // Magene new firmware fit coordinates are GCJ-02 system, need to fix coordinates
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
      // fallback to original file if fixed file not found, maybe the file is not in GCJ-02 system
      final response2 = await http.get(
        Uri.parse(_otmUrl + base64Encode(utf8.encode(fileKey))),
        headers: {'Authorization': _token!},
      );
      if (response2.statusCode == 200) {
        final bytes = await CoordFixer.processFitBytes(response2.bodyBytes);
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
}
