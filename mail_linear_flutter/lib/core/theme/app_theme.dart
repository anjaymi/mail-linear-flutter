import 'package:flutter/material.dart';

abstract final class LinearColors {
  static const bg = Color(0xfff6f8fc);
  static const surface = Color(0xffffffff);
  static const chrome = Color(0xfff8fbff);
  static const panel = Color(0xfffafdff);
  static const accentPanel = Color(0xffe7f1ff);
  static const surfaceSoft = Color(0xffeef3fb);
  static const line = Color(0xffdde5f0);
  static const chromeLine = Color(0xffdbe6f5);
  static const ink = Color(0xff172033);
  static const muted = Color(0xff697789);
  static const faint = Color(0xff93a0b3);
  static const blue = Color(0xff3b6df6);
  static const green = Color(0xff18b981);
  static const red = Color(0xffef4444);
  static const amber = Color(0xfff59e0b);
}

abstract final class AppText {
  static const display = TextStyle(
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const pageTitle = TextStyle(
    fontSize: 24,
    height: 1.18,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    height: 1.28,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
  );

  static const itemTitle = TextStyle(
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: LinearColors.ink,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: LinearColors.ink,
  );

  static const bodyStrong = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: LinearColors.ink,
  );

  static const muted = TextStyle(
    fontSize: 13,
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
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: LinearColors.muted,
  );

  static const control = TextStyle(
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
}

abstract final class AppSurfaces {
  static BoxDecoration chrome({double radius = 24}) {
    return BoxDecoration(
      color: LinearColors.chrome.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: LinearColors.chromeLine.withValues(alpha: .72)),
      boxShadow: [
        BoxShadow(
          color: LinearColors.ink.withValues(alpha: .055),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  static BoxDecoration panel({double radius = 26}) {
    return BoxDecoration(
      color: LinearColors.panel.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: LinearColors.chromeLine.withValues(alpha: .58)),
      boxShadow: [
        BoxShadow(
          color: LinearColors.ink.withValues(alpha: .025),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration accent({double radius = 26}) {
    return BoxDecoration(
      color: LinearColors.accentPanel.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xffc8dcff)),
      boxShadow: [
        BoxShadow(
          color: LinearColors.blue.withValues(alpha: .055),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
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
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LinearColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LinearColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LinearColors.blue, width: 1.4),
        ),
      ),
    );
  }
}
