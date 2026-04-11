import 'package:flutter/material.dart';

// ─── Theme-sensitive colour palette ──────────────────────────────────────────
//
// "Stone + Teal" — near-neutral dark surfaces, teal pops as the sole brand
// colour. Backgrounds have a microscopic warm-green tint so teal feels at
// home without the "navy soup" effect.
//
// Access in widgets via: AppTheme.of(context).card
// Brand/signal colours (same in both themes) stay as static consts.

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // ── Dark palette — near-black warm-stone ──────────────────────────────────
  static const dark = AppColors(
    background:    Color(0xFF0F1110), // near-black, tiny warm-green tint
    surface:       Color(0xFF161918), // slightly lifted — sheets / nav bar
    card:          Color(0xFF1C1F1E), // card surfaces
    cardAlt:       Color(0xFF232726), // secondary / input backgrounds
    border:        Color(0xFF2C302F), // dividers and outlines
    borderLight:   Color(0xFF363B3A), // lighter outline / focused states
    textPrimary:   Color(0xFFF2F5F4), // warm near-white
    textSecondary: Color(0xFF8A9693), // muted warm grey-green
    textMuted:     Color(0xFF506060), // very dim — timestamps, labels
  );

  // ── Light palette — warm off-white ────────────────────────────────────────
  static const light = AppColors(
    background:    Color(0xFFF0F3F2), // warm off-white base
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    cardAlt:       Color(0xFFECEFEE),
    border:        Color(0xFFD4DBD9),
    borderLight:   Color(0xFFE2E8E6),
    textPrimary:   Color(0xFF111A18), // rich warm dark
    textSecondary: Color(0xFF4A6060),
    textMuted:     Color(0xFF8AA09A),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardAlt,
    Color? border,
    Color? borderLight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) =>
      AppColors(
        background:    background    ?? this.background,
        surface:       surface       ?? this.surface,
        card:          card          ?? this.card,
        cardAlt:       cardAlt       ?? this.cardAlt,
        border:        border        ?? this.border,
        borderLight:   borderLight   ?? this.borderLight,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      cardAlt:       Color.lerp(cardAlt,       other.cardAlt,       t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      borderLight:   Color.lerp(borderLight,   other.borderLight,   t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
    );
  }
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────

class AppTheme {
  // ── Brand / signal colours — identical in light & dark ────────────────────
  static const Color accent    = Color(0xFF14B8A6); // logo teal
  // accentDim is intentionally very low opacity so icon boxes read as
  // "elevated surface" not "coloured blob".
  static const Color accentDim = Color(0x1214B8A6); // ~7 % teal
  static const Color green     = Color(0xFF22C55E); // income
  static const Color greenDim  = Color(0x1222C55E);
  static const Color red       = Color(0xFFEF4444); // expense
  static const Color redDim    = Color(0x12EF4444);
  static const Color amber     = Color(0xFFF59E0B); // warning

  // ── Dark-only static consts (prefer AppTheme.of(context).xxx in widgets) ──
  static const Color background    = Color(0xFF0F1110);
  static const Color surface       = Color(0xFF161918);
  static const Color card          = Color(0xFF1C1F1E);
  static const Color cardAlt       = Color(0xFF232726);
  static const Color border        = Color(0xFF2C302F);
  static const Color borderLight   = Color(0xFF363B3A);
  static const Color textPrimary   = Color(0xFFF2F5F4);
  static const Color textSecondary = Color(0xFF8A9693);
  static const Color textMuted     = Color(0xFF506060);

  // ── Context-aware colour lookup ────────────────────────────────────────────
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.dark;

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: green,
        surface: surface,
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Sora', fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 0.8,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Sora', fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 0.8,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w400, color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: textMuted, letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontFamily: 'Sora'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: border, thickness: 1, space: 0,
      ),
      extensions: const [AppColors.dark],
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF0F3F2),
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: green,
        surface: Color(0xFFFFFFFF),
        surfaceTint: Colors.transparent,
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF0F3F2),
        elevation: 0,
        scrolledUnderElevation: 1.5,
        shadowColor: Color(0x18000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111A18),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF4A6060)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF8AA09A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Sora', fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 0.8,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Sora', fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 0.8,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: Color(0xFF111A18), letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: Color(0xFF111A18), letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: Color(0xFF111A18), letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Color(0xFF111A18),
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: Color(0xFF111A18),
        ),
        bodySmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w400,
          color: Color(0xFF4A6060),
        ),
        labelSmall: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: Color(0xFF8AA09A), letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4DBD9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4DBD9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(
            color: Color(0xFF8AA09A), fontFamily: 'Sora'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFD4DBD9), thickness: 1, space: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [AppColors.light],
    );
  }
}
