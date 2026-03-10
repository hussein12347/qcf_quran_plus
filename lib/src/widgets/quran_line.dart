import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../qcf_quran_plus.dart';
import '../models/highlight_verse.dart';
import '../models/quran_page.dart';

/// A widget that renders a single line of the Quran with support for
/// Tajweed color filtering, highlighting, and RTL alignment.
class QuranLine extends StatelessWidget {
  const QuranLine(
      this.line,
      this.bookmarks, {
        super.key,
        this.boxFit = BoxFit.fill,
        this.onLongPress,
        this.ayahStyle,
        this.isTajweed = true,
        this.isDark = false,
      });

  final Line line;
  final List<HighlightVerse> bookmarks;
  final BoxFit boxFit;

  /// Callback triggered when an Ayah is long-pressed.
  final void Function(
      int surahNumber,
      int verseNumber,
      LongPressStartDetails details,
      )? onLongPress;

  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Initialize default style using the specific page font
    final defaultStyle = QuranTextStyles.qcfStyle(
      fontSize: 23.55,
      height: 1.45,
      pageNumber: line.ayahs.first.page,
    );

    final finalStyle =
    ayahStyle != null ? defaultStyle.merge(ayahStyle) : defaultStyle;

    ColorFilter? textFilter;

    // Define color filtering logic:
    // Tajweed fonts use specific colors that must be inverted manually in dark mode
    // using a Color Matrix to preserve the Tajweed color coding.
    if (isDark && isTajweed) {
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    } else if (isDark && !isTajweed) {
      textFilter = const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      );
    } else if (!isDark && !isTajweed) {
      textFilter = const ColorFilter.mode(
        Colors.black,
        BlendMode.srcIn,
      );
    }

    Widget textWidget = RichText(
      text: TextSpan(
        children: line.ayahs.reversed.map((ayah) {
          final highlight = bookmarks.firstWhere(
                (h) => h.surah == ayah.surahNumber && h.verseNumber == ayah.ayahNumber,
            orElse: () => HighlightVerse(
              surah: 0,
              verseNumber: 0,
              page: 0,
              color: Colors.transparent,
            ),
          );

          bool isHighlighted = highlight.color != Colors.transparent;

          // Extract and clean the QCF text data
          String currentQcfText = ayah.qcfData.trimRight();
          String glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);

          String textWithoutGlyph = currentQcfText;
          bool hasGlyph = currentQcfText.endsWith(glyph);

          // Separate the Ayah text from the end-of-verse glyph if present in this line
          if (hasGlyph) {
            textWithoutGlyph =
                currentQcfText.substring(0, currentQcfText.length - glyph.length);
          }

          // --- Prepare the main Ayah text style ---
          TextStyle mainTextStyle = finalStyle.copyWith(height: null);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(
                foreground: Paint()..colorFilter = textFilter,
              ),
            );
          }

          // --- Prepare the Ayah number style (to ensure correct placement and font) ---
          TextStyle numberTextStyle = finalStyle.copyWith(height: null);
          if (isDark) {
            // In Dark Mode: Apply matrix inversion to the number glyph as well
            numberTextStyle = numberTextStyle.copyWith(color: null).merge(
              TextStyle(
                foreground: Paint()
                  ..colorFilter = const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0,
                  ]),
              ),
            );
          } else {
            // In Light Mode: Use the app's default primary color
            numberTextStyle = numberTextStyle.copyWith(
              foreground: null,
            );
          }

          // Merge text and number into a single RichText to maintain kerning and alignment
          Widget ayahTextWidget = RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              children: [
                TextSpan(
                  text: textWithoutGlyph,
                  style: mainTextStyle,
                ),
                if (hasGlyph)
                  TextSpan(
                    text: glyph,
                    style: numberTextStyle,
                  ),
              ],
            ),
          );

          return WidgetSpan(
            child: GestureDetector(
              onLongPressStart: (details) => onLongPress?.call(
                ayah.surahNumber,
                ayah.ayahNumber,
                details,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isHighlighted ? highlight.color.withOpacity(0.4) : null,
                ),
                child: ayahTextWidget,
              ),
            ),
          );
        }).toList(),
        style: finalStyle,
      ),
    );

    return FittedBox(
      fit: boxFit,
      child: textWidget,
    );
  }
}