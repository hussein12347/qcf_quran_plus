import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../qcf_quran_plus.dart';
import '../data/quran_data.dart';
import '../widgets/bsmallah_widget.dart';

/// A scrollable list view that renders the verses (Ayahs) of a specific Surah.
///
/// This widget supports interactive word tapping, verse long-pressing,
/// custom highlight layers for both words and entire verses, and advanced
/// QCF (Quran Complex Font) rendering with optional Tajweed coloring.
///
/// Key features:
/// - RTL layout out of the box for Arabic Quranic text.
/// - Custom surah header and Basmallah builders (defaults are provided).
/// - Per-word highlighting via [wordHighlights].
/// - Per-verse highlighting via [highlights].
/// - Optional Tajweed coloring controlled by [isTajweed].
/// - Programmatic scrolling through [itemScrollController] and observing
///   visible items through [itemPositionsListener].
class QuranSurahListView extends StatelessWidget {
  /// Creates a [QuranSurahListView].
  ///
  /// Only [surahNumber] and [highlights] are required. All other parameters
  /// are optional and fall back to sensible defaults.
  const QuranSurahListView({
    super.key,
    required this.surahNumber,
    required this.highlights,
    this.wordHighlights = const [],
    this.onWordTap,
    this.onLongPress,
    this.ayahStyle,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahBuilder,
    this.itemScrollController,
    this.itemPositionsListener,
    this.initialScrollIndex = 0,
    this.isTajweed = true,
    this.isDarkMode = false,
    this.fontSize,
  });

  /// The number of the Surah (1-114) to display in this list.
  final int surahNumber;

  /// A list of verses to highlight (e.g., active audio playback, bookmarks).
  final List<HighlightVerse> highlights;

  /// A list of specific words to highlight within the displayed verses.
  final List<WordHighlight> wordHighlights;

  /// Callback triggered when a user long-presses on a verse.
  /// Provides the Surah number, verse number, and gesture details.
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;

  /// Callback triggered when a user taps on a specific word.
  /// Provides the Surah number, verse number, word index, and the raw word string.
  final void Function(
    int surahNumber,
    int verseNumber,
    int wordIndex,
    String word,
  )?
  onWordTap;

  /// Custom text style to apply to the verses.
  /// Overrides the default QCF style if provided.
  final TextStyle? ayahStyle;

  /// A custom builder for the header of the Surah.
  /// If null, a default [SurahHeaderWidget] is used.
  final Widget Function(BuildContext context, int surahNumber)?
  surahHeaderBuilder;

  /// A custom builder for the Basmallah graphic/text.
  /// If null, a default [BasmallahWidget] is used.
  /// Not displayed for Surah At-Tawbah (9).
  final Widget Function(BuildContext context, int surahNumber)?
  basmallahBuilder;

  /// A custom builder for rendering the verse container.
  /// Allows wrapping the verse in custom decorations, padding, or interactive widgets.
  final Widget Function(
    BuildContext context,
    int surahNumber,
    int verseNumber,
    int pageNumber,
    Widget ayahWidget,
    bool isHighlighted,
    Color highlightColor,
  )?
  ayahBuilder;

  /// Controller to programmatically scroll to a specific verse index.
  final ItemScrollController? itemScrollController;

  /// Listener to observe the currently visible indices in the viewport.
  final ItemPositionsListener? itemPositionsListener;

  /// The initial index to scroll to when the view is first built.
  final int initialScrollIndex;

  /// Whether to render the text using Tajweed-specific fonts and colors.
  final bool isTajweed;

  /// Whether the app is currently in dark mode, adjusting default colors accordingly.
  final bool isDarkMode;

  /// Optional font size to override the default text size.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    // Filter the global Quran dataset to only include ayahs for the requested Surah.
    final surahAyahs = quran
        .where((ayah) => ayah['sora'] == surahNumber)
        .toList();

