import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_line.dart';
import 'package:qcf_quran_plus/src/widgets/surah_header_widget.dart';

import '../models/highlight_verse.dart';
import '../models/quran_page.dart';
import '../services/get_page.dart';
import 'bsmallah_widget.dart';

/// A highly customizable, high-performance widget to display pages of the Holy Quran.
///
/// [QuranPageView] handles the complex rendering of Quranic pages, utilizing
/// [PageController] for navigation and [ValueNotifier] for dynamic verse highlighting
/// without rebuilding the entire page, ensuring smooth performance.
class QuranPageView extends StatefulWidget {
  final PageController pageController;
  final Function(int)? onPageChanged;

  /// Listens for verse highlights to update the UI efficiently without full rebuilds.
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;
  final GlobalKey<ScaffoldState> scaffoldKey;

  final Widget? topBar;
  final Widget? bottomBar;

  /// Callback triggered when a verse is long-pressed.
  final void Function(
      int surahNumber,
      int verseNumber,
      LongPressStartDetails details,
      )? onLongPress;

  final int quranPagesCount;

  /// Custom builder for the Surah name header.
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;

  /// Custom builder for the Basmallah widget.
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;

  final TextStyle? ayahStyle;
  final Color? pageBackgroundColor;
final bool isTajweed;
final bool isDarkMode;
  const QuranPageView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    required this.highlightsNotifier,
    required this.scaffoldKey,
    this.onLongPress,
    this.quranPagesCount = 604,
    this.topBar,
    this.bottomBar,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    this.pageBackgroundColor,  this.isTajweed=true,  this.isDarkMode=false,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  List<QuranPage> pages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuranData();
  }

  /// Initializes the Quran data processor and loads pages into memory.
  void _loadQuranData() {
    final processor = GetPage();
    processor.getQuran(widget.quranPagesCount);

    pages = processor.staticPages;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: widget.pageBackgroundColor ?? Colors.transparent,
        child: PageView.builder(
          physics: const BouncingScrollPhysics(),
          controller: widget.pageController,
          itemCount: pages.length,
          onPageChanged: (index) {
            // Notify listener of the current page index (1-based)
            widget.onPageChanged?.call(index + 1);
          },
          itemBuilder: (context, index) {
            return Column(
              children: [
                if (widget.topBar != null) widget.topBar!,
                Expanded(
                  child: QuranSinglePageWidget(
                    isTajweed:widget.isTajweed,
                    isDarkMode: widget.isDarkMode,
                    key: PageStorageKey(index), // Maintains scroll position per page
                    page: pages[index],
                    pageIndex: index + 1,
                    highlightsNotifier: widget.highlightsNotifier,
                    scaffoldKey: widget.scaffoldKey,
                    onLongPress: widget.onLongPress,
                    pageController: widget.pageController,
                    surahHeaderBuilder: widget.surahHeaderBuilder,
                    basmallahBuilder: widget.basmallahBuilder,
                    ayahStyle: widget.ayahStyle,
                  ),
                ),
                if (widget.bottomBar != null) widget.bottomBar!,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// An internal widget that renders a single full page of the Quran.
///
/// It differentiates between the layout of the first two pages (unique designs)
/// and standard pages (15 lines).
class QuranSinglePageWidget extends StatelessWidget {
  final QuranPage page;
  final int pageIndex;
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final void Function(int, int, LongPressStartDetails)? onLongPress;
  final PageController pageController;
  final Widget Function(BuildContext context, int surahNumber)? surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)? basmallahBuilder;
  final TextStyle? ayahStyle;
final bool isTajweed;
final bool isDarkMode;
  const QuranSinglePageWidget({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.highlightsNotifier,
    required this.scaffoldKey,
    this.onLongPress,
    required this.pageController,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    this.isTajweed=true,
    this.isDarkMode=false,
  });

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    return SizedBox(
      height: deviceSize.height,
      child: (pageIndex == 1 || pageIndex == 2)
          ? _buildFirstTwoPages(context, deviceSize,isDarkMode)
          : _buildStandardPage(context, deviceSize, orientation),
    );
  }

  /// Builds the unique centered layout for Al-Fatiha and the start of Al-Baqarah.
  Widget _buildFirstTwoPages(BuildContext context, Size deviceSize,bool isDarkMode) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (page.ayahs.isNotEmpty)
                surahHeaderBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    SurahHeaderWidget(suraNumber: page.ayahs[0].surahNumber),

              if (page.pageNumber == 2 && page.ayahs.isNotEmpty)
                basmallahBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    BasmallahWidget(page.ayahs[0].surahNumber),

              ...page.lines.map(
                    (line) => _buildQuranLine(line, deviceSize, BoxFit.scaleDown,isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a standard 15-line Quran page with surah headers and basmallah support.
  Widget _buildStandardPage(
      BuildContext context,
      Size deviceSize,
      Orientation orientation,
      ) {
    List<String> newSurahs = [];
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          // Prevents scrolling on portrait to keep the 15 lines fixed on screen
          physics: orientation == Orientation.portrait
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: page.lines.length,
          itemBuilder: (context, lineIndex) {
            final line = page.lines[lineIndex];
            bool isFirstAyahInSurah = false;

            // Detect if a new Surah starts on this specific line
            if (line.ayahs.isNotEmpty) {
              if (line.ayahs[0].ayahNumber == 1 &&
                  !newSurahs.contains(line.ayahs[0].surahNameAr)) {
                newSurahs.add(line.ayahs[0].surahNameAr);
                isFirstAyahInSurah = true;
              }
            }

            // Calculate height dynamically to ensure 15 lines fit the screen perfectly
            double availableHeight = (orientation == Orientation.portrait
                ? constraints.maxHeight
                : deviceSize.width);

            double surahHeaderOffset = (page.numberOfNewSurahs *
                (line.ayahs.isNotEmpty && line.ayahs[0].surahNumber != 9
                    ? 110 // Height for header + basmallah
                    : 80)); // Height for header only (e.g., At-Tawbah)

            int linesCount = page.lines.isNotEmpty ? page.lines.length : 1;
            double lineHeight = (availableHeight - surahHeaderOffset) * 0.95 / linesCount;

            return Column(
              children: [
                if (isFirstAyahInSurah && line.ayahs.isNotEmpty) ...[
                  surahHeaderBuilder?.call(context, line.ayahs[0].surahNumber) ??
                      SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber),

                  // Show Basmallah for all Surahs except At-Tawbah (9)
                  if (line.ayahs[0].surahNumber != 9)
                    basmallahBuilder?.call(context, line.ayahs[0].surahNumber) ??
                        BasmallahWidget(line.ayahs[0].surahNumber),
                ],
                SizedBox(
                  width: deviceSize.width - 32,
                  height: lineHeight > 0 ? lineHeight : 40,
                  child: _buildQuranLine(
                    line,
                    deviceSize,
                    line.ayahs.isNotEmpty && line.ayahs.last.centered
                        ? BoxFit.scaleDown
                        : BoxFit.fill,
                      isDarkMode
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Wraps the [QuranLine] in a [ValueListenableBuilder] to handle highlights
  /// with maximum efficiency.
  Widget _buildQuranLine(Line line, Size deviceSize, BoxFit boxFit,bool isDarkMode) {
    return ValueListenableBuilder<List<HighlightVerse>>(
      valueListenable: highlightsNotifier,
      builder: (context, highlights, _) {
        return QuranLine(
          line,
          highlights,
          boxFit: boxFit,
          onLongPress: onLongPress,
          ayahStyle: ayahStyle,
          isTajweed: isTajweed,
          isDark: isDarkMode,
        );
      },
    );
  }
}