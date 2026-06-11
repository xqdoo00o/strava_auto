import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'strava_service.dart';
import 'strava_webview_bridge_native.dart'
    if (dart.library.js_interop) 'strava_webview_bridge_web.dart';
import 'strava_webview_page_native.dart'
    if (dart.library.js_interop) 'strava_webview_page_web.dart';

class StravaWebViewShell extends StatefulWidget {
  const StravaWebViewShell({super.key, required this.child});

  final Widget child;

  static bool showWebView(BuildContext context) {
    final scope =
        context
                .getElementForInheritedWidgetOfExactType<
                  _StravaWebViewShellScope
                >()
                ?.widget
            as _StravaWebViewShellScope?;
    scope?.state.showWebView();
    return scope != null;
  }

  @override
  State<StravaWebViewShell> createState() => _StravaWebViewShellState();
}

class _StravaWebViewShellState extends State<StravaWebViewShell> {
  final StravaService _stravaService = GetIt.I<StravaService>();
  final StravaWebViewBridge _stravaWebViewBridge =
      GetIt.I<StravaWebViewBridge>();
  late final PageController _pageController;
  bool _isWaitingForWebPreload = false;

  bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _isWaitingForWebPreload =
        kIsWeb && _stravaService.uploadMode == StravaUploadMode.webView;
    _pageController = PageController(
      initialPage: _isWaitingForWebPreload ? 0 : 1,
    );
    _stravaService.addListener(_handleUploadModeChanged);
    _stravaWebViewBridge.addListener(_handleWebViewBridgeChanged);
  }

  @override
  void dispose() {
    _stravaService.removeListener(_handleUploadModeChanged);
    _stravaWebViewBridge.removeListener(_handleWebViewBridgeChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _handleUploadModeChanged() {
    if (!mounted) return;
    setState(() {});
    if (_stravaService.uploadMode == StravaUploadMode.webView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showWebView();
      });
    }
  }

  void _handleWebViewBridgeChanged() {
    if (_stravaWebViewBridge.isLoggedIn &&
        _stravaService.uploadMode == StravaUploadMode.webView) {
      _isWaitingForWebPreload = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateToPage(1);
      });
      return;
    }

    if (!_isWaitingForWebPreload || _stravaWebViewBridge.currentUrl == null) {
      return;
    }

    _isWaitingForWebPreload = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPage(1);
    });
  }

  void showWebView() {
    if (_stravaService.uploadMode != StravaUploadMode.webView) return;
    _animateToPage(0);
  }

  void _showHome() {
    if (_stravaService.uploadMode != StravaUploadMode.webView) return;
    _animateToPage(1);
  }

  void _animateToPage(int page) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpToPage(int page) {
    if (!_pageController.hasClients) return;
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    if (_stravaService.uploadMode != StravaUploadMode.webView) {
      return widget.child;
    }

    return _StravaWebViewShellScope(
      state: this,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: PageView(
          controller: _pageController,
          physics: _isMobilePlatform
              ? const NeverScrollableScrollPhysics()
              : null,
          allowImplicitScrolling: true,
          children: [
            StravaWebViewPage(onReturnHome: _showHome),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _StravaWebViewShellScope extends InheritedWidget {
  const _StravaWebViewShellScope({required this.state, required super.child});

  final _StravaWebViewShellState state;

  @override
  bool updateShouldNotify(_StravaWebViewShellScope oldWidget) {
    return state != oldWidget.state;
  }
}
