import 'package:flutter/material.dart';

extension SnackBarExtension on BuildContext {
  void showToast(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2), // 默认 2 秒
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
