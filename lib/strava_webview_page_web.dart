import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:web/web.dart' as web;

import 'strava_webview_app_bar.dart';
import 'strava_webview_bridge_web.dart';
import 'web_iframe_element.dart';

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

class _StravaWebViewPageState extends State<StravaWebViewPage>
    with AutomaticKeepAliveClientMixin {
  final StravaWebViewBridge _bridge = GetIt.I<StravaWebViewBridge>();
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final web.EventListener _messageListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _viewType = 'strava-webview-iframe-${identityHashCode(this)}';
    _iframe = createEmbeddedIframe(
      src: StravaWebViewBridge.loginUrl,
      title: 'Strava WebView',
    );

    _messageListener = ((web.Event event) {
      final message = event as web.MessageEvent;
      _bridge.handleExtensionMessage(message.data.dartify());
    }).toJS;
    web.window.addEventListener('message', _messageListener);

    _bridge.bindIframe();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void dispose() {
    _iframe.remove();
    web.window.removeEventListener('message', _messageListener);
    _bridge.unbindIframe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final view = HtmlElementView(viewType: _viewType);
    return Scaffold(
      appBar: StravaWebViewAppBar(onReturnHome: widget.onReturnHome),
      body: widget.interactive ? view : IgnorePointer(child: view),
    );
  }
}
