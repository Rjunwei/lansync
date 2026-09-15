import 'package:flutter/material.dart';

/// 局域网互传应用的 Material 3 风格主题设计
class AppTheme {
  // 核心品牌色：科技深蓝 / 灵动青
  static const Color primaryBlue = Color(0xFF0F62FE);
  static const Color secondaryCyan = Color(0xFF00B4D8);
  static const Color accentGreen = Color(0xFF24A148);
  static const Color warningOrange = Color(0xFFFF832B);
  static const Color alertRed = Color(0xFFDA1E28);

  /// 浅色主题
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: secondaryCyan,
      surface: const Color(0xFFF4F6FB),
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F6FB),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  /// 深色主题
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF4589FF),
      secondary: secondaryCyan,
      surface: const Color(0xFF161616),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF262626)),
      ),
      color: const Color(0xFF1E1E1E),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
