import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:xml/xml.dart';
import "stub_logic.dart" if (dart.library.js_interop) "web_logic.dart";
import 'coord_fixer.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';

class KeepService {
  static final String _baseUrl = shouldUseWebProxy()
      ? '/proxy/keep'
      : 'https://api.gotokeep.com';
  static final String _loginUrl = '$_baseUrl/v1.1/users/login';
  static final String _activityIdsUrl =
      '$_baseUrl/pd/v3/stats/detail?dateUnit=all';
  static final String _activityDataUrl = '$_baseUrl/pd/v3/';
  static const double _alpha = 0.3;

  String? _token;
  set token(String value) {
    _token = value;
    _headers['Authorization'] = 'Bearer $_token';
  }

  final _timestampThresholdInDecisecond = 3600000;
  final _cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  final _key = base64Decode('NTZmZTU5OzgyZzpkODczYw==');
  final _iv = base64Decode('MjM0Njg5MjQzMjkyMDMwMA==');
  final Map<String, String> _headers = {
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
        headers: _headers,
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
          _headers['Authorization'] = 'Bearer $_token';
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
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final rawData = data['data'];
          if (rawData == null) break;
          final records = (rawData['records'] as List?) ?? [];
          for (var record in records) {
            final logs = (record['logs'] as List?) ?? [];
            for (var log in logs) {
              final stats = log['stats'] as Map<String, dynamic>;
              if (stats['isDoubtful'] == false && stats['startTime'] != null) {
                final startTime = stats['startTime'] as int;
                if (startTime < lastSyncTimeStamp) {
                  break outerLoop;
                }
                final name =
                    "${DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(startTime))}_${stats['name'] ?? ""}.tcx";
                result.add({'id': stats['id'].toString(), 'fileName': name});
              }
            }
          }
          lastDate = rawData['lastTimestamp'];
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

  Future<XFile> downloadSportFile(
    String id,
    String savePath,
    String sportType,
  ) async {
    final response = await http.get(
      Uri.parse('$_activityDataUrl${sportType}log/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('data')) {
        final sportData = data['data'] as Map<String, dynamic>;
        final outputBytes = parseRawDataToFile(sportData);
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
      _cipher.reset();
      _cipher.init(
        false,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(_key), _iv),
          null,
        ),
      );
      cipherBytes = _cipher.process(cipherBytes);
    }
    final decompressedBytes = GZipDecoder().decodeBytes(cipherBytes);
    return jsonDecode(utf8.decode(decompressedBytes));
  }

  List<int>? findNearestHr(
    List<dynamic> hrDataList,
    int targetTime,
    int startTime,
    int startIndex, {
    int threshold = 100,
  }) {
    Map<String, dynamic>? closestElement;
    if (targetTime > _timestampThresholdInDecisecond) {
      targetTime = targetTime - (startTime ~/ 100);
    }
    num minDifference = double.infinity;
    if (startIndex == 0) {
      for (var i = startIndex; i < hrDataList.length; i++) {
        final item = hrDataList[i];
        final timestamp = item['timestamp'] as num?;
        if (timestamp == null) continue;
        final difference = (timestamp - targetTime).abs();
        if (difference <= threshold && difference < minDifference) {
          closestElement = item;
          minDifference = difference;
          startIndex = i;
        }
      }
    } else {
      while (closestElement == null && startIndex < hrDataList.length) {
        final searchEndIndex = (startIndex + 5).clamp(0, hrDataList.length);
        for (var i = startIndex; i < searchEndIndex; i++) {
          final item = hrDataList[i];
          final timestamp = item['timestamp'] as num?;
          if (timestamp == null) continue;

          final difference = (timestamp - targetTime).abs();
          if (difference <= threshold && difference < minDifference) {
            closestElement = item;
            minDifference = difference;
            startIndex = i;
          }
        }
        if (closestElement == null) {
          startIndex = startIndex + 5;
        }
      }
    }

    if (closestElement != null) {
      final hr = closestElement['beatsPerMinute'];
      if (hr != null && hr > 0) {
        return [hr as int, startIndex];
      }
    }
    return null;
  }

