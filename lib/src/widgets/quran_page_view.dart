import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/src/widgets/quran_line.dart';
import 'package:qcf_quran_plus/src/widgets/surah_header_widget.dart';

import '../models/highlight_verse.dart';
import '../models/quran_page.dart';
import '../services/get_page.dart';
import '../utils/font_loader_service.dart';
import 'bsmallah_widget.dart';


class QuranPageView extends StatefulWidget {
  final PageController pageController;
  final Function(int)? onPageChanged;
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;
  final GlobalKey<ScaffoldState> scaffoldKey;
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
    this.pageBackgroundColor,
    this.isTajweed = true,
    required this.isDarkMode,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  List<QuranPage> pages = [];
  bool isLoading = true;
  Timer? _preloadDebounce;

  @override
  void initState() {
    super.initState();
    _loadQuranData();

    final int initialPage = widget.pageController.initialPage + 1;
    QcfFontLoader.ensureFontLoaded(initialPage);   // ← محدث
    QcfFontLoader.preloadNearbyPages(initialPage);
  }

  void _loadQuranData() {
    final processor = GetPage();
    processor.getQuran(widget.quranPagesCount);
    pages = processor.staticPages;
    setState(() => isLoading = false);
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
            final int page = index + 1;
            widget.onPageChanged?.call(page);

            _preloadDebounce?.cancel();
            _preloadDebounce = Timer(const Duration(milliseconds: 0), () {
              QcfFontLoader.ensureFontLoaded(page);
              QcfFontLoader.preloadNearbyPages(page);
            });
          },
          itemBuilder: (context, index) {
            final int pageNum = index + 1;

            return Column(
              children: [
                if (widget.topBar != null) widget.topBar!,
                Expanded(
                  child: FutureBuilder<void>(
                    future: QcfFontLoader.ensureFontLoaded(pageNum),
                    builder: (context, fontSnapshot) {
                      // الخط لسه بيتحمل → شاشة فارغة
                      if (fontSnapshot.connectionState != ConnectionState.done) {
                        return Container(
                          color: widget.pageBackgroundColor ?? Colors.transparent,
                        );
                      }

                      // الخط تحمل → انتظر 300 مللي ثانية ثم اعرض الصفحة مع أنيميشن
                      return FutureBuilder<void>(
                        future: Future.delayed(const Duration(milliseconds: 300)),
                        builder: (context, delaySnapshot) {
                          // نتحقق إذا كان وقت الانتظار انتهى
                          final bool isReady = delaySnapshot.connectionState == ConnectionState.done;

                          // استخدام AnimatedSwitcher لعمل انتقال ناعم
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300), // مدة الأنيميشن (يمكنك تقليلها أو زيادتها)
                            switchInCurve: Curves.easeIn,
                            switchOutCurve: Curves.easeOut,
                            child: isReady
                                ? QuranSinglePageWidget(
                              // الـ Key مهم جداً هنا عشان AnimatedSwitcher يفهم إن الويدجت اتغيرت ويبدأ الأنيميشن
                              key: PageStorageKey('page_$pageNum'),
                              isTajweed: widget.isTajweed,
                              page: pages[index],
                              pageIndex: pageNum,
                              highlightsNotifier: widget.highlightsNotifier,
                              scaffoldKey: widget.scaffoldKey,
                              onLongPress: widget.onLongPress,
                              pageController: widget.pageController,
                              surahHeaderBuilder: widget.surahHeaderBuilder,
                              basmallahBuilder: widget.basmallahBuilder,
                              ayahStyle: widget.ayahStyle,
                              isDark: widget.isDarkMode,
                            )
                                : Container(
                              // الـ Key مهم هنا أيضاً لنفس السبب
                              key: const ValueKey('empty_state'),
                              color: widget.pageBackgroundColor ?? Colors.transparent,
                            ),
                          );
                        },
                      );
                    },
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
  @override
  void dispose() {
    _preloadDebounce?.cancel();
    super.dispose();
  }
}
// ====================== QuranSinglePageWidget (نفسها بدون أي تغيير) ======================
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
  final bool isDark;

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
    required this.isDark,
    this.isTajweed = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    return SizedBox(
      height: deviceSize.height,
      child: (pageIndex == 1 || pageIndex == 2)
          ? _buildFirstTwoPages(context, deviceSize, isDark)
          : _buildStandardPage(context, deviceSize, orientation, isDark),
    );
  }

  Widget _buildFirstTwoPages(BuildContext context, Size deviceSize, bool isDark) {
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
                    (line) => _buildQuranLine(line, deviceSize, BoxFit.scaleDown, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardPage(BuildContext context, Size deviceSize, Orientation orientation, bool isDark) {
    List<String> newSurahs = [];
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          physics: orientation == Orientation.portrait
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: page.lines.length,
          itemBuilder: (context, lineIndex) {
            final line = page.lines[lineIndex];
            bool isFirstAyahInSurah = false;

            if (line.ayahs.isNotEmpty) {
              if (line.ayahs[0].ayahNumber == 1 &&
                  !newSurahs.contains(line.ayahs[0].surahNameAr)) {
                newSurahs.add(line.ayahs[0].surahNameAr);
                isFirstAyahInSurah = true;
              }
            }

            double availableHeight = (orientation == Orientation.portrait
                ? constraints.maxHeight
                : deviceSize.width);

            double surahHeaderOffset = (page.numberOfNewSurahs *
                (line.ayahs.isNotEmpty && line.ayahs[0].surahNumber != 9 ? 110 : 80));

            int linesCount = page.lines.isNotEmpty ? page.lines.length : 1;
            double lineHeight = (availableHeight - surahHeaderOffset) * 0.95 / linesCount;

            return Column(
              children: [
                if (isFirstAyahInSurah && line.ayahs.isNotEmpty) ...[
                  surahHeaderBuilder?.call(context, line.ayahs[0].surahNumber) ??
                      SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber),
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

  Widget _buildQuranLine(Line line, Size deviceSize, BoxFit boxFit, bool isDark) {
    return RepaintBoundary(
      child: ValueListenableBuilder<List<HighlightVerse>>(
        valueListenable: highlightsNotifier,
        builder: (context, highlights, _) {
          return QuranLine(
            line,
            highlights,
            boxFit: boxFit,
            onLongPress: onLongPress,
            ayahStyle: ayahStyle,
            isTajweed: isTajweed,
            isDark: isDark,
          );
        },
      ),
    );
  }
}