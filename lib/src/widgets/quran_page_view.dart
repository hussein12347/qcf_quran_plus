import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_line.dart';
import 'package:qcf_quran_plus/src/widgets/surah_header_widget.dart';

import '../models/highlight_verse.dart';
import '../models/quran_page.dart';
import '../services/get_page.dart';
import 'bsmallah_widget.dart';

/// A widget that displays the entire Quran using a swipeable PageView.
class QuranPageView extends StatelessWidget {
  final PageController pageController;
  final Function(int)? onPageChanged;

  // A standard list of highlights passed directly without a ValueNotifier
  final List<HighlightVerse> highlights;

  final Widget? topBar;
  final Widget? bottomBar;
  final void Function(int surahNumber, int verseNumber, LongPressStartDetails details)? onLongPress;
  final int quranPagesCount;
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;
  final bool isDarkMode;
  final TextStyle? ayahStyle;
  final Color? pageBackgroundColor;
  final bool isTajweed;

  // Pre-loaded list of Quran pages
  final List<QuranPage> pages;

  QuranPageView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    required this.highlights,
    this.onLongPress,
    this.quranPagesCount = 604, // Default to the standard 604 pages of the Madani Mushaf
    this.topBar,
    this.bottomBar,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    this.pageBackgroundColor,
    this.isTajweed = true,
    required this.isDarkMode,
  }) : pages = _loadQuranData(quranPagesCount);

  /// Static helper method to load the Quran pages only once upon widget initialization.
  static List<QuranPage> _loadQuranData(int count) {
    final processor = GetPage();
    processor.getQuran(count);
    return processor.staticPages;
  }

  @override
  Widget build(BuildContext context) {
    // Force Right-to-Left (RTL) text direction for Arabic
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: pageBackgroundColor ?? Colors.transparent,
        child: PageView.builder(
          allowImplicitScrolling: false, // Pre-render adjacent pages for smoother scrolling
          controller: pageController,
          itemCount: pages.length,
          onPageChanged: (index) {
            final int page = index + 1; // Convert 0-indexed to 1-indexed page numbers
            onPageChanged?.call(page);
          },
          itemBuilder: (context, index) {
            final int pageNum = index + 1;

            return Column(
              children: [
                // Display top bar if provided (e.g., for Surah name, Juz info)
                if (topBar != null) topBar!,

                // The main Quran page content
                Expanded(
                  child: QuranSinglePageWidget(
                    key: ValueKey('page_content_$pageNum'), // Helps Flutter optimize rendering
                    isTajweed: isTajweed,
                    page: pages[index],
                    pageIndex: pageNum,
                    highlights: highlights, // Pass the static list of highlights
                    onLongPress: onLongPress,
                    pageController: pageController,
                    surahHeaderBuilder: surahHeaderBuilder,
                    basmallahBuilder: basmallahBuilder,
                    ayahStyle: ayahStyle,
                    isDark: isDarkMode,
                  ),
                ),

                // Display bottom bar if provided (e.g., for page numbers)
                if (bottomBar != null) bottomBar!,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================== QuranSinglePageWidget ======================

/// A widget responsible for rendering the layout of a single Quran page.
class QuranSinglePageWidget extends StatelessWidget {
  final QuranPage page;
  final int pageIndex;
  final List<HighlightVerse> highlights;
  final void Function(int, int, LongPressStartDetails)? onLongPress;
  final PageController pageController;
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;
  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  const QuranSinglePageWidget({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.highlights,
    this.onLongPress,
    required this.pageController,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    required this.isDark,
    this.isTajweed = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    // RepaintBoundary isolates the page rendering to prevent unnecessary repaints of the whole screen
    return RepaintBoundary(
      child: SizedBox(
        height: deviceSize.height,
        // The first two pages (Al-Fatihah and early Al-Baqarah) have a unique, centered layout
        child: (pageIndex == 1 || pageIndex == 2)
            ? _buildFirstTwoPages(context, deviceSize, isDark)
            : _buildStandardPage(context, deviceSize, orientation, isDark),
      ),
    );
  }

  /// Builds the layout specifically for Page 1 (Al-Fatihah) and Page 2 (Al-Baqarah).
  Widget _buildFirstTwoPages(BuildContext context, Size deviceSize, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display Surah Header if verses exist on this page
              if (page.ayahs.isNotEmpty)
                surahHeaderBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    SurahHeaderWidget(suraNumber: page.ayahs[0].surahNumber),

              // Display Basmallah on page 2 (Al-Baqarah)
              if (page.pageNumber == 2 && page.ayahs.isNotEmpty)
                basmallahBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    BasmallahWidget(page.ayahs[0].surahNumber),

              // Render the actual lines of the Quran text
              ...page.lines.map(
                    (line) => _buildQuranLine(line, deviceSize, BoxFit.scaleDown, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the standard layout for pages 3 through 604.
  Widget _buildStandardPage(BuildContext context, Size deviceSize, Orientation orientation, bool isDark) {
    // Keep track of Surahs already displayed on this page to avoid duplicate headers
    Set<String> newSurahs = {};

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          // Disable scrolling in portrait mode (fits perfectly), enable in landscape
          physics: orientation == Orientation.portrait
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: page.lines.length,
          itemBuilder: (context, lineIndex) {
            final line = page.lines[lineIndex];
            bool isFirstAyahInSurah = false;

            // Check if this line contains the first Ayah of a new Surah
            if (line.ayahs.isNotEmpty) {
              if (line.ayahs[0].ayahNumber == 1 &&
                  !newSurahs.contains(line.ayahs[0].surahNameAr)) {
                newSurahs.add(line.ayahs[0].surahNameAr);
                isFirstAyahInSurah = true;
              }
            }

            // Calculate available height based on screen orientation
            double availableHeight = (orientation == Orientation.portrait
                ? constraints.maxHeight
                : deviceSize.width);

            // Calculate how much space is taken up by Surah headers/Basmallahs on this page
            // Note: Surah 9 (At-Tawbah) does not have a Basmallah
            double surahHeaderOffset = (page.numberOfNewSurahs *
                (line.ayahs.isNotEmpty && line.ayahs[0].surahNumber != 9 ? 110 : 80));

            // Dynamically calculate the height of each line to ensure the text fills the page perfectly
            int linesCount = page.lines.isNotEmpty ? page.lines.length : 1;
            double lineHeight = (availableHeight - surahHeaderOffset) * 0.95 / linesCount;

            return Column(
              children: [
                // Insert Header and Basmallah if this line starts a new Surah
                if (isFirstAyahInSurah && line.ayahs.isNotEmpty) ...[
                  surahHeaderBuilder?.call(context, line.ayahs[0].surahNumber) ??
                      SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber),

                  // Add Basmallah unless it's Surah 9 (At-Tawbah)
                  if (line.ayahs[0].surahNumber != 9)
                    basmallahBuilder?.call(context, line.ayahs[0].surahNumber) ??
                        BasmallahWidget(line.ayahs[0].surahNumber),
                ],

                // The actual line of Quranic text
                SizedBox(
                  width: deviceSize.width - 32, // Apply padding
                  height: lineHeight > 0 ? lineHeight : 40, // Fallback height if calculations fail
                  child: _buildQuranLine(
                    line,
                    deviceSize,
                    // If the line contains the end of an Ayah and is marked as centered, scale it down. Otherwise, stretch it to fill the line width (Justified text).
                    line.ayahs.isNotEmpty && line.ayahs.last.centered
                        ? BoxFit.scaleDown
                        : BoxFit.fill,
                    isDark,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Renders a single line of Quran text and handles highlights and interactions.
  Widget _buildQuranLine(Line line, Size deviceSize, BoxFit boxFit, bool isDark) {
    return RepaintBoundary(
      child: QuranLine(
        line,
        highlights, // Passes the normal list of highlighted verses directly
        boxFit: boxFit,
        onLongPress: onLongPress,
        ayahStyle: ayahStyle,
        isTajweed: isTajweed,
        isDark: isDark,
      ),
    );
  }
}