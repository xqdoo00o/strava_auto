import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:xml/xml.dart';
import 'coord_fixer.dart';
import 'package:cross_file/cross_file.dart';

class KeepService {
  static const String _loginUrl = 'https://api.gotokeep.com/v1.1/users/login';
  static const String _activityIdsUrl =
      "https://api.gotokeep.com/pd/v3/stats/detail?dateUnit=all";
  static const String _activityDataUrl = "https://api.gotokeep.com/pd/v3/";

  String? _token;
  int timestampThresholdInDecisecond = 3600000;
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  final key = base64Decode('NTZmZTU5OzgyZzpkODczYw==');
  final iv = base64Decode('MjM0Njg5MjQzMjkyMDMwMA==');
  Map<String, String> headers = {
    "User-Agent":
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0",
    "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
  };
  bool get isLoggedIn => _token != null;

  Future<Map<String, dynamic>> login(String account, String password) async {
    final body = {'mobile': account, 'password': password};

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
        if (responseData is Map && responseData.isNotEmpty) {
          _token = responseData['token'];
          headers['Authorization'] = 'Bearer $_token';
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
    String sportType,
    DateTime? lastSyncDate,
  ) async {
    if (_token == null) throw Exception('Not logged in');
    final lastSyncTimeStamp = lastSyncDate != null
        ? lastSyncDate.millisecondsSinceEpoch
        : 0;
    int lastDate = 0;
    List<Map<String, dynamic>> result = [];
    outerLoop:
    while (true) {
      final response = await http.get(
        Uri.parse('$_activityIdsUrl&type=$sportType&last_date=$lastDate'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final records = data['data']['records'] as List;
          for (var record in records) {
            final logs = record['logs'] as List;
            for (var log in logs) {
              final stats = log['stats'] as Map<String, dynamic>;
              if (stats['isDoubtful'] == false && stats['startTime'] != null) {
                final startTime = stats['startTime'] as int;
                if (startTime < lastSyncTimeStamp) {
                  break outerLoop;
                }
                final name =
                    "${DateTime.fromMillisecondsSinceEpoch(startTime).toIso8601String()}_${stats['name'] ?? ""}.tcx";
                result.add({'id': stats['id'].toString(), 'fileName': name});
              }
            }
          }
          lastDate = data['data']['lastTimestamp'];
          await Future.delayed(Duration(seconds: 1)); // spider rule
          if (lastDate == 0) break;
        } else {
          throw Exception('Invalid response format: $data');
        }
      } else {
        throw Exception('Failed to load activities: ${response.statusCode}');
      }
    }
    return result;
  }

  Future<XFile> getActivityData(
    String id,
    String savePath,
    String sportType,
  ) async {
    final response = await http.get(
      Uri.parse('$_activityDataUrl${sportType}log/$id'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('data')) {
        final runData = data['data'] as Map<String, dynamic>;
        final outputBytes = parseRawDataToFile(runData);
        final XFile xfile;
        if (kIsWeb) {
          xfile = XFile.fromData(outputBytes, name: savePath);
        } else {
          final file = File(savePath);
          await file.writeAsBytes(outputBytes);
          xfile = XFile(file.path);
        }
        return xfile;
      }
    }
    throw Exception('Failed to load activity data');
  }

  List<dynamic> decodeRunmapData(String text, {bool isGeo = false}) {
    var cipherBytes = base64Decode(text);
    if (isGeo) {
      cipher.reset();
      cipher.init(
        false,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
      cipherBytes = cipher.process(cipherBytes);
    }
    final decompressedBytes = GZipDecoder().decodeBytes(cipherBytes);
    final runPointsData = jsonDecode(utf8.decode(decompressedBytes));
    return runPointsData;
  }

  int? findNearestHr(
    List<dynamic> hrDataList,
    int targetTime,
    int startTime, {
    int threshold = 100,
  }) {
    Map<String, dynamic>? closestElement;
    num minDifference = double.infinity;
    if (targetTime > timestampThresholdInDecisecond) {
      targetTime = targetTime - (startTime ~/ 100);
    }
    for (var item in hrDataList) {
      final timestamp = item['timestamp'] as num?;
      if (timestamp == null) continue;
      final difference = (timestamp - targetTime).abs();
      if (difference <= threshold && difference < minDifference) {
        closestElement = item;
        minDifference = difference;
      }
    }
    if (closestElement != null) {
      final hr = closestElement['beatsPerMinute'];
      if (hr != null && hr > 0) {
        return hr;
      }
    }
    return null;
  }

  Uint8List parseRawDataToFile(Map<String, dynamic> runData) {
    final startTime = runData['startTime'];
    double? avgHeartRate;
    List<dynamic> decodedHrData = [];
    if (runData['heartRate'] != null) {
      avgHeartRate = runData['heartRate']['averageHeartRate'];
      final heartRateData = runData['heartRate']['heartRates'];
      if (heartRateData != null) {
        decodedHrData = decodeRunmapData(heartRateData);
      }
      if (avgHeartRate != null && avgHeartRate < 0) {
        avgHeartRate = null;
      }
    }
    if (runData['geoPoints'] != null) {
      final geoPoints = runData['geoPoints'];
      final runPointsData = decodeRunmapData(geoPoints, isGeo: true);
      for (var p in runPointsData) {
        final transformed = CoordinateConverter.gcj2WGSExact(
          p['latitude'],
          p['longitude'],
        );
        p['latitude'] = transformed[0];
        p['longitude'] = transformed[1];
      }
      for (var p in runPointsData) {
        if (!p.containsKey('timestamp')) {
          p['timestamp'] = p.containsKey('unixTimestamp')
              ? p['unixTimestamp']
              : 0;
        }
        final pHr = findNearestHr(
          decodedHrData,
          int.parse(p['timestamp'].toString()),
          startTime,
        );
        if (pHr != null) {
          p['hr'] = pHr;
        }
      }
      // Strava running: 跑步 biking: 骑行
      return parsePointsToTcx(
        runData,
        runPointsData,
        runData["dataType"].toLowerCase().contains("running")
            ? "running"
            : "biking",
      );
    }
    throw Exception('No geoPoints data available');
  }

  Uint8List parsePointsToTcx(
    Map<String, dynamic> runData,
    List<dynamic> runPointsData,
    String sportType,
  ) {
    final fitStartTime = DateTime.fromMillisecondsSinceEpoch(
      runData['startTime'],
      isUtc: true,
    ).toIso8601String();
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'TrainingCenterDatabase',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2',
        );
        builder.attribute(
          'xmlns:ns5',
          'http://www.garmin.com/xmlschemas/ActivityGoals/v1',
        );
        builder.attribute(
          'xmlns:ns3',
          'http://www.garmin.com/xmlschemas/ActivityExtension/v2',
        );
        builder.attribute(
          'xmlns:ns2',
          'http://www.garmin.com/xmlschemas/UserProfile/v2',
        );
        builder.attribute(
          'xmlns:xsi',
          'http://www.w3.org/2001/XMLSchema-instance',
        );
        builder.attribute(
          'xmlns:ns4',
          'http://www.garmin.com/xmlschemas/ProfileExtension/v1',
        );
        builder.attribute(
          'xsi:schemaLocation',
          'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd',
        );
        builder.element(
          'Activities',
          nest: () {
            builder.element(
              'Activity',
              attributes: {'Sport': sportType},
              nest: () {
                builder.element('Id', nest: fitStartTime);
                builder.element(
                  'Lap',
                  attributes: {'StartTime': fitStartTime},
                  nest: () {
                    builder.element(
                      'TotalTimeSeconds',
                      nest: runData['duration'].toString(),
                    );
                    builder.element(
                      'DistanceMeters',
                      nest: runData['distance'].toString(),
                    );
                    builder.element(
                      'Calories',
                      nest: runData['calorie'].toString(),
                    );
                    builder.element(
                      'Track',
                      nest: () {
                        for (int i = 0; i < runPointsData.length; i++) {
                          final point = runPointsData[i];
                          final timeStamp = DateTime.fromMillisecondsSinceEpoch(
                            runData['startTime'] + (point['timestamp'] * 100),
                            isUtc: true,
                          ).toIso8601String();
                          builder.element(
                            'Trackpoint',
                            nest: () {
                              builder.element('Time', nest: timeStamp);
                              if (point.containsKey('latitude') &&
                                  point.containsKey('longitude')) {
                                builder.element(
                                  'Position',
                                  nest: () {
                                    builder.element(
                                      'LatitudeDegrees',
                                      nest: point['latitude'].toString(),
                                    );
                                    builder.element(
                                      'LongitudeDegrees',
                                      nest: point['longitude'].toString(),
                                    );
                                  },
                                );
                                if (point.containsKey('altitude') &&
                                    point['altitude'] != 0) {
                                  builder.element(
                                    'AltitudeMeters',
                                    nest: point['altitude'].toString(),
                                  );
                                }
                                if (point.containsKey('currentTotalDistance') &&
                                    point['currentTotalDistance'] != 0) {
                                  builder.element(
                                    'DistanceMeters',
                                    nest: point['currentTotalDistance']
                                        .toString(),
                                  );
                                }
                              }
                              if (point.containsKey('hr')) {
                                builder.element(
                                  'HeartRateBpm',
                                  nest: () {
                                    builder.element(
                                      'Value',
                                      nest: point['hr'].toString(),
                                    );
                                  },
                                );
                              }
                              if (point.containsKey('currentTotalSteps') &&
                                  point.containsKey("currentTotalDuration")) {
                                final step = point['currentTotalSteps'];
                                final duration = point['currentTotalDuration'];
                                if (step != null &&
                                    step > 0 &&
                                    duration != null &&
                                    duration > 0) {
                                  if (duration <= 10) {
                                    final cadence = (step / (duration / 60) / 2)
                                        .round();
                                    builder.element(
                                      'Cadence',
                                      nest: cadence.toString(),
                                    );
                                  } else {
                                    final prevTime = duration - 4;
                                    num prevStep = 0;
                                    num prevDuration = 0;
                                    for (int j = i - 1; j >= 0; j--) {
                                      final nowDuration =
                                          runPointsData[j]['currentTotalDuration'];
                                      if (nowDuration != null &&
                                          nowDuration < prevTime) {
                                        prevDuration = nowDuration;
                                        prevStep =
                                            runPointsData[j]['currentTotalSteps'] ??
                                            0;
                                        break;
                                      }
                                    }
                                    final cadence =
                                        ((step - prevStep) /
                                                ((duration - prevDuration) /
                                                    60) /
                                                2)
                                            .round();
                                    builder.element(
                                      'Cadence',
                                      nest: cadence.toString(),
                                    );
                                  }
                                }
                              }
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
    return utf8.encode(builder.buildDocument().toXmlString());
  }
}
