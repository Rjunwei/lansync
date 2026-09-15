import 'package:flutter/material.dart';

/// 局域网互传应用的 Material 3 现代科技美学主题
class AppTheme {
  // 核心调色板 (现代化 Slate & Indigo/Blue 配色)
  static const Color primaryBlue = Color(0xFF2563EB); // 经典科技蓝
  static const Color secondaryCyan = Color(0xFF06B6D4); // 灵动青
  static const Color accentGreen = Color(0xFF10B981); // 成功翠绿
  static const Color warningOrange = Color(0xFFF59E0B); // 警告暖橙
  static const Color alertRed = Color(0xFFEF4444); // 错误珊瑚红

  /// 浅色主题
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: secondaryCyan,
      surface: const Color(0xFFF8FAFC), // Slate 50
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardTheme: CardThemeData(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      color: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        letterSpacing: -0.5,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFDBEAFE), // primary 100
      selectedIconTheme: IconThemeData(color: primaryBlue),
      unselectedIconTheme: IconThemeData(color: Color(0xFF64748B)),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryBlue,
      ),
    ),
  );

  /// 深色主题
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA),
      secondary: secondaryCyan,
      surface: const Color(0xFF0F172A), // Slate 900
    ),
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      color: const Color(0xFF1E293B), // Slate 800
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF8FAFC),
        letterSpacing: -0.5,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF1E293B),
      indicatorColor: Color(0xFF1E3A8A),
      selectedIconTheme: IconThemeData(color: Color(0xFF60A5FA)),
      unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8)),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF60A5FA),
      ),
    ),
  );
}
