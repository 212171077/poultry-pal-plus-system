import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// APP THEME - Production-Ready Design System for Poultry Pal Plus
/// ============================================================================
/// 
/// This file contains the complete theme implementation for the app, including:
/// - Color system (light & dark modes)
/// - Typography scale (Google Fonts)
/// - Component theming
/// - Spacing system
/// - Elevation and shadow system
///
/// Design Philosophy:
/// Modern, clean, and farmer-friendly UI with earthy tones inspired by farming.
/// Prioritizes clarity, readability, and usability in outdoor environments.
/// ============================================================================

// ============================================================================
// COLOR SYSTEM
// ============================================================================

/// Centralized color palette for the entire app.
///
/// ── DESIGN RATIONALE ──────────────────────────────────────────────────────
/// Brown is the primary brand color — grounding the identity in the earth,
/// soil, and rustic warmth of farming. Paired with a warm harvest gold as the
/// secondary accent and neutral system colors for text/backgrounds, the
/// palette feels rich, professional, and distinctly farm-relevant.
///
/// Palette direction: "Rich Farmhouse Dashboard"
///   Primary   → #8B5A2B  warm sienna brown  — earthy, bold, high-contrast
///   Secondary → #F4A623  harvest amber/gold  — sun/grain warmth, accent
///   Backgrounds → barely-warm cream neutrals — harmonise with brown primary
///   Dark mode → dark brown-tinted surfaces   — cohesive depth & warmth
///   Semantics → vibrant and clearly distinct — strong data-state signalling
/// ──────────────────────────────────────────────────────────────────────────
abstract class AppColors {

  // ── PRIMARY — Warm Sienna Brown ──────────────────────────────────────────
  // WHY: #8B5A2B is a rich, warm sienna brown — modern enough for a
  // dashboard while rooted in the earthy farming identity. Contrast ratio
  // ~5.4:1 with white text → WCAG AA compliant for buttons & large text.
  // Far more vibrant and readable than a muddy, desaturated brown.
  static const Color primary      = Color(0xFF8B5A2B); // Warm sienna brown
  static const Color primaryLight = Color(0xFFA6703F); // Lighter for dark-mode use
  static const Color primaryDark  = Color(0xFF6B4320); // Deeper for pressed/hover

  // ── SECONDARY — Harvest Amber / Gold ─────────────────────────────────────
  // WHY: Amber (#F4A623) sits naturally alongside brown — like wheat beside
  // soil, or sunlight on a barn. It adds warmth and energy without competing
  // with the primary. Used for accents, badges, icons, and highlights.
  // ⚠ Use dark text (textPrimaryLight) on amber backgrounds — not white.
  static const Color secondary      = Color(0xFFF4A623); // Warm harvest amber
  static const Color secondaryLight = Color(0xFFF7BC55); // Lighter golden
  static const Color secondaryDark  = Color(0xFFD4890F); // Deeper amber

  // ── BACKGROUNDS & SURFACES — Light Mode ──────────────────────────────────
  // WHY: A barely-warm cream (#FAF7F4) harmonises with brown primary without
  // feeling muddy. Surface variant (#F4EDE5) is a soft warm cream — it
  // clearly distinguishes input fills and cards while feeling cohesive.
  static const Color backgroundLight     = Colors.white; // Barely warm cream
  //static const Color backgroundLight     = Color(0xFFFAF7F4); // Barely warm cream
  static const Color surfaceLight        = Color(0xFFFFFFFF); // Pure white (cards)
  static const Color surfaceVariantLight = Color(0xFFF4EDE5); // Warm cream fill

  // ── BACKGROUNDS & SURFACES — Dark Mode ───────────────────────────────────
  // WHY: Dark surfaces are given a subtle warm brown tint (#1A1410) that
  // echoes the primary without being too heavy. Cards and surface variants
  // step progressively lighter to maintain clear visual hierarchy.
  static const Color backgroundDark     = Color(0xFF1A1410); // Deep dark warm
  static const Color surfaceDark        = Color(0xFF261C14); // Slightly lighter
  static const Color surfaceVariantDark = Color(0xFF33251A); // Medium warm dark

