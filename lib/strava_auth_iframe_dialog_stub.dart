import 'package:flutter/material.dart';

typedef StravaAuthCallback = Future<void> Function(Uri uri);

Future<bool> showStravaAuthIframeDialog(
  BuildContext context, {
  required Uri authorizationUrl,
  required StravaAuthCallback onCallback,
}) async {
  return false;
}
