import 'package:flutter/widgets.dart';
import 'design_tokens.dart';

/// Screen classification based on available width
enum ScreenType {
  compact, // Phones (< 600px)
  medium,  // Tablets / Foldables (600px - 899px)
  expanded // Desktop / Large tablets (>= 900px)
}

/// Dynamic, modern responsive utility for BizMate.
/// Replaces static fixed pixel multipliers with real-time responsive constraints.
class Responsive {
  /// Backwards-compatibility initializer (retains non-breaking legacy API)
  static void init(BuildContext context) {}

  /// Legacy helper backwards compatibility (clamped to prevent distortion)
  static double pxW(double value) => value;
  static double pxH(double value) => value;
  static double font(double size) => size;

  /// Determine screen type from width
  static ScreenType getScreenType(double width) {
    if (width < AppBreakpoints.compact) {
      return ScreenType.compact;
    } else if (width < AppBreakpoints.medium) {
      return ScreenType.medium;
    } else {
      return ScreenType.expanded;
    }
  }

  /// Check if viewport is compact (< 600px)
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

  /// Check if viewport is tablet/medium (600px - 899px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppBreakpoints.compact && width < AppBreakpoints.medium;
  }

  /// Check if viewport is desktop/large (>= 900px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

  /// Check if viewport is wide desktop (>= 1200px)
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

  /// Select a value conditionally based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.medium && desktop != null) {
      return desktop;
    }
    if (width >= AppBreakpoints.compact && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Get responsive grid column count for card grids
  static int gridColumns(BuildContext context, {double minItemWidth = 320}) {
    final width = MediaQuery.sizeOf(context).width;
    final count = (width / minItemWidth).floor();
    return count < 1 ? 1 : count;
  }
}

/// Convenient extension methods on BuildContext for clean responsive UI code
extension ResponsiveContextX on BuildContext {
  /// Size of the app window
  Size get windowSize => MediaQuery.sizeOf(this);

  /// Width of the app window
  double get screenWidth => windowSize.width;

  /// Height of the app window
  double get screenHeight => windowSize.height;

  /// Whether current view is mobile (< 600px)
  bool get isCompact => screenWidth < AppBreakpoints.compact;

  /// Whether current view is tablet (600px - 899px)
  bool get isTablet =>
      screenWidth >= AppBreakpoints.compact &&
      screenWidth < AppBreakpoints.medium;

  /// Whether current view is desktop (>= 900px)
  bool get isDesktop => screenWidth >= AppBreakpoints.medium;

  /// Pick a value matching current responsive breakpoint
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}
