import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/highlight_index.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:qcf_quran_plus/src/widgets/surah_header_widget.dart';
import '../../qcf_quran_plus.dart';
import '../models/highlight_verse.dart';
import '../models/highlight_word.dart';
import '../models/quran_page.dart';
import '../utils/font_loader_service.dart';
import 'bsmallah_widget.dart';
import 'quran_line.dart';

/// Renders the full Quran in either a single-page or two-page layout.
///
/// This widget manages page synchronization, highlight state, and page-level
/// font preloading while keeping the UI responsive for both mobile and tablet
/// layouts.
class QuranPageView extends StatefulWidget {
  /// Controls the current page index for the single-page layout.
  final PageController pageController;

  /// Callback fired when the user swipes or changes the active page.
  final Function(int)? onPageChanged;

  /// List of verses that should be highlighted (e.g., for bookmarks or active recitation).
  final List<HighlightVerse> highlights;

  /// List of specific words that should be highlighted.
  final List<WordHighlight> wordHighlights;

  /// Callback fired when a user taps on a specific word.
  final void Function(
    int surahNumber,
    int verseNumber,
    int wordIndex,
    String word,
  )?
  onWordTap;

  /// Optional widget rendered above the Quran page content.
  final Widget? topBar;

  /// Optional widget rendered below the Quran page content.
  final Widget? bottomBar;

  /// Callback fired when a user long-presses on a specific verse.
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;

  /// The total number of pages in the Quran edition being used (defaults to 604).
  final int quranPagesCount;

  /// Custom builder for the Surah header graphic/text.
  final Widget Function(BuildContext, int surahNumber)? surahHeaderBuilder;

  /// Custom builder for the Basmallah graphic/text.
  final Widget Function(BuildContext, int surahNumber)? basmallahBuilder;

  /// Custom builder for the header of the page (e.g., displaying Juz or Page number).
  final Widget Function(BuildContext, int pageIndex)? pageHeaderBuilder;

  /// Indicates if the application is currently in dark mode.
  final bool isDarkMode;

  /// Custom text style applied to the Quranic text.
  final TextStyle? ayahStyle;

  /// Background color of the page. Defaults to transparent.
  final Color? pageBackgroundColor;

  /// Enables or disables Tajweed color-coded rendering.
  final bool isTajweed;

  /// Toggles the ability to show two pages side-by-side on wider screens.
  final bool enableTwoPageLayout;

  const QuranPageView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    required this.highlights,
    this.wordHighlights = const [],
    this.onWordTap,
    this.onLongPress,
    this.quranPagesCount = 604,
    this.topBar,
    this.bottomBar,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.pageHeaderBuilder,
    this.ayahStyle,
    this.pageBackgroundColor,
    this.isTajweed = true,
    required this.isDarkMode,
    this.enableTwoPageLayout = true,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  bool _dataReady = false;

  final MemoizedWordHighlightIndex _wordHighlightIndexer =
      MemoizedWordHighlightIndex();
  final MemoizedBookmarkIndex _bookmarkIndexer = MemoizedBookmarkIndex();

  late WordHighlightIndex _wordHighlightIndex;
  late BookmarkIndex _bookmarkIndex;

  late PageController _twoPageController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _dataReady = QuranRepository.instance.isReady;

    int initialPage = widget.pageController.initialPage;
    _twoPageController = PageController(initialPage: initialPage ~/ 2);

    widget.pageController.addListener(_syncExternalToInternal);
    _twoPageController.addListener(_syncInternalToExternal);

    _wordHighlightIndex = _wordHighlightIndexer.refresh(widget.wordHighlights);
    _bookmarkIndex = _bookmarkIndexer.refresh(widget.highlights);

