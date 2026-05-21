import 'dart:convert';
import 'package:flutter/material.dart';

int getJWTTOkenExp(String token) {
  try {
    final payload = token.split('.').reversed.elementAt(1);
    final data = jsonDecode(
      utf8.decode(base64Decode(base64.normalize(payload))),
    );
    return data['exp'] ?? 0;
  } catch (e) {
    return 0;
  }
}

extension SnackBarExtension on BuildContext {
  void showToast(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 1500), // 默认 1.5 秒
    SnackBarBehavior behavior = SnackBarBehavior.fixed, // 默认固定样式
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: behavior,
      ),
    );
  }
}
