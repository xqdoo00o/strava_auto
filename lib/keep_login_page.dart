import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'app_state.dart';
import 'extension.dart';
import 'keep_manager.dart';
import 'l10n/generated/app_localizations.dart';

class KeepLoginPage extends StatefulWidget {
  const KeepLoginPage({super.key});

  @override
  State<KeepLoginPage> createState() => _KeepLoginPageState();
}

class _KeepLoginPageState extends State<KeepLoginPage> {
  final AppState appState = GetIt.I<AppState>();
  final _formKey = GlobalKey<FormState>();
  DateTime? _lastSyncDate;
  final _nowDate = DateTime.now();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDate();
    _loadCredentials();
  }

  Future<void> _initDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt('keep_last_sync_time');

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
    await KeepManager().init();
    if (mounted) {
      setState(() {
        if (KeepManager().username != null) {
          _usernameController.text = KeepManager().username!;
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

    final success = await KeepManager().login(
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
          context.showToast(
            AppLocalizations.of(
              context,
            )!.loginSuccess(AppLocalizations.of(context)!.keep),
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
      final syncedCount = await KeepManager().syncNow(_lastSyncDate);
      if (mounted) {
        context.showToast(l10n.syncSuccessMessage(syncedCount));
        final prefs = await SharedPreferences.getInstance();
        final nowTime = DateTime.now();
        await prefs.setInt(
          'keep_last_sync_time',
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
      appBar: AppBar(title: Text(l10n.thirdLoginTitle(l10n.keep))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.thirdLoginDescription(l10n.keep, l10n.run),
                style: TextStyle(fontSize: 16, color: theme.hintColor),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
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
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
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
                    : Text(
                        KeepManager().username != null
                            ? l10n.reconnectButton
                            : l10n.connectSyncButton,
                      ),
              ),
              const SizedBox(height: 16),
              if (KeepManager().username != null) ...[
                ElevatedButton.icon(
                  onPressed: () => _pickDate(context),
                  icon: Icon(Icons.calendar_today),
                  label: Text(
                    _lastSyncDate == null
                        ? l10n.allActivities
                        : "${_lastSyncDate!.toIso8601String().split('T')[0]} ${l10n.postActivities}",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
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
                            const Icon(Icons.sync),
                            const SizedBox(width: 8),
                            Text(l10n.syncNowButton),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await KeepManager().logout();
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
