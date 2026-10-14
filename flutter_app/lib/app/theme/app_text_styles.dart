import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tuned for an older, low-tech-comfort audience reading a
/// bilingual (Myanmar / English) census form.
///
/// Everything is built on a bundled Noto Sans Myanmar family. Myanmar script
/// needs generous line height so vowels, medials and stacked consonants do not
/// collide; sizes start larger than Material defaults and scale with the user's
/// system text-size setting.
abstract final class AppTextStyles {
  static const String fontFamily = 'NotoSansMyanmar';

  /// Myanmar needs extra vertical room for stacked glyphs and vowels.
  static const double _lineHeight = 1.55;

  static TextTheme textTheme(Color onSurface) => TextTheme(
        displayLarge: _base(30, FontWeight.w700, onSurface, 1.35),
        displayMedium: _base(26, FontWeight.w700, onSurface, 1.4),
        displaySmall: _base(24, FontWeight.w700, onSurface, 1.45),
        headlineLarge: _base(26, FontWeight.w700, onSurface, 1.45),
        headlineMedium: _base(24, FontWeight.w700, onSurface, 1.45),
        headlineSmall: _base(22, FontWeight.w700, onSurface, 1.5),
        titleLarge: _base(22, FontWeight.w700, onSurface, 1.5),
        titleMedium: _base(19, FontWeight.w600, onSurface, _lineHeight),
        titleSmall: _base(17, FontWeight.w600, onSurface, _lineHeight),
        bodyLarge: _base(19, FontWeight.w400, onSurface, _lineHeight),
        bodyMedium: _base(17, FontWeight.w400, onSurface, _lineHeight),
        bodySmall: _base(15, FontWeight.w400, AppColors.textSecondary, _lineHeight),
        labelLarge: _base(19, FontWeight.w600, onSurface, _lineHeight),
        labelMedium: _base(16, FontWeight.w600, onSurface, _lineHeight),
        labelSmall: _base(14, FontWeight.w500, AppColors.textSecondary, _lineHeight),
      );

  static TextStyle _base(
    double size,
    FontWeight weight,
    Color color,
    double height,
  ) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  // Semantic shortcuts mirroring [textTheme] so widgets can reference a style
  // without reaching into the inherited theme. They share the same sizes so the
  // two paths stay in sync.
  static TextStyle get displaySmall => _base(24, FontWeight.w700, AppColors.textPrimary, 1.45);
  static TextStyle get headlineSmall => _base(22, FontWeight.w700, AppColors.textPrimary, 1.5);
  static TextStyle get titleMedium => _base(19, FontWeight.w600, AppColors.textPrimary, _lineHeight);
  static TextStyle get titleSmall => _base(17, FontWeight.w600, AppColors.textPrimary, _lineHeight);
  static TextStyle get bodyLarge => _base(19, FontWeight.w400, AppColors.textPrimary, _lineHeight);
  static TextStyle get bodyMedium => _base(17, FontWeight.w400, AppColors.textPrimary, _lineHeight);
  static TextStyle get bodySmall => _base(15, FontWeight.w400, AppColors.textSecondary, _lineHeight);
  static TextStyle get labelLarge => _base(19, FontWeight.w600, AppColors.textPrimary, _lineHeight);
  static TextStyle get labelMedium => _base(16, FontWeight.w600, AppColors.textPrimary, _lineHeight);
  static TextStyle get labelSmall => _base(14, FontWeight.w500, AppColors.textSecondary, _lineHeight);

  // Named styles used directly by widgets where a semantic list entry does not
  // fit (e.g. a small helper caption under a field).
  static TextStyle get fieldLabel => _base(16, FontWeight.w600, AppColors.textPrimary, 1.5);
  static TextStyle get input => _base(19, FontWeight.w400, AppColors.textPrimary, _lineHeight);
  static TextStyle get button => _base(19, FontWeight.w600, AppColors.onPrimary, 1.3);
  static TextStyle get supporting => _base(16, FontWeight.w400, AppColors.textSecondary, _lineHeight);
  static TextStyle get caption => _base(15, FontWeight.w500, AppColors.textMuted, _lineHeight);
}
