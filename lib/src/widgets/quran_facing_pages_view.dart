import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/models/highlight_verse.dart';
import 'package:qcf_quran_plus/src/models/quran_page.dart';
import 'package:qcf_quran_plus/src/services/get_page.dart';
import 'package:qcf_quran_plus/src/utils/facing_pages.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page_view.dart';

/// A two-page (facing) mushaf view optimized for tablets and wide screens.
///
/// Uses authentic Madani pairing:
/// - Spread 0: page 1 alone on the right
/// - Spreads 1-301: even (left) | odd (right)
/// - Spread 302: page 604 alone on the left
///
/// [pageController] indexes **spreads** (0 .. [totalFacingSpreads] - 1), not
/// mushaf pages. Convert with [mushafPageToSpreadIndex] /
/// [spreadIndexToPages].
class QuranFacingPagesView extends StatelessWidget {
  final PageController pageController;
  final void Function(int pageNumber)? onPageChanged;
  final void Function(int? leftPage, int? rightPage)? onSpreadChanged;

  final List<HighlightVerse> highlights;

  final Widget? topBar;
  final Widget? bottomBar;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;
  final int quranPagesCount;
  final Widget Function(BuildContext context, int surahNumber)?
  surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)?
  basmallahBuilder;
  final bool isDarkMode;
  final TextStyle? ayahStyle;
  final Color? pageBackgroundColor;
  final bool isTajweed;
  final Color? spineDividerColor;
  final double spineDividerWidth;

  final List<QuranPage> pages;

  QuranFacingPagesView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    this.onSpreadChanged,
    required this.highlights,
    this.onLongPress,
    this.quranPagesCount = 604,
    this.topBar,
    this.bottomBar,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    this.pageBackgroundColor,
    this.isTajweed = true,
    required this.isDarkMode,
    this.spineDividerColor,
    this.spineDividerWidth = 1,
  }) : pages = _loadQuranData(quranPagesCount);

  static List<QuranPage> _loadQuranData(int count) {
    final processor = GetPage();
    processor.getQuran(count);
    return processor.staticPages;
  }

  void _notifySpread(int spreadIndex) {
    final pagesForSpread = spreadIndexToPages(spreadIndex);
    onSpreadChanged?.call(pagesForSpread.leftPage, pagesForSpread.rightPage);
    onPageChanged?.call(primaryPageForSpread(spreadIndex));
  }

  Widget _buildPageSlot(BuildContext context, int? pageNumber) {
    if (pageNumber == null) {
      return const SizedBox.expand();
    }

    final pageIndex = pageNumber - 1;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return const SizedBox.expand();
    }

    return QuranSinglePageWidget(
      key: ValueKey('facing_page_$pageNumber'),
      isTajweed: isTajweed,
      page: pages[pageIndex],
      pageIndex: pageNumber,
      highlights: highlights,
      onLongPress: onLongPress,
      pageController: pageController,
      surahHeaderBuilder: surahHeaderBuilder,
      basmallahBuilder: basmallahBuilder,
      ayahStyle: ayahStyle,
      isDark: isDarkMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        spineDividerColor ??
        (isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: pageBackgroundColor ?? Colors.transparent,
        child: PageView.builder(
          allowImplicitScrolling: false,
          controller: pageController,
          itemCount: totalFacingSpreads,
          onPageChanged: _notifySpread,
          itemBuilder: (context, spreadIndex) {
            final pagesForSpread = spreadIndexToPages(spreadIndex);

            // Visual order: screen-left = odd page, screen-right = even page.
            return Column(
              children: [
                ?topBar,
                Expanded(
                  child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildPageSlot(
                          context,
                          pagesForSpread.rightPage,
                        ),
                      ),
                      if (spineDividerWidth > 0)
                        VerticalDivider(
                          width: spineDividerWidth,
                          thickness: spineDividerWidth,
                          color: dividerColor,
                        ),
                      Expanded(
                        child: _buildPageSlot(
                          context,
                          pagesForSpread.leftPage,
                        ),
                      ),
                    ],
                  ),
                ),
                ?bottomBar,
              ],
            );
          },
        ),
      ),
    );
  }
}