// KAMOS — Theme + token extension.
//
// Mirrors `_workspace/01_design/colors_and_type.css` verbatim. Widgets read
// tokens by name from `KamosTokens` and `Theme.of(context)`; no hex / px
// literals in widget code anywhere else in the app.

import 'package:flutter/material.dart';

@immutable
class KamosTokens extends ThemeExtension<KamosTokens> {
  const KamosTokens({
    required this.mizu,
    required this.sora,
    required this.hanada,
    required this.ai,
    required this.kon,
    required this.rurikon,
    required this.sumi,
    required this.shironeri,
    required this.kinari,
    required this.gray50,
    required this.gray100,
    required this.gray200,
    required this.gray300,
    required this.gray400,
    required this.gray500,
    required this.gray600,
    required this.gray700,
    required this.gray800,
    required this.koh,
    required this.matcha,
    required this.akane,
    required this.yamabuki,
    required this.bgPage,
    required this.bgSurface,
    required this.bgSunken,
    required this.bgWarm,
    required this.bgBrand,
    required this.bgBrandDeep,
    required this.bgTintMizu,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fgMuted,
    required this.fgOnDark,
    required this.fgLink,
    required this.fgBrand,
    required this.border1,
    required this.border2,
    required this.borderStrong,
    required this.fgSuccess,
    required this.fgWarning,
    required this.fgDanger,
    required this.bgSuccess,
    required this.bgWarning,
    required this.bgDanger,
  });

  // Japanese-blue palette
  final Color mizu;
  final Color sora;
  final Color hanada;
  final Color ai;
  final Color kon;
  final Color rurikon;
  final Color sumi;
  final Color shironeri;
  final Color kinari;
  final Color gray50;
  final Color gray100;
  final Color gray200;
  final Color gray300;
  final Color gray400;
  final Color gray500;
  final Color gray600;
  final Color gray700;
  final Color gray800;
  final Color koh;
  final Color matcha;
  final Color akane;
  final Color yamabuki;

  // Surfaces
  final Color bgPage;
  final Color bgSurface;
  final Color bgSunken;
  final Color bgWarm;
  final Color bgBrand;
  final Color bgBrandDeep;
  final Color bgTintMizu;

  // Text
  final Color fg1;
  final Color fg2;
  final Color fg3;
  final Color fgMuted;
  final Color fgOnDark;
  final Color fgLink;
  final Color fgBrand;

  // Borders
  final Color border1;
  final Color border2;
  final Color borderStrong;

  // Status
  final Color fgSuccess;
  final Color fgWarning;
  final Color fgDanger;
  final Color bgSuccess;
  final Color bgWarning;
  final Color bgDanger;

  // Spacing scale (4px base) — exposed as constants so widgets do not
  // recompute multiples by hand.
  double get space1 => 4;
  double get space2 => 8;
  double get space3 => 12;
  double get space4 => 16;
  double get space5 => 20;
  double get space6 => 24;
  double get space7 => 32;
  double get space8 => 40;
  double get space9 => 48;
  double get space10 => 64;

  // Radii
  double get radiusXs => 4;
  double get radiusSm => 8;
  double get radiusMd => 12;
  double get radiusLg => 16;
  double get radiusXl => 24;
  double get radiusPill => 999;

  // Motion
  Duration get durFast => const Duration(milliseconds: 120);
  Duration get durBase => const Duration(milliseconds: 200);
  Duration get durSlow => const Duration(milliseconds: 320);

  // Layout
  double get mobileMax => 420;

