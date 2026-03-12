import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../qcf_quran_plus.dart';
import '../data/quran_data.dart';
import 'bsmallah_widget.dart';
import 'surah_header_widget.dart';

/// A widget that displays a Surah as a vertically scrollable list of verses.
class QuranSurahListView extends StatefulWidget {
  final int surahNumber;
  final double? fontSize;
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;
  final void Function(int surahNumber, int verseNumber, LongPressStartDetails details)? onLongPress;
  final TextStyle? ayahStyle;
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;
  final Widget Function(BuildContext context, int surahNumber, int verseNumber, int pageNumber, Widget ayahWidget, bool isHighlighted, Color highlightColor)? ayahBuilder;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final int initialScrollIndex;
  final bool isTajweed;
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
  State<QuranSurahListView> createState() => _QuranSurahListViewState();
}

class _QuranSurahListViewState extends State<QuranSurahListView> {
  List<dynamic> surahAyahs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSurahData();
  }

  @override
  void didUpdateWidget(covariant QuranSurahListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber) {
      setState(() {
        _initSurahData();
      });
    }
  }

  void _initSurahData() {
    // Extract ayahs for the current surah
    surahAyahs = quran.where((ayah) => ayah['sora'] == widget.surahNumber).toList();

    // Identify all unique pages in this surah and ensure their fonts are loaded
    final Set<int> requiredPages = surahAyahs.map<int>((a) => a['page'] as int).toSet();
    for (var page in requiredPages) {
      QcfFontLoader.ensureFontLoaded(page);
    }

    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Configure color filtering for dark mode support with QCF fonts
    ColorFilter? textFilter;
    if (widget.isDarkMode && widget.isTajweed) {
      // Inverts colors for Tajweed while preserving distinct color tones
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    } else if (widget.isDarkMode && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    } else if (!widget.isDarkMode && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScrollablePositionedList.builder(
        itemScrollController: widget.itemScrollController,
        itemPositionsListener: widget.itemPositionsListener,
        initialScrollIndex: widget.initialScrollIndex,
        physics: const BouncingScrollPhysics(),
        itemCount: surahAyahs.length + 1,
        itemBuilder: (context, index) {
          // Item 0: Surah Header and Basmallah
          if (index == 0) {
            return Column(
              children: [
                const SizedBox(height: 16),
                widget.surahHeaderBuilder?.call(context, widget.surahNumber) ??
                    SurahHeaderWidget(suraNumber: widget.surahNumber),
                if (widget.surahNumber != 9)
                  widget.basmallahBuilder?.call(context, widget.surahNumber) ??
                      BasmallahWidget(widget.surahNumber),
                const SizedBox(height: 16),
              ],
            );
          }

          final ayahData = surahAyahs[index - 1];
          final int verseNumber = ayahData['aya_no'];
          final int pageNumber = ayahData['page'];

          // Clean text and prepare QCF glyphs
          final String othmanicText = ayahData['qcfData']
              .toString()
              .replaceAll('\n', '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trimRight();

          String glyph = getaya_noQCF(widget.surahNumber, verseNumber);
          String textWithoutGlyph = othmanicText;
          bool hasGlyph = othmanicText.endsWith(glyph);

          if (hasGlyph) {
            textWithoutGlyph = othmanicText.substring(0, othmanicText.length - glyph.length);
          }

          final defaultStyle = widget.ayahStyle ??
              QuranTextStyles.qcfStyle(
                height: 1.45,
                pageNumber: pageNumber,
              );

          // Apply font size and color filters
          TextStyle mainTextStyle = defaultStyle.copyWith(height: null, fontSize: widget.fontSize);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(foreground: Paint()..colorFilter = textFilter),
            );
          }

          // Style for the Ayah Number end-glyph
          TextStyle numberTextStyle = defaultStyle.copyWith(height: null);
          if (widget.isDarkMode) {
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

          // Wrap Ayah with Interaction and Highlight logic
          Widget ayahInteractiveWidget = ValueListenableBuilder<List<HighlightVerse>>(
            valueListenable: widget.highlightsNotifier,
            builder: (context, highlights, _) {
              final isHighlighted = highlights.any(
                    (h) => h.surah == widget.surahNumber && h.verseNumber == verseNumber,
              );
              final highlightColor = isHighlighted
                  ? highlights.firstWhere((h) => h.surah == widget.surahNumber && h.verseNumber == verseNumber).color
                  : Colors.transparent;

              return GestureDetector(
                onLongPressStart: (details) {
                  widget.onLongPress?.call(widget.surahNumber, verseNumber, details);
                },
                child: widget.ayahBuilder != null
                    ? widget.ayahBuilder!(
                  context,
                  widget.surahNumber,
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

          // Check if font is ready for immediate display or show placeholder
          final bool isFontReady = QcfFontLoader.isFontLoaded(pageNumber);

          if (isFontReady) {
            return KeyedSubtree(
              key: ValueKey('ayah_${widget.surahNumber}_$verseNumber'),
              child: ayahInteractiveWidget,
            );
          } else {
            return FutureBuilder<void>(
              future: QcfFontLoader.ensureFontLoaded(pageNumber),
              builder: (context, fontSnapshot) {
                if (fontSnapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(width: double.infinity, height: 40);
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey('ayah_${widget.surahNumber}_$verseNumber'),
                    child: ayahInteractiveWidget,
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}