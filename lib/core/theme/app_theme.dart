import 'package:flutter/material.dart';

abstract final class AppColors {
  static const accent = Color(0xFFE8FF00);
  static const accentDim = Color(0x33E8FF00);
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF111111);
  static const panel = Color(0xFF161616);
  static const border = Color(0xFF2A2A2A);
  static const divider = Color(0xFF1E1E1E);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);
  static const textDim = Color(0xFF333333);
  static const folderYellow = Color(0xFF666600);
  static const errorRed = Color(0xFFFF4444);
  static const errorBg = Color(0xFF2A0A0A);
}

abstract final class AppTextStyles {
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
    fontFamily: 'monospace',
    color: AppColors.accent,
  );

  static const mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: AppColors.textSecondary,
  );

  static const body = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const bodySmall = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
}

final class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: AppColors.border,
        ),
        sliderTheme: const SliderThemeData(
          thumbColor: AppColors.accent,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.textDim,
          overlayColor: AppColors.accentDim,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          trackHeight: 3,
        ),
        dividerColor: AppColors.divider,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.accent, width: 1),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.border),
          ),
        ),
      );
}
