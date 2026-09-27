import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/highlight_index.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
import '../../qcf_quran_plus.dart';

class QuranLine extends StatefulWidget {
  const QuranLine({
    super.key,
    required this.parsedAyahs,
    required this.pageNumber,
    this.wordHighlightIndex = WordHighlightIndex.empty,
    this.bookmarkIndex = BookmarkIndex.empty,
    this.boxFit = BoxFit.fill,
    this.onLongPress,
    this.onWordTap,
    this.ayahStyle,
    this.isTajweed = true,
    this.isDark = false,
  });

  final List<ParsedAyahData> parsedAyahs;
  final int pageNumber;
  final WordHighlightIndex wordHighlightIndex;
  final BookmarkIndex bookmarkIndex;
  final BoxFit boxFit;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;
  final void Function(
    int surahNumber,
    int verseNumber,
    int wordIndex,
    String word,
  )?
  onWordTap;
  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  List<List<TapGestureRecognizer?>> _recognizers = [];
  bool _recognizersReady = false;
  Timer? _debounceTimer;

  late TextStyle _mainTextStyle;
  late TextStyle _numberTextStyle;

  @override
  void initState() {
    super.initState();
    _buildRecognizersAsync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildStyles();
  }

  @override
  void didUpdateWidget(covariant QuranLine oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.parsedAyahs != widget.parsedAyahs ||
        oldWidget.onWordTap != widget.onWordTap) {
      _buildRecognizersAsync();
    }
    if (oldWidget.isDark != widget.isDark ||
        oldWidget.isTajweed != widget.isTajweed ||
        oldWidget.ayahStyle != widget.ayahStyle) {
      _buildStyles();
    }
  }

  /// Builds the tap recognizers for word-level interactions after a brief debounce.
  ///
  /// This helps avoid blocking the UI while scrolling through a page containing
  /// many ayahs and words.
  void _buildRecognizersAsync() {
    if (widget.onWordTap == null) {
      _recognizersReady = false;
      return;
    }

    _recognizersReady = false;
    _disposeRecognizers();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      _recognizers = widget.parsedAyahs.map((ayahData) {
        return ayahData.words.map<TapGestureRecognizer?>((wordData) {
          if (wordData.isSpace ||
              wordData.isSymbol ||
              wordData.wordIndex == null ||
              wordData.logicalWord == null) {
            return null;
          }
          final surah = ayahData.surahNumber;
          final ayah = ayahData.ayahNumber;
          final wordIndex = wordData.wordIndex!;
          final logicalWord = wordData.logicalWord!;

          return TapGestureRecognizer()
            ..onTap = () =>
                widget.onWordTap?.call(surah, ayah, wordIndex, logicalWord);
        }).toList();
      }).toList();

      if (mounted) {
        setState(() {
          _recognizersReady = true;
        });
      }
    });
  }

  /// Releases all gesture recognizers created for word-level interaction.
  void _disposeRecognizers() {
    for (final ayahRecognizers in _recognizers) {
      for (final r in ayahRecognizers) {
        r?.dispose();
      }
    }
    _recognizers.clear();
  }

  void _buildStyles() {
    final defaultStyle =
        widget.ayahStyle ??
        QuranTextStyles.qcfStyle(
          height: 1.45,
          pageNumber: widget.pageNumber,
          isTajweed: widget.isTajweed,
          isDark: widget.isDark,
        );

    _mainTextStyle = defaultStyle.copyWith(height: null, color: null);
    _numberTextStyle = _mainTextStyle.copyWith(
      fontFamily: QuranTextStyles.getQcfFontFamily(
        pageNumber: widget.pageNumber,
        isTajweed: true,
        isDark: false,
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parsedAyahs.isEmpty) return const SizedBox.shrink();

    final textWidget = RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: _mainTextStyle,
        children: List.generate(widget.parsedAyahs.length, (ayahIdx) {
          final ayahData = widget.parsedAyahs[ayahIdx];

          final bookmark = widget.bookmarkIndex.lookup(
            ayahData.surahNumber,
            ayahData.ayahNumber,
          );
          final isAyahHighlighted = bookmark != null;
          final highlightColor = bookmark?.color ?? Colors.transparent;
          final wordSpans = <InlineSpan>[];

          for (int wIdx = 0; wIdx < ayahData.words.length; wIdx++) {
            final wordData = ayahData.words[wIdx];
            var charStyle = _mainTextStyle;

            if (!wordData.isSpace && wordData.wordIndex != null) {
              final wordHighlight = widget.wordHighlightIndex.lookup(
                ayahData.surahNumber,
                ayahData.ayahNumber,
                wordData.wordIndex!,
              );

              if (wordHighlight != null) {
                if (wordHighlight.textColor != null) {
                  charStyle = charStyle.copyWith(
                    color: wordHighlight.textColor!,
                  );
                }
                if (!wordData.isSymbol &&
                    wordHighlight.backgroundColor != null) {
                  charStyle = charStyle.copyWith(
                    backgroundColor: wordHighlight.backgroundColor,
                  );
                }
              }
            }

            wordSpans.add(
              TextSpan(
                text: wordData.text,
                style: charStyle,
                recognizer: _recognizersReady
                    ? _recognizers[ayahIdx][wIdx]
                    : null,
              ),
            );
          }

          if (ayahData.glyph != null) {
            wordSpans.add(
              TextSpan(text: ayahData.glyph, style: _numberTextStyle),
            );
          }

          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onLongPressStart: (details) => widget.onLongPress?.call(
                ayahData.surahNumber,
                ayahData.ayahNumber,
                details,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isAyahHighlighted
                      ? highlightColor.withValues(alpha: 0.4)
                      : null,
                ),
                child: Text.rich(
                  TextSpan(children: wordSpans),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          );
        }),
      ),
    );

    return FittedBox(fit: widget.boxFit, child: textWidget);
  }
}
