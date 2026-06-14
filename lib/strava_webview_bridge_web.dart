import 'dart:convert';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

@JS('stravaExtension.getIframeUrl')
external JSPromise<JSString?> _getStravaIframeUrl();

@JS('stravaExtension.logout')
external JSPromise<JSAny?> _runStravaLogoutInChromeExtension();

@JS('stravaExtension.upload')
external JSPromise<JSAny?> _runStravaUploadInChromeExtension(
  JSString fileName,
  JSString fileBase64,
);

class StravaWebViewBridge extends ChangeNotifier {
  static const String loginUrl = 'https://www.strava.com/athlete/training';

  Uri? _currentUrl;
  String _csrfToken = '';
  bool _isLoggedIn = false;
  bool _isReady = false;

  Uri? get currentUrl => _currentUrl;
  String get csrfToken => _csrfToken;
  bool get isLoggedIn => _isLoggedIn;
  bool get isReady => _isReady;

  void bindIframe() {
    if (_isReady) return;
    _isReady = true;
    notifyListeners();
  }

  void unbindIframe() {
    if (!_isReady && _currentUrl == null && !_isLoggedIn) return;
    _setSession(isReady: false, url: null, csrfToken: '', isLoggedIn: false);
  }

  Future<void> initWebViewEnvironment() async {}

  void handleDomContentLoaded(String? url, {required String csrfToken}) {
    final parsedUrl = url == null || url.isEmpty ? null : Uri.tryParse(url);
    _setSession(
      url: parsedUrl,
      csrfToken: csrfToken,
      isLoggedIn: csrfToken.isNotEmpty,
    );
  }

  void handleExtensionMessage(Object? data) {
    if (data is! Map) return;
    if (data['source'] != 'stravaExtension' ||
        data['type'] != 'stravaDomContentLoaded') {
      return;
    }

    final payload = data['payload'];
    if (payload is! Map) return;

    handleDomContentLoaded(
      payload['url']?.toString(),
      csrfToken: payload['csrfToken']?.toString() ?? '',
    );
  }

  Future<void> refreshStatus() async {
    if (!_isReady) return;

    try {
      final value = await _getStravaIframeUrl().toDart;
      _setCurrentUrl(value?.toDart);
    } catch (error, stackTrace) {
      debugPrint('Failed to read Strava iframe URL: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> logout() async {
    _requireIframe();

    try {
      await _runStravaLogoutInChromeExtension().toDart;
    } finally {
      _setSession(url: null, csrfToken: '', isLoggedIn: false);
    }
  }

  Future<String> uploadStravaFile(XFile file) async {
    _requireIframe();

    if (!isLoggedIn) {
      await refreshStatus();
    }
    if (!isLoggedIn) {
      throw Exception('Please log in to Strava in the WebView first');
    }

    final bytes = await file.readAsBytes();
    final result = await _runStravaUploadInChromeExtension(
      file.name.toJS,
      base64Encode(bytes).toJS,
    ).toDart;

    final value = result?.dartify();
    if (value is Map && value['ok'] == true) {
      final body = value['body']?.toString() ?? '';
      final status = value['status']?.toString() ?? '200';
      final pathname = value['pathname']?.toString();
      if (pathname != null) {
        _setCurrentUrl('https://www.strava.com$pathname');
      }
      return 'WebView upload successful. Status: $status. $body';
    }
    throw Exception('WebView upload failed: $value');
  }

  void _requireIframe() {
    if (!_isReady) {
      throw Exception(
        'Strava WebView is not ready. Open the WebView page first',
      );
    }
  }

  void _setCurrentUrl(String? value) {
    final url = value == null || value.isEmpty ? null : Uri.tryParse(value);
    final isLoggedIn = _isLoggedInUrl(url);
    _setSession(
      url: url,
      csrfToken: isLoggedIn ? null : '',
      isLoggedIn: isLoggedIn,
    );
  }

  void _setSession({
    bool? isReady,
    Uri? url,
    String? csrfToken,
    required bool isLoggedIn,
  }) {
    final changed =
        (isReady != null && _isReady != isReady) ||
        _currentUrl?.toString() != url?.toString() ||
        (csrfToken != null && _csrfToken != csrfToken) ||
        _isLoggedIn != isLoggedIn;

    if (isReady != null) _isReady = isReady;
    _currentUrl = url;
    if (csrfToken != null) _csrfToken = csrfToken;
    _isLoggedIn = isLoggedIn;

    if (changed) notifyListeners();
  }

  bool _isLoggedInUrl(Uri? url) {
    if (url == null) return false;
    final host = url.host.toLowerCase();
    if (host != 'strava.com' && !host.endsWith('.strava.com')) return false;
    return url.path != '/login' && url.path != '/session/new';
  }
}
