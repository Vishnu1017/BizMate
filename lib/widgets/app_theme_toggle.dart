import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// APP THEME TOGGLE WIDGET
/// A standalone, animated theme toggle button that can be embedded in any
/// AppBar, Page Header, or custom toolbar across the entire project.
/// ─────────────────────────────────────────────────────────────────────────────
class AppThemeToggle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const AppThemeToggle({
    super.key,
    this.size = 36.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final platformDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system && platformDark);

        final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF8E1);
        final border =
            isDark ? const Color(0xFF334155) : const Color(0xFFFFCC02);
        final shadow = isDark
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0xFFFFB300).withValues(alpha: 0.2);

        return Container(
          margin: margin,
          child: Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  AppTheme.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: isDark
                          ? const Icon(
                              Icons.nightlight_round_rounded,
                              key: ValueKey('dark'),
                              color: Color(0xFF38BDF8),
                              size: 20,
                            )
                          : const Icon(
                              Icons.wb_sunny_rounded,
                              key: ValueKey('light'),
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// SEGMENTED APP THEME TOGGLE (For Profile & Settings Page)
/// Allows explicit selection of Light, Dark, or System mode.
/// ─────────────────────────────────────────────────────────────────────────────
class AppThemeSegmentedToggle extends StatelessWidget {
  const AppThemeSegmentedToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
        final text2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final activeColor = const Color(0xFF2563EB);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Theme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: text1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred visual appearance across all pages',
              style: TextStyle(
                fontSize: 13,
                color: text2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    context: context,
                    title: 'Light',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isSelected: currentMode == ThemeMode.light,
                    onTap: () => AppTheme.setThemeMode(ThemeMode.light),
                    cardBg: cardBg,
                    text1: text1,
                    activeColor: activeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOptionTile(
                    context: context,
                    title: 'Dark',
                    icon: Icons.nightlight_round_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    isSelected: currentMode == ThemeMode.dark,
                    onTap: () => AppTheme.setThemeMode(ThemeMode.dark),
                    cardBg: cardBg,
                    text1: text1,
                    activeColor: activeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOptionTile(
                    context: context,
                    title: 'System',
                    icon: Icons.settings_brightness_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    isSelected: currentMode == ThemeMode.system,
                    onTap: () => AppTheme.setThemeMode(ThemeMode.system),
                    cardBg: cardBg,
                    text1: text1,
                    activeColor: activeColor,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required Color cardBg,
    required Color text1,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : iconColor,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : text1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
