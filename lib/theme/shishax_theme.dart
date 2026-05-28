import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ShishaX brand theme. The single source of truth for app styling.
///
/// Replaces the four drifted theme files:
///   - theme/app_colors.dart      (purple/teal, off-brand)
///   - theme/mechanical_theme.dart (cyan/gears, off-brand)
///   - theme/app_theme.dart        (Outfit font, off-brand)
///   - inline page colors (#FF512F / #FF6B35 / #FF9800)
///
/// Tokens mirror the locked brand system and the Lovable glass/glow look:
///   orange  #FF8000   red  #F82629
///   bg      #0A0A0A   surface #1A1A1A
///   Orbitron (display), Space Grotesk (body)
///
/// NOTE on fonts: this uses the google_fonts package (already a dependency).
/// On first run it fetches Orbitron + Space Grotesk over the network and caches
/// them. Because this is a BLE controller that is often used offline, bundle the
/// .ttf files as assets for guaranteed offline rendering. See the integration
/// note shipped with this file.
class ShishaX {
  ShishaX._();

  // ---------------------------------------------------------------------------
  // Core brand colors
  // ---------------------------------------------------------------------------
  static const Color orange = Color(0xFFFF8000); // primary
  static const Color red = Color(0xFFF82629); // accent
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color foreground = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF8C8C8C); // secondary text
  static const Color border = Color(0xFF262626);

  // Status
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = red;

  // ---------------------------------------------------------------------------
  // Gradients (brand orange -> red)
  // ---------------------------------------------------------------------------
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, red],
  );

  static const LinearGradient brandGradientHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [orange, red],
  );

  // ---------------------------------------------------------------------------
  // Glow shadows
  // ---------------------------------------------------------------------------
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.5,
    double blur = 20,
    double spread = 0,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withOpacity(opacity * 0.4),
        blurRadius: blur * 3,
        spreadRadius: spread,
      ),
    ];
  }

  static List<BoxShadow> get orangeGlow => glow(orange);

  // ---------------------------------------------------------------------------
  // Glass panel decoration (frosted translucent card, the Lovable signature)
  // ---------------------------------------------------------------------------
  static BoxDecoration glass({
    double radius = 16,
    Color? borderColor,
    double fill = 0.04,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(fill),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.08),
        width: 1,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Type helpers
  // ---------------------------------------------------------------------------
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = foreground,
    double spacing = 0.5,
  }) {
    return GoogleFonts.orbitron(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
    );
  }

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = foreground,
    double spacing = 0,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
    );
  }

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final base = ThemeData.dark();
    final text = GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: foreground, displayColor: foreground)
        .copyWith(
          displayLarge: GoogleFonts.orbitron(
            textStyle: base.textTheme.displayLarge,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
          displayMedium: GoogleFonts.orbitron(
            textStyle: base.textTheme.displayMedium,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
          headlineMedium: GoogleFonts.orbitron(
            textStyle: base.textTheme.headlineMedium,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
          titleLarge: GoogleFonts.orbitron(
            textStyle: base.textTheme.titleLarge,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: orange,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        secondary: red,
        surface: surface,
        background: background,
        error: red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: foreground,
        onBackground: foreground,
      ),
      textTheme: text,
      iconTheme: const IconThemeData(color: foreground),
      dividerColor: border,
      splashColor: orange.withOpacity(0.12),
      highlightColor: Colors.transparent,
    );
  }
}

/// Brand orange -> red gradient text. Use for the ShishaX wordmark and
/// any headline that should carry the brand gradient.
class BrandGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const BrandGradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          ShishaX.brandGradientHorizontal.createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
