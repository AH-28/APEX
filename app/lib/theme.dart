import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A selectable colour theme. Every colour in the app derives from the seed
/// via Material 3's ColorScheme.fromSeed (vibrant variant), so one swatch
/// restyles everything.
class ThemePreset {
  const ThemePreset(this.name, this.seed);
  final String name;
  final Color seed;
}

const themePresets = [
  ThemePreset('Nebula', Color(0xFF8B5CF6)), // electric violet (default)
  ThemePreset('Ocean', Color(0xFF06AED5)),
  ThemePreset('Forest', Color(0xFF10B981)),
  ThemePreset('Sunset', Color(0xFFFF5A36)),
  ThemePreset('Rose', Color(0xFFF43F76)),
  ThemePreset('Gold', Color(0xFFF5A623)),
];

class ThemeSettings {
  const ThemeSettings({required this.presetName, required this.mode});
  final String presetName;
  final ThemeMode mode;

  ThemePreset get preset => themePresets.firstWhere(
        (p) => p.name == presetName,
        orElse: () => themePresets.first,
      );

  ThemeSettings copyWith({String? presetName, ThemeMode? mode}) =>
      ThemeSettings(
        presetName: presetName ?? this.presetName,
        mode: mode ?? this.mode,
      );
}

/// The fixed default — always shown on the login/signup screens and before
/// a user's saved theme has loaded.
const defaultTheme = ThemeSettings(presetName: 'Nebula', mode: ThemeMode.dark);

/// App-wide live theme state. The MaterialApp listens to this; it's driven by
/// the signed-in user's profile (per-account, not per-device).
final themeController = ValueNotifier<ThemeSettings>(defaultTheme);

/// Build settings from the values stored on the profile.
ThemeSettings settingsFrom(String presetName, String mode) => ThemeSettings(
      presetName: presetName,
      mode: ThemeMode.values.asNameMap()[mode] ?? ThemeMode.dark,
    );

/// Apply a theme to the live app (no persistence — caller persists to the
/// user's profile via the API).
void applyTheme(ThemeSettings settings) => themeController.value = settings;

/// Reset to the fixed default — used on logout and the auth screens.
void resetThemeToDefault() => themeController.value = defaultTheme;

/// Shifts a colour's hue — used to build two-tone gradients from one seed.
Color shiftHue(Color color, double degrees) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

/// Pulls a colour to a vivid mid-tone (Material dark schemes hand out pastel
/// "primary" tones; gradients need saturation to pop).
Color vivid(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.65, 1.0))
      .withLightness(hsl.lightness.clamp(0.42, 0.58))
      .toColor();
}

/// The signature two-tone gradient for a given accent colour.
LinearGradient accentGradient(Color accent) {
  final base = vivid(accent);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base, shiftHue(base, 40)],
  );
}

/// The app's full theme, built for any seed colour and brightness.
ThemeData buildTheme(Color seed, Brightness brightness) {
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  if (brightness == Brightness.dark) {
    // Punchy near-black canvas instead of Material's tinted grey.
    scheme = scheme.copyWith(
      surface: const Color(0xFF0A0A10),
      surfaceContainerLowest: const Color(0xFF07070C),
      surfaceContainerLow: const Color(0xFF12121C),
      surfaceContainer: const Color(0xFF16161F),
      surfaceContainerHigh: const Color(0xFF1D1D29),
      surfaceContainerHighest: const Color(0xFF252533),
    );
  }

  // Typography with personality: Space Grotesk for titles, Outfit for body.
  final base = brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  final body = GoogleFonts.outfitTextTheme(base);
  final textTheme = body.copyWith(
    displaySmall: GoogleFonts.spaceGrotesk(
        textStyle: body.displaySmall, fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineSmall, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.spaceGrotesk(
        textStyle: body.titleLarge, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.titleMedium, fontWeight: FontWeight.w600),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// The APEX wordmark: gradient text in the display face.
class ApexWordmark extends StatelessWidget {
  const ApexWordmark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ShaderMask(
      shaderCallback: (bounds) =>
          accentGradient(scheme.primary).createShader(bounds),
      child: Text(
        'APEX',
        style: GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: size / 3,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Pill-shaped gradient button used for primary actions.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: accentGradient(scheme.primary),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expand ? 0 : 20,
                vertical: 13,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
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