    if (_dataReady) {
      _kickOffInitialFontPreload(initialPage);
    } else {
      QuranRepository.instance.ensureLoaded(widget.quranPagesCount).then((_) {
        if (!mounted) return;
        setState(() => _dataReady = true);
        _kickOffInitialFontPreload(initialPage);
      });
    }
  }

  @override
  void didUpdateWidget(covariant QuranPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    _wordHighlightIndex = _wordHighlightIndexer.refresh(widget.wordHighlights);
    _bookmarkIndex = _bookmarkIndexer.refresh(widget.highlights);

    if (oldWidget.enableTwoPageLayout != widget.enableTwoPageLayout) {
      final int currentPage = widget.pageController.hasClients
          ? widget.pageController.page?.round() ??
                widget.pageController.initialPage
          : widget.pageController.initialPage;

      if (widget.enableTwoPageLayout && _twoPageController.hasClients) {
        final int pair = currentPage ~/ 2;
        _twoPageController.jumpToPage(pair);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_syncExternalToInternal);
    _twoPageController.removeListener(_syncInternalToExternal);
    _twoPageController.dispose();
    super.dispose();
  }

  /// Synchronizes the single-page controller's state to the two-page controller.
  void _syncExternalToInternal() {
    if (_isSyncing ||
        !widget.pageController.hasClients ||
        !_twoPageController.hasClients)
      return;
    _isSyncing = true;
    final int targetPair = widget.pageController.page!.round() ~/ 2;
    if (_twoPageController.page?.round() != targetPair) {
      _twoPageController.jumpToPage(targetPair);
    }
    _isSyncing = false;
  }

  /// Synchronizes the two-page controller's state back to the single-page controller.
  void _syncInternalToExternal() {
    if (_isSyncing ||
        !widget.pageController.hasClients ||
        !_twoPageController.hasClients)
      return;
    _isSyncing = true;
    final int targetSingle = (_twoPageController.page!.round() * 2);
    if (widget.pageController.page?.round() != targetSingle) {
      widget.pageController.jumpToPage(targetSingle);
    }
    _isSyncing = false;
  }

  void _kickOffInitialFontPreload(int initialPage) {
    QcfFontLoader.preloadPages(initialPage + 1, radius: 3);
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final ScrollPhysics physics =
        Theme.of(context).platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWideScreen = constraints.maxWidth >= 750;
          final bool useTwoPageMode =
              widget.enableTwoPageLayout && isWideScreen;

          return Container(
            color: widget.pageBackgroundColor ?? Colors.transparent,
            child: IndexedStack(
              index: useTwoPageMode ? 0 : 1,
              children: [
                _buildTwoPageLayout(
                  key: const ValueKey('double'),
                  physics: physics,
                ),
                _buildSinglePageLayout(
                  key: const ValueKey('single'),
                  physics: physics,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSinglePageLayout({
    required Key key,
    required ScrollPhysics physics,
  }) {
    final pages = QuranRepository.instance.pages;
    final wordOffsets = QuranRepository.instance.wordOffsets;

    return PageView.builder(
      key: key,
      controller: widget.pageController,
      physics: physics,
      itemCount: pages.length,
      onPageChanged: (index) {
        final pageNum = index + 1;
        widget.onPageChanged?.call(pageNum);
        QcfFontLoader.preloadPages(pageNum, radius: 3);
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;

        return Column(
          children: [
            if (widget.topBar != null) widget.topBar!,
            Expanded(
              child: QuranSinglePageWidget(
                key: ValueKey('page_content_$pageNum'),
                isTajweed: widget.isTajweed,
                page: pages[index],
                pageIndex: pageNum,
                wordHighlightIndex: _wordHighlightIndex,
                bookmarkIndex: _bookmarkIndex,
                onWordTap: widget.onWordTap,
                onLongPress: widget.onLongPress,
                pageController: widget.pageController,
                surahHeaderBuilder: widget.surahHeaderBuilder,
                basmallahBuilder: widget.basmallahBuilder,
                pageHeaderBuilder: widget.pageHeaderBuilder,
                ayahStyle: widget.ayahStyle,
                isDark: widget.isDarkMode,
                lineOffsets: wordOffsets[index] ?? const {},
                forceFitConstraints: false,
              ),
            ),
            if (widget.bottomBar != null) widget.bottomBar!,
          ],
        );
      },
    );
  }

  Widget _buildTwoPageLayout({
    required Key key,
    required ScrollPhysics physics,
  }) {
    final pages = QuranRepository.instance.pages;
    final wordOffsets = QuranRepository.instance.wordOffsets;
    final int pairCount = (pages.length / 2).ceil();

    return PageView.builder(
      key: key,
      controller: _twoPageController,
      physics: physics,
      itemCount: pairCount,
      onPageChanged: (index) {
        final rightPageNum = (index * 2) + 1;
        widget.onPageChanged?.call(rightPageNum);
        QcfFontLoader.preloadPages(rightPageNum, radius: 4);
      },
      itemBuilder: (context, index) {
        final rightPageIndex = index * 2;
        final leftPageIndex = index * 2 + 1;

        return Column(
          children: [
            if (widget.topBar != null) widget.topBar!,
            Expanded(
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: rightPageIndex < pages.length
                        ? _buildPageContainer(
                            rightPageIndex,
                            pages,
                            wordOffsets,
                            isTwoPageMode: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: leftPageIndex < pages.length
                        ? _buildPageContainer(
                            leftPageIndex,
                            pages,
                            wordOffsets,
                            isTwoPageMode: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            if (widget.bottomBar != null) widget.bottomBar!,
          ],
        );
      },
    );
  }

  Widget _buildPageContainer(
    int index,
    List<QuranPage> pages,
    Map<int, Map<int, Map<String, int>>> wordOffsets, {
    required bool isTwoPageMode,
  }) {
    final pageNum = index + 1;
    return QuranSinglePageWidget(
      key: ValueKey('page_content_two_mode_$pageNum'),
      isTajweed: widget.isTajweed,
      page: pages[index],
      pageIndex: pageNum,
      wordHighlightIndex: _wordHighlightIndex,
      bookmarkIndex: _bookmarkIndex,
      onWordTap: widget.onWordTap,
      onLongPress: widget.onLongPress,
      pageController: widget.pageController,
      surahHeaderBuilder: widget.surahHeaderBuilder,
      basmallahBuilder: widget.basmallahBuilder,
      pageHeaderBuilder: widget.pageHeaderBuilder,
      ayahStyle: widget.ayahStyle,
      isDark: widget.isDarkMode,
      lineOffsets: wordOffsets[index] ?? const {},
      forceFitConstraints: true, // Always enforce portrait constraints in two-page mode.
    );
  }
}

/// Renders a single page of the Quran, including Surah headers, Basmallah, and individual lines.
class QuranSinglePageWidget extends StatefulWidget {
  /// The data model representing the current page.
  final QuranPage page;
  
  /// The 1-based index of the page being rendered.
  final int pageIndex;
  
  /// Pre-computed index for active word highlights.
  final WordHighlightIndex wordHighlightIndex;
  
  /// Pre-computed index for active bookmarks.
  final BookmarkIndex bookmarkIndex;
  
  /// Callback triggered on a verse long-press.
  final void Function(int, int, LongPressStartDetails)? onLongPress;
  
  /// Callback triggered on a word tap.
  final void Function(int, int, int, String)? onWordTap;
  
  /// PageController to manage navigation context if required by child components.
  final PageController pageController;
  
  /// Builder for rendering Surah headers.
  final Widget Function(BuildContext, int)? surahHeaderBuilder;
  
  /// Builder for rendering the Basmallah.
  final Widget Function(BuildContext, int)? basmallahBuilder;
  
  /// Builder for the page header (e.g., Juz or Hizb markers).
  final Widget Function(BuildContext, int)? pageHeaderBuilder;
  
  /// Custom text style applied to the verses.
  final TextStyle? ayahStyle;
  
  /// Flag to enable or disable Tajweed coloring.
  final bool isTajweed;
  
  /// Indicates if the application is currently in dark mode.
  final bool isDark;
  
  /// Spatial mapping of words to their specific line boundaries.
  final Map<int, Map<String, int>> lineOffsets;
  
  /// Ensures the page respects standard portrait dimensions even in landscape orientations.
  final bool forceFitConstraints;

  const QuranSinglePageWidget({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.wordHighlightIndex,
    required this.bookmarkIndex,
    this.onLongPress,
    this.onWordTap,
    required this.pageController,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.pageHeaderBuilder,
    this.ayahStyle,
    required this.isDark,
    this.isTajweed = true,
    required this.lineOffsets,
    required this.forceFitConstraints,
  });

  @override
  State<QuranSinglePageWidget> createState() => _QuranSinglePageWidgetState();
}

class _QuranSinglePageWidgetState extends State<QuranSinglePageWidget> {
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size availableSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          if (widget.pageIndex == 1 || widget.pageIndex == 2) {
            return _buildFirstTwoPages(context, availableSize, orientation);
          } else {
            return _buildStandardPage(context, availableSize, orientation);
          }
        },
      ),
    );
  }

  /// Constructs the layout specifically tailored for the first two pages of the Quran.
  /// 
  /// Page 1 (Al-Fatihah) and Page 2 (beginning of Al-Baqarah) typically feature 
  /// unique framing and spacing requirements compared to standard pages.
  Widget _buildFirstTwoPages(
    BuildContext context,
    Size availableSize,
    Orientation orientation,
  ) {
    final bool shouldFit =
        (orientation == Orientation.portrait) || widget.forceFitConstraints;
    final List<Widget> children = [];

    if (widget.pageHeaderBuilder != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: widget.pageHeaderBuilder!(context, widget.pageIndex),
        ),
      );
    }

    int flexCount = 0;
    final List<Widget> flexChildren = [];

    if (widget.page.ayahs.isNotEmpty) {
      Widget sHeader =
          widget.surahHeaderBuilder?.call(
            context,
            widget.page.ayahs[0].surahNumber,
          ) ??
          SurahHeaderWidget(suraNumber: widget.page.ayahs[0].surahNumber);

      flexChildren.add(
        shouldFit ? Expanded(child: Center(child: sHeader)) : sHeader,
      );
      flexCount++;

      if (widget.pageIndex == 2) {
        Widget bHeader =
            widget.basmallahBuilder?.call(
              context,
              widget.page.ayahs[0].surahNumber,
            ) ??
            BasmallahWidget(widget.page.ayahs[0].surahNumber);

        flexChildren.add(
          shouldFit ? Expanded(child: Center(child: bHeader)) : bHeader,
        );
        flexCount++;
      }
    }

    for (int i = 0; i < widget.page.lines.length; i++) {
      final line = widget.page.lines[i];
      final bool isCentered = line.ayahs.isNotEmpty && line.ayahs.last.centered;

      final BoxFit fit = isCentered
          ? BoxFit.scaleDown
          : (shouldFit ? BoxFit.contain : BoxFit.fitWidth);

      final lineWidget = _buildQuranLine(
        line,
        availableSize,
        fit,
        i,
        shouldFit,
        isCentered: isCentered,
      );

      flexChildren.add(
        shouldFit
            ? Expanded(child: Center(child: lineWidget))
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: lineWidget,
              ),
      );
      flexCount++;
    }

    if (shouldFit) {
      int emptyFlex = (15 - flexCount).clamp(0, 15);
      if (emptyFlex > 0) {
        int topEmpty = emptyFlex ~/ 2;
        int bottomEmpty = emptyFlex - topEmpty;
        if (topEmpty > 0) children.add(Spacer(flex: topEmpty));
        children.addAll(flexChildren);
        if (bottomEmpty > 0) children.add(Spacer(flex: bottomEmpty));
      } else {
        children.addAll(flexChildren);
      }
    } else {
      children.addAll(flexChildren);
    }

    final pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return shouldFit
        ? pageContent
        : Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: pageContent,
            ),
          );
  }

  /// Constructs the layout for standard Quran pages, handling standard line rendering and inline Surah headers.
  Widget _buildStandardPage(
    BuildContext context,
    Size availableSize,
    Orientation orientation,
  ) {
    final bool shouldFit =
        (orientation == Orientation.portrait) || widget.forceFitConstraints;
    final Set<String> newSurahs = <String>{};
    final List<Widget> children = [];

    if (widget.pageHeaderBuilder != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: widget.pageHeaderBuilder!(context, widget.pageIndex),
        ),
      );
    }

    for (int lineIdx = 0; lineIdx < widget.page.lines.length; lineIdx++) {
      final line = widget.page.lines[lineIdx];

      bool isFirstAyahInSurah = false;
      if (line.ayahs.isNotEmpty) {
        if (line.ayahs[0].ayahNumber == 1 &&
            !newSurahs.contains(line.ayahs[0].surahNameAr)) {
          newSurahs.add(line.ayahs[0].surahNameAr);
          isFirstAyahInSurah = true;
        }
      }

      if (isFirstAyahInSurah && line.ayahs.isNotEmpty) {
        Widget sHeader =
            widget.surahHeaderBuilder?.call(
              context,
              line.ayahs[0].surahNumber,
            ) ??
            SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber);

        children.add(
          shouldFit ? Expanded(child: Center(child: sHeader)) : sHeader,
        );

        if (line.ayahs[0].surahNumber != 9) {
          Widget bHeader =
              widget.basmallahBuilder?.call(
                context,
                line.ayahs[0].surahNumber,
              ) ??
              BasmallahWidget(line.ayahs[0].surahNumber);

          children.add(
            shouldFit ? Expanded(child: Center(child: bHeader)) : bHeader,
          );
        }
      }

      final bool isCentered = line.ayahs.isNotEmpty && line.ayahs.last.centered;

      final BoxFit fit = isCentered
          ? BoxFit.scaleDown
          : (shouldFit ? BoxFit.contain : BoxFit.fitWidth);

      Widget lineWidget = _buildQuranLine(
        line,
        availableSize,
        fit,
        lineIdx,
        shouldFit,
        isCentered: isCentered,
      );

      if (isCentered) {
        lineWidget = Center(
          child: FractionallySizedBox(widthFactor: 0.98, child: lineWidget),
        );
      } else {
        lineWidget = Center(
          child: SizedBox(width: double.infinity, child: lineWidget),
        );
      }

      children.add(
        shouldFit
            ? Expanded(child: lineWidget)
            : Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: lineWidget,
              ),
      );
    }

    if (shouldFit) {
      int flexCount = children.whereType<Expanded>().length;
      if (flexCount > 0 && flexCount < 15) {
        children.add(Spacer(flex: 15 - flexCount));
      }
    }

    final pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return shouldFit
        ? pageContent
        : Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: pageContent,
            ),
          );
  }

  /// Builds an individual line of Quranic text.
  /// 
  /// Dynamically scales the font size for centered text on smaller device screens 
  /// to ensure visual consistency and prevent overflow.
  Widget _buildQuranLine(
    Line line,
    Size deviceSize,
    BoxFit boxFit,
    int lineIndex,
    bool shouldFit, {
    bool isCentered = false,
  }) {
    final parsedAyahs = ParsedLineCache.instance.getOrParse(
      widget.pageIndex,
      lineIndex,
      line,
      widget.lineOffsets[lineIndex],
    );

    final baseStyle =
        widget.ayahStyle ??
        QuranTextStyles.qcfStyle(
          height: 1.45,
          pageNumber: widget.pageIndex,
          isTajweed: widget.isTajweed,
          isDark: widget.isDark,
        );

    double fontSize = 45.0; 

    // Scale down the font size for centered lines on smaller screens (e.g., mobile devices).
    // A ratio of 5.5% of the screen width ensures the text fits proportionally without overflowing.
    if (isCentered && deviceSize.width < 600) {
      fontSize = deviceSize.width * 0.055;
    }

    final TextStyle fixedStyle = baseStyle.copyWith(fontSize: fontSize);

    return QuranLine(
      parsedAyahs: parsedAyahs,
      pageNumber: widget.pageIndex,
      wordHighlightIndex: widget.wordHighlightIndex,
      bookmarkIndex: widget.bookmarkIndex,
      onWordTap: widget.onWordTap,
      boxFit: boxFit,
      onLongPress: widget.onLongPress,
      ayahStyle: fixedStyle,
      isTajweed: widget.isTajweed,
      isDark: widget.isDark,
    );
  }
}