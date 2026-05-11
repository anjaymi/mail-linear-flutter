import 'package:flutter/material.dart';

abstract final class AppRadii {
  /// pills, badges, chips, small tags
  static const xs = 6.0;

  /// buttons, tiles, inputs, nav items, list rows
  static const sm = 8.0;

  /// regular panels, metric cards, rail cards
  static const md = 10.0;

  /// shell chrome, hero reader surface
  static const lg = 14.0;
}

abstract final class AppSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class LinearColors {
  static const bg = Color(0xfffafafa);
  static const surface = Color(0xffffffff);
  static const chrome = Color(0xfff8f8f9);
  static const panel = Color(0xfffcfcfd);
  static const accentPanel = Color(0xffeeeffc);
  static const surfaceSoft = Color(0xfff3f3f5);
  static const line = Color(0xffe7e7ea);
  static const chromeLine = Color(0xffdedee1);
  static const ink = Color(0xff1b1b1f);
  static const muted = Color(0xff6e6e76);
  static const faint = Color(0xffa1a1a7);
  static const blue = Color(0xff5e6ad2);
  static const green = Color(0xff18b981);
  static const red = Color(0xffef4444);
  static const amber = Color(0xfff59e0b);
}

abstract final class AppText {
  static const display = TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const pageTitle = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: LinearColors.ink,
  );

  static const itemTitle = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: LinearColors.ink,
  );

  static const body = TextStyle(
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: LinearColors.ink,
  );

  static const bodyStrong = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: LinearColors.ink,
  );

  static const muted = TextStyle(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: LinearColors.muted,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: LinearColors.faint,
  );

  static const label = TextStyle(
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: LinearColors.muted,
  );

  static const control = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
}

abstract final class AppSurfaces {
  static BoxDecoration chrome({double radius = AppRadii.lg}) {
    return BoxDecoration(
      color: LinearColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: LinearColors.chromeLine),
    );
  }

  static BoxDecoration panel({double radius = AppRadii.md}) {
    return BoxDecoration(
      color: LinearColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: LinearColors.line),
    );
  }

  static BoxDecoration accent({double radius = AppRadii.md}) {
    return BoxDecoration(
      color: LinearColors.accentPanel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: LinearColors.blue.withValues(alpha: .18)),
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LinearColors.blue,
      brightness: Brightness.light,
      surface: LinearColors.surface,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: LinearColors.bg,
      fontFamily: 'Segoe UI Variable Text',
      fontFamilyFallback: const [
        'Segoe UI',
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'Arial',
      ],
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: AppText.display,
        headlineMedium: AppText.pageTitle,
        titleLarge: AppText.sectionTitle,
        titleMedium: AppText.itemTitle,
        bodyLarge: AppText.bodyStrong,
        bodyMedium: AppText.body,
        bodySmall: AppText.muted,
        labelLarge: AppText.control,
        labelMedium: AppText.label,
        labelSmall: AppText.caption,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LinearColors.ink,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontFamily: 'Segoe UI Variable Text',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: LinearColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: LinearColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: LinearColors.blue, width: 1.4),
        ),
      ),
    );
  }
}
