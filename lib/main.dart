import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strava_service.dart';
import 'strava_webview_bridge_native.dart'
    if (dart.library.js_interop) 'strava_webview_bridge_web.dart';
import 'strava_auth_iframe_dialog_stub.dart'
    if (dart.library.js_interop) 'strava_auth_iframe_dialog_web.dart';
import 'strava_webview_shell.dart';
import 'swipe_hint_animation.dart';
import 'log_manager.dart';
import 'settings_page.dart';
import 'theme_manager.dart';
import 'locale_manager.dart';
import 'coord_manager.dart';
import 'coord_fixer.dart';
import 'strava_setting.dart';
import 'app_state.dart';
import 'extension.dart';
import 'onelap_login_page.dart' deferred as onelap_login;
import 'onelap_manager.dart' deferred as onelap_manager;
import 'igp_login_page.dart' deferred as igp_login;
import 'igp_manager.dart' deferred as igp_manager;
import 'garmin_login_page.dart' deferred as garmin_login;
import 'garmin_manager.dart' deferred as garmin_manager;
import 'keep_login_page.dart' deferred as keep_login;
import 'keep_manager.dart' deferred as keep_manager;
import "stub_logic.dart"
    if (dart.library.js_interop) "web_logic.dart"
    if (dart.library.io) "native_logic.dart";
import 'l10n/generated/app_localizations.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stravaWebViewBridge = StravaWebViewBridge();
  final stravaService = StravaService(webViewBridge: stravaWebViewBridge);
  await stravaService.init();
  getIt.registerSingleton<AppState>(AppState());
  getIt.registerSingleton<StravaWebViewBridge>(stravaWebViewBridge);
  getIt.registerSingleton<StravaService>(stravaService);
  runApp(const UpstraApp());
}

