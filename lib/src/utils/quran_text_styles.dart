import 'package:flutter/material.dart';

/// A utility class providing ready-to-use TextStyles for rendering Quranic text.
/// This saves developers from needing to manually specify font families and package names.
class QuranTextStyles {
  /// The official Hafs Othmanic font style for a specific Quran page.
  ///
  /// [pageNumber] is used to dynamically load the specific font file for that page.
  static TextStyle qcfStyle({
    required int pageNumber,
    Color? color,
    double fontSize = 23.55,
    double? height,
  }) {
    // Converts the page number to a 3-digit string (e.g., 1 becomes "001")
    String pageStr = pageNumber.toString().padLeft(3, '0');

    return TextStyle(
      // Combines the page string with the base font family name defined in pubspec
      fontFamily: 'QCF4_tajweed_$pageStr',
      color: color,
      fontSize: fontSize,
      height: height,
    );
  }

  /// Standard Hafs font style for general Quranic text.
  static TextStyle hafsStyle({
    Color? color,
    double fontSize = 23.55,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'hafs',
      package: 'qcf_quran_plus', // Crucial for external apps using this package
      color: color,
      fontSize: fontSize,
      height: height,
    );
  }

  /// The special decorative font used for rendering Surah names in headers.
  static TextStyle surahHeaderStyle({Color? color, double fontSize = 30.0}) {
    return TextStyle(
      fontFamily: 'arsura',
      package: 'qcf_quran_plus',
      color: color,
      fontSize: fontSize,
    );
  }

  /// Specialized font style for the Basmallah (Bismillah) calligraphic text.
  static TextStyle basmallahStyle({Color? color, double fontSize = 30.0}) {
    return TextStyle(
      fontFamily: 'QCF4_BSML',
      package: 'qcf_quran_plus',
      color: color,
      fontSize: fontSize,
    );
  }
}