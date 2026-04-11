import 'package:flutter/material.dart';

// ─── Theme-sensitive colour palette ──────────────────────────────────────────
//
// Access in widgets via: AppTheme.of(context).card
// Brand/signal colours that are identical in both themes stay as static
// consts on AppTheme and require no context.

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

  // ── Dark palette ───────────────────────────────────────────────────────────
  static const dark = AppColors(
    background: Color(0xFF0A0B0F),
    surface: Color(0xFF111217),
    card: Color(0xFF18191F),
    cardAlt: Color(0xFF1E1F28),
    border: Color(0xFF2A2B36),
    borderLight: Color(0xFF353645),
    textPrimary: Color(0xFFEEF0F8),
    textSecondary: Color(0xFF8B8FA8),
    textMuted: Color(0xFF5A5D72),
  );

  // ── Light palette ──────────────────────────────────────────────────────────
  static const light = AppColors(
    background:    Color(0xFFEBEDF4), // mid-grey-blue base — cards float above it
    surface:       Color(0xFFFFFFFF), // pure white for bottom sheets
    card:          Color(0xFFFFFFFF), // white cards clearly lifted off background
    cardAlt:       Color(0xFFF4F5FA), // neutral grey, no purple tint
    border:        Color(0xFFD2D4E0), // visible without being harsh
    borderLight:   Color(0xFFE2E4EF),
    textPrimary:   Color(0xFF0D0E1A),
    textSecondary: Color(0xFF52556A), // slightly darker for readability
    textMuted:     Color(0xFF9196AD),
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
  static const Color green = Color(0xFF3DD68C);
  static const Color greenDim = Color(0x1F3DD68C);
  static const Color red = Color(0xFFF1496B);
  static const Color redDim = Color(0x1FF1496B);
  static const Color accent = Color(0xFF6C6FFF);
  static const Color accentDim = Color(0x266C6FFF);
  static const Color amber = Color(0xFFF59E0B);

  // ── Dark-only static consts (used inside ThemeData definitions below) ─────
  // Prefer AppTheme.of(context).xxx in widgets.
  static const Color background = Color(0xFF0A0B0F);
  static const Color surface = Color(0xFF111217);
  static const Color card = Color(0xFF18191F);
  static const Color cardAlt = Color(0xFF1E1F28);
  static const Color border = Color(0xFF2A2B36);
  static const Color borderLight = Color(0xFF353645);
  static const Color textPrimary = Color(0xFFEEF0F8);
  static const Color textSecondary = Color(0xFF8B8FA8);
  static const Color textMuted = Color(0xFF5A5D72);

  // ── Context-aware colour lookup ────────────────────────────────────────────
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.dark;

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0B0F),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: green,
        surface: Color(0xFF111217),
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0B0F),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEF0F8),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF8B8FA8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF111217),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF5A5D72),
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
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEEF0F8),
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEF0F8),
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEF0F8),
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEF0F8),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFFEEF0F8),
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Color(0xFF8B8FA8),
        ),
        labelSmall: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5A5D72),
          letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF18191F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2B36)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2B36)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(
            color: Color(0xFF5A5D72), fontFamily: 'Sora'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2B36),
        thickness: 1,
        space: 0,
      ),
      extensions: const [AppColors.dark],
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFEBEDF4),
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: green,
        surface: Color(0xFFFFFFFF),
        // Disable M3 surface tint — stops purple bleeding into AppBar/dialogs
        surfaceTint: Colors.transparent,
        error: red,
      ),
      fontFamily: 'Sora',
      appBarTheme: const AppBarTheme(
        // Match scaffold background so it reads as part of the page
        backgroundColor: Color(0xFFEBEDF4),
        elevation: 0,
        // Gentle shadow when content scrolls underneath
        scrolledUnderElevation: 1.5,
        shadowColor: Color(0x20000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D0E1A),
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF52556A)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        // White bottom bar contrasts nicely with the grey-blue scaffold
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF9196AD),
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
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0D0E1A),
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D0E1A),
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D0E1A),
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D0E1A),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF0D0E1A),
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Color(0xFF52556A),
        ),
        labelSmall: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9196AD),
          letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD2D4E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD2D4E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(
            color: Color(0xFF9196AD), fontFamily: 'Sora'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFD2D4E0),
        thickness: 1,
        space: 0,
      ),
      // Prevent M3 from tinting dialogs/bottom sheets with purple
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
