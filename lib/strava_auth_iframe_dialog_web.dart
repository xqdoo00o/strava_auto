import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_iframe_element.dart';

typedef StravaAuthCallback = Future<void> Function(Uri uri);

Future<bool> showStravaAuthIframeDialog(
  BuildContext context, {
  required Uri authorizationUrl,
  required StravaAuthCallback onCallback,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _StravaAuthIframeDialog(
          authorizationUrl: authorizationUrl,
          onCallback: onCallback,
        ),
      ) ??
      false;
}

class _StravaAuthIframeDialog extends StatefulWidget {
  const _StravaAuthIframeDialog({
    required this.authorizationUrl,
    required this.onCallback,
  });

  final Uri authorizationUrl;
  final StravaAuthCallback onCallback;

  @override
  State<_StravaAuthIframeDialog> createState() =>
      _StravaAuthIframeDialogState();
}

class _StravaAuthIframeDialogState extends State<_StravaAuthIframeDialog> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final web.EventListener _messageListener;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _viewType = 'strava-auth-iframe-${identityHashCode(this)}';
    _iframe = createEmbeddedIframe(
      src: widget.authorizationUrl.toString(),
      title: 'Strava API Authorization',
    );

    _messageListener = ((web.Event event) {
      final message = event as web.MessageEvent;
      _handleMessage(message);
    }).toJS;
    web.window.addEventListener('message', _messageListener);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void dispose() {
    _iframe.remove();
    web.window.removeEventListener('message', _messageListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Strava API Authorization')),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: _isProcessing
                ? null
                : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: SizedBox(
        width: 720,
        height: 640,
        child: Stack(
          children: [
            Positioned.fill(child: HtmlElementView(viewType: _viewType)),
            if (_isProcessing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x99FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessage(web.MessageEvent message) async {
    if (_isProcessing) return;

    final url = _extractUrl(message.data.dartify());
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!_isAuthCallbackUrl(uri)) return;

    setState(() {
      _isProcessing = true;
    });

    await widget.onCallback(uri);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  bool _isAuthCallbackUrl(Uri url) {
    return url.host == 'localhost';
  }

  String? _extractUrl(Object? data) {
    final payload = _decodePayload(data);
    if (payload == null) return null;

    final directUrl = payload['url'];
    if (directUrl != null) return directUrl.toString();

    final nestedPayload = payload['payload'];
    if (nestedPayload is Map) {
      final nestedUrl = nestedPayload['url'];
      if (nestedUrl != null) return nestedUrl.toString();
    }

    return null;
  }

  Map<String, dynamic>? _decodePayload(Object? data) {
    Object? decoded = data;
    for (var i = 0; i < 2; i++) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is String) {
        try {
          decoded = jsonDecode(decoded);
          continue;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }
}
