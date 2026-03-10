import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../qcf_quran_plus.dart';
import '../data/quran_data.dart';
import '../models/highlight_verse.dart';
import 'bsmallah_widget.dart';
import 'surah_header_widget.dart';

/// A highly customizable widget that displays a specific Surah as a vertically scrollable list.
///
/// [QuranSurahListView] is perfect for building "Reading Modes", Tafseer apps,
/// or translation views. It natively supports Audio Syncing capabilities by
/// exposing [itemScrollController] and [itemPositionsListener] from the
/// `scrollable_positioned_list` package.
class QuranSurahListView extends StatelessWidget {
  /// The Surah number (1-114) to be displayed.
  final int surahNumber;
  final double? fontSize;

  /// A reactive notifier containing a list of [HighlightVerse] for dynamically
  /// highlighting specific Ayahs without rebuilding the entire list.
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;

  /// Callback fired when a specific verse is long-pressed.
  final void Function(
      int surahNumber,
      int verseNumber,
      LongPressStartDetails details,
      )? onLongPress;

  /// Custom text styling for the default Quranic text rendering.
  final TextStyle? ayahStyle;

  /// A custom builder to completely override the default Surah Header widget.
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;

  /// A custom builder to completely override the default Basmallah widget.
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;

  /// A powerful builder that grants FULL CONTROL over how each Ayah is rendered.
  final Widget Function(
      BuildContext context,
      int surahNumber,
      int verseNumber,
      int pageNumber,
      Widget ayahWidget,
      bool isHighlighted,
      Color highlightColor,
      )? ayahBuilder;

  /// Controller to programmatically jump or scroll to a specific Ayah.
  /// **NOTE:** Index 0 is reserved for the Surah Header/Basmallah.
  final ItemScrollController? itemScrollController;

  /// Listener to track which Ayahs are currently visible on the screen.
  final ItemPositionsListener? itemPositionsListener;

  /// The initial index to scroll to when the view is first created.
  final int initialScrollIndex;

  /// Enable or disable Tajweed colors.
  final bool isTajweed;

  /// Enable or disable Dark Mode styling for the text and filters.
  final bool isDarkMode;

  const QuranSurahListView({
    super.key,
    required this.surahNumber,
    required this.highlightsNotifier,
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
    // Fetch all Ayahs belonging to the requested Surah
    final List surahAyahs = quran.where((ayah) => ayah['sora'] == surahNumber).toList();

    // 1. Determine the appropriate ColorFilter based on the theme and Tajweed state.
    ColorFilter? textFilter;

    if (isDarkMode && isTajweed) {
      // Magic matrix for Tajweed: Inverts colors while preserving the specific
      // Tajweed rule colors (Madd, Ikhfa, etc.) against a dark background.
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255, // Red
        0, -1, 0, 0, 255, // Green
        0, 0, -1, 0, 255, // Blue
        0, 0, 0, 1, 0,    // Alpha
      ]);
    } else if (isDarkMode && !isTajweed) {
      textFilter = const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      );
    } else if (!isDarkMode && !isTajweed) {
      textFilter = const ColorFilter.mode(
        Colors.black,
        BlendMode.srcIn,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScrollablePositionedList.builder(
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        initialScrollIndex: initialScrollIndex,
        physics: const BouncingScrollPhysics(),
        itemCount: surahAyahs.length + 1, // +1 for the Header/Basmallah at the top
        itemBuilder: (context, index) {
          // Render Header and Basmallah at index 0
          if (index == 0) {
            return Column(
              children: [
                const SizedBox(height: 16),
                surahHeaderBuilder?.call(context, surahNumber) ??
                    SurahHeaderWidget(suraNumber: surahNumber),
                if (surahNumber != 9) // Surah At-Tawbah does not start with Basmallah
                  basmallahBuilder?.call(context, surahNumber) ??
                      BasmallahWidget(surahNumber),
                const SizedBox(height: 16),
              ],
            );
          }

          // Extract Ayah data (index - 1 because index 0 is used for the header)
          final ayahData = surahAyahs[index - 1];
          final int verseNumber = ayahData['aya_no'];
          final int pageNumber = ayahData['page'];

          // Clean the Othmanic text: remove newlines and normalize whitespace
          final String othmanicText = ayahData['qcfData']
              .toString()
              .replaceAll('\n', '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trimRight();

          // 2. Process text and isolate the Ayah number glyph
          String glyph = getaya_noQCF(surahNumber, verseNumber);
          String textWithoutGlyph = othmanicText;
          bool hasGlyph = othmanicText.endsWith(glyph);

          if (hasGlyph) {
            textWithoutGlyph = othmanicText.substring(0, othmanicText.length - glyph.length);
          }

          // 3. Prepare text styles for the body and the verse number
          final defaultStyle = ayahStyle ??
              QuranTextStyles.qcfStyle(
                height: 1.5,
                pageNumber: pageNumber,
              );

          TextStyle mainTextStyle = defaultStyle.copyWith(height: null, fontSize: fontSize);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(
                foreground: Paint()..colorFilter = textFilter,
              ),
            );
          }

          TextStyle numberTextStyle = defaultStyle.copyWith(height: null);
          if (isDarkMode) {
            // Apply matrix inversion to the verse number glyph in Dark Mode
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
            // Use the app's primary color for verse numbers in Light Mode
            numberTextStyle = numberTextStyle.copyWith(
              color: Theme.of(context).primaryColor,
              foreground: null,
            );
          }

          Widget preBuiltAyahWidget = RichText(
            textAlign: TextAlign.right,
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

          // Reactive builder for performant verse highlighting during audio playback or selection
          return ValueListenableBuilder<List<HighlightVerse>>(
            valueListenable: highlightsNotifier,
            builder: (context, highlights, _) {
              final isHighlighted = highlights.any(
                    (h) => h.surah == surahNumber && h.verseNumber == verseNumber,
              );
              final highlightColor = isHighlighted
                  ? highlights
                  .firstWhere(
                    (h) => h.surah == surahNumber && h.verseNumber == verseNumber,
              )
                  .color
                  : Colors.transparent;

              return GestureDetector(
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
            },
          );
        },
      ),
    );
  }
}