import 'dart:js_interop';

import 'package:web/web.dart' as web;

void clearURLParameter() {
  // 将地址栏重置为不带参数的状态
  web.window.history.replaceState(null, '', web.window.location.pathname);
}

String getRedirectURI() {
  return web.window.location.origin + web.window.location.pathname;
}

@JS('chrome.runtime.id')
external JSString? get chromeRuntimeId;

bool isChromeExtension() {
  try {
    return chromeRuntimeId != null;
  } catch (_) {
    return false;
  }
}

bool shouldUseWebProxy() {
  return !isChromeExtension();
}

bool isWebViewRuntimeAvailable() {
  return true;
}

Future<void> registerDesktopCustomProtocol() async {}
