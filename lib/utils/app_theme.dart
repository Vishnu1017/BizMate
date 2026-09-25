// lib/utils/app_theme.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS — ThemeExtension
// Register on both lightTheme and darkTheme so every Widget in the tree can
// call  context.appColors.surface  (etc.) without any isDark check.
// ─────────────────────────────────────────────────────────────────────────────
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.background,
    required this.card,
    required this.text1,
    required this.text2,
    required this.divider,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.icon,
    required this.inputFill,
    required this.inputBorder,
    required this.shadowColor,
  });

  final Color surface;       // white  / dark-slate
  final Color background;    // off-white / near-black
  final Color card;          // white  / dark-slate
  final Color text1;         // near-black / near-white
  final Color text2;         // mid-grey / muted-slate
  final Color divider;       // light-grey / dark-border
  final Color primary;       // brand blue / sky blue
  final Color secondary;     // deep-blue / soft-blue
  final Color accent;        // cyan / light-cyan
  final Color icon;          // grey / muted-slate
  final Color inputFill;     // off-white / dark-slate
  final Color inputBorder;   // light-grey / dark-border
  final Color shadowColor;   // near-transparent black (dark-mode deeper)

  // ── LIGHT ──────────────────────────────────────────────────────────────────
  static const AppColors light = AppColors(
    surface:     Color(0xFFFFFFFF),
    background:  Color(0xFFF5F7FA),
    card:        Color(0xFFFFFFFF),
    text1:       Color(0xFF1A1A1A),
    text2:       Color(0xFF484848),
    divider:     Color(0xFFE0E0E0),
    primary:     Color(0xFF1A237E),
    secondary:   Color(0xFF3949AB),
    accent:      Color(0xFF00BCD4),
    icon:        Color(0xFF484848),
    inputFill:   Color(0xFFF5F7FA),
    inputBorder: Color(0xFFE0E0E0),
    shadowColor: Color(0x08000000),
  );

  // ── DARK ───────────────────────────────────────────────────────────────────
  static const AppColors dark = AppColors(
    surface:     Color(0xFF1E293B),
    background:  Color(0xFF0F172A),
    card:        Color(0xFF1E293B),
    text1:       Color(0xFFF1F5F9),
    text2:       Color(0xFF94A3B8),
    divider:     Color(0xFF334155),
    primary:     Color(0xFF38BDF8),
    secondary:   Color(0xFF60A5FA),
    accent:      Color(0xFF22D3EE),
    icon:        Color(0xFF94A3B8),
    inputFill:   Color(0xFF1E293B),
    inputBorder: Color(0xFF334155),
    shadowColor: Color(0x40000000),
  );

  // ── ThemeExtension boilerplate ─────────────────────────────────────────────
  @override
  AppColors copyWith({
    Color? surface,
    Color? background,
    Color? card,
    Color? text1,
    Color? text2,
    Color? divider,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? icon,
    Color? inputFill,
    Color? inputBorder,
    Color? shadowColor,
  }) {
    return AppColors(
      surface:     surface     ?? this.surface,
      background:  background  ?? this.background,
      card:        card        ?? this.card,
      text1:       text1       ?? this.text1,
      text2:       text2       ?? this.text2,
      divider:     divider     ?? this.divider,
      primary:     primary     ?? this.primary,
      secondary:   secondary   ?? this.secondary,
      accent:      accent      ?? this.accent,
      icon:        icon        ?? this.icon,
      inputFill:   inputFill   ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surface:     Color.lerp(surface,     other.surface,     t)!,
      background:  Color.lerp(background,  other.background,  t)!,
      card:        Color.lerp(card,        other.card,        t)!,
      text1:       Color.lerp(text1,       other.text1,       t)!,
      text2:       Color.lerp(text2,       other.text2,       t)!,
      divider:     Color.lerp(divider,     other.divider,     t)!,
      primary:     Color.lerp(primary,     other.primary,     t)!,
      secondary:   Color.lerp(secondary,   other.secondary,   t)!,
      accent:      Color.lerp(accent,      other.accent,      t)!,
      icon:        Color.lerp(icon,        other.icon,        t)!,
      inputFill:   Color.lerp(inputFill,   other.inputFill,   t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVENIENCE EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────
extension AppColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? (isDark ? AppColors.dark : AppColors.light);
  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get surfaceBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF484848);
  Color get borderColor => isDark ? const Color(0xFF334155) : const Color(0xFFE0E0E0);
}

// ─────────────────────────────────────────────────────────────────────────────
// APP THEME SYSTEM (DARK & LIGHT MODE)
// Persists choice via SharedPreferences. Drives MaterialApp via ValueNotifier.
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _themeKey = 'app_theme_mode';

  /// Load theme setting on app startup
  static Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedTheme = prefs.getString(_themeKey);

      if (savedTheme == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  /// Change and save theme mode
  static Future<void> setThemeMode(ThemeMode mode) async {
    try {
      themeModeNotifier.value = mode;
      final prefs = await SharedPreferences.getInstance();

      if (mode == ThemeMode.light) {
        await prefs.setString(_themeKey, 'light');
      } else if (mode == ThemeMode.dark) {
        await prefs.setString(_themeKey, 'dark');
      } else {
        await prefs.setString(_themeKey, 'system');
      }
    } catch (e) {
      debugPrint('Error setting theme mode: $e');
    }
  }

  // ── LIGHT THEME ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF16A34A);
    const secondaryColor = Color(0xFF0F73B8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A1A),
        surfaceContainer: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAFC),
        surfaceContainerHigh: const Color(0xFFF1F5F9),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF484848)),
        labelLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x08000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF484848)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF484848),
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
      ),
      dividerColor: const Color(0xFFE0E0E0),
      extensions: const <ThemeExtension<dynamic>>[AppColors.light],
    );
  }

  // ── DARK THEME ──────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const primaryColor = Color(0xFF22C55E);
    const secondaryColor = Color(0xFF38BDF8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF16A34A),
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFF1F5F9),
        surfaceContainer: const Color(0xFF1E293B),
        surfaceContainerLow: const Color(0xFF111713),
        surfaceContainerHigh: const Color(0xFF1B241E),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
        bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 2,
        shadowColor: const Color(0x40000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: Color(0xFFF1F5F9),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        modalBackgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: Color(0xFF94A3B8));
        }),
      ),
      dividerColor: const Color(0xFF334155),
      extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
    );
  }
}
