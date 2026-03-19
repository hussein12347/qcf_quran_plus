import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../qcf_quran_plus.dart';
import '../data/quran_data.dart';
import 'bsmallah_widget.dart';
import 'surah_header_widget.dart';

/// A widget that displays a specific Surah as a vertically scrollable list of verses.
/// It supports dark mode, Tajweed colors, and verse highlighting.
class QuranSurahListView extends StatelessWidget {
  /// The number of the Surah to display (1 to 114).
  final int surahNumber;

  /// Custom font size for the Quranic text. If null, the default size is used.
  final double? fontSize;

  /// A list of verses that should be highlighted.
  final List<HighlightVerse> highlights;

  /// Callback triggered when a verse is long-pressed.
  final void Function(int surahNumber, int verseNumber, LongPressStartDetails details)? onLongPress;

  /// Custom text style applied to the Quranic text.
  final TextStyle? ayahStyle;

  /// A custom builder to override the default Surah header (the frame containing the Surah name).
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;

  /// A custom builder to override the default Basmallah image/text.
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;

  /// A custom builder to completely override how an individual Ayah (verse) is rendered.
  final Widget Function(BuildContext context, int surahNumber, int verseNumber, int pageNumber, Widget ayahWidget, bool isHighlighted, Color highlightColor)? ayahBuilder;

  /// Controller to programmatically scroll to a specific verse.
  final ItemScrollController? itemScrollController;

  /// Listener to track the currently visible verses on the screen.
  final ItemPositionsListener? itemPositionsListener;

  /// The index of the verse to scroll to initially when the widget is built.
  final int initialScrollIndex;

  /// Whether to display the text with Tajweed color coding.
  final bool isTajweed;

  /// Adapts the text colors to be visible on dark backgrounds.
  final bool isDarkMode;

  const QuranSurahListView({
    super.key,
    required this.surahNumber,
    required this.highlights,
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

  @override
  Widget build(BuildContext context) {
    // Filter the global quran dataset for the current Surah directly in the build method
    final List<dynamic> surahAyahs = quran.where((ayah) => ayah['sora'] == surahNumber).toList();

    // Configure color filtering for dark mode support with QCF fonts.
    ColorFilter? textFilter;
    if (isDarkMode && isTajweed) {
      // Inverts brightness for dark mode while preserving the distinct Tajweed color hues
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    } else if (isDarkMode && !isTajweed) {
      // Forces all text to be pure white
      textFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    } else if (!isDarkMode && !isTajweed) {
      // Forces all text to be pure black
      textFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
    }

    // Force Right-to-Left (RTL) text direction for Arabic
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScrollablePositionedList.builder(
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        initialScrollIndex: initialScrollIndex,
        physics: const BouncingScrollPhysics(),
        // Add 1 to the item count to accommodate the Surah Header/Basmallah at index 0
        itemCount: surahAyahs.length + 1,
        itemBuilder: (context, index) {
          // Render the Surah Header and Basmallah at the very top of the list
          if (index == 0) {
            return Column(
              children: [
                const SizedBox(height: 16),
                surahHeaderBuilder?.call(context, surahNumber) ??
                    SurahHeaderWidget(suraNumber: surahNumber),
                // Display Basmallah for all Surahs except At-Tawbah (Surah 9)
                if (surahNumber != 9)
                  basmallahBuilder?.call(context, surahNumber) ??
                      BasmallahWidget(surahNumber),
                const SizedBox(height: 16),
              ],
            );
          }

          // Adjust index by -1 to map correctly to the surahAyahs list
          final ayahData = surahAyahs[index - 1];
          final int verseNumber = ayahData['aya_no'];
          final int pageNumber = ayahData['page'];

          // Clean the raw text and prepare QCF glyphs
          final String othmanicText = ayahData['qcfData']
              .toString()
              .replaceAll('\n', '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trimRight();

          // Extract the special Ayah end-glyph (the decorative circle with the number)
          String glyph = getaya_noQCF(surahNumber, verseNumber);
          String textWithoutGlyph = othmanicText;
          bool hasGlyph = othmanicText.endsWith(glyph);

          // Separate the text from the glyph to allow independent styling
          if (hasGlyph) {
            textWithoutGlyph = othmanicText.substring(0, othmanicText.length - glyph.length);
          }

          final defaultStyle = ayahStyle ??
              QuranTextStyles.qcfStyle(
                height: 1.45,
                pageNumber: pageNumber,
              );

          // Apply requested font size and color filters to the main text
          TextStyle mainTextStyle = defaultStyle.copyWith(height: null, fontSize: fontSize);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(foreground: Paint()..colorFilter = textFilter),
            );
          }

          // Style for the Ayah Number end-glyph
          TextStyle numberTextStyle = defaultStyle.copyWith(height: null);
          if (isDarkMode) {
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
            numberTextStyle = numberTextStyle.copyWith(
              color: Theme.of(context).primaryColor,
              foreground: null,
            );
          }

          // Build the RichText representation of the verse
          Widget preBuiltAyahWidget = RichText(
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            text: TextSpan(
              children: [
                TextSpan(text: textWithoutGlyph, style: mainTextStyle),
                if (hasGlyph) TextSpan(text: glyph, style: numberTextStyle),
              ],
            ),
          );

          // Check if this specific verse is marked for highlighting
          final isHighlighted = highlights.any(
                (h) => h.surah == surahNumber && h.verseNumber == verseNumber,
          );

          final highlightColor = isHighlighted
              ? highlights.firstWhere((h) => h.surah == surahNumber && h.verseNumber == verseNumber).color
              : Colors.transparent;

          // Wrap the Ayah with Interaction (GestureDetector) and Highlight (Container) logic
          Widget ayahInteractiveWidget = GestureDetector(
            onLongPressStart: (details) {
              onLongPress?.call(surahNumber, verseNumber, details);
            },
            child: ayahBuilder != null
                ? ayahBuilder!(
              context,
              surahNumber,
              verseNumber,
              pageNumber,
              preBuiltAyahWidget,
              isHighlighted,
              highlightColor,
            )
                : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isHighlighted ? highlightColor.withAlpha(76) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: preBuiltAyahWidget,
            ),
          );

          // Return the widget directly without FutureBuilder or font checking
          return KeyedSubtree(
            key: ValueKey('ayah_${surahNumber}_$verseNumber'),
            child: ayahInteractiveWidget,
          );
        },
      ),
    );
  }
}