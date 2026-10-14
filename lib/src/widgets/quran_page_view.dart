import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/highlight_index.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/parsed_quran_data.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import '../../qcf_quran_plus.dart';
import 'bsmallah_widget.dart';
import 'quran_line.dart';

/// A high-level widget that renders Quran pages with support for both
/// single-page and two-page layouts.
///
/// [QuranPageView] wraps an internal pagination system and exposes a public
/// [PageController] so callers can programmatically navigate between pages.
/// It also supports:
/// - Per-verse highlights via [highlights].
/// - Per-word highlights via [wordHighlights].
/// - Word tap, verse tap, and long-press callbacks.
/// - Custom surah header, Basmallah, and page header builders.
/// - Tajweed coloring and dark-mode rendering.
/// - Automatic layout switching based on available width.
/// - Optional deferral of new page construction during user scrolling to
///   avoid jank on low-end devices.
class QuranPageView extends StatefulWidget {
  /// Controller for the single-page layout. Its page index is zero-based
  /// and represents a single Quran page (0 = page 1).
  final PageController pageController;

  /// Called whenever the currently visible page changes.
  /// The callback receives a 1-based page number.
  final Function(int)? onPageChanged;

  /// A list of verse highlights (e.g. active audio verse, bookmark).
  final List<HighlightVerse> highlights;

  /// A list of word-level highlights within the visible pages.
  final List<WordHighlight> wordHighlights;

  /// Called when the user taps a specific word.
  /// Provides: surah number, verse number, word index, and the raw word text.
  final void Function(int, int, int, String)? onWordTap;

  /// Called when the user taps a specific verse.
  /// Provides: surah number and verse number.
  final void Function(int surah, int verse)? onVerseTap;

  /// Optional widget rendered at the top of every page.
  final Widget? topBar;

  /// Optional widget rendered at the bottom of every page.
  final Widget? bottomBar;

  /// Called when the user long-presses a verse.
  /// Provides: surah number, verse number, and gesture details.
  final void Function(int, int, LongPressStartDetails)? onLongPress;

  /// Total number of Quran pages. Defaults to 604.
  final int quranPagesCount;

  /// Builder for a custom surah header. Receives the surah number.
  final Widget Function(BuildContext, int)? surahHeaderBuilder;

  /// Builder for a custom Basmallah widget. Receives the surah number.
  final Widget Function(BuildContext, int)? basmallahBuilder;

  /// Builder for a custom page header. Receives the 1-based page number.
  final Widget Function(BuildContext, int)? pageHeaderBuilder;

  /// Whether the app is currently in dark mode.
  final bool isDarkMode;

  /// Optional custom text style for the ayah text.
  final TextStyle? ayahStyle;

  /// Optional background color for the page container.
  final Color? pageBackgroundColor;

  /// Whether to render text using Tajweed-specific fonts and colors.
  final bool isTajweed;

  /// Whether the two-page layout is allowed on wide screens.
  /// When `true` and the available width is >= 750 logical pixels, pages
  /// are rendered side by side.
  final bool enableTwoPageLayout;

  /// Whether to defer building newly appearing pages during user scrolling.
  ///
  /// When `true` (default), pages that appear during a swipe/scroll are
  /// rendered empty and only built once the scrolling gesture settles.
  /// The current page is never affected.
  /// When `false`, the original behavior applies (pages are built immediately).
  ///
  /// This flag can be toggled at runtime (e.g. from settings) and takes
  /// effect immediately.
  final bool deferNewPages;

  /// The delay after scrolling stops before deferred pages are built.
  ///
  /// If the user starts a new scroll during this delay, the build is cancelled
  /// so that rapid page flipping does not trigger construction of many pages.
  /// Only used when [deferNewPages] is `true`.
  final Duration deferDelay;