  static const light = KamosTokens(
    mizu: Color(0xFFB6D6E2),
    sora: Color(0xFF88B7D6),
    hanada: Color(0xFF4A86A8),
    ai: Color(0xFF165E83),
    kon: Color(0xFF0F2350),
    rurikon: Color(0xFF1B264F),
    sumi: Color(0xFF14171F),
    shironeri: Color(0xFFFCFAF6),
    kinari: Color(0xFFF4EFE6),
    gray50: Color(0xFFF5F7FA),
    gray100: Color(0xFFECEFF4),
    gray200: Color(0xFFDCE2EA),
    gray300: Color(0xFFC2CBD6),
    gray400: Color(0xFF95A2B3),
    gray500: Color(0xFF6B7787),
    gray600: Color(0xFF4A5462),
    gray700: Color(0xFF2F3640),
    gray800: Color(0xFF1B1F26),
    koh: Color(0xFFC97B5A),
    matcha: Color(0xFF6B8E5C),
    akane: Color(0xFFA23B3B),
    yamabuki: Color(0xFFD4A845),
    bgPage: Color(0xFFFCFAF6),
    bgSurface: Color(0xFFFFFFFF),
    bgSunken: Color(0xFFF5F7FA),
    bgWarm: Color(0xFFF4EFE6),
    bgBrand: Color(0xFF165E83),
    bgBrandDeep: Color(0xFF0F2350),
    bgTintMizu: Color(0xFFEAF3F8),
    fg1: Color(0xFF14171F),
    fg2: Color(0xFF4A5462),
    fg3: Color(0xFF6B7787),
    fgMuted: Color(0xFF95A2B3),
    fgOnDark: Color(0xFFFCFAF6),
    fgLink: Color(0xFF165E83),
    fgBrand: Color(0xFF165E83),
    border1: Color(0xFFDCE2EA),
    border2: Color(0xFFC2CBD6),
    borderStrong: Color(0xFF2F3640),
    fgSuccess: Color(0xFF6B8E5C),
    fgWarning: Color(0xFFD4A845),
    fgDanger: Color(0xFFA23B3B),
    bgSuccess: Color(0xFFE8EFE3),
    bgWarning: Color(0xFFF6EBCB),
    bgDanger: Color(0xFFF4DFDF),
  );

  @override
  KamosTokens copyWith({Color? ai}) => this;

  @override
  KamosTokens lerp(ThemeExtension<KamosTokens>? other, double t) => this;
}

extension KamosTokensX on BuildContext {
  KamosTokens get tokens => Theme.of(this).extension<KamosTokens>()!;
}

ThemeData buildKamosTheme() {
  const t = KamosTokens.light;

  // Display: Shippori Mincho (substitution flag in design HANDOFF.md).
  // Body: Noto Sans JP. Mono: JetBrains Mono. We do not bundle the fonts;
  // the OS falls back through the cascade Hiragino → Yu Mincho → Songti SC.
  // Substitution is documented in README_flutter.md.
  const displayFamily = 'ShipporiMincho';
  const bodyFamily = 'NotoSansJP';

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.ai,
      primary: t.ai,
      onPrimary: Colors.white,
      surface: t.bgSurface,
      onSurface: t.fg1,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: t.bgPage,
    fontFamily: bodyFamily,
    fontFamilyFallback: const [
      'Noto Sans JP',
      'Noto Sans KR',
      '.AppleSystemUIFont',
      'Helvetica Neue',
      'Arial',
      'sans-serif',
    ],
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: displayFamily, fontSize: 44, height: 1.1, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontFamily: displayFamily, fontSize: 32, height: 1.25, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontFamily: displayFamily, fontSize: 24, height: 1.25, fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(fontFamily: displayFamily, fontSize: 22, height: 1.25, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontFamily: bodyFamily, fontSize: 20, height: 1.3, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontFamily: bodyFamily, fontSize: 16, height: 1.55, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: bodyFamily, fontSize: 16, height: 1.55, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontFamily: bodyFamily, fontSize: 14, height: 1.55, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontFamily: bodyFamily, fontSize: 12, height: 1.3, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontFamily: bodyFamily, fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontFamily: bodyFamily, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3),
    ),
    extensions: const [KamosTokens.light],
  );

  return base.copyWith(
    // Typography metadata for mono (used inline via TextStyle factories).
    appBarTheme: AppBarTheme(
      backgroundColor: t.bgPage,
      foregroundColor: t.fg1,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: displayFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: DividerThemeData(color: t.border1, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.bgSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.border2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.ai, width: 1.5),
      ),
      hintStyle: TextStyle(color: t.fgMuted, fontFamily: bodyFamily),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.ai,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.fg1,
        backgroundColor: t.bgSurface,
        side: BorderSide(color: t.border2),
        textStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.fgLink,
        textStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.kon,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontFamily: bodyFamily,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

/// Convenience styles that don't live in [ThemeData] — overline, mono.
class KamosTextStyles {
  static const overline = TextStyle(
    fontFamily: 'NotoSansJP',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
  );
  static const mono = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const monoSmall = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
