import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

// APEX Supabase project (publishable key — safe to ship in the client;
// row-level security protects the data).
const supabaseUrl = 'https://tugxgfpdcpsfzfckoqtc.supabase.co';
const supabaseKey = 'sb_publishable_YBKmAWJpMGB6rltYFpvxDg_D_kGdY_0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const ApexApp());
}

class ApexApp extends StatefulWidget {
  const ApexApp({super.key});

  @override
  State<ApexApp> createState() => _ApexAppState();
}

class _ApexAppState extends State<ApexApp> {
  final api = ApiClient();
  late final StreamSubscription _authSub;

  @override
  void initState() {
    super.initState();
    // Rebuild on sign-in / sign-out, and drive the theme from the signed-in
    // user's account (the login/signup screens always show the default).
    _authSub = api.authChanges.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        resetThemeToDefault();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (api.isAuthed) {
          try {
            final p = await api.me();
            applyTheme(settingsFrom(p.themePreset, p.themeMode));
          } catch (_) {/* keep default on failure */}
        } else {
          resetThemeToDefault();
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: themeController,
      builder: (context, settings, _) => MaterialApp(
        title: 'APEX',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(settings.preset.seed, Brightness.light),
        darkTheme: buildTheme(settings.preset.seed, Brightness.dark),
        themeMode: settings.mode,
        home: api.isAuthed
            ? HomeScreen(api: api, onLogout: () => setState(() {}))
            : LoginScreen(api: api, onLoggedIn: () => setState(() {})),
      ),
    );
  }
}