  Uint8List parseRawDataToFile(Map<String, dynamic> sportData) {
    final startTime = sportData['startTime'];
    List<dynamic> decodedHrData = [];
    if (sportData['heartRate'] != null) {
      final heartRateData = sportData['heartRate']['heartRates'];
      if (heartRateData != null) {
        decodedHrData = decodeRunmapData(heartRateData);
      }
    }
    if (sportData['geoPoints'] != null) {
      final geoPoints = sportData['geoPoints'];
      final sportPointsData = decodeRunmapData(geoPoints, isGeo: true);
      for (var p in sportPointsData) {
        final transformed = CoordinateConverter.gcj2WGSExact(
          p['latitude'],
          p['longitude'],
        );
        p['latitude'] = transformed[0];
        p['longitude'] = transformed[1];
      }
      var hrStartIndex = 0;
      for (var p in sportPointsData) {
        if (!p.containsKey('timestamp')) {
          p['timestamp'] = p.containsKey('unixTimestamp')
              ? p['unixTimestamp']
              : 0;
        }
        final targetTime = int.parse(p['timestamp'].toString());
        final hrMatch = findNearestHr(
          decodedHrData,
          targetTime,
          startTime,
          hrStartIndex,
        );
        if (hrMatch == null) continue;
        hrStartIndex = hrMatch[1];
        p['hr'] = hrMatch[0];
      }
      // Strava running: 跑步 biking: 骑行
      return parsePointsToTcx(
        sportData,
        sportPointsData,
        sportData["dataType"].toLowerCase().contains("running")
            ? "running"
            : "biking",
      );
    }
    throw Exception('No geoPoints data available');
  }

  Uint8List parsePointsToTcx(
    Map<String, dynamic> sportData,
    List<dynamic> sportPointsData,
    String sportType,
  ) {
    final fitStartTime = DateTime.fromMillisecondsSinceEpoch(
      sportData['startTime'],
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
                      nest: sportData['duration'].toString(),
                    );
                    builder.element(
                      'DistanceMeters',
                      nest: sportData['distance'].toString(),
                    );
                    builder.element(
                      'Calories',
                      nest: sportData['calorie'].toString(),
                    );
                    builder.element(
                      'Track',
                      nest: () {
                        double? smoothCadence;
                        int? initStep;
                        int cadenceWindowStartIndex = 0;
                        for (int i = 0; i < sportPointsData.length; i++) {
                          final point = sportPointsData[i];
                          final timeStamp = DateTime.fromMillisecondsSinceEpoch(
                            sportData['startTime'] + (point['timestamp'] * 100),
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
                                  initStep ??= step;
                                  if ((step - initStep) > 5) {
                                    late double rawCadence;
                                    if (duration <= 10) {
                                      rawCadence = (step / (duration / 60) / 2);
                                    } else {
                                      final prevTime = duration - 10;
                                      num prevStep = 0;
                                      num prevDuration = 0;
                                      while (cadenceWindowStartIndex < i) {
                                        final nextDuration =
                                            sportPointsData[cadenceWindowStartIndex +
                                                1]['currentTotalDuration'];
                                        if (nextDuration == null ||
                                            nextDuration >= prevTime) {
                                          break;
                                        }
                                        cadenceWindowStartIndex++;
                                      }
                                      final prevPoint =
                                          sportPointsData[cadenceWindowStartIndex];
                                      prevDuration =
                                          prevPoint['currentTotalDuration'];
                                      prevStep =
                                          prevPoint['currentTotalSteps'] ?? 0;
                                      rawCadence =
                                          ((step - prevStep) /
                                          ((duration - prevDuration) / 60) /
                                          2);
                                    }
                                    if (smoothCadence == null) {
                                      smoothCadence = rawCadence;
                                    } else {
                                      smoothCadence =
                                          _alpha * rawCadence +
                                          (1 - _alpha) * smoothCadence!;
                                    }
                                    builder.element(
                                      'Cadence',
                                      nest: smoothCadence!.round().toString(),
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
