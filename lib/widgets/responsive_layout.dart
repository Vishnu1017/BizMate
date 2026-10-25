import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import '../utils/responsive.dart';

/// ---------------------------------------------------------------------------
/// RESPONSIVE BUILDER
/// Passes down BoxConstraints and computed ScreenType to child builder
/// ---------------------------------------------------------------------------
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ScreenType screenType,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Responsive.getScreenType(constraints.maxWidth);
        return builder(context, constraints, screenType);
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESPONSIVE CONTAINER
/// Centers content and applies maxWidth and adaptive horizontal padding
/// ---------------------------------------------------------------------------
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppDimensions.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? AppSpacing.pagePadding(context);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESPONSIVE FORM CONTAINER
/// Specifically optimized for data entry, forms, and settings pages (max 680px)
/// ---------------------------------------------------------------------------
class ResponsiveFormContainer extends StatelessWidget {
  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.maxWidth = AppDimensions.formMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < AppBreakpoints.compact;

    final defaultPadding = EdgeInsets.symmetric(
      horizontal: isCompact ? AppSpacing.base : AppSpacing.xl,
      vertical: isCompact ? AppSpacing.md : AppSpacing.xl,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESPONSIVE TWO COLUMN LAYOUT
/// Side-by-side on wide viewports (>= 768px), stacked vertically on mobile
/// ---------------------------------------------------------------------------
class ResponsiveTwoColumn extends StatelessWidget {
  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.breakpoint = 768.0,
    this.spacing = AppSpacing.lg,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(
                flex: leftFlex,
                child: left,
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: rightFlex,
                child: right,
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESPONSIVE GRID
/// Automatically adjusts column count based on available width and minItemWidth
/// ---------------------------------------------------------------------------
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = AppDimensions.cardMinWidth,
    this.spacing = AppSpacing.base,
    this.runSpacing = AppSpacing.base,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int columns = (availableWidth / minItemWidth).floor();
        if (columns < 1) columns = 1;

        final itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESPONSIVE CARD
/// Standardized card adhering to AppRadius and theme colors
/// ---------------------------------------------------------------------------
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? AppRadius.lgBorder;

    final cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: r,
        border: Border.all(
          color: borderColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
        boxShadow: AppElevations.cardShadow(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return cardContent;
  }
}
