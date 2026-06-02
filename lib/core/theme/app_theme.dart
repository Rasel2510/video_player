import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds — layered depth
  static const bg       = Color(0xFF0C0C0E);   // deepest
  static const surface  = Color(0xFF141416);   // cards / app bar
  static const panel    = Color(0xFF1C1C1F);   // bottom sheets / dialogs
  static const elevated = Color(0xFF242428);   // elevated surfaces

  // Borders & dividers
  static const border   = Color(0xFF2C2C30);
  static const divider  = Color(0xFF1F1F23);

  // Accent — soft blue-white instead of neon yellow
  static const accent      = Color(0xFF6C8EFF);   // primary CTA
  static const accentSoft  = Color(0x266C8EFF);   // overlays / fill
  static const accentGlow  = Color(0x406C8EFF);

  // Text
  static const textPrimary   = Color(0xFFF0F0F2);
  static const textSecondary = Color(0xFF8A8A92);
  static const textMuted     = Color(0xFF4A4A52);
  static const textDim       = Color(0xFF2E2E34);

  // Semantic
  static const folderTint = Color(0xFF2A1020);
  static const folderIcon = Color(0xFFFF6B8E);
  static const errorRed   = Color(0xFFFF5C5C);
  static const errorBg    = Color(0xFF2A1010);

  // Progress / resume
  static const progressBg   = Color(0xFF252528);
  static const progressFill = accent;
}

abstract final class AppRadius {
  static const xs  = BorderRadius.all(Radius.circular(6));
  static const sm  = BorderRadius.all(Radius.circular(10));
  static const md  = BorderRadius.all(Radius.circular(14));
  static const lg  = BorderRadius.all(Radius.circular(20));
  static const xl  = BorderRadius.all(Radius.circular(28));
}

abstract final class AppTextStyles {
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  static const labelAccent = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.accent,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );

  static const mono = TextStyle(
    fontSize: 11,
    fontFamily: 'monospace',
    color: AppColors.textSecondary,
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
          surfaceContainerHighest: AppColors.panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          iconTheme: IconThemeData(
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
        sliderTheme: const SliderThemeData(
          thumbColor: AppColors.accent,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.textDim,
          overlayColor: AppColors.accentSoft,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          trackHeight: 3,
        ),
        dividerColor: AppColors.divider,
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.panel,
          hintStyle: TextStyle(
              color: AppColors.textMuted, fontSize: 14),
          contentPadding:
              EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide:
                BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide:
                BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide:
                BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.panel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          dragHandleColor: AppColors.border,
          showDragHandle: true,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.panel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.md),
          titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
          contentTextStyle: TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: StadiumBorder(),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.accent,
          linearTrackColor: AppColors.progressBg,
        ),
      );
}
