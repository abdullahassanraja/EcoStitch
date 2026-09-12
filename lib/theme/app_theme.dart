import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized EcoStitch Design System Tokens
/// Pure implementation of colors, gradients, and Google Fonts (Fraunces & Manrope)
class AppTheme {
  // Brand Palette
  static const Color mintTop = Color(0xFFDFF0E2);
  static const Color mintMid = Color(0xFFEEF8EF);
  static const Color cream = Color(0xFFFDFDFB);
  static const Color greenDeep = Color(0xFF234430);
  static const Color greenMid = Color(0xFF3F6B4C);
  static const Color greenSoft = Color(0xFF7FA98C);
  static const Color ink = Color(0xFF1C2A20);
  static const Color inkSoft = Color(0xFF5C6B60);
  static const Color thread = Color(0xFFB98A3E);

  // Background Linear Gradient: mintTop -> mintMid -> cream
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mintTop, mintMid, cream],
    stops: [0.0, 0.45, 1.0],
  );

  // Hero Card Swing-Tag Dark Green Gradient
  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF234430), // greenDeep
      Color(0xFF2F543D),
      Color(0xFF3F6B4C), // greenMid
    ],
  );

  // Recent Projects Card Gradient
  static const LinearGradient projectCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF4FAF5),
    ],
  );

  // Tip Banner Tint
  static final Color tipBannerBg = thread.withOpacity(0.08);

  // Google Fonts Typography Presets
  // Brand / Headlines: Fraunces (serif, weight 500-600)
  static TextStyle headlineLarge({Color color = greenDeep}) =>
      GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle headlineMedium({Color color = greenDeep}) =>
      GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle headlineSmall({Color color = greenDeep}) =>
      GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle brandWordmark({Color color = greenDeep}) =>
      GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle statHeroNumber({Color color = cream}) =>
      GoogleFonts.fraunces(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: color,
      );

  // Body / UI / Buttons: Manrope (weight 400-800)
  static TextStyle bodyLarge({Color color = ink}) =>
      GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyMedium({Color color = ink}) =>
      GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  static TextStyle bodySmall({Color color = inkSoft}) =>
      GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle labelCapsFree({Color color = inkSoft}) =>
      GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color,
      );

  static TextStyle statLabel({Color color = inkSoft}) =>
      GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle statValue({Color color = greenDeep}) =>
      GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle buttonText({Color color = cream}) =>
      GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle tipText({Color color = ink}) =>
      GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.35,
      );

  // ThemeData Definition
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      primaryColor: greenDeep,
      colorScheme: const ColorScheme.light(
        primary: greenDeep,
        secondary: greenMid,
        surface: cream,
        onPrimary: cream,
        onSecondary: cream,
        onSurface: ink,
      ),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        displayLarge: headlineLarge(),
        displayMedium: headlineMedium(),
        displaySmall: headlineSmall(),
        bodyLarge: bodyLarge(),
        bodyMedium: bodyMedium(),
        bodySmall: bodySmall(),
      ),
    );
  }
}
