import 'package:flutter/material.dart';

import '../api_client.dart';
import '../avatar.dart';
import '../theme.dart';
import 'avatar_editor_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart' show categoryIcons;

const _ageRanges = ['13-17', '18-24', '25-34', '35-49', '50+'];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});

  final ApiClient api;
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();

  bool _signupMode = false;
  int _step = 0; // 0 credentials, 1 personalisation, 2 character (both optional)
  bool _busy = false;
  String? _error;

  final Set<String> _interests = {};
  String? _ageRange;
  AvatarConfig? _avatar;

  void _continueToAbout() {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  Future<void> _submit({bool skipPrefs = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signupMode) {
        final ready = await widget.api.signup(
          _email.text.trim(),
          _password.text,
          displayName: _name.text.trim(),
          interests: skipPrefs ? null : _interests.toList(),
          ageRange: skipPrefs ? null : _ageRange,
          location: skipPrefs ? null : _location.text,
          avatar: skipPrefs ? null : _avatar?.toJson(),
        );
        if (!ready) {
          // Project has email confirmation enabled.
          setState(() {
            _signupMode = false;
            _step = 0;
            _error = 'Check your inbox to confirm your email, then log in.';
          });
          return;
        }
      } else {
        await widget.api.login(_email.text.trim(), _password.text);
      }
      widget.onLoggedIn();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _step = 0; // back to credentials so the error makes sense
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: !_signupMode || _step == 0
                  ? _credentialsForm(context)
                  : _step == 1
                      ? _aboutForm(context)
                      : _avatarForm(context),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: credentials ─────────────────────────────────────────
  Widget _credentialsForm(BuildContext context) {
    return Column(
      key: const ValueKey('credentials'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: accentGradient(Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.explore, size: 46, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        const Center(child: ApexWordmark(size: 40)),
        const SizedBox(height: 6),
        Text(
          'turn every day into a quest',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        if (_signupMode) ...[
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _signupMode ? _continueToAbout() : _submit(),
          decoration: const InputDecoration(
            labelText: 'Password',
            helperText: 'At least 8 characters',
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        GradientButton(
          expand: true,
          onPressed: _busy
              ? null
              : _signupMode
                  ? _continueToAbout
                  : _submit,
          icon: _signupMode ? Icons.arrow_forward : Icons.login,
          label: _busy
              ? '...'
              : _signupMode
                  ? 'Continue'
                  : 'Log in',
        ),
        TextButton(
          onPressed: () => setState(() {
            _signupMode = !_signupMode;
            _error = null;
          }),
          child: Text(
            _signupMode
                ? 'Already have an account? Log in'
                : 'New here? Create an account',
          ),
        ),
        if (!_signupMode)
          TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(
              'Forgot password?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  void _forgotPassword() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(
        api: widget.api,
        initialEmail: _email.text.trim(),
      ),
    ));
  }

  // ── Step 2: optional personalisation ────────────────────────────
  Widget _aboutForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('about'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Make it yours',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'All optional — your quests get better with every answer. '
            'You can change these anytime in your profile.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Text('What are you into?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categoryIcons.keys)
              FilterChip(
                avatar: Icon(
                  categoryIcons[c],
                  size: 16,
                  color: _interests.contains(c)
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
                label: Text(c),
                showCheckmark: false,
                selected: _interests.contains(c),
                selectedColor: scheme.primary,
                labelStyle: TextStyle(
                  color: _interests.contains(c)
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
                onSelected: (sel) => setState(
                  () => sel ? _interests.add(c) : _interests.remove(c),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _ageRange,
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(
            labelText: 'Age range (optional)',
            prefixIcon: Icon(Icons.cake_outlined),
          ),
          items: [
            for (final a in _ageRanges) DropdownMenuItem(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => _ageRange = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          decoration: const InputDecoration(
            labelText: 'Location (optional)',
            prefixIcon: Icon(Icons.place_outlined),
            hintText: 'e.g. Cairo, EG',
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.error),
            ),
          ),
        GradientButton(
          expand: true,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _step = 2;
                    _avatar ??= AvatarConfig();
                  }),
          icon: Icons.arrow_forward,
          label: 'Continue',
        ),
        TextButton(
          onPressed: _busy ? null : () => _submit(skipPrefs: true),
          child: const Text('Skip all of this for now'),
        ),
      ],
    );
  }

  // ── Step 3: make your character (optional) ──────────────────────
  Widget _avatarForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('avatar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Make your character',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'Totally optional — you can build or change it anytime '
            'from your profile.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 460,
          child: AvatarEditorScreen(
            embedded: true,
            initial: _avatar,
            onDone: (_) {},
            key: const ValueKey('signup-avatar-editor'),
          ),
        ),
        const SizedBox(height: 12),
        GradientButton(
          expand: true,
          onPressed: _busy ? null : _submit,
          icon: Icons.rocket_launch,
          label: _busy ? '...' : 'Start questing',
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  _avatar = null;
                  _submit();
                },
          child: const Text('Skip character for now'),
        ),
      ],
    );
  }
}
