import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color background = Colors.white;
  static const Color border = Color(0xFFE0E0E0);
  static const Color text = Colors.black;
}

abstract class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const TextStyle normal = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w200,
    color: AppColors.text,
  );
}

abstract class AppTheme {
  // 1. Minimalist AppBar Theme
  static AppBarThemeData get _appBarTheme => const AppBarThemeData(
    backgroundColor: AppColors.background, // Icon and text color
    elevation: 0, // Flat design with no drop shadow
    scrolledUnderElevation: 0, // Prevents background color change on scroll
    centerTitle: true,
    titleTextStyle: AppTextStyles.title,
  );

  static ButtonStyle get _elevatedButtonStyle => ElevatedButton.styleFrom(
    shape: _framedShape,
    elevation: 2,
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.text,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: AppTextStyles.normal,
  );

  static RoundedRectangleBorder get _framedShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(5),
    side: const BorderSide(
      color: AppColors.background, // Light border frame
      width: 1,
    ),
  );

  static ListTileThemeData get _listTileTheme => ListTileThemeData(
    // Controls title text style (default is ~16px)
    shape: _framedShape,

    titleTextStyle: AppTextStyles.normal,
    // Optional: Reduces vertical padding to match the compact text look
    dense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
  );

  // 1. Card Theme (Handles outer margin & border frame)
  static CardThemeData get _cardTheme => CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: const BorderSide(
        color: AppColors.border, // Light border frame
        width: 1,
      ),
    ),
    color: AppColors.background,
    elevation: 0, // Flat design
    margin: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 4,
    ), // Outer spacing
  );

  // Re-evaluated on every hot reload
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      appBarTheme: _appBarTheme,
      scaffoldBackgroundColor: AppColors.background,
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
      listTileTheme: _listTileTheme,
      cardTheme: _cardTheme,
    );
  }
}