class UpstraApp extends StatelessWidget {
  const UpstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ThemeManager(), LocaleManager()]),
      builder: (context, child) {
        return MaterialApp(
          onGenerateTitle: (context) => "Strava Auto",
          locale: LocaleManager().locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('zh'), // Chinese
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFC4C02), // Strava Orange
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F7F7),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              color: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC4C02),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFC4C02),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle.light,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              color: const Color(0xFF1E1E1E),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC4C02),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          themeMode: ThemeManager().themeMode,
          home: const DashboardPage(),
          builder: (context, child) {
            return StravaWebViewShell(child: child ?? const SizedBox.shrink());
          },
          // Fix for "Failed to handle route information"
          onGenerateRoute: (settings) {
            // If this is the auth redirect, show a transient loading page instead of pushing a new DashboardPage
            final routeName = settings.name?.toLowerCase() ?? '';
            if (routeName.contains('code=') ||
                routeName.startsWith('stravaauto://')) {
              return MaterialPageRoute(
                builder: (context) => const AuthCallbackPage(),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const DashboardPage(),
            );
          },
        );
      },
    );
  }
}

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    // Automatically close this page after a short delay to reveal the updated DashboardPage underneath
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFC4C02)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.finalizingConnection,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final StravaService _stravaService = GetIt.I<StravaService>();
  final StravaWebViewBridge _stravaWebViewBridge =
      GetIt.I<StravaWebViewBridge>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  // State
  final AppState _appState = GetIt.I<AppState>();
  bool _isUploading = false;
  bool _isDragging = false;
  Set<String> _visibleThirdPartySyncs = {_thirdPartyOneLap};
  bool _oneLapLoaded = false;
  bool _igpLoaded = false;
  bool _keepLoaded = false;
  bool _garminLoaded = false;
  double _statusCardDragDx = 0;
  bool _hasPlayedStatusCardSwipeHint = false;
  final bool _isMobilePlatform =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  final extensions = ['fit', 'tcx', 'gpx'];
  static const String _thirdPartySyncPrefsKey = 'home_third_party_syncs';
  static const String _thirdPartyOneLap = 'onelap';
  static const String _thirdPartyIGP = 'igp';
  static const String _thirdPartyKeep = 'keep';
  static const String _thirdPartyGarmin = 'garmin';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _statusCardSwipeHintController;
  late Animation<double> _statusCardSwipeHintAnimation;

  double get _statusCardVisualDx {
    final dragOffset = _statusCardDragDx.clamp(-8.0, 28.0);
    return dragOffset + _statusCardSwipeHintAnimation.value;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _statusCardSwipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _statusCardSwipeHintAnimation = buildSwipeHintAnimation(
      _statusCardSwipeHintController,
      direction: 1,
    );
    _appState.addListener(_handleStateChange);
    _stravaService.addListener(_handleStravaServiceChange);
    _stravaWebViewBridge.addListener(_handleStravaServiceChange);
    _initStrava();
    unawaited(_initVisibleThirdPartySyncs());
    _initDeepLinks();
    if (!kIsWeb) _initSharingIntent();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _intentSub?.cancel();
    _pulseController.dispose();
    _statusCardSwipeHintController.dispose();
    _appState.removeListener(_handleStateChange);
    _stravaService.removeListener(_handleStravaServiceChange);
    _stravaWebViewBridge.removeListener(_handleStravaServiceChange);
    super.dispose();
  }

  bool _isApplyingServiceConnectionState = false;

  void _handleStateChange() {
    if (_isApplyingServiceConnectionState) return;
    if (!_appState.isConnected) {
      _disconnect();
    }
  }

  void _handleStravaServiceChange() {
    _applyServiceConnectionState();
    if (mounted) {
      setState(() {});
    }
  }

  void _applyServiceConnectionState() {
    _isApplyingServiceConnectionState = true;
    _appState.setConnected(_stravaService.isReadyForUpload);
    _isApplyingServiceConnectionState = false;
  }

  void _addLog(String message, {bool isError = false}) {
    LogManager().addLog(message, isError: isError);
  }

  Future<void> _initVisibleThirdPartySyncs() async {
    final prefs = await SharedPreferences.getInstance();
    final syncs = prefs.getStringList(_thirdPartySyncPrefsKey);
    final visibleSyncs = syncs?.toSet() ?? {_thirdPartyOneLap};
    await Future.wait(visibleSyncs.map(_ensureThirdPartySyncLoaded));

    if (mounted) {
      setState(() {
        _visibleThirdPartySyncs = visibleSyncs;
      });
    }
  }

  Future<void> _saveVisibleThirdPartySyncs(Set<String> syncs) async {
    await Future.wait(syncs.map(_ensureThirdPartySyncLoaded));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_thirdPartySyncPrefsKey, syncs.toList());
    if (mounted) {
      setState(() {
        _visibleThirdPartySyncs = syncs;
      });
    }
  }

  Future<void> _ensureThirdPartySyncLoaded(String syncKey) async {
    switch (syncKey) {
      case _thirdPartyOneLap:
        if (_oneLapLoaded) return;
        await onelap_manager.loadLibrary();
        await onelap_manager.OneLapManager().init();
        _oneLapLoaded = true;
        break;
      case _thirdPartyIGP:
        if (_igpLoaded) return;
        await igp_manager.loadLibrary();
        await igp_manager.IGPManager().init();
        _igpLoaded = true;
        break;
      case _thirdPartyKeep:
        if (_keepLoaded) return;
        await keep_manager.loadLibrary();
        await keep_manager.KeepManager().init();
        _keepLoaded = true;
        break;
      case _thirdPartyGarmin:
        if (_garminLoaded) return;
        await garmin_manager.loadLibrary();
        await garmin_manager.GarminManager().init();
        _garminLoaded = true;
        break;
    }
  }

  // --- Initialization & Listeners ---

  Future<void> _initStrava() async {
    try {
      _applyServiceConnectionState();
      if (_appState.isConnected) {
        _addLog("Connected to Strava session.");
      } else {
        _addLog("Welcome! Please connect to Strava.");
      }
    } catch (e) {
      _addLog("Failed to initialize Strava service: $e", isError: true);
    }
  }

  String getExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  void _initDeepLinks() async {
    if (kIsWeb) {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null &&
          initialUri.queryParameters.containsKey('code')) {
        _handleAuthCallback(initialUri);
      }
    } else {
      registerDesktopCustomProtocol();
      _sub = _appLinks.uriLinkStream.listen(
        (uri) {
          _addLog("Received link: $uri");
          if (uri.scheme == 'stravaauto') {
            _handleAuthCallback(uri);
          } else if (uri.scheme == 'file') {
            // Handle file open request (iOS "Open with...")
            try {
              final filePath = uri.toFilePath();
              final ext = getExtension(filePath);
              if (extensions.contains(ext)) {
                _addLog("Detected file from link: $filePath");
                // Delay slightly to ensure UI is ready if app was just launched
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) _showUploadDialog([XFile(filePath)]);
                });
              } else {
                _addLog(
                  "Ignored non-supported file link: ${uri.pathSegments.last}",
                  isError: true,
                );
              }
            } catch (e) {
              _addLog("Error parsing file link: $e", isError: true);
            }
          }
        },
        onError: (err) {
          _addLog("Deep link error: $err", isError: true);
        },
      );
    }
  }

  void _initSharingIntent() {
    // While running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) _handleSharedFiles(value);
      },
      onError: (err) {
        _addLog("Sharing intent error: $err", isError: true);
      },
    );

    // Initial launch
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) _handleSharedFiles(value);
    });
  }

  // --- Logic ---

  Future<void> _handleAuthCallback(Uri uri) async {
    _addLog("Processing authorization...");
    try {
      final success = await _stravaService.handleAuthCallback(uri);
      if (mounted) {
        _appState.setConnected(success);
        if (success) {
          _addLog("Authorization successful! Ready to upload.");
          if (kIsWeb) {
            try {
              clearURLParameter();
            } catch (e) {
              _addLog("Failed to clear URL parameters: $e", isError: true);
            }
          }
          context.showToast(
            AppLocalizations.of(context)!.connectedSuccess,
            backgroundColor: Colors.green,
          );
        } else {
          _addLog("Authorization failed.", isError: true);
          context.showToast(
            AppLocalizations.of(context)!.authFailed,
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      _addLog("Auth error: $e", isError: true);
      if (mounted) {
        context.showToast(
          AppLocalizations.of(context)!.connectionError(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _connectToStrava() async {
    if (_stravaService.uploadMode == StravaUploadMode.webView) {
      final shown = StravaWebViewShell.showWebView(context);
      _addLog("Opened Strava WebView login.");
      if (!shown && mounted) {
        context.showToast(
          AppLocalizations.of(context)!.webViewLoginRequired,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    if (!_stravaService.hasCredentials) {
      _addLog("Missing Client ID/Secret configuration.", isError: true);

      bool shouldDisconnect = await StravaConfigUtils.showStravaConfigDialog(
        context,
      );

      if (!mounted) return;

      if (!shouldDisconnect) {
        _addLog("Configuration cancelled by user.");
        return;
      }
    }
    try {
      final url = _stravaService.getAuthorizationUrl();
      if (kIsWeb && isChromeExtension()) {
        await showStravaAuthIframeDialog(
          context,
          authorizationUrl: url,
          onCallback: _handleAuthCallback,
        );
        _addLog("Opened Strava iframe login.");
        return;
      }
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
        _addLog("Launched Strava login...");
      } else {
        _addLog("Could not launch browser.", isError: true);
      }
    } catch (e) {
      _addLog("Auth launch error: $e", isError: true);
    }
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.logoutConfirmationTitle),
        content: Text(
          AppLocalizations.of(context)!.logoutConfirmationMessage('Strava'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _appState.setConnected(false);
    }
  }

  Future<void> _disconnect() async {
    if (_stravaService.uploadMode == StravaUploadMode.webView) {
      await _stravaWebViewBridge.logout();
    } else {
      await _stravaService.logout();
    }
    _addLog("Disconnected from Strava.");
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    _addLog("Received shared files: ${files.length}");
    for (var file in files) {
      _addLog("Checking file: ${file.path}");
      final ext = getExtension(file.path);
      if (extensions.contains(ext)) {
        _showUploadDialog([XFile(file.path)]);
        break;
      } else {
        _addLog(
          "Ignored non-supported file: ${file.path.split('/').last}",
          isError: true,
        );
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: true,
        withData: true,
      );
      final ctx = context;
      if (!ctx.mounted) {
        return;
      }
      if (result != null && result.files.isNotEmpty) {
        final validPlatformFiles = result.files.where((file) {
          return extensions.contains(getExtension(file.name));
        }).toList();
        if (validPlatformFiles.isEmpty) {
          _addLog("No valid files picked.", isError: true);
          ctx.showToast(
            AppLocalizations.of(ctx)!.noValidFiles,
            backgroundColor: Colors.red,
          );
          return;
        }
        final validFiles = validPlatformFiles
            .map((file) => file.xFile)
            .toList();
        _showUploadDialog(validFiles);
      }
    } catch (e) {
      _addLog("File picker error: $e", isError: true);
    }
  }

  void _showUploadDialog(List<XFile> files) {
    if (!_stravaService.isReadyForUpload) {
      _addLog(
        "Please connect to Strava to upload ${files.first.name}",
        isError: true,
      );
      context.showToast(
        _stravaService.uploadMode == StravaUploadMode.webView
            ? AppLocalizations.of(context)!.webViewLoginRequired
            : AppLocalizations.of(context)!.pleaseConnectFirst,
      );
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadSheet(files: files, onUpload: _uploadFiles),
    );
  }

  Future<void> _uploadFiles(List<XFile> files, String sportType) async {
    setState(() {
      _isUploading = true;
    });

    try {
      for (final file in files) {
        await _uploadFile(file, sportType);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadFile(XFile uploadFile, String sportType) async {
    final fileName = uploadFile.name;
    _addLog("Starting upload: $fileName...");
    if (CoordManager().gcjCorrection == true) {
      uploadFile = await CoordFixer.processFile(
        uploadFile,
        getExtension(uploadFile.name),
      );
    }
    try {
      final resultMsg = await _stravaService.uploadStravaFile(
        uploadFile,
        sportType,
      );
      _addLog("Success: $resultMsg");

      if (mounted) {
        context.showToast(
          AppLocalizations.of(context)!.uploadFileSuccess(fileName),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        );
      }
    } catch (e) {
      _addLog("Upload failed: $e", isError: true);
      if (mounted) {
        context.showToast(
          AppLocalizations.of(context)!.uploadFileFailed(fileName),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        );
      }
    }
  }

  // --- UI Components ---

  Future<void> _handleThirdPartyAction({
    required String? username,
    required Future<int> Function() syncNow,
    required Future<void> Function() loadLoginLibrary,
    required WidgetBuilder loginPageBuilder,
  }) async {
    if (username == null) {
      await loadLoginLibrary();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: loginPageBuilder));
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    context.showToast(
      l10n.syncingMessage,
      duration: const Duration(seconds: 1),
    );

    try {
      final syncedCount = await syncNow();
      if (mounted) {
        context.showToast(l10n.syncSuccessMessage(syncedCount));
      }
    } catch (e) {
      if (mounted) {
        context.showToast(
          '${l10n.syncFailedMessage} $e',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _showThirdPartySyncConfigDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedSyncs = Set<String>.from(_visibleThirdPartySyncs);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void toggleSync(String key, bool? checked) {
              setDialogState(() {
                if (checked == true) {
                  selectedSyncs.add(key);
                } else {
                  selectedSyncs.remove(key);
                }
              });
            }

            return AlertDialog(
              title: Text(l10n.syncPlatforms),
              contentPadding: const EdgeInsets.only(top: 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: selectedSyncs.contains(_thirdPartyOneLap),
                    onChanged: (value) => toggleSync(_thirdPartyOneLap, value),
                    secondary: _buildThirdPartyLetterIcon(
                      letter: 'W',
                      color: const Color(0xFF0155FF),
                    ),
                    title: Text(l10n.thirdSyncTitle(l10n.oneLap)),
                    subtitle: Text(
                      l10n.thirdSyncSubtitle(l10n.oneLap, l10n.ride),
                    ),
                  ),
                  CheckboxListTile(
                    value: selectedSyncs.contains(_thirdPartyIGP),
                    onChanged: (value) => toggleSync(_thirdPartyIGP, value),
                    secondary: _buildThirdPartyLetterIcon(
                      letter: 'I',
                      color: const Color(0xFFFF3C1F),
                    ),
                    title: Text(l10n.thirdSyncTitle(l10n.iGPS)),
                    subtitle: Text(
                      l10n.thirdSyncSubtitle(l10n.iGPS, l10n.ride),
                    ),
                  ),
                  CheckboxListTile(
                    value: selectedSyncs.contains(_thirdPartyGarmin),
                    onChanged: (value) => toggleSync(_thirdPartyGarmin, value),
                    secondary: _buildThirdPartyLetterIcon(
                      letter: 'G',
                      color: const Color(0xFF11AEED),
                    ),
                    title: Text(l10n.thirdSyncTitle(l10n.garmin)),
                    subtitle: Text(
                      l10n.thirdSyncSubtitle(l10n.garmin, l10n.sport),
                    ),
                  ),
                  CheckboxListTile(
                    value: selectedSyncs.contains(_thirdPartyKeep),
                    onChanged: (value) => toggleSync(_thirdPartyKeep, value),
                    secondary: _buildThirdPartyLetterIcon(
                      letter: 'K',
                      color: const Color(0xFF4B3E5F),
                    ),
                    title: Text(l10n.thirdSyncTitle(l10n.keep)),
                    subtitle: Text(
                      l10n.thirdSyncSubtitle(l10n.keep, l10n.sport),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancelButton),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedSyncs),
                  child: Text(l10n.confirmButton),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _saveVisibleThirdPartySyncs(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, child) {
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 50,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusCard(theme),
                          const SizedBox(height: 30),
                          Expanded(child: _buildMainActionArea(theme)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    if (_isWebViewUploadMode) {
      _maybePlayStatusCardSwipeHint();
    }

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _appState.isConnected
              ? [const Color(0xFFFC4C02), const Color(0xFFFF8243)]
              : [theme.cardColor, theme.cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _appState.isConnected
                ? const Color(0xFFFC4C02).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _appState.isConnected
                  ? Icons.check_rounded
                  : Icons.link_off_rounded,
              color: _appState.isConnected
                  ? Colors.white
                  : theme.iconTheme.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appState.isConnected
                      ? AppLocalizations.of(context)!.statusConnected
                      : AppLocalizations.of(context)!.statusNotConnected,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _appState.isConnected
                        ? Colors.white
                        : theme.textTheme.titleMedium?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _appState.isConnected
                      ? AppLocalizations.of(context)!.readyToSync
                      : AppLocalizations.of(context)!.connectToStart,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _appState.isConnected
                        ? Colors.white.withValues(alpha: 0.9)
                        : theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            color: _appState.isConnected ? Colors.white : theme.iconTheme.color,
            tooltip: AppLocalizations.of(context)!.settingsTooltip,
            onPressed: () async {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          if (_appState.isConnected) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              color: Colors.white,
              tooltip: AppLocalizations.of(context)!.syncPlatforms,
              onPressed: _showThirdPartySyncConfigDialog,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              color: Colors.white,
              tooltip: AppLocalizations.of(context)!.disconnectTooltip,
              onPressed: _confirmDisconnect,
            ),
          ],
        ],
      ),
    );

    if (!_isWebViewUploadMode) {
      return card;
    }

    final animatedCard = AnimatedBuilder(
      animation: _statusCardSwipeHintAnimation,
      child: card,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_statusCardVisualDx, 0),
          child: child,
        );
      },
    );

    if (!_canSwipeStatusCardToWebView) {
      return _buildStatusCardHoverCursor(animatedCard);
    }

    return _buildStatusCardHoverCursor(
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          _statusCardSwipeHintController.stop();
          _statusCardSwipeHintController.reset();
          setState(() {
            _statusCardDragDx = 0;
          });
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            _statusCardDragDx += details.primaryDelta ?? 0;
          });
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final shouldOpenWebView = velocity > 250 || _statusCardDragDx > 36;
          setState(() {
            _statusCardDragDx = 0;
          });
          if (shouldOpenWebView) {
            StravaWebViewShell.showWebView(context);
          }
        },
        child: animatedCard,
      ),
    );
  }

  Widget _buildStatusCardHoverCursor(Widget child) {
    return MouseRegion(cursor: SystemMouseCursors.resizeLeft, child: child);
  }

  void _maybePlayStatusCardSwipeHint() {
    if (_hasPlayedStatusCardSwipeHint) return;
    _hasPlayedStatusCardSwipeHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isWebViewUploadMode) return;
      _statusCardSwipeHintController.forward(from: 0);
    });
  }

  bool get _isWebViewUploadMode {
    return _stravaService.uploadMode == StravaUploadMode.webView;
  }

  bool get _canSwipeStatusCardToWebView {
    return _isMobilePlatform && _isWebViewUploadMode;
  }

  Widget _buildMainActionArea(ThemeData theme) {
    if (!_appState.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.unlockUpload,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _connectToStrava,
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/strava.png', height: 48),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildThirdPartyActionList(theme),
        const SizedBox(height: 16),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180),
            child: _isUploading
                ? _buildUploadProgressOverlay(theme)
                : _buildUploadDropTarget(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadDropTarget(ThemeData theme) {
    return DropTarget(
      onDragDone: (detail) async {
        final validFiles = detail.files.where((file) {
          return extensions.contains(getExtension(file.name));
        }).toList();
        if (validFiles.isEmpty) {
          _addLog("No valid files dropped.", isError: true);
          context.showToast(
            AppLocalizations.of(context)!.noValidFiles,
            backgroundColor: Colors.red,
          );
          return;
        }
        _showUploadDialog(validFiles);
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: GestureDetector(
        onTap: _pickAndUploadFile,
        child: _buildUploadDropCard(theme),
      ),
    );
  }

  Widget _buildUploadProgressOverlay(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFC4C02).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 48,
                  color: Color(0xFFFC4C02),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.uploading,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThirdPartyActionList(ThemeData theme) {
    final listenables = <Listenable>[LocaleManager()];
    if (_oneLapLoaded) listenables.add(onelap_manager.OneLapManager());
    if (_igpLoaded) listenables.add(igp_manager.IGPManager());
    if (_garminLoaded) listenables.add(garmin_manager.GarminManager());
    if (_keepLoaded) listenables.add(keep_manager.KeepManager());

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final tiles = <Widget>[];

        void addSpacing() {
          if (tiles.isNotEmpty) {
            tiles.add(const SizedBox(height: 10));
          }
        }

        if (_visibleThirdPartySyncs.contains(_thirdPartyOneLap) &&
            _oneLapLoaded) {
          final manager = onelap_manager.OneLapManager();
          addSpacing();
          tiles.add(
            _buildThirdPartyActionTile(
              theme: theme,
              leading: _buildThirdPartyLetterIcon(
                letter: 'W',
                color: const Color(0xFF0155FF),
              ),
              title: l10n.thirdSyncTitle(l10n.oneLap),
              subtitle:
                  manager.username ??
                  l10n.thirdSyncSubtitle(l10n.oneLap, l10n.ride),
              isConnected: manager.username != null,
              isSyncing: manager.isSyncing,
              onTap: manager.isSyncing
                  ? null
                  : () => _handleThirdPartyAction(
                      username: manager.username,
                      syncNow: manager.syncNow,
                      loadLoginLibrary: onelap_login.loadLibrary,
                      loginPageBuilder: (_) => onelap_login.OneLapLoginPage(),
                    ),
            ),
          );
        }

        if (_visibleThirdPartySyncs.contains(_thirdPartyIGP) && _igpLoaded) {
          final manager = igp_manager.IGPManager();
          addSpacing();
          tiles.add(
            _buildThirdPartyActionTile(
              theme: theme,
              leading: _buildThirdPartyLetterIcon(
                letter: 'I',
                color: const Color(0xFFFF3C1F),
              ),
              title: l10n.thirdSyncTitle(l10n.iGPS),
              subtitle:
                  manager.username ??
                  l10n.thirdSyncSubtitle(l10n.iGPS, l10n.ride),
              isConnected: manager.username != null,
              isSyncing: manager.isSyncing,
              onTap: manager.isSyncing
                  ? null
                  : () => _handleThirdPartyAction(
                      username: manager.username,
                      syncNow: manager.syncNow,
                      loadLoginLibrary: igp_login.loadLibrary,
                      loginPageBuilder: (_) => igp_login.IGPLoginPage(),
                    ),
            ),
          );
        }
        if (_visibleThirdPartySyncs.contains(_thirdPartyGarmin) &&
            _garminLoaded) {
          final manager = garmin_manager.GarminManager();
          addSpacing();
          tiles.add(
            _buildThirdPartyActionTile(
              theme: theme,
              leading: _buildThirdPartyLetterIcon(
                letter: 'G',
                color: const Color(0xFF11AEED),
              ),
              title: l10n.thirdSyncTitle(l10n.garmin),
              subtitle:
                  manager.username ??
                  l10n.thirdSyncSubtitle(l10n.garmin, l10n.sport),
              isConnected: manager.username != null,
              isSyncing: manager.isSyncing,
              connectedLeadingAction: manager.username == null
                  ? null
                  : _buildKeepSportTypeMenu(
                      sportType: manager.sportType,
                      onSelected: manager.setSportType,
                    ),
              onTap: manager.isSyncing
                  ? null
                  : () => _handleThirdPartyAction(
                      username: manager.username,
                      syncNow: manager.syncNow,
                      loadLoginLibrary: garmin_login.loadLibrary,
                      loginPageBuilder: (_) => garmin_login.GarminLoginPage(),
                    ),
            ),
          );
        }

        if (_visibleThirdPartySyncs.contains(_thirdPartyKeep) && _keepLoaded) {
          final manager = keep_manager.KeepManager();
          addSpacing();
          tiles.add(
            _buildThirdPartyActionTile(
              theme: theme,
              leading: _buildThirdPartyLetterIcon(
                letter: 'K',
                color: const Color(0xFF4B3E5F),
              ),
              title: l10n.thirdSyncTitle(l10n.keep),
              subtitle:
                  manager.username ??
                  l10n.thirdSyncSubtitle(l10n.keep, l10n.sport),
              isConnected: manager.username != null,
              isSyncing: manager.isSyncing,
              connectedLeadingAction: manager.username == null
                  ? null
                  : _buildKeepSportTypeMenu(
                      sportType: manager.sportType,
                      onSelected: manager.setSportType,
                    ),
              onTap: manager.isSyncing
                  ? null
                  : () => _handleThirdPartyAction(
                      username: manager.username,
                      syncNow: manager.syncNow,
                      loadLoginLibrary: keep_login.loadLibrary,
                      loginPageBuilder: (_) => keep_login.KeepLoginPage(),
                    ),
            ),
          );
        }

        return Column(children: tiles);
      },
    );
  }

  Widget _buildThirdPartyActionTile({
    required ThemeData theme,
    Widget? leading,
    required String title,
    required String subtitle,
    required bool isConnected,
    required bool isSyncing,
    required VoidCallback? onTap,
    Widget? connectedLeadingAction,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: connectedLeadingAction != null
            ? const EdgeInsetsDirectional.only(start: 16, end: 8)
            : null,
        leading:
            leading ?? const Icon(Icons.sync_rounded, color: Color(0xFFFC4C02)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: isSyncing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                  if (isConnected) const SizedBox(width: 8),
                  Icon(
                    isConnected ? Icons.sync_rounded : Icons.chevron_right,
                    size: isConnected ? 20 : null,
                  ),
                  if (isConnected && connectedLeadingAction != null) ...[
                    connectedLeadingAction,
                  ],
                ],
              ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildKeepSportTypeMenu({
    required String sportType,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: sportType == keep_manager.KeepManager.ride
          ? AppLocalizations.of(context)!.ride
          : AppLocalizations.of(context)!.run,
      padding: EdgeInsets.zero,
      menuPadding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      constraints: const BoxConstraints(minWidth: 75, maxWidth: 75),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: keep_manager.KeepManager.run,
          height: 48,
          padding: EdgeInsets.zero,
          child: const Center(child: Icon(Icons.directions_run_rounded)),
        ),
        PopupMenuItem(
          value: keep_manager.KeepManager.ride,
          height: 48,
          padding: EdgeInsets.zero,
          child: const Center(child: Icon(Icons.directions_bike_rounded)),
        ),
      ],
      onSelected: onSelected,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(
          sportType == keep_manager.KeepManager.ride
              ? Icons.directions_bike_rounded
              : Icons.directions_run_rounded,
        ),
      ),
    );
  }

  Widget _buildThirdPartyLetterIcon({
    required String letter,
    required Color color,
  }) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUploadDropCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isDragging ? theme.focusColor : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          style: BorderStyle.none,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: theme.dividerColor,
          strokeWidth: 2,
          gap: _isDragging ? 0 : 10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isDragging
                    ? theme.focusColor
                    : theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.tapToSelect,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Visibility(
              visible: !(kIsWeb && _isMobilePlatform),
              child: Text(
                _isMobilePlatform
                    ? AppLocalizations.of(context)!.orShare
                    : AppLocalizations.of(context)!.orDrag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadSheet extends StatefulWidget {
  final List<XFile> files;
  final Future<void> Function(List<XFile> files, String sportType) onUpload;

  const _UploadSheet({required this.files, required this.onUpload});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  String _sportType = 'Default';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight - 12,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.uploadActivityTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Flexible(child: _UploadFileList(files: widget.files)),
                    const SizedBox(height: 20),
                    _SportTypeSelector(
                      sportType: _sportType,
                      onChanged: (sportType) {
                        setState(() {
                          _sportType = sportType;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l10n.cancelButton),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await widget.onUpload(widget.files, _sportType);
                            },
                            child: Text(l10n.uploadNowButton),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UploadFileList extends StatelessWidget {
  final List<XFile> files;

  const _UploadFileList({required this.files});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: files.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final file = files[index];
            return Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFFFC4C02)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SportTypeSelector extends StatelessWidget {
  final String sportType;
  final ValueChanged<String> onChanged;

  const _SportTypeSelector({required this.sportType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        segments: [
          ButtonSegment(
            value: 'Default',
            label: Text(l10n.defaultStr),
            icon: const Icon(Icons.star_border),
          ),
          ButtonSegment(
            value: 'Run',
            label: Text(l10n.run),
            icon: const Icon(Icons.directions_run_rounded),
          ),
          ButtonSegment(
            value: 'Ride',
            label: Text(l10n.ride),
            icon: const Icon(Icons.directions_bike_rounded),
          ),
        ],
        selected: {sportType},
        onSelectionChanged: (newSelection) => onChanged(newSelection.first),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(24),
        ),
      );

    final Path dashedPath = _dashPath(
      path,
      dashArray: CircularIntervalList<double>([10, gap]),
    );
    canvas.drawPath(dashedPath, paint);
  }

  Path _dashPath(
    Path source, {
    required CircularIntervalList<double> dashArray,
  }) {
    final Path dest = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray.next;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap;
  }
}

class CircularIntervalList<T> {
  final List<T> _values;
  int _index = 0;

  CircularIntervalList(this._values);

  T get next {
    if (_index >= _values.length) {
      _index = 0;
    }
    return _values[_index++];
  }
}
