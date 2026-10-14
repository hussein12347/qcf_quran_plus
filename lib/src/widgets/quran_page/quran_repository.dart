import 'package:flutter/foundation.dart';
import '../../../qcf_quran_plus.dart';
import '../../services/get_page.dart';
import 'parsed_quran_data.dart';

/// A singleton repository that loads, caches, and exposes the parsed Quran
/// data needed by the rendering widgets.
///
/// Loading is performed once, off the main isolate, via [compute]. The result
/// is stored in memory and reused by all consumers. The repository exposes:
///
/// - [pages]: the list of parsed [QuranPage] objects.
/// - [wordOffsets]: per-page, per-line word offsets keyed by `surah-ayah`.
/// - [headerLineIndices]: per-page set of line indices that contain a surah
///   header (the first ayah of a new surah on that page).
///
/// Access to the repository is through [QuranRepository.instance].
///
/// Example:
/// ```dart
/// await QuranRepository.instance.ensureLoaded(604);
/// final pages = QuranRepository.instance.pages;
/// ```
class QuranRepository {
  /// Private constructor used to enforce the singleton pattern.
  QuranRepository._();

  /// The singleton instance of the repository.
  static final QuranRepository instance = QuranRepository._();

  /// Parsed Quran pages, available after [ensureLoaded] completes.
  List<QuranPage>? _pages;

  /// Per-page word offsets for every line.
  ///
  /// Structure: `pageIndex -> lineIndex -> "surah-ayah" -> wordOffset`
  Map<int, Map<int, Map<String, int>>>? _wordOffsets;

  /// Per-page set of line indices that contain a surah header.
  ///
  /// Structure: `pageNumber -> {lineIndices}`
  Map<int, Set<int>>? _headerLineIndices;

  /// The future returned by the first call to [ensureLoaded].
  /// Subsequent calls return this same future until loading finishes.
  Future<void>? _loadingFuture;

  /// Whether the repository has finished loading all of its data.
  bool get isReady =>
      _pages != null && _wordOffsets != null && _headerLineIndices != null;

  /// Returns the parsed Quran pages. Must only be called when [isReady] is true.
  List<QuranPage> get pages => _pages!;

  /// Returns the per-page word offsets. Must only be called when [isReady] is true.
  Map<int, Map<int, Map<String, int>>> get wordOffsets => _wordOffsets!;

  /// Returns the per-page surah header line indices. Must only be called when
  /// [isReady] is true.
  Map<int, Set<int>> get headerLineIndices => _headerLineIndices!;

  /// Ensures that the Quran data is loaded.
  ///
  /// - If the data is already loaded, returns an already-completed future.
  /// - If a load is already in progress, returns the existing future.
  /// - Otherwise, starts a new load using [quranPagesCount] as the total
  ///   number of pages.
  Future<void> ensureLoaded(int quranPagesCount) {
    // Fast path: data is already available.
    if (isReady) return Future.value();

    // Start the load only once; reuse the same future for concurrent callers.
    return _loadingFuture ??= _load(quranPagesCount);
  }

  /// Performs the actual loading by running [_loadAndPrecompute] on a
  /// background isolate, then stores the results in memory.
  Future<void> _load(int quranPagesCount) async {
    // Offload heavy parsing and precomputation to a separate isolate.
    final result = await compute(_loadAndPrecompute, quranPagesCount);

    _pages = result.pages;
    _wordOffsets = result.offsets;
    _headerLineIndices = result.headerLineIndices;

    // Prefill the parsed-line cache so widgets don't re-parse lines on first build.
    ParsedLineCache.instance.prefill(result.parsedLines);
  }

  /// Resets all internal state. Intended for tests only.
  @visibleForTesting
  void debugReset() {
    _pages = null;
    _wordOffsets = null;
    _headerLineIndices = null;
    _loadingFuture = null;
    ParsedLineCache.instance.debugClear();
  }
}

/// Internal container for the results produced by [_loadAndPrecompute].
///
/// This type exists only to bundle multiple return values from the isolate
/// function into a single object.
class _LoadResult {
  /// Parsed Quran pages.
  final List<QuranPage> pages;

