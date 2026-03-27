import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoordManager extends ChangeNotifier {
  static final CoordManager _instance = CoordManager._internal();
  factory CoordManager() => _instance;
  CoordManager._internal() {
    _loadGcjCorrection();
  }

  bool? _gcjCorrection;
  bool? get gcjCorrection => _gcjCorrection;

  Future<void> _loadGcjCorrection() async {
    final prefs = await SharedPreferences.getInstance();
    final gcj = prefs.getString('gcj_correction');
    _gcjCorrection = gcj == 'true';
    notifyListeners();
  }

  Future<void> setGcjCorrection(bool? gcjCorrection) async {
    if (_gcjCorrection == gcjCorrection) return;
    
    _gcjCorrection = gcjCorrection;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    if (gcjCorrection != null) {
      await prefs.setString('gcj_correction', gcjCorrection.toString());
    } else {
      await prefs.remove('gcj_correction');
    }
  }
}
