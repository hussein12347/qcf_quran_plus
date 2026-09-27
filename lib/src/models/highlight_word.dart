import 'package:flutter/material.dart';

// Make sure you have this class defined in your project, or import it.
class WordHighlight {
  final int surah;
  final int verseNumber;
  final int wordIndex;
  final Color? backgroundColor;
  final Color? textColor;

  WordHighlight({
    required this.surah,
    required this.verseNumber,
    required this.wordIndex,
    this.backgroundColor,
    this.textColor,
  });
}

