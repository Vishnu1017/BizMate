import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// BIZMATE DESIGN TOKENS
/// Centralized design constants for spacing, layout, radiuses, elevations,
/// and responsive breakpoints.
/// ---------------------------------------------------------------------------
class AppBreakpoints {
  AppBreakpoints._();

  /// Mobile / Compact phones: < 600px
  static const double compact = 600.0;

  /// Foldables & Tablets: 600px - 899px
  static const double medium = 900.0;

  /// Desktops & Laptops: 900px - 1199px
  static const double expanded = 1200.0;

  /// Large Desktop Displays: >= 1200px
  static const double large = 1440.0;
}

class AppDimensions {
  AppDimensions._();

  /// Maximum comfortable width for forms and inputs (preserves eye tracking)
  static const double formMaxWidth = 680.0;

  /// Maximum width for authentication & auth-gate dialogs/cards
  static const double authMaxWidth = 440.0;

  /// Maximum content width for standard business dashboards and data pages
  static const double contentMaxWidth = 1200.0;

  /// Maximum width for popup dialogs
  static const double dialogMaxWidth = 520.0;

  /// Standard sidebar / navigation rail width on wide viewports
  static const double navigationRailWidth = 240.0;
  static const double collapsedRailWidth = 76.0;

  /// Minimum width per card in multi-column grids
  static const double cardMinWidth = 320.0;
  static const double smallCardMinWidth = 240.0;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double huge = 48.0;

  /// Standard horizontal page padding based on screen width
  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) {
      return const EdgeInsets.symmetric(horizontal: xl, vertical: xl);
    } else if (width >= AppBreakpoints.compact) {
      return const EdgeInsets.symmetric(horizontal: lg, vertical: lg);
    } else {
      return const EdgeInsets.symmetric(horizontal: base, vertical: md);
    }
  }

  /// Form section padding
  static const EdgeInsets formSectionPadding = EdgeInsets.all(base);
  static const EdgeInsets cardPadding = EdgeInsets.all(base);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  static final BorderRadius smBorder = BorderRadius.circular(sm);
  static final BorderRadius mdBorder = BorderRadius.circular(md);
  static final BorderRadius lgBorder = BorderRadius.circular(lg);
  static final BorderRadius xlBorder = BorderRadius.circular(xl);
  static final BorderRadius xxlBorder = BorderRadius.circular(xxl);
  static final BorderRadius pillBorder = BorderRadius.circular(pill);
}

class AppElevations {
  AppElevations._();

  static List<BoxShadow> cardShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF64748B).withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: const Color(0xFF64748B).withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> hoverShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
