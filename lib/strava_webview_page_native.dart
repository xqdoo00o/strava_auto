import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get_it/get_it.dart';

import 'strava_webview_app_bar.dart';
import 'strava_webview_bridge_native.dart';

class StravaWebViewPage extends StatefulWidget {
  const StravaWebViewPage({
    super.key,
    this.interactive = true,
    this.onReturnHome,
  });

  final bool interactive;
  final VoidCallback? onReturnHome;

  @override
  State<StravaWebViewPage> createState() => _StravaWebViewPageState();
}

class _StravaWebViewPageState extends State<StravaWebViewPage> {
  static const String _domContentLoadedUrlHandler = 'stravaDomContentLoadedUrl';

  static final UserScript _domContentLoadedUrlScript = UserScript(
    source:
        '''
      (() => {
        if (window.self !== window.top) return;

        const notifyFlutter = () => {
          if (!window.flutter_inappwebview ||
              !window.flutter_inappwebview.callHandler) {
            window.addEventListener(
              'flutterInAppWebViewPlatformReady',
              notifyFlutter,
              { once: true }
            );
            return;
          }

          try {
            let csrfDOM = document.querySelector('meta[name="csrf-token"]');
            const csrfToken = (csrfDOM && csrfDOM.content) || '';
            window.flutter_inappwebview
              .callHandler('$_domContentLoadedUrlHandler', {
                url: window.location.href,
                csrfToken
              })
              .catch(() => {});
          } catch (_) {}
        };

        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', notifyFlutter, {
            once: true
          });
        } else {
          notifyFlutter();
        }
      })();
    ''',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: true,
  );

  final StravaWebViewBridge _bridge = GetIt.I<StravaWebViewBridge>();
  InAppWebViewController? _controller;

  bool get _showAppBar =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  void _handleDomContentLoadedUrl(List<dynamic> arguments) {
    if (arguments.isEmpty) return;

    final payload = arguments.first;
    if (payload is! Map) return;

    final url = payload['url']?.toString();
    if (url == null || url.isEmpty) return;

    final csrfToken = payload['csrfToken']?.toString() ?? '';
    _bridge.handleDomContentLoaded(WebUri(url), csrfToken: csrfToken);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      _bridge.unbindController(controller);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(url: StravaWebViewBridge.loginUrl),
      initialUserScripts: UnmodifiableListView<UserScript>([
        _domContentLoadedUrlScript,
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        allowsBackForwardNavigationGestures: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        _bridge.bindController(controller);
        controller.addJavaScriptHandler(
          handlerName: _domContentLoadedUrlHandler,
          callback: _handleDomContentLoadedUrl,
        );
      },
    );

    return Scaffold(
      appBar: _showAppBar
          ? StravaWebViewAppBar(
              onReturnHome: widget.onReturnHome,
              enableSwipeReturn: true,
            )
          : null,
      body: widget.interactive ? webView : IgnorePointer(child: webView),
    );
  }
}
