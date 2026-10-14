import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/highlight_index.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
import '../../qcf_quran_plus.dart';

/// A widget that renders a single line of Quranic text using QCF fonts.
///
/// The line may contain multiple ayahs (verses) that share the same physical
/// line on a Quran page. Each ayah is rendered as a sequence of word spans
/// with support for:
/// - Word-level highlights (text color and background color).
/// - Verse-level (bookmark) highlights.
/// - Tap gestures on words and verses.
/// - Long-press gestures on verses.
/// - Tajweed coloring and dark mode.
///
/// Internally, the widget uses [ParsedAyahData] to avoid re-parsing the line
/// on every rebuild, and caches text styles for performance.
class QuranLine extends StatefulWidget {
  /// Creates a [QuranLine].
  const QuranLine({
    super.key,
    required this.parsedAyahs,
    required this.pageNumber,
    this.wordHighlightIndex = WordHighlightIndex.empty,
    this.bookmarkIndex = BookmarkIndex.empty,
    this.boxFit = BoxFit.fill,
    this.onLongPress,
    this.onWordTap,
    this.onVerseTap,
    this.ayahStyle,
    this.isTajweed = true,
    this.isDark = false,
  });

  /// The pre-parsed list of ayahs that make up this line.
  final List<ParsedAyahData> parsedAyahs;

  /// The 1-based page number this line belongs to.
  /// Used to select the correct QCF font family.
  final int pageNumber;

  /// An index for fast lookup of word-level highlights.
  final WordHighlightIndex wordHighlightIndex;

  /// An index for fast lookup of verse-level (bookmark) highlights.
  final BookmarkIndex bookmarkIndex;

  /// How the line should be fitted inside its parent.
  final BoxFit boxFit;

  /// Called when the user long-presses on a verse.
  /// Provides: surah number, verse number, and gesture details.
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPress;

  /// Called when the user taps on a word.
  /// Provides: surah number, verse number, word index, and the raw word text.
  final void Function(
    int surahNumber,
    int verseNumber,
    int wordIndex,
    String word,
  )? onWordTap;

  /// Called when the user taps on a verse.
  /// Provides: surah number and verse number.
  final void Function(int surahNumber, int verseNumber)? onVerseTap;

  /// Optional custom text style for the ayah text.
  final TextStyle? ayahStyle;

  /// Whether Tajweed coloring is enabled.
  final bool isTajweed;

  /// Whether the app is in dark mode.
  final bool isDark;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  /// The main text style used for regular Quranic characters.
  late TextStyle _mainTextStyle;

  /// The text style used for the ayah number glyph (end-of-verse symbol).
  late TextStyle _numberTextStyle;

  /// A special style for rendering spaces.
  ///
  /// QCF fonts are designed so that every glyph fills the entire em-square.
  /// As a result, a normal space character (`' '`) takes up an enormous amount
  /// of width (approximately the font size) and distorts the line.
  /// The solution: draw the space using the same QCF font family (to avoid
  /// breaking text shaping) but with a very small font size and a transparent
  /// color. This produces a natural-looking space without any visual artifact.
  late TextStyle _spaceStyle;

  /// Gesture recognizers must be disposed to avoid memory leaks.
  final List<GestureRecognizer> _recognizers = [];

  /// The maximum font size allowed for spaces before they start breaking the layout.
  static const double _spaceFontSize = 10.0;

  @override
  void initState() {
    super.initState();
    _buildStyles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildStyles();
  }

  @override
  void didUpdateWidget(covariant QuranLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild styles whenever any style-affecting input changes.
    if (oldWidget.ayahStyle != widget.ayahStyle ||
        oldWidget.isTajweed != widget.isTajweed ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.pageNumber != widget.pageNumber) {
      _buildStyles();
    }
  }

  /// Builds and caches the text styles used by this line.
  ///
  /// The main style is derived from the provided [ayahStyle] or the default
  /// QCF style for the current page. The number style always uses the light
  /// Tajweed font to ensure correct rendering of the ayah-end glyph. The
  /// space style inherits the main font family but uses a tiny size and
  /// transparent color to avoid layout distortion.
  void _buildStyles() {
    final defaultStyle = widget.ayahStyle ??
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

    // Important: use the same QCF font family (inherited from _mainTextStyle)
    // to avoid font fallback conflicts, but with a tiny size and transparent color.
    _spaceStyle = _mainTextStyle.copyWith(
      fontSize: _spaceFontSize,
      color: Colors.transparent,
      height: 1.0,
      letterSpacing: 0,
      wordSpacing: 0,
    );
  }

