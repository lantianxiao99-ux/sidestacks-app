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

  // ── Light palette — clean white ───────────────────────────────────────────
  static const light = AppColors(
    background:    Color(0xFFF2F4F6), // neutral light gray — cards pop against it
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    cardAlt:       Color(0xFFF2F4F6),
    border:        Color(0xFFE4E8EC), // soft, barely visible border
    borderLight:   Color(0xFFEFF1F3),
    textPrimary:   Color(0xFF0D1117), // near-black — crisp on white
    textSecondary: Color(0xFF57606A), // medium gray
    textMuted:     Color(0xFF8C959F), // light gray
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
  static const Color accent    = Color(0xFF0D9488); // teal — deeper, more authoritative
  static const Color accentDim = Color(0x120D9488); // ~7 % teal
  static const Color green     = Color(0xFF16A34A); // income — richer, less neon
  static const Color greenDim  = Color(0x1216A34A);
  static const Color red       = Color(0xFFDC2626); // errors / destructive only
  static const Color redDim    = Color(0x12DC2626);
  static const Color amber     = Color(0xFFD97706); // warning
  static const Color expense   = Color(0xFF64748B); // expense amounts — slate, not alarming

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
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Sora', fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Sora', fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w400, color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: textMuted,
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
      scaffoldBackgroundColor: const Color(0xFFF2F4F6),
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: green,
        surface: Color(0xFFFFFFFF),
        surfaceTint: Colors.transparent,
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F4F6),
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
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Sora', fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Sora', fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: Color(0xFF111A18), letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600,
          color: Color(0xFF111A18), letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: Color(0xFF111A18), letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
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
          fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF8AA09A),
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
