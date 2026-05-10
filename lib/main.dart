import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:get_it/get_it.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'strava_service.dart';
import 'log_manager.dart';
import 'settings_page.dart';
import 'theme_manager.dart';
import 'locale_manager.dart';
import 'coord_manager.dart';
import 'coord_fixer.dart';
import 'strava_setting.dart';
import 'app_state.dart';
import 'extension.dart';
import "stub_logic.dart"
    if (dart.library.js_interop) "web_logic.dart"
    if (dart.library.io) "native_logic.dart";
import 'l10n/generated/app_localizations.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stravaService = StravaService();
  await stravaService.init();
  getIt.registerSingleton<AppState>(AppState());
  getIt.registerSingleton<StravaService>(stravaService);
  runApp(const UpstraApp());
}

class UpstraApp extends StatelessWidget {
  const UpstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeManager(),
        LocaleManager(),
        CoordManager(),
      ]),
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
    with SingleTickerProviderStateMixin {
  final StravaService _stravaService = GetIt.I<StravaService>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  // State
  final AppState _appState = GetIt.I<AppState>();
  bool _isUploading = false;
  bool _isDragging = false;
  final bool _isMobilePlatform =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  final extensions = ['fit', 'tcx', 'gpx'];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _appState.addListener(_handleStateChange);
    _initStrava();
    _initDeepLinks();
    if (!kIsWeb) _initSharingIntent();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _intentSub?.cancel();
    _pulseController.dispose();
    _appState.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!_appState.isConnected) {
      _disconnect();
    }
  }

  void _addLog(String message, {bool isError = false}) {
    LogManager().addLog(message, isError: isError);
  }

  // --- Initialization & Listeners ---

  Future<void> _initStrava() async {
    try {
      _appState.setConnected(_stravaService.isAuthenticated);
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
    // 1. 检查凭据，如果没有，则显示弹窗并等待
    if (!_stravaService.hasCredentials) {
      _addLog("Missing Client ID/Secret configuration.", isError: true);

      bool shouldDisconnect = await StravaConfigUtils.showStravaConfigDialog(
        context,
      );

      if (!shouldDisconnect) {
        _addLog("Configuration cancelled by user.");
        return;
      }
    }
    try {
      final url = _stravaService.getAuthorizationUrl();
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
        content: Text(AppLocalizations.of(context)!.logoutConfirmationMessage),
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
    await _stravaService.logout();
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
      );
      if (!context.mounted) return;
      if (result != null && result.xFiles.isNotEmpty) {
        final validFiles = result.xFiles.where((file) {
          return extensions.contains(getExtension(file.name));
        }).toList();
        if (validFiles.isEmpty) {
          _addLog("No valid files picked.", isError: true);
          final ctx = context;
          ctx.showToast(
            AppLocalizations.of(ctx)!.noValidFiles,
            backgroundColor: Colors.red,
          );
          return;
        }
        _showUploadDialog(validFiles);
      }
    } catch (e) {
      _addLog("File picker error: $e", isError: true);
    }
  }

  void _showUploadDialog(List<XFile> files) {
    if (!_appState.isConnected) {
      _addLog(
        "Please connect to Strava to upload ${files.first.name}",
        isError: true,
      );
      context.showToast(AppLocalizations.of(context)!.pleaseConnectFirst);
      return;
    }
    String tempSportType = 'Default';
    Navigator.of(context).popUntil((route) => route.isFirst);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        // 2. 使用 StatefulBuilder 来管理弹窗内部状态
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
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
                  AppLocalizations.of(context)!.uploadActivityTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: files
                        .map(
                          (file) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                            ), // 文件之间的间距
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  color: Color(0xFFFC4C02),
                                ),
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
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // --- 3. 插入 SegmentedButton ---
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      // visualDensity: VisualDensity(horizontal: 1, vertical: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: 'Default',
                        label: Text(AppLocalizations.of(context)!.defaultStr),
                        icon: const Icon(Icons.star_border),
                      ),
                      ButtonSegment(
                        value: 'Run',
                        label: Text(AppLocalizations.of(context)!.run),
                        icon: const Icon(Icons.directions_run_rounded),
                      ),
                      ButtonSegment(
                        value: 'Ride',
                        label: Text(AppLocalizations.of(context)!.ride),
                        icon: const Icon(Icons.directions_bike_rounded),
                      ),
                    ],
                    selected: {tempSportType},
                    onSelectionChanged: (newSelection) {
                      // 使用 setModalState 刷新底部弹窗的 UI
                      setModalState(() {
                        tempSportType = newSelection.first;
                      });
                    },
                  ),
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
                        child: Text(AppLocalizations.of(context)!.cancelButton),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog first
                          for (var file in files) {
                            await _uploadFile(file, tempSportType);
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context)!.uploadNowButton,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _uploadFile(XFile uploadFile, String sportType) async {
    setState(() {
      _isUploading = true;
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatusCard(theme),
                ),

                const SizedBox(height: 30),

                // Main Action Area
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMainActionArea(theme),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              icon: const Icon(Icons.logout_rounded),
              color: Colors.white,
              tooltip: AppLocalizations.of(context)!.disconnectTooltip,
              onPressed: _confirmDisconnect,
            ),
          ],
        ],
      ),
    );
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

    if (_isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFFFC4C02).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 60,
                  color: Color(0xFFFC4C02),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.uploading,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

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
        child: Container(
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
                    fontWeight: FontWeight.w600,
                  ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
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