  /// Disposes all gesture recognizers created for this line.
  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Creates a [TapGestureRecognizer] that invokes [onTap] and tracks it for disposal.
  TapGestureRecognizer _tap(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  /// Builds the list of [InlineSpan]s that represent the visual content of the line.
  ///
  /// This method iterates over all parsed ayahs and their words, applying
  /// highlights and attaching gestures where appropriate. It also handles
  /// zero-width spaces (skipped) and regular spaces (rendered with a shrunken
  /// style to avoid layout issues).
  List<InlineSpan> _buildDisplayChildren() {
    // Clean up recognizers from previous builds to prevent leaks.
    _disposeRecognizers();

    final children = <InlineSpan>[];

    for (int ayahIdx = 0; ayahIdx < widget.parsedAyahs.length; ayahIdx++) {
      final ayahData = widget.parsedAyahs[ayahIdx];
      final surah = ayahData.surahNumber;
      final ayah = ayahData.ayahNumber;

      // Check if this verse has a bookmark highlight.
      final bookmark = widget.bookmarkIndex.lookup(surah, ayah);
      final isAyahHighlighted = bookmark != null;
      final highlightColor = bookmark?.color ?? Colors.transparent;

      final wordSpans = <InlineSpan>[];

      for (int wIdx = 0; wIdx < ayahData.words.length; wIdx++) {
        final wordData = ayahData.words[wIdx];

        // Zero-width space: visually invisible, skip it entirely.
        if (wordData.text == '\u200B') {
          continue;
        }

        // Space: render with the shrunken style to avoid distorting the line.
        if (wordData.isSpace) {
          wordSpans.add(TextSpan(text: ' ', style: _spaceStyle));
          continue;
        }

        var charStyle = _mainTextStyle;

        // Apply word-level highlight if available.
        if (wordData.wordIndex != null) {
          final h = widget.wordHighlightIndex.lookup(
            surah,
            ayah,
            wordData.wordIndex!,
          );
          if (h != null) {
            if (h.textColor != null) {
              charStyle = charStyle.copyWith(color: h.textColor);
            }
            // Background highlight is skipped for symbols (e.g. sajdah markers).
            if (!wordData.isSymbol && h.backgroundColor != null) {
              charStyle = charStyle.copyWith(
                backgroundColor: h.backgroundColor,
              );
            }
          }
        }

        // Attach tap gestures for words and/or verses.
        GestureRecognizer? recognizer;
        final canWordTap = wordData.wordIndex != null &&
            wordData.logicalWord != null &&
            widget.onWordTap != null;

        if (canWordTap || widget.onVerseTap != null) {
          recognizer = _tap(() {
            if (canWordTap) {
              widget.onWordTap!(
                surah,
                ayah,
                wordData.wordIndex!,
                wordData.logicalWord!,
              );
            }
            widget.onVerseTap?.call(surah, ayah);
          });
        }

        wordSpans.add(
          TextSpan(
            text: wordData.text,
            style: charStyle,
            recognizer: recognizer,
          ),
        );
      }

      // Append the ayah number glyph (end-of-verse symbol) if present.
      if (ayahData.glyph != null) {
        wordSpans.add(
          TextSpan(
            text: ayahData.glyph,
            style: _numberTextStyle,
            recognizer: widget.onVerseTap == null
                ? null
                : _tap(() => widget.onVerseTap!(surah, ayah)),
          ),
        );
      }

      // Wrap the ayah spans in a WidgetSpan so we can attach a long-press
      // gesture and a background decoration for verse-level highlights.
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: widget.onLongPress == null
                ? null
                : (d) => widget.onLongPress!(surah, ayah, d),
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
        ),
      );
    }

    return children;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to render if there are no parsed ayahs.
    if (widget.parsedAyahs.isEmpty) return const SizedBox.shrink();

    return FittedBox(
      fit: widget.boxFit,
      child: RichText(
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: _mainTextStyle,
          children: _buildDisplayChildren(),
        ),
      ),
    );
  }
}