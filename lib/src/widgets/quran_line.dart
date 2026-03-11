import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../qcf_quran_plus.dart';
import '../models/highlight_verse.dart';
import '../models/quran_page.dart';
import '../utils/font_loader_service.dart';

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

  final void Function(
      int surahNumber,
      int verseNumber,
      LongPressStartDetails details,
      )? onLongPress;

  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  bool _fontLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFont();
  }

  void _loadFont() async {
    int page = widget.line.ayahs.first.page;

     QcfFontLoader.preloadNearbyPages(page);

    if (mounted) {
      setState(() {
        _fontLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = QuranTextStyles.qcfStyle(
      fontSize: 23.55,
      height: 1.45,
      pageNumber: widget.line.ayahs.first.page,
    );

    final finalStyle =
    widget.ayahStyle != null ? defaultStyle.merge(widget.ayahStyle) : defaultStyle;

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

    Widget textWidget = RichText(
      text: TextSpan(
        children: widget.line.ayahs.reversed.map((ayah) {
          final highlight = widget.bookmarks.firstWhere(
                (h) => h.surah == ayah.surahNumber && h.verseNumber == ayah.ayahNumber,
            orElse: () => HighlightVerse(surah: 0, verseNumber: 0, page: 0, color: Colors.transparent),
          );

          bool isHighlighted = highlight.color != Colors.transparent;

          String currentQcfText = ayah.qcfData.trimRight();
          String glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);
          String textWithoutGlyph = currentQcfText;
          bool hasGlyph = currentQcfText.endsWith(glyph);

          if (hasGlyph) {
            textWithoutGlyph =
                currentQcfText.substring(0, currentQcfText.length - glyph.length);
          }

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

          Widget ayahTextWidget = RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              children: [
                TextSpan(text: textWithoutGlyph, style: mainTextStyle),
                if (hasGlyph) TextSpan(text: glyph, style: numberTextStyle),
              ],
            ),
          );

          return WidgetSpan(
            child: GestureDetector(
              onLongPressStart: (details) => widget.onLongPress?.call(
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
      fit: widget.boxFit,
      child: textWidget,
    );
  }
}