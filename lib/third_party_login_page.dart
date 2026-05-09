import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'extension.dart';
import 'l10n/generated/app_localizations.dart';
import 'password_field.dart';

typedef LocalizedTextBuilder = String Function(AppLocalizations l10n);

class ThirdPartyLoginPage extends StatefulWidget {
  const ThirdPartyLoginPage({
    super.key,
    required this.platformName,
    required this.sportName,
    required this.accountLabel,
    required this.lastSyncTimeKey,
    required this.username,
    required this.init,
    required this.login,
    required this.logout,
    required this.syncNow,
  });

  final LocalizedTextBuilder platformName;
  final LocalizedTextBuilder sportName;
  final LocalizedTextBuilder accountLabel;
  final String lastSyncTimeKey;
  final String? Function() username;
  final Future<void> Function() init;
  final Future<bool> Function(String username, String password) login;
  final Future<void> Function() logout;
  final Future<int> Function(DateTime? lastSyncDate) syncNow;

  @override
  State<ThirdPartyLoginPage> createState() => _ThirdPartyLoginPageState();
}

class _ThirdPartyLoginPageState extends State<ThirdPartyLoginPage> {
  final AppState appState = GetIt.I<AppState>();
  final _formKey = GlobalKey<FormState>();
  final _nowDate = DateTime.now();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _lastSyncDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDate();
    _loadCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt(widget.lastSyncTimeKey);

    if (mounted) {
      setState(() {
        if (lastSyncTime != null && lastSyncTime > 0) {
          _lastSyncDate = DateTime.fromMillisecondsSinceEpoch(
            lastSyncTime * 1000,
          );
        } else {
          _lastSyncDate = _nowDate;
        }
      });
    }
  }

  Future<void> _loadCredentials() async {
    await widget.init();
    if (mounted) {
      setState(() {
        final username = widget.username();
        if (username != null) {
          _usernameController.text = username;
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

    final success = await widget.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = l10n.loginFailed;
        } else {
          _passwordController.clear();
          FocusScope.of(context).unfocus();
          context.showToast(l10n.loginSuccess(widget.platformName(l10n)));
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
      final syncedCount = await widget.syncNow(_lastSyncDate);
      if (mounted) {
        context.showToast(l10n.syncSuccessMessage(syncedCount));
        final prefs = await SharedPreferences.getInstance();
        final nowTime = DateTime.now();
        await prefs.setInt(
          widget.lastSyncTimeKey,
          nowTime.millisecondsSinceEpoch ~/ 1000,
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
    final username = widget.username();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.thirdLoginTitle(widget.platformName(l10n))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.thirdLoginDescription(
                  widget.platformName(l10n),
                  widget.sportName(l10n),
                ),
                style: TextStyle(fontSize: 16, color: theme.hintColor),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: widget.accountLabel(l10n),
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
                            username != null ? Icons.refresh : Icons.login,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: kIsWeb ? 2.0 : 0.0,
                            ),
                            child: Text(
                              username != null
                                  ? l10n.reconnectButton
                                  : l10n.connectSyncButton,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              if (username != null) ...[
                ElevatedButton.icon(
                  onPressed: () => _pickDate(context),
                  icon: const Icon(Icons.calendar_today),
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
                    await widget.logout();
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