  /// Per-page, per-line word offsets keyed by `surah-ayah`.
  final Map<int, Map<int, Map<String, int>>> offsets;

  /// Pre-parsed lines keyed by a composite line key (see [parsedLineKey]).
  final Map<int, List<ParsedAyahData>> parsedLines;

  /// Per-page set of line indices that contain a surah header.
  final Map<int, Set<int>> headerLineIndices;

  /// Creates a [_LoadResult] bundling all precomputed data.
  _LoadResult(
    this.pages,
    this.offsets,
    this.parsedLines,
    this.headerLineIndices,
  );
}

/// Loads and precomputes all data required by the repository.
///
/// This function is designed to run inside a background isolate via [compute].
/// It performs the following steps:
///
/// 1. Builds the list of parsed [QuranPage] objects using [GetPage].
/// 2. Computes per-line word offsets for every page. The offsets are keyed by
///    `"surahNumber-ayahNumber"` and represent the number of logical words
///    that appear before the given ayah on the same line.
/// 3. Pre-parses every line into [ParsedAyahData] using [parseLine].
/// 4. Computes, for every page, the set of line indices that contain a surah
///    header (i.e. the first ayah of a new surah).
///
/// The result is returned as a [_LoadResult] and later stored by
/// [QuranRepository._load].
_LoadResult _loadAndPrecompute(int count) {
  // Build all pages from the raw Quran data.
  final processor = GetPage();
  processor.getQuran(count);
  final pages = processor.staticPages;

  // Output collections populated below.
  final offsets = <int, Map<int, Map<String, int>>>{};
  final parsedLines = <int, List<ParsedAyahData>>{};
  final headerLineIndices = <int, Set<int>>{};

  // Tracks the running word count per ayah key across lines and pages.
  final runningCounts = <String, int>{};

  // Regex used to split Arabic text into words.
  final wordSplitRegex = RegExp(r'\s+');

  // Regex that matches tokens consisting only of digits or decorative symbols.
  // Such tokens are excluded from the logical word count.
  final digitsRegex =
      RegExp(r'^[\d٠-٩۩۞ۤ\u06D6-\u06DC\u06DE\u06E4\u06E9]+$');

  // Process each page.
  for (int p = 0; p < pages.length; p++) {
    final page = pages[p];

    // Per-page map: lineIndex -> { "surah-ayah": offset }.
    final pageMap = <int, Map<String, int>>{};
    offsets[p] = pageMap;

    // Process each line on the page.
    for (int l = 0; l < page.lines.length; l++) {
      final line = page.lines[l];

      // Per-line map: "surah-ayah" -> offset.
      final lineMap = <String, int>{};
      pageMap[l] = lineMap;

      // Compute the offset for each ayah that starts on this line.
      for (final ayah in line.ayahs) {
        final key = '${ayah.surahNumber}-${ayah.ayahNumber}';

        // Offset for this ayah = words accumulated before it on this line.
        final currentOffset = runningCounts[key] ?? 0;
        lineMap[key] = currentOffset;

        // Normalize the ayah text and count its logical words.
        final ayaText = ayah.ayah.replaceAll('\n', ' ').trim();
        final wordCount = ayaText
            .split(wordSplitRegex)
            .where((w) => w.isNotEmpty && !digitsRegex.hasMatch(w))
            .length;

        // Advance the running count for this ayah key.
        runningCounts[key] = currentOffset + wordCount;
      }

      // Pre-parse this line into ParsedAyahData using the computed offsets.
      parsedLines[parsedLineKey(p + 1, l)] = parseLine(line, lineMap);
    }

    // Precompute the surah header line indices for this page.
    // This is done inside the isolate to keep the main thread fast.
    headerLineIndices[p + 1] = computeHeaderLineIndices(page);
  }

  // Bundle everything into a single result object for the isolate boundary.
  return _LoadResult(pages, offsets, parsedLines, headerLineIndices);
}