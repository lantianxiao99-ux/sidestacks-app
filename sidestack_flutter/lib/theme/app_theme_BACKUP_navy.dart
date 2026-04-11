import 'package:flutter/material.dart';

// ─── Theme-sensitive colour palette ──────────────────────────────────────────
//
// Brand: Teal #14B8A6 + Navy #0F172A — derived from the SideStacks logo.
// Access in widgets via: AppTheme.of(context).card
// Brand/signal colours identical in both themes stay as static consts.

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

  // ── Dark palette (navy-based) ──────────────────────────────────────────────
  static const dark = AppColors(
    background:   Color(0xFF080E1A), // deeper than the logo navy
    surface:      Color(0xFF0F172A), // logo's own dark navy
    card:         Color(0xFF152033), // slightly lifted navy
    cardAlt:      Color(0xFF1C2B40), // secondary card surface
    border:       Color(0xFF243550), // navy border
    borderLight:  Color(0xFF2E4260), // lighter navy border
    textPrimary:  Color(0xFFE2EEF0), // cool off-white with teal tint
    textSecondary:Color(0xFF7A9BAA), // muted slate-teal
    textMuted:    Color(0xFF4A6B7A), // dark muted teal
  );

  // ── Light palette ──────────────────────────────────────────────────────────
  static const light = AppColors(
    background:   Color(0xFFEBF2F5), // very light teal-grey base
    surface:      Color(0xFFFFFFFF), // pure white sheets
    card:         Color(0xFFFFFFFF), // white cards
    cardAlt:      Color(0xFFEEF5F7), // subtle teal-grey alt
    border:       Color(0xFFC4D6DE), // soft teal-grey border
    borderLight:  Color(0xFFDAEAEE), // very light border
    textPrimary:  Color(0xFF0F172A), // logo navy — rich, not pure black
    textSecondary:Color(0xFF4A6070), // muted navy-teal
    textMuted:    Color(0xFF8EA5B0), // light muted
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
        background: background ?? this.background,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        cardAlt: cardAlt ?? this.cardAlt,
        border: border ?? this.border,
        borderLight: borderLight ?? this.borderLight,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────

class AppTheme {
  // ── Shared brand / signal colours (same in light & dark) ──────────────────
  static const Color accent    = Color(0xFF14B8A6); // logo teal
  static const Color accentDim = Color(0x2014B8A6); // teal at ~12% opacity
  static const Color green     = Color(0xFF3DD68C); // income green
  static const Color greenDim  = Color(0x1F3DD68C);
  static const Color red       = Color(0xFFF1496B); // expense red
  static const Color redDim    = Color(0x1FF1496B);
  static const Color amber     = Color(0xFFF59E0B); // warning amber

  // ── Dark-only static consts (prefer AppTheme.of(context).xxx in widgets) ──
  static const Color background  = Color(0xFF080E1A);
  static const Color surface     = Color(0xFF0F172A);
  static const Color card        = Color(0xFF152033);
  static const Color cardAlt     = Color(0xFF1C2B40);
  static const Color border      = Color(0xFF243550);
  static const Color borderLight = Color(0xFF2E4260);
  static const Color textPrimary   = Color(0xFFE2EEF0);
  static const Color textSecondary = Color(0xFF7A9BAA);
  static const Color textMuted     = Color(0xFF4A6B7A);

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
          fontFamily: 'Sora',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
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
        fillColor: card,
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
      scaffoldBackgroundColor: const Color(0xFFEBF2F5),
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: green,
        surface: Color(0xFFFFFFFF),
        surfaceTint: Colors.transparent,
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEBF2F5),
        elevation: 0,
        scrolledUnderElevation: 1.5,
        shadowColor: Color(0x20000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF4A6070)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF8EA5B0),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A), letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A), letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A), letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A),
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF0F172A),
        ),
        bodySmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF4A6070),
        ),
        labelSmall: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: Color(0xFF8EA5B0), letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC4D6DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC4D6DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF8EA5B0), fontFamily: 'Sora'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFC4D6DE), thickness: 1, space: 0,
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
