import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'app_state.dart';
import 'extension.dart';
import 'igp_manager.dart';
import 'password_field.dart';
import 'l10n/generated/app_localizations.dart';

class IGPLoginPage extends StatefulWidget {
  const IGPLoginPage({super.key});

  @override
  State<IGPLoginPage> createState() => _IGPLoginPageState();
}

class _IGPLoginPageState extends State<IGPLoginPage> {
  final AppState appState = GetIt.I<AppState>();
  final _formKey = GlobalKey<FormState>();
  DateTime? _lastSyncDate;
  final _nowDate = DateTime.now();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final IGPManager _manager = IGPManager();

  @override
  void initState() {
    super.initState();
    _initDate();
    _loadCredentials();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt('igp_last_sync_time');

    if (mounted) {
      setState(() {
        if (lastSyncTime != null && lastSyncTime > 0) {
          _lastSyncDate = DateTime.fromMillisecondsSinceEpoch(
            lastSyncTime * 1000,
          );
        } else {
          _lastSyncDate = DateTime.parse("2026-01-01");
        }
      });
    }
  }

  Future<void> _loadCredentials() async {
    await _manager.init();
    if (mounted) {
      setState(() {
        if (_manager.username != null) {
          _usernameController.text = _manager.username!;
        }
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await _manager.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = AppLocalizations.of(context)!.loginFailed;
        } else {
          // Success
          _passwordController.clear();
          context.showToast(
            AppLocalizations.of(
              context,
            )!.loginSuccess(AppLocalizations.of(context)!.iGPS),
          );
        }
      });
    }
  }

  Future<void> _handleSyncNow() async {
    final l10n = AppLocalizations.of(context)!;
    if (appState.isConnected == false) {
      context.showToast(l10n.statusPleaseConnect, backgroundColor: Colors.red);
      return;
    }
    setState(() {
      _isLoading = true;
    });

    context.showToast(l10n.syncingMessage);

    try {
      final syncedCount = await _manager.syncNow(_lastSyncDate);
      if (mounted) {
        context.showToast(l10n.syncSuccessMessage(syncedCount));
        final prefs = await SharedPreferences.getInstance();
        final nowTime = DateTime.now();
        await prefs.setInt(
          'igp_last_sync_time',
          (nowTime.millisecondsSinceEpoch ~/ 1000),
        );
        setState(() {
          _lastSyncDate = nowTime;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showToast(
          '${l10n.syncFailedMessage} $e',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastSyncDate,
      firstDate: DateTime(2020),
      lastDate: _nowDate,
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);
        return Center(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _lastSyncDate = null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.history),
                    label: Text(
                      AppLocalizations.of(context)!.clearDate,
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _lastSyncDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.thirdLoginTitle(l10n.iGPS))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.thirdLoginDescription(l10n.iGPS, l10n.ride),
                style: TextStyle(fontSize: 16, color: theme.hintColor),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n.accountLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your account';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomPasswordField(
                controller: _passwordController,
                labelText: l10n.passwordLabel,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _manager.username != null
                                ? Icons.refresh
                                : Icons.login,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: kIsWeb ? 2.0 : 0.0,
                            ),
                            child: Text(
                              _manager.username != null
                                  ? l10n.reconnectButton
                                  : l10n.connectSyncButton,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              if (_manager.username != null) ...[
                ElevatedButton.icon(
                  onPressed: () => _pickDate(context),
                  icon: Icon(Icons.calendar_today),
                  label: Padding(
                    padding: EdgeInsets.only(bottom: kIsWeb ? 2.0 : 0.0),
                    child: Text(
                      _lastSyncDate == null
                          ? l10n.allActivities
                          : "${_lastSyncDate!.toIso8601String().split('T')[0]} ${l10n.postActivities}",
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSyncNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onTertiary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sync, size: 20),
                            const SizedBox(width: 6),
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: kIsWeb ? 2.0 : 0.0,
                              ),
                              child: Text(l10n.syncNowButton),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await _manager.logout();
                    setState(() {
                      _usernameController.clear();
                      _passwordController.clear();
                    });
                  },
                  child: Text(
                    l10n.disconnectAccountButton,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