    // Force RTL direction so the Arabic text flows naturally right-to-left.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScrollablePositionedList.builder(
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        initialScrollIndex: initialScrollIndex,
        physics: const BouncingScrollPhysics(),
        // Add 1 to the item count to reserve index 0 for the header section.
        itemCount: surahAyahs.length + 1,
        itemBuilder: (context, index) {
          // Index 0 is reserved for the Surah Header and Basmallah.
          if (index == 0) {
            return Column(
              children: [
                const SizedBox(height: 16),
                // Use the custom header builder when provided; otherwise, the default.
                surahHeaderBuilder?.call(context, surahNumber) ??
                    SurahHeaderWidget(suraNumber: surahNumber),
                // Surah At-Tawbah (9) does not begin with a Basmallah.
                if (surahNumber != 9)
                  basmallahBuilder?.call(context, surahNumber) ??
                      BasmallahWidget(surahNumber),
                const SizedBox(height: 16),
              ],
            );
          }

          // Retrieve verse data (adjusting index to account for the header at index 0).
          final ayahData = surahAyahs[index - 1];
          final verseNumber = ayahData['aya_no'] as int;
          final pageNumber = ayahData['page'] as int;

          // Normalize the plain Arabic text by collapsing newlines and trimming.
          final ayaText = ayahData['aya_text']
              .toString()
              .replaceAll('\n', ' ')
              .trim();

          // Regex to filter out verse numbering digits and specific symbols.
          final digitsRegex = RegExp(
            r'^[\d٠-٩۩۞ۤ\u06D6-\u06DC\u06DE\u06E4\u06E9]+$',
          );

          // Split the text into "logical words" and drop tokens that are
          // only digits or decorative symbols (they don't map to QCF glyphs).
          final logicalWords = ayaText
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty && !digitsRegex.hasMatch(word))
              .toList();

          // Prepare the raw QCF glyph string for this ayah.
          final rawQcf = ayahData['qcfData']
              .toString()
              .replaceAll('\n', '')
              .trimRight();

          // Fetch the ayah-number glyph from the QCF dataset (cached internally).
          final glyph = getAyaNoQCF(surahNumber, verseNumber);

          // Strip the trailing ayah-number glyph from the QCF body text so we
          // can render it separately with its own dedicated style.
          final cleanQcf = rawQcf.endsWith(glyph)
              ? rawQcf.substring(0, rawQcf.length - glyph.length)
              : rawQcf;

          // Resolve the base style: custom [ayahStyle] takes priority over the
          // default QCF style derived from the current page number.
          final defaultStyle =
              (ayahStyle ??
                      QuranTextStyles.qcfStyle(
                        height: 1.45,
                        pageNumber: pageNumber,
                        isTajweed: isTajweed,
                        isDark: isDarkMode,
                      ))
                  .copyWith(color: null);

          // Main style used for the verse body characters.
          final mainTextStyle = defaultStyle.copyWith(
            height: null,
            fontSize: fontSize,
            color: null,
          );

          // Always use the light Tajweed font for the verse number/end glyph
          // to ensure correct styling regardless of dark mode or normal text settings.
          final numberTextStyle = mainTextStyle.copyWith(
            height: null,
            color: null,
            fontFamily: QuranTextStyles.getQcfFontFamily(
              pageNumber: pageNumber,
              isTajweed: true,
              isDark: false,
            ),
          );

          // Map word highlights for O(1) lookup during span generation.
          final wordHighlightMap = <String, WordHighlight>{};
          for (final highlight in wordHighlights) {
            if (highlight.surah == surahNumber &&
                highlight.verseNumber == verseNumber) {
              wordHighlightMap[
                  '${highlight.surah}_${highlight.verseNumber}_${highlight.wordIndex}'] =
                  highlight;
            }
          }

          // Regex used to count Tajweed/symbol marks embedded in a logical word.
          final symbolRegex = RegExp(r'[\u06D6-\u06DC\u06DE\u06E9]');
          final wordSpans = <InlineSpan>[];

          // Trackers for mapping logical words to QCF glyphs.
          int qcfCharIndex = 0;
          int currentWordIndex = 0;