  // ── TEXT — Light Mode ─────────────────────────────────────────────────────
  // WHY: Neutral iOS-system grays ensure numbers and data labels are easy to
  // scan with no color interference from the brown primary.
  static const Color textPrimaryLight   = Color(0xFF1C1C1E); // Near-black (neutral)
  static const Color textSecondaryLight = Color(0xFF636366); // Medium neutral gray
  static const Color textTertiaryLight  = Color(0xFFAEAEB2); // Lighter hint gray
  static const Color textDisabledLight  = Color(0xFFC7C7CC); // Disabled state

  // ── TEXT — Dark Mode ──────────────────────────────────────────────────────
  // WHY: Soft off-white (#F2F2F7) avoids OLED glare. Grays mirror the
  // light-mode scale for a cohesive, readable dark experience.
  static const Color textPrimaryDark   = Color(0xFFF2F2F7); // Soft off-white
  static const Color textSecondaryDark = Color(0xFFAEAEB2); // Medium gray
  static const Color textTertiaryDark  = Color(0xFF636366); // Darker hint gray
  static const Color textDisabledDark  = Color(0xFF48484A); // Disabled state

  // ── SEMANTIC COLORS ───────────────────────────────────────────────────────
  // WHY: All four semantic colors are clearly distinct from the brown primary
  // AND from each other, preventing confusion in dashboards and data views.
  //   Success (#22C55E) — fresh bright green, instantly positive
  //   Error   (#EF4444) — clean modern red, clearly destructive
  //   Warning (#F59E0B) — deep amber; close to secondary but used contextually
  //   Info    (#3B82F6) — calm sky blue; weather-app feel, farm-friendly
  static const Color success      = Color(0xFF22C55E); // Bright fresh green
  static const Color successLight = Color(0xFF4ADE80); // Lighter success tint
  static const Color error        = Color(0xFFEF4444); // Clean modern red
  static const Color errorLight   = Color(0xFFF87171); // Softer error tint
  static const Color warning      = Color(0xFFF59E0B); // Warm amber warning
  static const Color warningLight = Color(0xFFFCD34D); // Light warning tint
  static const Color info         = Color(0xFF3B82F6); // Sky blue info
  static const Color infoLight    = Color(0xFF60A5FA); // Lighter info tint

  // ── BORDERS & DIVIDERS ────────────────────────────────────────────────────
  // WHY: Warm beige borders (#E5D9CE) harmonise with the cream background and
  // brown primary — visually cohesive without adding noise.
  static const Color borderLight  = Color(0xFFE5D9CE); // Warm beige border
  static const Color borderDark   = Color(0xFF3D2E22); // Dark warm border
  static const Color dividerLight = Color(0xFFEDE4D8); // Warm light divider
  static const Color dividerDark  = Color(0xFF2E2218); // Dark warm divider

  // ── SHADOWS ───────────────────────────────────────────────────────────────
  static const Color shadowLight = Color(0xFF000000);
  static const Color shadowDark  = Color(0xFF000000);
}

// ============================================================================
// SPACING SYSTEM
// ============================================================================

/// Standardized spacing constants for consistent layout and padding.
/// Use these throughout the app to maintain visual harmony.
abstract class AppSpacing {
  static const double xs = 4.0; // Extra small
  static const double sm = 8.0; // Small
  static const double md = 16.0; // Medium (default)
  static const double lg = 24.0; // Large
  static const double xl = 32.0; // Extra large
  static const double xxl = 48.0; // Extra extra large

  // Common compound spacings
  static const double cardPadding = md;
  static const double screenPadding = md;
  static const double dialogPadding = lg;
  static const double inputSpacing = md;
}

// ============================================================================
// BORDER RADIUS SYSTEM
// ============================================================================

/// Standardized border radius constants for consistent corner rounding.
abstract class AppBorderRadius {
  static const double xs = 4.0; // Extra small (minimal rounding)
  static const double sm = 8.0; // Small
  static const double md = 12.0; // Medium (default)
  static const double lg = 16.0; // Large
  static const double xl = 20.0; // Extra large
  static const double circle = 50.0; // Circle/pill shape

  // Common BorderRadius objects
  static BorderRadius radiusXs = BorderRadius.circular(xs);
  static BorderRadius radiusSm = BorderRadius.circular(sm);
  static BorderRadius radiusMd = BorderRadius.circular(md);
  static BorderRadius radiusLg = BorderRadius.circular(lg);
  static BorderRadius radiusXl = BorderRadius.circular(xl);
}

// ============================================================================
// ELEVATION & SHADOW SYSTEM
// ============================================================================

/// Standardized elevation and shadow definitions for depth.
abstract class AppElevation {
  static const double xs = 1.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;