  /// Creates a [QuranPageView].
  const QuranPageView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    required this.highlights,
    this.wordHighlights = const [],
    this.onWordTap,
    this.onVerseTap,
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
    this.deferNewPages = true,
    this.deferDelay = const Duration(milliseconds: 50),
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  /// Memoized indexer for word highlights (avoids rebuilding the index
  /// every time the widget is rebuilt with the same input list).
  final MemoizedWordHighlightIndex _wordHighlightIndexer =
      MemoizedWordHighlightIndex();

  /// Memoized indexer for bookmark/verse highlights.
  final MemoizedBookmarkIndex _bookmarkIndexer = MemoizedBookmarkIndex();

  /// Current word highlight index (see [_wordHighlightIndexer]).
  late WordHighlightIndex _wordHighlightIndex;

  /// Current bookmark/verse highlight index (see [_bookmarkIndexer]).
  late BookmarkIndex _bookmarkIndex;

  /// Internal PageController used when the two-page layout is active.
  /// Its page index represents a "pair" of pages (two consecutive pages).
  late PageController _twoPageController;

  /// Guards against recursive synchronization between the two controllers.
  bool _isSyncing = false;

  /// Tracks the last applied layout mode to detect transitions between
  /// single-page and two-page layouts.
  bool? _lastLayoutMode;

  /// The last page (0-based) the user actually landed on.
  ///
  /// This is used as a stable reference when switching between layout modes,
  /// instead of reading controller positions that may be affected by layout
  /// corrections during size changes.
  late int _currentPage;

  /// While switching layout modes, automatic synchronization is ignored
  /// for a short window to avoid fighting with layout corrections.
  DateTime _switchUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the widget is currently inside a layout-switch grace period.
  bool get _isSwitching => DateTime.now().isBefore(_switchUntil);

  /// `true` while the user is actively scrolling.
  /// Used to defer building new pages.
  final ValueNotifier<bool> _isScrolling = ValueNotifier<bool>(false);

  /// Timer used to confirm that scrolling has settled.
  /// Cancelled if a new scroll starts before it fires.
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();

    final int initialPage = widget.pageController.initialPage;

    _currentPage = initialPage;

    // Direct pair index: each pair holds two consecutive pages 2i and 2i+1 (0-based).
    final int initialPair = initialPage ~/ 2;

    _twoPageController = PageController(initialPage: initialPair);

    widget.pageController.addListener(_syncExternalToInternal);

    _twoPageController.addListener(_syncInternalToExternal);

    _wordHighlightIndex = _wordHighlightIndexer.refresh(widget.wordHighlights);

