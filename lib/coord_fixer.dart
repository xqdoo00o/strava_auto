import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fit_tool/fit_tool.dart';
import 'package:xml/xml.dart';
import 'package:cross_file/cross_file.dart';

extension GpsFormatter on double {
  String toGpsString() {
    return toStringAsFixed(10).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class CoordinateConverter {
  static const double earthR = 6378137.0;
  static const double ee = 0.00669342162296594323;

  /// 判断是否在中国境外
  static bool outOfChina(double lat, double lng) {
    if (lng < 72.004 || lng > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  /// 转换偏移量辅助函数
  static List<double> _transform(double x, double y) {
    double xy = x * y;
    double absX = math.sqrt(x.abs());
    double xPi = x * math.pi;
    double yPi = y * math.pi;
    double d = 20.0 * math.sin(6.0 * xPi) + 20.0 * math.sin(2.0 * xPi);

    double lat = d;
    double lng = d;

    lat += 20.0 * math.sin(yPi) + 40.0 * math.sin(yPi / 3.0);
    lng += 20.0 * math.sin(xPi) + 40.0 * math.sin(xPi / 3.0);

    lat += 160.0 * math.sin(yPi / 12.0) + 320 * math.sin(yPi / 30.0);
    lng += 150.0 * math.sin(xPi / 12.0) + 300.0 * math.sin(xPi / 30.0);

    lat *= 2.0 / 3.0;
    lng *= 2.0 / 3.0;

    lat += -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * xy + 0.2 * absX;
    lng += 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * xy + 0.1 * absX;

    return [lat, lng];
  }

  /// 计算经纬度差值
  static List<double> _delta(double lat, double lng) {
    List<double> t = _transform(lng - 105.0, lat - 35.0);
    double dLat = t[0];
    double dLng = t[1];

    double radLat = lat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = math.sqrt(magic);

    dLat =
        (dLat * 180.0) / ((earthR * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (earthR / sqrtMagic * math.cos(radLat) * math.pi);
    return [dLat, dLng];
  }

  /// GCJ-02 转换为 WGS-84 (精确迭代版)
  static List<double> gcj2WGSExact(double gcjLat, double gcjLng) {
    if (outOfChina(gcjLat, gcjLng)) {
      return [gcjLat, gcjLng];
    }

    double newLat = gcjLat;
    double newLng = gcjLng;
    double oldLat, oldLng;
    const double threshold = 1e-6;

    for (int i = 0; i < 30; i++) {
      oldLat = newLat;
      oldLng = newLng;

      List<double> d = _delta(newLat, newLng);
      newLat = gcjLat - d[0];
      newLng = gcjLng - d[1];

      if (math.max((oldLat - newLat).abs(), (oldLng - newLng).abs()) <
          threshold) {
        break;
      }
    }
    return [newLat, newLng];
  }
}

class CoordFixer {
  static void _updateCoords(
    double? latField,
    double? lngField,
    void Function(double lat, double lng) onUpdate,
  ) {
    if (latField != null && lngField != null) {
      List<double> wgs84 = CoordinateConverter.gcj2WGSExact(latField, lngField);
      onUpdate((wgs84[0]), (wgs84[1]));
    }
  }

  static Future<Uint8List> processFitBytes(Uint8List fitBytes) async {
    final fitFile = FitFile.fromBytes(fitBytes);

    for (var record in fitFile.records) {
      final msg = record.message;
      switch (msg) {
        case RecordMessage m:
          _updateCoords(m.positionLat, m.positionLong, (la, lo) {
            m.positionLat = la;
            m.positionLong = lo;
          });
        case CoursePointMessage m:
          _updateCoords(m.positionLat, m.positionLong, (la, lo) {
            m.positionLat = la;
            m.positionLong = lo;
          });
        case SegmentPointMessage m:
          _updateCoords(m.positionLat, m.positionLong, (la, lo) {
            m.positionLat = la;
            m.positionLong = lo;
          });
        case SegmentLapMessage m:
          _updateCoords(m.startPositionLat, m.startPositionLong, (la, lo) {
            m.startPositionLat = la;
            m.startPositionLong = lo;
          });
          _updateCoords(m.endPositionLat, m.endPositionLong, (la, lo) {
            m.endPositionLat = la;
            m.endPositionLong = lo;
          });
        case LapMessage m:
          _updateCoords(m.startPositionLat, m.startPositionLong, (la, lo) {
            m.startPositionLat = la;
            m.startPositionLong = lo;
          });
          _updateCoords(m.endPositionLat, m.endPositionLong, (la, lo) {
            m.endPositionLat = la;
            m.endPositionLong = lo;
          });
        case SessionMessage m:
          _updateCoords(m.startPositionLat, m.startPositionLong, (la, lo) {
            m.startPositionLat = la;
            m.startPositionLong = lo;
          });
          _updateCoords(m.necLat, m.necLong, (la, lo) {
            m.necLat = la;
            m.necLong = lo;
          });
          _updateCoords(m.swcLat, m.swcLong, (la, lo) {
            m.swcLat = la;
            m.swcLong = lo;
          });
      }
    }

    fitFile.crc = null; // 重新计算 CRC
    return fitFile.toBytes();
  }

  static Future<XFile> processFit(XFile inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final outBytes = await processFitBytes(bytes);
    final outputFile = XFile.fromData(
      outBytes,
      name: inputFile.name,
      path: inputFile.path,
    );
    return outputFile;
  }

  static Future<XFile> processGpx(XFile inputFile) async {
    final gpxString = await inputFile.readAsString();
    final document = XmlDocument.parse(gpxString);
    const coordinateTags = ['trkpt', 'wpt', 'rtept'];

    for (var tagName in coordinateTags) {
      final elements = document.findAllElements(tagName);
      for (var element in elements) {
        final latAttr = element.getAttribute('lat');
        final lonAttr = element.getAttribute('lon');
        if (latAttr != null && lonAttr != null) {
          double? lat = double.tryParse(latAttr);
          double? lng = double.tryParse(lonAttr);
          if (lat != null && lng != null) {
            List<double> corrected = CoordinateConverter.gcj2WGSExact(lat, lng);
            element.setAttribute('lat', corrected[0].toGpsString());
            element.setAttribute('lon', corrected[1].toGpsString());
          }
        }
      }
    }
    return XFile.fromData(
      utf8.encode(document.toXmlString()),
      name: inputFile.name,
      path: inputFile.path,
    );
  }

  static Future<XFile> processTcx(XFile inputFile) async {
    final tcxString = await inputFile.readAsString();
    final document = XmlDocument.parse(tcxString);
    final allLatitudes = document.findAllElements('LatitudeDegrees');

    for (var latElem in allLatitudes) {
      final parent = latElem.parentElement;
      if (parent == null) continue;
      final lngElem = parent.findElements('LongitudeDegrees').firstOrNull;
      if (lngElem != null) {
        double? lat = double.tryParse(latElem.innerText);
        double? lng = double.tryParse(lngElem.innerText);
        if (lat != null && lng != null) {
          List<double> corrected = CoordinateConverter.gcj2WGSExact(lat, lng);
          latElem.innerText = corrected[0].toGpsString();
          lngElem.innerText = corrected[1].toGpsString();
        }
      }
    }
    return XFile.fromData(
      utf8.encode(document.toXmlString()),
      name: inputFile.name,
      path: inputFile.path,
    );
  }

  static Future<XFile> processFile(XFile inputFile, String fileType) async {
    if (fileType == 'fit') {
      return await processFit(inputFile);
    } else if (fileType == 'tcx') {
      return await processTcx(inputFile);
    } else if (fileType == 'gpx') {
      return await processGpx(inputFile);
    } else {
      throw Exception('Unsupported file type: $fileType');
    }
  }
}
