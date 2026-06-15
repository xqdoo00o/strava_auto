import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'garmin_manager.dart';

class GarminWebSsoPanel extends StatefulWidget {
  const GarminWebSsoPanel({super.key, required this.manager});

  final GarminManager manager;

  @override
  State<GarminWebSsoPanel> createState() => _GarminWebSsoPanelState();
}

class _GarminWebSsoPanelState extends State<GarminWebSsoPanel> {
  static const _domain = 'garmin.cn';
  static const _viewType = 'garmin-sso-iframe';
  static var _isViewFactoryRegistered = false;
  String _iframeUrl = '';

  late final web.EventListener _messageListener;
  bool _isConnecting = false;
  String? _errorMessage;

  String get _ssoOrigin => 'https://sso.$_domain';
  String get _ssoBase => '$_ssoOrigin/sso';
  String get _ssoEmbed => '$_ssoBase/embed';

  @override
  void initState() {
    super.initState();
    _iframeUrl = _buildSignInUrl();
    _registerViewFactory();
    _messageListener = ((web.Event event) {
      final message = event as web.MessageEvent;
      _handleMessage(message);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _messageListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              height: 280,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: const HtmlElementView(viewType: _viewType),
            ),
          ),
        ),
        if (_isConnecting) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  void _registerViewFactory() {
    if (_isViewFactoryRegistered) return;
    _isViewFactoryRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe
        ..src = _iframeUrl
        ..title = 'Garmin SSO';
      iframe.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';
      iframe.setAttribute('referrerpolicy', 'origin');
      iframe.setAttribute('allow', 'storage-access');
      return iframe;
    });
  }

  String _buildSignInUrl() {
    final origin = web.window.location.origin;
    final isChromeExtension = origin.startsWith('chrome-extension://');
    return Uri.parse(
          isChromeExtension ? '$_ssoBase/signin' : '$origin/sso/signin',
        )
        .replace(
          queryParameters: {
            'id': 'gauth-widget',
            'embedWidget': 'true',
            'gauthHost': _ssoBase,
            'service': _ssoEmbed,
            'source': _ssoOrigin,
            'consumeServiceTicket': 'false',
          },
        )
        .toString();
  }

  Future<void> _handleMessage(web.MessageEvent message) async {
    if (_isConnecting) return;

    final payload = _decodeMessagePayload(message.data.dartify());
    if (payload == null) return;

    final serviceTicket = payload['serviceTicket']?.toString();
    if (serviceTicket == null || serviceTicket.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final serviceUrl = payload['serviceUrl']?.toString() ?? _ssoEmbed;
    final success = await widget.manager.loginWithServiceTicket(
      serviceTicket,
      serviceUrl: serviceUrl,
    );

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _errorMessage = success ? null : 'Garmin login failed.';
    });
  }

  Map<String, dynamic>? _decodeMessagePayload(Object? data) {
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