    _bookmarkIndex = _bookmarkIndexer.refresh(widget.highlights);
  }

  @override
  void didUpdateWidget(covariant QuranPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the caller disabled deferral while running, cancel the pending timer
    // and reset the scrolling state so pages build immediately again.
    if (oldWidget.deferNewPages && !widget.deferNewPages) {
      _settleTimer?.cancel();
      _settleTimer = null;
      if (_isScrolling.value) _isScrolling.value = false;
    }

    // Refresh the word highlight index when the input list changes identity.
    if (!identical(oldWidget.wordHighlights, widget.wordHighlights)) {
      _wordHighlightIndex = _wordHighlightIndexer.refresh(
        widget.wordHighlights,
      );
    }

    // Refresh the bookmark index when the input list changes identity.
    if (!identical(oldWidget.highlights, widget.highlights)) {
      _bookmarkIndex = _bookmarkIndexer.refresh(widget.highlights);
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_syncExternalToInternal);

    _twoPageController.removeListener(_syncInternalToExternal);

    _twoPageController.dispose();

    _settleTimer?.cancel();

    _isScrolling.dispose();

    super.dispose();
  }

  /// External PageController -> Two Page Controller
  ///
  /// The external controller works on a 0-based single-page index.
  /// Each pair contains two pages, so the relationship is:
  /// `pair = pageIndex ~/ 2`.
  void _syncExternalToInternal() {
    // Skip during programmatic sync or layout-switch grace period.
    if (_isSyncing || _isSwitching) return;

    if (!widget.pageController.hasClients || !_twoPageController.hasClients) {
      return;
    }

    final double? externalPage = widget.pageController.page;

    if (externalPage == null) return;

    // If the user is currently dragging the two-page view, do not interfere.
    if (_twoPageController.position.isScrollingNotifier.value) return;

    final int pageIndex = externalPage.round();

    _currentPage = pageIndex;

    final int targetPair = pageIndex ~/ 2;

    // Already on the correct pair; nothing to do.
    if (_twoPageController.page?.round() == targetPair) {
      return;
    }

    _isSyncing = true;

    try {
      _twoPageController.jumpToPage(targetPair);
    } finally {
      _isSyncing = false;
    }
  }

  /// Two Page Controller -> External PageController
  ///
  /// We always report the first (odd-numbered) page of the pair.
  void _syncInternalToExternal() {
    // Skip during programmatic sync or layout-switch grace period.
    if (_isSyncing || _isSwitching) return;

    if (!widget.pageController.hasClients || !_twoPageController.hasClients) {
      return;
    }

    // Only sync during actual user dragging, not during layout corrections
    // (such as window resizing) to avoid drifting the external controller.
    if (!_twoPageController.position.isScrollingNotifier.value) return;

    final double? internalPage = _twoPageController.page;

    if (internalPage == null) return;

    final int pairIndex = internalPage.round();

    // 0-based index of the first page in the pair (odd page number = 2i+1).
    final int targetSingle = pairIndex * 2;

    // If the external controller is already inside the same pair, leave it alone.
    // (The old code always reset it to the first page of the pair, which caused
    // a jump backwards when a surah starts on an even page.)
    final int? currentExternal = widget.pageController.page?.round();

    if (currentExternal != null && currentExternal ~/ 2 == pairIndex) {
      _currentPage = currentExternal;
      return;
    }

    _isSyncing = true;

    try {
      _currentPage = targetSingle;
      widget.pageController.jumpToPage(targetSingle);
    } finally {
      _isSyncing = false;
    }
  }

  /// Restores both controllers to the last page the user actually landed on.
  ///
  /// Called when switching layout modes so we never depend on reading
  /// controller positions that may be stale during the transition.
  void _applyCurrentPage() {
    if (!widget.pageController.hasClients || !_twoPageController.hasClients) {
      return;
    }

    final int total = QuranRepository.instance.pages.length;

    final int page = _currentPage.clamp(0, total - 1);

    final int pair = page ~/ 2;

    _isSyncing = true;

    try {
      if (widget.pageController.page?.round() != page) {
        widget.pageController.jumpToPage(page);
      }

      if (_twoPageController.page?.round() != pair) {
        _twoPageController.jumpToPage(pair);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Tracks the scroll state of the currently active PageView only.
  ///
  /// Important: the inactive PageView still receives `jumpToPage` calls for
  /// synchronization, which instantly emits ScrollStart/End notifications.
  /// These must be ignored so they don't cancel the deferral while the user
  /// is actually dragging.
  Widget _trackScrolling({required bool isActive, required Widget child}) {
    // Important: keep the widget tree shape stable. If we sometimes returned
    // `child` directly and other times wrapped it in a NotificationListener,
    // the PageView would be recreated and its controller reset to initialPage
    // (this was the cause of a bug where the view jumped back to page one).
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Ignore notifications from the inactive view, and never track
        // when deferral is disabled.
        if (!isActive || !widget.deferNewPages) return false;

        // Only respond to top-level scroll notifications.
        if (n.depth == 0) {
          if (n is ScrollStartNotification) {
            // New scroll started: cancel any pending build and mark as busy.
            _settleTimer?.cancel();
            if (!_isScrolling.value) _isScrolling.value = true;
          } else if (n is ScrollEndNotification) {
            // Do not build immediately: wait for [deferDelay]; a new scroll
            // will cancel this timer and keep pages deferred.
            _settleTimer?.cancel();
            _settleTimer = Timer(widget.deferDelay, () {
              if (mounted && _isScrolling.value) _isScrolling.value = false;
            });
          }
        }

        return false;
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wait until the Quran data is fully loaded before rendering.
    if (!QuranRepository.instance.isReady) {
      return const SizedBox.shrink();
    }

    // Platform-specific scroll physics for a more native feel.
    final ScrollPhysics physics =
        Theme.of(context).platform == TargetPlatform.iOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enable the two-page layout only when allowed and wide enough.
          final bool useTwoPageMode =
              widget.enableTwoPageLayout && constraints.maxWidth >= 750;

          // Detect a layout mode change and re-sync controllers afterwards.
          if (_lastLayoutMode != useTwoPageMode) {
            _lastLayoutMode = useTwoPageMode;

            // Ignore auto-sync briefly while the layout is settling.
            _switchUntil = DateTime.now().add(
              const Duration(milliseconds: 250),
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              _applyCurrentPage();
            });
          }

          return Container(
            color: widget.pageBackgroundColor ?? Colors.transparent,
            // Both layouts are kept alive via IndexedStack to preserve their
            // state and controllers when switching modes.
            child: IndexedStack(
              index: useTwoPageMode ? 0 : 1,
              children: [
                _buildTwoPageLayout(
                  physics: physics,
                  isActive: useTwoPageMode,
                ),
                _buildSinglePageLayout(
                  key: const ValueKey('single'),
                  physics: physics,
                  isActive: !useTwoPageMode,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the single-page (mobile) layout.
  Widget _buildSinglePageLayout({
    required Key key,
    required ScrollPhysics physics,
    required bool isActive,
  }) {
    final pages = QuranRepository.instance.pages;

    final wordOffsets = QuranRepository.instance.wordOffsets;

    return _trackScrolling(
      isActive: isActive,
      child: PageView.builder(
        key: key,
        controller: widget.pageController,
        physics: physics,
        itemCount: pages.length,
        onPageChanged: isActive
            ? (index) {
                _currentPage = index;

                // Report the 1-based page number to the caller.
                widget.onPageChanged?.call(index + 1);
              }
            : null,
        itemBuilder: (context, index) {
          // The inactive layout is rendered as empty space.
          if (!isActive) {
            return const SizedBox.expand();
          }

          final int pageNum = index + 1;

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
                  onVerseTap: widget.onVerseTap,
                  onLongPress: widget.onLongPress,
                  pageController: widget.pageController,
                  surahHeaderBuilder: widget.surahHeaderBuilder,
                  basmallahBuilder: widget.basmallahBuilder,
                  pageHeaderBuilder: widget.pageHeaderBuilder,
                  ayahStyle: widget.ayahStyle,
                  isDark: widget.isDarkMode,
                  lineOffsets: wordOffsets[index] ?? const {},
                  forceFitConstraints: false,
                  deferWhile: widget.deferNewPages ? _isScrolling : null,
                ),
              ),

              if (widget.bottomBar != null) widget.bottomBar!,
            ],
          );
        },
      ),
    );
  }

  /// Builds the two-page (tablet / landscape) layout.
  Widget _buildTwoPageLayout({
    required ScrollPhysics physics,
    required bool isActive,
  }) {
    final pages = QuranRepository.instance.pages;

    final wordOffsets = QuranRepository.instance.wordOffsets;

    // Each pair contains two pages, so the number of pairs is ceil(total / 2).
    final int pairCount = (pages.length / 2).ceil();

    return _trackScrolling(
      isActive: isActive,
      child: PageView.builder(
        // Fixed key so the PageView stays alive across rebuilds.
        key: const ValueKey('quran_two_page_layout'),
        controller: _twoPageController,
        physics: physics,
        itemCount: pairCount,
        onPageChanged: isActive
            ? (index) {
                // If the external controller already points to a page inside
                // this pair (e.g. after navigating to a surah), report that
                // page; otherwise report the first page of the pair.
                final int? ext = widget.pageController.hasClients
                    ? widget.pageController.page?.round()
                    : null;

                final int reported = (ext != null && ext ~/ 2 == index)
                    ? ext
                    : index * 2;

                _currentPage = reported;

                widget.onPageChanged?.call(reported + 1);
              }
            : null,
        itemBuilder: (context, index) {
          // The inactive layout is rendered as empty space.
          if (!isActive) {
            return const SizedBox.expand();
          }

          // 0-based indices:
          // firstIndex  → pageNumber = 2i+1  (odd)
          // secondIndex → pageNumber = 2i+2  (even)
          final int firstIndex = index * 2;
          final int secondIndex = firstIndex + 1;

          // Important: in a Row with `textDirection: rtl`:
          //   first child  → left side
          //   second child → right side
          //
          // We want the odd page on the left, so:
          //   first child  = odd page  → left
          //   second child = even page → right
          final int leftPageIndex = firstIndex; // odd  → left
          final int rightPageIndex = secondIndex; // even → right

          return Column(
            children: [
              if (widget.topBar != null) widget.topBar!,

              Expanded(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    // First child → left: odd page.
                    Expanded(
                      child: leftPageIndex < pages.length
                          ? _buildPageContainer(
                              leftPageIndex,
                              pages,
                              wordOffsets,
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Vertical divider between the two pages.
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

                    // Second child → right: even page.
                    Expanded(
                      child: rightPageIndex < pages.length
                          ? _buildPageContainer(
                              rightPageIndex,
                              pages,
                              wordOffsets,
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
      ),
    );
  }

  /// Builds a single page container for the two-page layout.
  Widget _buildPageContainer(
    int index,
    List<QuranPage> pages,
    Map<int, Map<int, Map<String, int>>> wordOffsets,
  ) {
    final int pageNum = index + 1;

    return QuranSinglePageWidget(
      key: ValueKey('page_content_two_mode_$pageNum'),
      isTajweed: widget.isTajweed,
      page: pages[index],
      pageIndex: pageNum,
      wordHighlightIndex: _wordHighlightIndex,
      bookmarkIndex: _bookmarkIndex,
      onWordTap: widget.onWordTap,
      onVerseTap: widget.onVerseTap,
      onLongPress: widget.onLongPress,
      pageController: widget.pageController,
      surahHeaderBuilder: widget.surahHeaderBuilder,
      basmallahBuilder: widget.basmallahBuilder,
      pageHeaderBuilder: widget.pageHeaderBuilder,
      ayahStyle: widget.ayahStyle,
      isDark: widget.isDarkMode,
      lineOffsets: wordOffsets[index] ?? const {},
      forceFitConstraints: true,
      deferWhile: widget.deferNewPages ? _isScrolling : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// QuranSinglePageWidget
// ─────────────────────────────────────────────────────────────────

/// Renders the content of a single Quran page.
///
/// This widget is responsible for:
/// - Laying out the page lines and their surrounding surah/Basmallah headers.
/// - Computing per-line styles and caching them.
/// - Selecting between the "first two pages" layout (pages 1 and 2) and the
///   standard layout used by all other pages.
/// - Deferring construction while the user is scrolling, when requested.
class QuranSinglePageWidget extends StatefulWidget {
  /// The parsed Quran page model to render.
  final QuranPage page;

  /// The 1-based page index (page number in the Quran).
  final int pageIndex;

  /// Memoized lookup for word-level highlights.
  final WordHighlightIndex wordHighlightIndex;

  /// Memoized lookup for bookmark/verse-level highlights.
  final BookmarkIndex bookmarkIndex;

  /// Called when the user long-presses a verse.
  final void Function(int, int, LongPressStartDetails)? onLongPress;

  /// Called when the user taps a word.
  final void Function(int, int, int, String)? onWordTap;

  /// Called when the user taps a verse.
  final void Function(int surah, int verse)? onVerseTap;

  /// External page controller (used for surah/basmallah interplay).
  final PageController pageController;

  /// Optional custom surah header builder.
  final Widget Function(BuildContext, int)? surahHeaderBuilder;

  /// Optional custom Basmallah builder.
  final Widget Function(BuildContext, int)? basmallahBuilder;

  /// Optional custom page header builder.
  final Widget Function(BuildContext, int)? pageHeaderBuilder;

  /// Optional custom text style for the ayah text.
  final TextStyle? ayahStyle;

  /// Whether Tajweed coloring is enabled.
  final bool isTajweed;

  /// Whether the app is in dark mode.
  final bool isDark;

  /// Precomputed word offsets for each line on this page.
  final Map<int, Map<String, int>> lineOffsets;

  /// Whether to force the "fit to constraints" layout even in landscape.
  final bool forceFitConstraints;

  /// When this listenable is `true` at construction time, the page is
  /// rendered empty and only built once the value flips to `false`
  /// (i.e. after scrolling settles). `null` disables deferral.
  final ValueListenable<bool>? deferWhile;

  /// Creates a [QuranSinglePageWidget].
  const QuranSinglePageWidget({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.wordHighlightIndex,
    required this.bookmarkIndex,
    this.onLongPress,
    this.onWordTap,
    this.onVerseTap,
    required this.pageController,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.pageHeaderBuilder,
    this.ayahStyle,
    required this.isDark,
    this.isTajweed = true,
    required this.lineOffsets,
    required this.forceFitConstraints,
    this.deferWhile,
  });

  @override
  State<QuranSinglePageWidget> createState() => _QuranSinglePageWidgetState();
}

class _QuranSinglePageWidgetState extends State<QuranSinglePageWidget> {
  /// Cached base text style (without a specific font size).
  TextStyle? _cachedBaseStyle;

  /// Cache of computed styles keyed by font size to avoid repeated work.
  final Map<double, TextStyle> _styleCache = {};

  /// Cached set of line indices that contain a surah header.
  Set<int>? _cachedHeaderLineIndices;

  /// Page index associated with [_cachedHeaderLineIndices].
  int? _cachedHeaderPageIndex;

  // ── Deferred build state ──
  /// Whether the page is ready to build. `false` while deferred.
  bool _ready = true;

  /// The listenable being observed for deferral (if any).
  ValueListenable<bool>? _deferSub;

  @override
  void initState() {
    super.initState();

    final d = widget.deferWhile;

    // If deferral is requested and currently active, mark the page as not ready.
    if (d != null && d.value) {
      _ready = false;
      _deferSub = d;
      d.addListener(_onDeferChanged);
    }
  }

  /// Called when the deferral listenable changes value.
  void _onDeferChanged() {
    final d = _deferSub;

    // Ignore while still deferred.
    if (d == null || d.value) return;

    d.removeListener(_onDeferChanged);
    _deferSub = null;

    if (!mounted || _ready) return;

    /// Marks the page as ready so it can build on the next frame.
    void markReady() {
      if (mounted) setState(() => _ready = true);
    }

    // The notification may arrive during layout, so defer setState to after
    // the current frame to avoid "setState during build" errors.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => markReady());
    } else {
      markReady();
    }
  }

  @override
  void dispose() {
    _deferSub?.removeListener(_onDeferChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QuranSinglePageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If deferral was disabled while the page is still empty, build it now.
    if (widget.deferWhile == null && !_ready) {
      _deferSub?.removeListener(_onDeferChanged);
      _deferSub = null;
      _ready = true;
    }

    // Invalidate caches whenever style-affecting inputs change.
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.ayahStyle != widget.ayahStyle ||
        oldWidget.isTajweed != widget.isTajweed ||
        oldWidget.isDark != widget.isDark) {
      _cachedBaseStyle = null;
      _styleCache.clear();
      _cachedHeaderLineIndices = null;
      _cachedHeaderPageIndex = null;
    }
  }

  /// Returns the base style for this page, computing and caching it lazily.
  TextStyle _baseStyle() {
    return _cachedBaseStyle ??=
        (widget.ayahStyle ??
            QuranTextStyles.qcfStyle(
              height: 1.45,
              pageNumber: widget.pageIndex,
              isTajweed: widget.isTajweed,
              isDark: widget.isDark,
            ));
  }

  /// Returns a style with the given [fontSize], cached per size.
  TextStyle _styleFor(double fontSize) {
    final cached = _styleCache[fontSize];

    if (cached != null) {
      return cached;
    }

    final TextStyle style = _baseStyle().copyWith(fontSize: fontSize);

    _styleCache[fontSize] = style;

    return style;
  }

  /// Returns the set of line indices that contain a surah header
  /// (i.e. lines that begin with verse 1 of a new surah).
  Set<int> _headerLineIndices() {
    // Reuse the cached result if it matches the current page.
    if (_cachedHeaderPageIndex == widget.pageIndex &&
        _cachedHeaderLineIndices != null) {
      return _cachedHeaderLineIndices!;
    }

    final indices = <int>{};
    final seen = <String>{};

    for (int l = 0; l < widget.page.lines.length; l++) {
      final line = widget.page.lines[l];

      // A surah header appears at the first ayah of a new surah
      // (ayahNumber == 1) and only once per surah per page.
      if (line.ayahs.isNotEmpty &&
          line.ayahs[0].ayahNumber == 1 &&
          !seen.contains(line.ayahs[0].surahNameAr)) {
        seen.add(line.ayahs[0].surahNameAr);

        indices.add(l);
      }
    }

    _cachedHeaderLineIndices = indices;

    _cachedHeaderPageIndex = widget.pageIndex;

    return indices;
  }

  @override
  Widget build(BuildContext context) {
    // Deferred page while scrolling: render empty until scrolling settles.
    if (!_ready) return const SizedBox.expand();

    final Orientation orientation = MediaQuery.orientationOf(context);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size availableSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          // Pages 1 and 2 use a special centered layout.
          if (widget.pageIndex == 1 || widget.pageIndex == 2) {
            return _buildFirstTwoPages(context, availableSize, orientation);
          }

          return _buildStandardPage(context, availableSize, orientation);
        },
      ),
    );
  }

  /// Builds the special layout used for the first two pages of the Quran.
  Widget _buildFirstTwoPages(
    BuildContext context,
    Size availableSize,
    Orientation orientation,
  ) {
    // In portrait (or when forced) the page content must fit the constraints.
    final bool shouldFit =
        orientation == Orientation.portrait || widget.forceFitConstraints;

    final List<Widget> children = [];

    // Optional page header.
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

    // Surah header (and, for page 2, Basmallah) at the top of the page.
    if (widget.page.ayahs.isNotEmpty) {
      final Widget sHeader =
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
        final Widget bHeader =
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

    // Render each page line.
    for (int i = 0; i < widget.page.lines.length; i++) {
      final line = widget.page.lines[i];

      final bool isCentered = line.ayahs.isNotEmpty && line.ayahs.last.centered;

      final BoxFit fit = isCentered
          ? BoxFit.scaleDown
          : (shouldFit ? BoxFit.contain : BoxFit.fitWidth);

      final Widget lineWidget = _buildQuranLine(
        line,
        availableSize,
        fit,
        i,
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
      // Distribute empty space evenly above and below the content
      // to keep the visual balance of the first pages.
      final int emptyFlex = (15 - flexCount).clamp(0, 15);

      if (emptyFlex > 0) {
        final int topEmpty = emptyFlex ~/ 2;

        final int bottomEmpty = emptyFlex - topEmpty;

        if (topEmpty > 0) {
          children.add(Spacer(flex: topEmpty));
        }

        children.addAll(flexChildren);

        if (bottomEmpty > 0) {
          children.add(Spacer(flex: bottomEmpty));
        }
      } else {
        children.addAll(flexChildren);
      }
    } else {
      children.addAll(flexChildren);
    }

    final Widget pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    // In "fit" mode, the content fills the available space directly.
    // Otherwise, it becomes scrollable.
    return shouldFit
        ? pageContent
        : Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: pageContent,
            ),
          );
  }

  /// Builds the standard page layout (pages 3 through 604).
  Widget _buildStandardPage(
    BuildContext context,
    Size availableSize,
    Orientation orientation,
  ) {
    // In portrait (or when forced) the page content must fit the constraints.
    final bool shouldFit =
        orientation == Orientation.portrait || widget.forceFitConstraints;

    final Set<int> headerLines = _headerLineIndices();

    final List<Widget> children = [];

    // Optional page header.
    if (widget.pageHeaderBuilder != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: widget.pageHeaderBuilder!(context, widget.pageIndex),
        ),
      );
    }

    int flexCount = 0;

    for (int lineIdx = 0; lineIdx < widget.page.lines.length; lineIdx++) {
      final line = widget.page.lines[lineIdx];

      // Insert a surah header (and Basmallah) when this line starts a new surah.
      if (headerLines.contains(lineIdx) && line.ayahs.isNotEmpty) {
        final Widget sHeader =
            widget.surahHeaderBuilder?.call(
              context,
              line.ayahs[0].surahNumber,
            ) ??
            SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber);

        children.add(
          shouldFit ? Expanded(child: Center(child: sHeader)) : sHeader,
        );

        flexCount++;

        // Surah At-Tawbah (9) has no Basmallah.
        if (line.ayahs[0].surahNumber != 9) {
          final Widget bHeader =
              widget.basmallahBuilder?.call(
                context,
                line.ayahs[0].surahNumber,
              ) ??
              BasmallahWidget(line.ayahs[0].surahNumber);

          children.add(
            shouldFit ? Expanded(child: Center(child: bHeader)) : bHeader,
          );

          flexCount++;
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
        isCentered: isCentered,
      );

      // Centered lines are limited to 98% of the width for balance.
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

      flexCount++;
    }

    // Fill any remaining vertical space so content stays vertically centered.
    if (shouldFit && flexCount > 0 && flexCount < 15) {
      children.add(Spacer(flex: 15 - flexCount));
    }

    final Widget pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    // In "fit" mode, the content fills the available space directly.
    // Otherwise, it becomes scrollable.
    return shouldFit
        ? pageContent
        : Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: pageContent,
            ),
          );
  }

  /// Builds a single rendered Quran line using the parsed line cache.
  Widget _buildQuranLine(
    Line line,
    Size deviceSize,
    BoxFit boxFit,
    int lineIndex, {
    bool isCentered = false,
  }) {
    // Use the parsed line cache to avoid re-parsing on every rebuild.
    final parsedAyahs =
        ParsedLineCache.instance.tryGet(widget.pageIndex, lineIndex) ??
        ParsedLineCache.instance.getOrParse(
          widget.pageIndex,
          lineIndex,
          line,
          widget.lineOffsets[lineIndex],
        );

    // Default font size; scaled down for small centered lines.
    double fontSize = 45.0;

    if (isCentered && deviceSize.width < 600) {
      fontSize = deviceSize.width * 0.055;
    }

    final TextStyle fixedStyle = _styleFor(fontSize);

    return QuranLine(
      parsedAyahs: parsedAyahs,
      pageNumber: widget.pageIndex,
      wordHighlightIndex: widget.wordHighlightIndex,
      bookmarkIndex: widget.bookmarkIndex,
      onWordTap: widget.onWordTap,
      onVerseTap: widget.onVerseTap,
      boxFit: boxFit,
      onLongPress: widget.onLongPress,
      ayahStyle: fixedStyle,
      isTajweed: widget.isTajweed,
      isDark: widget.isDark,
    );
  }
}