import 'package:flutter/material.dart';

/// Mechanical theme color scheme
class MechanicalTheme {
  MechanicalTheme._();

  // Primary color - cyan blue
  static const Color primaryCyan = Color(0xFF3DD6F5);
  static const Color primaryCyanDark = Color(0xFF29B5D6);

  // Heat color - orange red
  static const Color heatOrange = Color(0xFFFF6B35);
  static const Color heatRed = Color(0xFFFF4500);

  // Cool color - cyan green
  static const Color coolGreen = Color(0xFF66FF7F);
  static const Color coolTeal = Color(0xFF4ECDC4);

  // Warning color
  static const Color warningYellow = Color(0xFFFFB347);
  static const Color warningRed = Color(0xFFFF6B6B);

  // Mechanical background color
  static const Color bgDark = Color(0xFF0a0a0f);
  static const Color bgMedium = Color(0xFF1a1a2e);
  static const Color bgLight = Color(0xFF16213e);

  // Metal color
  static const Color metalSilver = Color(0xFFC0C0C0);
  static const Color metalGray = Color(0xFF808080);
  static const Color metalDark = Color(0xFF4a4a4a);

  // Text color
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF606060);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, Color(0xFF667EEA)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient heatGradient = LinearGradient(
    colors: [heatOrange, heatRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    colors: [coolGreen, coolTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient metalGradient = LinearGradient(
    colors: [Color(0xFF2a2a3e), Color(0xFF1a1a2e), Color(0xFF2a2a3e)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgMedium, bgDark],
  );

  // Shadow
  static List<BoxShadow> createGlowShadow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 20 * intensity,
        spreadRadius: 2 * intensity,
      ),
      BoxShadow(
        color: color.withOpacity(0.2 * intensity),
        blurRadius: 40 * intensity,
        spreadRadius: 5 * intensity,
      ),
    ];
  }

  static List<BoxShadow> createMechanicalShadow({double intensity = 1.0}) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.5 * intensity),
        blurRadius: 15 * intensity,
        offset: Offset(0, 5 * intensity),
      ),
      BoxShadow(
        color: primaryCyan.withOpacity(0.1 * intensity),
        blurRadius: 25 * intensity,
        offset: Offset(0, 10 * intensity),
      ),
    ];
  }

  // Text style
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.3,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 1,
  );

  // Button style
  static BoxDecoration createPrimaryButtonStyle({
    bool enabled = true,
    double borderRadius = 28,
  }) {
    return BoxDecoration(
      gradient: enabled ? primaryGradient : null,
      color: enabled ? null : metalDark,
      borderRadius: BorderRadius.circular(borderRadius),
      border: enabled ? null : Border.all(color: metalGray, width: 1),
      boxShadow: enabled ? createGlowShadow(primaryCyan) : [],
    );
  }

  static BoxDecoration createHeatButtonStyle({
    bool enabled = true,
    double borderRadius = 28,
  }) {
    return BoxDecoration(
      gradient: enabled ? heatGradient : null,
      color: enabled ? null : metalDark,
      borderRadius: BorderRadius.circular(borderRadius),
      border: enabled ? null : Border.all(color: metalGray, width: 1),
      boxShadow: enabled ? createGlowShadow(heatOrange) : [],
    );
  }

  static BoxDecoration createCoolButtonStyle({
    bool enabled = true,
    double borderRadius = 28,
  }) {
    return BoxDecoration(
      gradient: enabled ? coolGradient : null,
      color: enabled ? null : metalDark,
      borderRadius: BorderRadius.circular(borderRadius),
      border: enabled ? null : Border.all(color: metalGray, width: 1),
      boxShadow: enabled ? createGlowShadow(coolGreen) : [],
    );
  }

  // Card style
  static BoxDecoration createMechanicalCardStyle({
    double borderRadius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: bgLight.withOpacity(0.5),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? primaryCyan.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: createMechanicalShadow(),
    );
  }

  // Input field style
  static InputDecoration createInputStyle({
    String? labelText,
    Color? focusColor,
  }) {
    final color = focusColor ?? primaryCyan;
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: textSecondary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: metalGray, width: 1),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: color, width: 2),
      ),
      filled: true,
      fillColor: bgLight.withOpacity(0.3),
    );
  }
}
