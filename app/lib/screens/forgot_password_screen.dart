import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../theme.dart';

/// Fully in-app password reset:
///   1. Enter your email → we send a 6-digit code.
///   2. Enter the code + a new password → done, you're signed straight in.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api, this.initialEmail});

  final ApiClient api;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.api.requestPasswordReset(email);
      setState(() {
        _codeSent = true;
        _info = 'We sent a 6-digit code to $email.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.verifyRecoveryCode(_email.text.trim(), code);
      await widget.api.changePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated — welcome back!')),
      );
      // verifyOTP created a session, so the app's auth listener already
      // switched the root to Home; pop this route to reveal it.
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: accentGradient(scheme.primary),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(_codeSent ? Icons.mark_email_read : Icons.lock_reset,
                        size: 38, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _codeSent ? 'Enter your code' : 'Reset your password',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _codeSent
                      ? 'Check your inbox for the code, then choose a new password.'
                      : 'Enter your email and we\'ll send you a verification code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),

                if (!_codeSent) ...[
                  TextField(
                    controller: _email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onSubmitted: (_) => _sendCode(),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ] else ...[
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(
                        fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: 'At least 8 characters',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    onSubmitted: (_) => _resetPassword(),
                    decoration:
                        const InputDecoration(labelText: 'Repeat new password'),
                  ),
                ],

                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: TextStyle(color: scheme.error)),
                  ),
                if (_info != null && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_info!,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),

                GradientButton(
                  expand: true,
                  onPressed: _busy
                      ? null
                      : (_codeSent ? _resetPassword : _sendCode),
                  icon: _codeSent ? Icons.check : Icons.send,
                  label: _busy
                      ? '...'
                      : (_codeSent ? 'Reset password' : 'Send code'),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Resend code'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
