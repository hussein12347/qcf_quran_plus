import 'package:flutter/material.dart';

/// Centralized text styling utilities for Quran rendering across the package.
///
/// This class provides ready-to-use [TextStyle] factories for Quran page fonts,
/// Tajweed variations, and decorative headings while keeping the font family
/// resolution consistent across both light and dark themes.
class QuranTextStyles {
  QuranTextStyles._();

  /// Resolves the correct QCF font family for a specific Quran page and mode.
  ///
  /// The font asset naming convention is page-based, and the selected family is
  /// determined by the page number, whether Tajweed is enabled, and whether the
  /// current theme is dark.
  ///
  /// [pageNumber] is the Quran page index used to generate the font name.
  /// [isTajweed] indicates whether the Tajweed version should be used.
  /// [isDark] selects the dark-theme variant when available.
  static String getQcfFontFamily({
    required int pageNumber,
    required bool isTajweed,
    required bool isDark,
  }) {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final base = 'QCF4${pageStr}_COLOR-Regular';

    if (isTajweed) {
      return isDark ? '$base-d' : base;
    }

    return isDark ? '$base-nd' : '$base-n';
  }

  /// Creates a [TextStyle] for the main QCF Quran page font.
  ///
  /// This is the standard style used for Quran page body text and automatically
  /// resolves the correct family based on the selected page, theme, and Tajweed
  /// mode.
  ///
  /// [pageNumber] identifies the target Quran page.
  /// [isTajweed] toggles the Tajweed font family.
  /// [isDark] applies the dark theme variant.
  /// [color] overrides the default text color.
  /// [fontSize] controls the rendered size.
  /// [height] sets the line height for multi-line content.
  static TextStyle qcfStyle({
    required int pageNumber,
    required bool isTajweed,
    required bool isDark,
    Color? color,
    double fontSize = 23.55,
    double? height,
  }) {
    final Color defaultSolidColor = isDark ? Colors.white : Colors.black;

    return TextStyle(
      fontFamily: getQcfFontFamily(
        pageNumber: pageNumber,
        isTajweed: isTajweed,
        isDark: isDark,
      ),
      color: color ?? defaultSolidColor,
      fontSize: fontSize,
      height: height,
    );
  }

  /// Creates a [TextStyle] for the Hafs Quran font family.
  ///
  /// Use this style when the design requires the dedicated Hafs-specific typeface
  /// instead of the page-based QCF font.
  static TextStyle hafsStyle({
    Color? color,
    double fontSize = 23.55,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'hafs',
      package: 'qcf_quran_plus',
      color: color,
      fontSize: fontSize,
      height: height,
    );
  }

  /// Creates a typography style for Quran surah headers.
  ///
  /// This is intended for section titles and decorative heading elements that
  /// should use the standalone surah header font.
  static TextStyle surahHeaderStyle({Color? color, double fontSize = 30}) {
    return TextStyle(
      fontFamily: 'arsura',
      package: 'qcf_quran_plus',
      color: color ?? Colors.black,
      fontSize: fontSize,
    );
  }

  /// Creates a [TextStyle] for the basmallah calligraphic word.
  ///
  /// This style is designed for the introductory basmallah invocation and other
  /// ornamental Arabic text elements that require the dedicated basmallah font.
  static TextStyle basmallahStyle({Color? color, double fontSize = 30}) {
    return TextStyle(
      fontFamily: 'QCF4_BSML',
      package: 'qcf_quran_plus',
      color: color ?? Colors.black,
      fontSize: fontSize,
    );
  }
}
