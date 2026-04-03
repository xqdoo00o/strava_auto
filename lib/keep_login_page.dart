import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'extension.dart';
import 'keep_manager.dart';
import 'package:flutter/foundation.dart';
import 'l10n/generated/app_localizations.dart';

class KeepLoginPage extends StatefulWidget {
  const KeepLoginPage({super.key});

  @override
  State<KeepLoginPage> createState() => _KeepLoginPageState();
}

class _KeepLoginPageState extends State<KeepLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
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

          // Request battery optimization permission on Android after successful login
          _requestBatteryOptimization();

          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _requestBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() {
      _isLoading = true;
    });

    final l10n = AppLocalizations.of(context)!;
    context.showToast(l10n.syncingMessage);

    try {
      final syncedCount = await KeepManager().syncNow();
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.backgroundSyncTip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
