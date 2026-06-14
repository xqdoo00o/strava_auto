import 'dart:io';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StravaWebViewBridge extends ChangeNotifier {
  static final WebUri loginUrl = WebUri(
    'https://www.strava.com/athlete/training',
  );
  static const String _logoutScript = '''
    (() => {
      const logoutLink = document.createElement('a');
      logoutLink.rel = 'nofollow';
      logoutLink.dataset.method = 'delete';
      logoutLink.href = '/session';
      logoutLink.style.display = 'none';

      document.body.appendChild(logoutLink);
      logoutLink.click();
      logoutLink.remove();
      return true;
    })();
  ''';
  static const String _uploadScript = '''
    const csrfToken =
        document.querySelector('meta[name="csrf-token"]')?.content ?? '';
    if (!csrfToken) {
      throw new Error('CSRF token was not found on the current page');
    }

    const binary = atob(fileBase64);
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    const formData = new FormData();
    formData.append('_method', 'post');
    formData.append('authenticity_token', csrfToken);
    formData.append(
      'files[]',
      new Blob([bytes], { type: 'application/octet-stream' }),
      fileName,
    );

    const response = await fetch('https://www.strava.com/upload/files', {
      method: 'POST',
      headers: {
        accept: 'text/plain, */*; q=0.01',
        'x-csrf-token': csrfToken,
        'x-requested-with': 'XMLHttpRequest',
      },
      body: formData,
      credentials: 'include',
    });

    return {
      ok: response.ok,
      status: response.status,
      body: await response.text(),
      pathname: location.pathname,
    };
  ''';

  InAppWebViewController? _controller;
  WebViewEnvironment? _webViewEnvironment;
  WebUri? _currentUrl;
  String _csrfToken = '';
  bool _isLoggedIn = false;

  WebViewEnvironment? get webViewEnvironment => _webViewEnvironment;
  WebUri? get currentUrl => _currentUrl;
  String get csrfToken => _csrfToken;
  bool get isLoggedIn => _isLoggedIn;
  bool get isReady => _controller != null;

  void bindController(InAppWebViewController controller) {
    if (_controller == controller) return;
    _controller = controller;
    notifyListeners();
  }

  void unbindController(InAppWebViewController controller) {
    if (_controller != controller) return;
    _controller = null;
    _setSession(url: null, csrfToken: '', isLoggedIn: false, forceNotify: true);
  }

  void handleDomContentLoaded(WebUri? url, {required String csrfToken}) {
    _setSession(
      url: url,
      csrfToken: csrfToken,
      isLoggedIn: csrfToken.isNotEmpty,
    );
  }

  Future<void> initWebViewEnvironment() async {
    if (Platform.isWindows) {
      final docDir = await getApplicationSupportDirectory();
      final webviewDataPath = p.join(docDir.path, 'WebviewData');

      _webViewEnvironment ??= await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: webviewDataPath),
      );
    }
  }

  Future<void> logout() async {
    final controller = _requireController();
    await controller.evaluateJavascript(source: _logoutScript);
    _setSession(url: null, csrfToken: '', isLoggedIn: false);
  }

  Future<String> uploadStravaFile(XFile file) async {
    if (!isLoggedIn) {
      throw Exception('Please log in to Strava in the WebView first');
    }

    final controller = _requireController();
    final bytes = await file.readAsBytes();
    final result = await controller.callAsyncJavaScript(
      functionBody: _uploadScript,
      arguments: {'fileName': file.name, 'fileBase64': base64Encode(bytes)},
    );

    final value = result?.value;
    if (value is Map && value['ok'] == true) {
      final body = value['body']?.toString() ?? '';
      final status = value['status']?.toString() ?? '200';
      return 'WebView upload successful. Status: $status. $body';
    }
    throw Exception('WebView upload failed: $value');
  }

  InAppWebViewController _requireController() {
    final controller = _controller;
    if (controller == null) {
      throw Exception(
        'Strava WebView is not ready. Open the WebView page first',
      );
    }
    return controller;
  }

  void _setSession({
    WebUri? url,
    required String csrfToken,
    required bool isLoggedIn,
    bool forceNotify = false,
  }) {
    final changed =
        forceNotify ||
        _currentUrl?.toString() != url?.toString() ||
        _csrfToken != csrfToken ||
        _isLoggedIn != isLoggedIn;

    _currentUrl = url;
    _csrfToken = csrfToken;
    _isLoggedIn = isLoggedIn;

    if (!changed) return;
    notifyListeners();
  }
}
