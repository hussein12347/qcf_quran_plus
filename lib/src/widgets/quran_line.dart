import 'package:flutter/material.dart';
import '../../qcf_quran_plus.dart';

/// Renders a single line of Quran text using QCF fonts with highlight support.
///
/// **Performance optimizations applied:**
/// - All heavy text processing (trim, substring, glyph lookup) is moved
///   to `initState` and `didUpdateWidget`.
/// - Processing happens **once** per line instead of 60 times a second during UI rendering.
/// - Removed `Isolate` because package functions (like getaya_noQCF) may contain
///   unsendable objects (like Completers). Synchronous caching is fast enough to prevent jank.
class QuranLine extends StatefulWidget {
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
  final void Function(int surahNumber, int verseNumber, LongPressStartDetails details)? onLongPress;
  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  /// Pre-processed data (text, glyph, etc.) stored in memory
  late final List<_AyahDisplayData> _displayData;

  @override
  void initState() {
    super.initState();
    _displayData = _processData();
  }
  List<_AyahDisplayData> _processData() {
    return widget.line.ayahs.reversed.map((ayah) {
      final currentQcfText = ayah.qcfData.trimRight();
      final glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);
      final hasGlyph = currentQcfText.endsWith(glyph);

      final textWithoutGlyph = hasGlyph
          ? currentQcfText.substring(0, currentQcfText.length - glyph.length)
          : currentQcfText;

      return _AyahDisplayData(
        textWithoutGlyph: textWithoutGlyph,
        glyph: glyph,
        hasGlyph: hasGlyph,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
      );
    }).toList();
  }

  @override
  void didUpdateWidget(covariant QuranLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-process only if the actual line data has changed
    if (oldWidget.line != widget.line) {
      _processData();
    }
  }

  /// Processes text strings ONCE synchronously.
  /// This eliminates scroll jank without the need for Isolates.

  @override
  Widget build(BuildContext context) {
    // If empty (safety check), return invisible box
    if (_displayData.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = QuranTextStyles.qcfStyle(
      fontSize: 23.55,
      height: 1.45,
      pageNumber: widget.line.ayahs.first.page,
    );

    final finalStyle = widget.ayahStyle != null
        ? defaultStyle.merge(widget.ayahStyle!)
        : defaultStyle;

    ColorFilter? textFilter;
    if (widget.isDark && widget.isTajweed) {
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    } else if (widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    } else if (!widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
    }
    final highlightMap = {
      for (var h in widget.bookmarks)
        '${h.surah}_${h.verseNumber}': h
    };
    final textWidget = RichText(
      text: TextSpan(
        // Build is now ultra-light and fast!
        children: _displayData.map((data) {
          final highlight = highlightMap['${data.surahNumber}_${data.ayahNumber}'];

          final isHighlighted = highlight?.color != Colors.transparent;

          TextStyle mainTextStyle = finalStyle.copyWith(height: null);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(foreground: Paint()..colorFilter = textFilter),
            );
          }

          TextStyle numberTextStyle = finalStyle.copyWith(height: null);
          if (widget.isDark) {
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
          }

          final ayahTextWidget = Text.rich(
        TextSpan(
              children: [
                TextSpan(text: data.textWithoutGlyph, style: mainTextStyle),
                if (data.hasGlyph) TextSpan(text: data.glyph, style: numberTextStyle),
              ],
            ),
          );

          return WidgetSpan(
            child: GestureDetector(
              onLongPressStart: (details) =>
                  widget.onLongPress?.call(data.surahNumber, data.ayahNumber, details),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isHighlighted ? highlight?.color.withOpacity(0.4) : null,
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
      fit: widget.boxFit,
      child: textWidget,
    );
  }
}

/// Lightweight immutable data class.
/// Contains everything needed to build the spans instantly.
class _AyahDisplayData {
  final String textWithoutGlyph;
  final String glyph;
  final bool hasGlyph;
  final int surahNumber;
  final int ayahNumber;

  const _AyahDisplayData({
    required this.textWithoutGlyph,
    required this.glyph,
    required this.hasGlyph,
    required this.surahNumber,
    required this.ayahNumber,
  });
}