  // Common shadow definitions
  static final List<BoxShadow> shadowXs = [
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.12),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.12),
      blurRadius: 2,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.15),
      blurRadius: 4,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> shadowXl = [
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.20),
      blurRadius: 16,
      offset: const Offset(0, 16),
    ),
  ];
}

// ============================================================================
// TYPOGRAPHY SYSTEM
// ============================================================================

/// Typography scale using Google Fonts (Poppins for headings, Inter for body).
/// Ensures consistent, readable text across the app.
class AppTypography {
  // ---- Display Styles (Large, prominent text) ----
  static TextStyle displayLarge({required Color color}) {
    return GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color,
      height: 1.2,
    );
  }

  static TextStyle displayMedium({required Color color}) {
    return GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color,
      height: 1.25,
    );
  }

  // ---- Heading Styles ----
  static TextStyle titleLarge({required Color color}) {
    return GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle titleMedium({required Color color}) {
    return GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color,
      height: 1.35,
    );
  }

  static TextStyle titleSmall({required Color color}) {
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: color,
      height: 1.4,
    );
  }

  // ---- Body Styles ----
  static TextStyle bodyLarge({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle bodySmall({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: color,
      height: 1.5,
    );
  }

  // ---- Label Styles ----
  static TextStyle labelLarge({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle labelMedium({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle labelSmall({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.3,
    );
  }

  // ---- Caption Style ----
  static TextStyle caption({required Color color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: color,
      height: 1.4,
    );
  }
}

// ============================================================================
// MAIN APP THEME CLASS
// ============================================================================

/// Central theme provider for the entire app.
/// Exposes lightTheme and darkTheme as production-ready ThemeData objects.
class AppTheme {
  // ---- Light Theme ----
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // ---- Color Scheme ----
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.secondary,
        tertiary: AppColors.info,
        onTertiary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: AppColors.error,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.dividerLight,
        scrim: AppColors.backgroundLight,
      ),

      // ---- Scaffold ----
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // ---- AppBar Theme ----
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge(
          color: AppColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 24,
        ),
      ),

      // ---- Card Theme ----
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: AppElevation.sm,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusMd,
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),

      // ---- Elevated Button Theme ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          elevation: AppElevation.md,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.radiusMd,
          ),
          textStyle: AppTypography.labelLarge(
            color: Colors.white,
          ),
        ),
      ),

      // ---- Text Button Theme ----
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.labelLarge(
            color: AppColors.primary,
          ),
        ),
      ),

      // ---- Outlined Button Theme ----
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.radiusMd,
            side: const BorderSide(color: AppColors.primary),
          ),
          textStyle: AppTypography.labelLarge(
            color: AppColors.primary,
          ),
        ),
      ),

      // ---- Input Decoration Theme ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        hintStyle: AppTypography.bodyMedium(
          color: AppColors.textTertiaryLight,
        ),
        labelStyle: AppTypography.bodyMedium(
          color: AppColors.textSecondaryLight,
        ),
        errorStyle: AppTypography.bodySmall(
          color: AppColors.error,
        ),
      ),

      // ---- Bottom Navigation Bar Theme ----
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryLight,
        elevation: AppElevation.lg,
        type: BottomNavigationBarType.fixed,
      ),

      // ---- Dialog Theme ----
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: AppElevation.lg,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusLg,
        ),
      ),

      // ---- Floating Action Button Theme ----
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppElevation.lg,
        shape: CircleBorder(),
      ),

      // ---- Divider Theme ----
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: AppSpacing.md,
      ),

      // ---- Progress Indicator Theme ----
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariantLight,
      ),

      // ---- Chip Theme ----
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        selectedColor: AppColors.primary,
        labelStyle: AppTypography.labelMedium(
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: AppTypography.labelMedium(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusSm,
        ),
      ),

      // ---- Text Theme ----
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge(
          color: AppColors.textPrimaryLight,
        ),
        displayMedium: AppTypography.displayMedium(
          color: AppColors.textPrimaryLight,
        ),
        titleLarge: AppTypography.titleLarge(
          color: AppColors.textPrimaryLight,
        ),
        titleMedium: AppTypography.titleMedium(
          color: AppColors.textPrimaryLight,
        ),
        titleSmall: AppTypography.titleSmall(
          color: AppColors.textPrimaryLight,
        ),
        bodyLarge: AppTypography.bodyLarge(
          color: AppColors.textPrimaryLight,
        ),
        bodyMedium: AppTypography.bodyMedium(
          color: AppColors.textSecondaryLight,
        ),
        bodySmall: AppTypography.bodySmall(
          color: AppColors.textTertiaryLight,
        ),
        labelLarge: AppTypography.labelLarge(
          color: AppColors.textPrimaryLight,
        ),
        labelMedium: AppTypography.labelMedium(
          color: AppColors.textSecondaryLight,
        ),
        labelSmall: AppTypography.labelSmall(
          color: AppColors.textTertiaryLight,
        ),
      ),
    );
  }

  // ---- Dark Theme ----
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ---- Color Scheme ----
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.secondaryLight,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: Colors.white,
        tertiary: AppColors.infoLight,
        onTertiary: Colors.white,
        error: AppColors.errorLight,
        onError: Colors.white,
        errorContainer: AppColors.error,
        onErrorContainer: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.surfaceVariantDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.dividerDark,
        scrim: AppColors.backgroundDark,
      ),

      // ---- Scaffold ----
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // ---- AppBar Theme ----
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge(
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.primaryLight,
          size: 24,
        ),
      ),

      // ---- Card Theme ----
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: AppElevation.sm,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusMd,
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),

      // ---- Elevated Button Theme ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          elevation: AppElevation.md,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.radiusMd,
          ),
          textStyle: AppTypography.labelLarge(
            color: Colors.white,
          ),
        ),
      ),

      // ---- Text Button Theme ----
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.labelLarge(
            color: AppColors.primaryLight,
          ),
        ),
      ),

      // ---- Outlined Button Theme ----
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.radiusMd,
            side: const BorderSide(color: AppColors.primaryLight),
          ),
          textStyle: AppTypography.labelLarge(
            color: AppColors.primaryLight,
          ),
        ),
      ),

      // ---- Input Decoration Theme ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.borderDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.borderDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.errorLight,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.radiusMd,
          borderSide: const BorderSide(
            color: AppColors.errorLight,
            width: 2,
          ),
        ),
        hintStyle: AppTypography.bodyMedium(
          color: AppColors.textTertiaryDark,
        ),
        labelStyle: AppTypography.bodyMedium(
          color: AppColors.textSecondaryDark,
        ),
        errorStyle: AppTypography.bodySmall(
          color: AppColors.errorLight,
        ),
      ),

      // ---- Bottom Navigation Bar Theme ----
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textTertiaryDark,
        elevation: AppElevation.lg,
        type: BottomNavigationBarType.fixed,
      ),

      // ---- Dialog Theme ----
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: AppElevation.lg,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusLg,
        ),
      ),

      // ---- Floating Action Button Theme ----
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: AppElevation.lg,
        shape: CircleBorder(),
      ),

      // ---- Divider Theme ----
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: AppSpacing.md,
      ),

      // ---- Progress Indicator Theme ----
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.surfaceVariantDark,
      ),

      // ---- Chip Theme ----
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantDark,
        selectedColor: AppColors.primaryLight,
        labelStyle: AppTypography.labelMedium(
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: AppTypography.labelMedium(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.radiusSm,
        ),
      ),

      // ---- Text Theme ----
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge(
          color: AppColors.textPrimaryDark,
        ),
        displayMedium: AppTypography.displayMedium(
          color: AppColors.textPrimaryDark,
        ),
        titleLarge: AppTypography.titleLarge(
          color: AppColors.textPrimaryDark,
        ),
        titleMedium: AppTypography.titleMedium(
          color: AppColors.textPrimaryDark,
        ),
        titleSmall: AppTypography.titleSmall(
          color: AppColors.textPrimaryDark,
        ),
        bodyLarge: AppTypography.bodyLarge(
          color: AppColors.textPrimaryDark,
        ),
        bodyMedium: AppTypography.bodyMedium(
          color: AppColors.textSecondaryDark,
        ),
        bodySmall: AppTypography.bodySmall(
          color: AppColors.textTertiaryDark,
        ),
        labelLarge: AppTypography.labelLarge(
          color: AppColors.textPrimaryDark,
        ),
        labelMedium: AppTypography.labelMedium(
          color: AppColors.textSecondaryDark,
        ),
        labelSmall: AppTypography.labelSmall(
          color: AppColors.textTertiaryDark,
        ),
      ),
    );
  }
}

