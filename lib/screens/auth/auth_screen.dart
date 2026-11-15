import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/supabase_error_mapper.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

/// Email & Password Sign In / Sign Up screen for Phase 1 MVP.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final Future<String?> Function(
    String fullName,
    String email,
    String password,
  ) onSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppLogger.warn('AuthScreen', 'Form validation failed.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      if (_isSignUp) {
        final info = await AppLogger.traceAsync(
          'AuthScreen',
          'onSignUp',
          () => widget.onSignUp(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          ),
        );
        if (mounted && info != null) {
          setState(() {
            _infoMessage = info;
            _isSignUp = false;
          });
          AppLogger.nav('AuthScreen switched to Sign In after signup notice.');
        }
      } else {
        await AppLogger.traceAsync(
          'AuthScreen',
          'onSignIn',
          () => widget.onSignIn(
            _emailController.text.trim(),
            _passwordController.text,
          ),
        );
      }
    } catch (e, st) {
      final mapped = e is AppFailure ? e.message : e.toString();
      AppLogger.error(
        'AuthScreen',
        'Auth submit failed: $mapped',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _errorMessage = mapped);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.bento_rounded,
                      color: AppTheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track daily office lunches, see your squad, and settle monthly bills without guesswork.',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Sign In'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Create Account'),
                      ),
                    ],
                    selected: {_isSignUp},
                    onSelectionChanged: _isLoading
                        ? null
                        : (values) {
                            final nextIsSignUp = values.first;
                            AppLogger.nav(
                              'AuthScreen mode -> ${nextIsSignUp ? 'Create Account' : 'Sign In'}',
                              scope: 'AuthScreen',
                            );
                            setState(() {
                              _isSignUp = nextIsSignUp;
                              _errorMessage = null;
                              _infoMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'e.g. Aarav Sharma',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (_isSignUp &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Work Email',
                                hintText: 'you@company.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty || !text.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              _MessageBanner(
                                message: _errorMessage!,
                                isError: true,
                              ),
                            ],
                            if (_infoMessage != null) ...[
                              const SizedBox(height: 14),
                              _MessageBanner(
                                message: _infoMessage!,
                                isError: false,
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'Create Account' : 'Sign In',
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : AppTheme.fullSoft;
    final fg = isError ? const Color(0xFFB91C1C) : AppTheme.fullColor;
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFB7E4CB);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