          // Process each logical word to generate interactive TextSpans.
          for (int i = 0; i < logicalWords.length; i++) {
            final logicalWord = logicalWords[i];
            final symbolCount = symbolRegex.allMatches(logicalWord).length;
            // Each logical word consumes 1 base glyph plus one per symbol.
            final glyphsNeeded = 1 + symbolCount;
            final thisWordIndex = currentWordIndex;

            currentWordIndex++;

            for (int k = 0; k < glyphsNeeded; k++) {
              // Skip spaces and zero-width spaces in QCF string.
              while (qcfCharIndex < cleanQcf.length &&
                  (cleanQcf[qcfCharIndex] == ' ' ||
                      cleanQcf[qcfCharIndex] == '\u200B')) {
                wordSpans.add(
                  TextSpan(text: cleanQcf[qcfCharIndex], style: mainTextStyle),
                );
                qcfCharIndex++;
              }

              // Guard against running past the end of the QCF string.
              if (qcfCharIndex >= cleanQcf.length) break;

              final char = cleanQcf[qcfCharIndex];

              // Identify stop signs and special symbols.
              final isSymbol =
                  logicalWord.startsWith('۞') || logicalWord.startsWith('۩')
                  ? k == 0
                  : k > 0;

              // Look up an optional per-word highlight for this specific word.
              final highlight =
                  wordHighlightMap['${surahNumber}_${verseNumber}_$thisWordIndex'];
              TextStyle charStyle = mainTextStyle;

              if (highlight != null) {
                // Apply a text color if provided.
                if (highlight.textColor != null) {
                  charStyle = charStyle.copyWith(color: highlight.textColor);
                }
                // Apply a background color, but skip it for decorative symbols.
                if (highlight.backgroundColor != null && !isSymbol) {
                  charStyle = charStyle.copyWith(
                    backgroundColor: highlight.backgroundColor,
                  );
                }
              }

              wordSpans.add(
                TextSpan(
                  text: char,
                  style: charStyle,
                  // Attach a tap recognizer to real words only (not symbols).
                  recognizer: isSymbol
                      ? null
                      : (TapGestureRecognizer()
                          ..onTap = () {
                            onWordTap?.call(
                              surahNumber,
                              verseNumber,
                              thisWordIndex,
                              logicalWord,
                            );
                          }),
                ),
              );

              qcfCharIndex++;
            }
          }

          // Catch any remaining characters at the end of the ayah.
          while (qcfCharIndex < cleanQcf.length) {
            wordSpans.add(
              TextSpan(text: cleanQcf[qcfCharIndex], style: mainTextStyle),
            );
            qcfCharIndex++;
          }

          // Combine words and the trailing verse number glyph into a single RichText.
          final preBuiltAyahWidget = Text.rich(
            TextSpan(
              children: [
                ...wordSpans,
                if (rawQcf.endsWith(glyph))
                  TextSpan(text: glyph, style: numberTextStyle),
              ],
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          );

          // Check if the entire verse is highlighted.
          final matchingHighlights = highlights.where(
            (h) => h.surah == surahNumber && h.verseNumber == verseNumber,
          );
          final matchingHighlight = matchingHighlights.isEmpty
              ? null
              : matchingHighlights.first;
          final isHighlighted = matchingHighlight != null;
          final highlightColor = matchingHighlight?.color ?? Colors.transparent;

          // Build the final interactive verse container.
          final ayahInteractiveWidget = GestureDetector(
            // Long-press reports the verse context back to the caller.
            onLongPressStart: (details) {
              onLongPress?.call(surahNumber, verseNumber, details);
            },
            child: ayahBuilder != null
                // Allow the caller to fully customize the verse container.
                ? ayahBuilder!(
                    context,
                    surahNumber,
                    verseNumber,
                    pageNumber,
                    preBuiltAyahWidget,
                    isHighlighted,
                    highlightColor,
                  )
                // Default container with optional highlight background.
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? highlightColor.withAlpha(76)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: preBuiltAyahWidget,
                  ),
          );

          // Use a stable key so Flutter can efficiently reuse list items.
          return KeyedSubtree(
            key: ValueKey('ayah_${surahNumber}_$verseNumber'),
            child: ayahInteractiveWidget,
          );
        },
      ),
    );
  }
}