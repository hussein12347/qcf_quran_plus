import '../../../qcf_quran_plus.dart';

/// Regex that matches Quranic symbol marks (e.g. sajdah, rub el hizb).
/// These characters are treated as separate symbol glyphs during parsing.
final _symbolRegex = RegExp(r'[\u06D6-\u06DC\u06DE\u06E9]');

/// Regex used to split Arabic text into logical words on whitespace.
final _wordSplitRegex = RegExp(r'\s+');

/// Regex that matches tokens consisting solely of digits or decorative symbols.
/// Such tokens are excluded from the logical word count and are not treated
/// as tappable words.
final _digitsRegex =
    RegExp(r'^[\d٠-٩۩۞ۤ\u06D6-\u06DC\u06DE\u06E4\u06E9]+$');

/// A single parsed word (or character) within an ayah.
///
/// Each instance corresponds to one QCF glyph that will be rendered. The
/// original logical word context is preserved via [wordIndex] and
/// [logicalWord] so that tap callbacks can report meaningful information.
class ParsedWordData {
  /// The exact QCF character to render.
  final String text;

  /// Whether this entry represents a space or zero-width space.
  final bool isSpace;

  /// Whether this entry is a decorative symbol (e.g. sajdah marker).
  final bool isSymbol;

  /// The zero-based index of the logical word this character belongs to,
  /// or `null` for spaces and trailing symbols.
  final int? wordIndex;

  /// The original logical word string (as it appeared before QCF splitting),
  /// or `null` for spaces and trailing symbols.
  final String? logicalWord;

  /// Creates a [ParsedWordData].
  const ParsedWordData({
    required this.text,
    this.isSpace = false,
    this.isSymbol = false,
    this.wordIndex,
    this.logicalWord,
  });
}

/// The parsed representation of a single ayah within a line.
///
/// Contains the list of [ParsedWordData] entries that make up the ayah and,
/// optionally, the ayah-number glyph that should be rendered at the end.
class ParsedAyahData {
  /// The 1-based surah number this ayah belongs to.
  final int surahNumber;

  /// The 1-based ayah (verse) number within the surah.
  final int ayahNumber;

  /// The ordered list of parsed glyphs for this ayah.
  final List<ParsedWordData> words;

  /// The QCF glyph representing the ayah number, or `null` if not present.
  final String? glyph;

  /// Creates a [ParsedAyahData].
  const ParsedAyahData({
    required this.surahNumber,
    required this.ayahNumber,
    required this.words,
    this.glyph,
  });
}

/// Parses a single [line] of Quranic text into a list of [ParsedAyahData].
///
/// This is a pure function and is therefore safe to call from any isolate.
///
/// The parsing process:
/// 1. Iterates over the ayahs in reverse order (as they appear in the line).
/// 2. Normalizes the ayah text and splits it into logical words.
/// 3. Strips the trailing ayah-number glyph from the QCF data.
/// 4. Maps each logical word to one or more QCF glyphs, preserving spaces
///    and marking symbols.
/// 5. Attaches a running word index so that highlights and taps can refer
///    to a specific word.
///
/// [startingWordIndices] provides the initial word index for each ayah key
/// (`"surah-ayah"`). When `null`, indices start from 0.
List<ParsedAyahData> parseLine(
  Line line,
  Map<String, int>? startingWordIndices,
) {
  final result = <ParsedAyahData>[];

  // Process ayahs in reverse order because they are laid out right-to-left.
  for (final ayah in line.ayahs.toList().reversed) {
    // Normalize the plain text and extract logical words.
    final ayaText = ayah.ayah.replaceAll('\n', ' ').trim();
    final logicalWords = ayaText.split(_wordSplitRegex).where((w) {
      return w.isNotEmpty && !_digitsRegex.hasMatch(w);
    }).toList();

    // Prepare the QCF glyph data and identify the trailing ayah-number glyph.
    final rawQcf = ayah.qcfData.replaceAll('\n', '').trimRight();
    final glyph = getAyaNoQCF(ayah.surahNumber, ayah.ayahNumber);
    final hasGlyph = rawQcf.endsWith(glyph);
    final cleanQcf = hasGlyph
        ? rawQcf.substring(0, rawQcf.length - glyph.length)
        : rawQcf;

    // Determine the starting word index for this ayah.
    final ayahKey = '${ayah.surahNumber}-${ayah.ayahNumber}';
    int currentWordIndex = startingWordIndices?[ayahKey] ?? 0;

    final wordsData = <ParsedWordData>[];
    int qcfCharIndex = 0;

    // Walk through each logical word and consume the matching QCF glyphs.
    for (int i = 0; i < logicalWords.length; i++) {
      final logicalWord = logicalWords[i];
      final symbolCount = _symbolRegex.allMatches(logicalWord).length;

      // Each logical word consumes one base glyph plus one per symbol.
      final glyphsNeeded = 1 + symbolCount;

      for (int k = 0; k < glyphsNeeded; k++) {
        // Emit any spaces or zero-width spaces that precede this glyph.
        while (qcfCharIndex < cleanQcf.length &&
            (cleanQcf[qcfCharIndex] == ' ' ||
                cleanQcf[qcfCharIndex] == '\u200B')) {
          wordsData.add(
            ParsedWordData(text: cleanQcf[qcfCharIndex], isSpace: true),
          );
          qcfCharIndex++;
        }
        if (qcfCharIndex >= cleanQcf.length) break;

        final char = cleanQcf[qcfCharIndex];

        // Determine whether this glyph is a decorative symbol.
        bool isSymbol = false;
        if (logicalWord.startsWith('۞') || logicalWord.startsWith('۩')) {
          isSymbol = (k == 0);
        } else {
          isSymbol = (k > 0);
        }

        wordsData.add(
          ParsedWordData(
            text: char,
            wordIndex: currentWordIndex,
            logicalWord: logicalWord,
            isSymbol: isSymbol,
          ),
        );
        qcfCharIndex++;
      }
      currentWordIndex++;
    }

    // Emit any remaining characters (e.g. trailing symbols or spaces).
    while (qcfCharIndex < cleanQcf.length) {
      wordsData.add(
        ParsedWordData(
          text: cleanQcf[qcfCharIndex],
          isSpace:
              cleanQcf[qcfCharIndex] == ' ' ||
              cleanQcf[qcfCharIndex] == '\u200B',
          isSymbol: true,
        ),
      );
      qcfCharIndex++;
    }

    // Append the parsed ayah to the result list.
    result.add(
      ParsedAyahData(
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
        words: wordsData,
        glyph: hasGlyph ? glyph : null,
      ),
    );
  }
  return result;
}

/// Key helper shared between the repository and the cache.
///
/// `(page << 8) | line` produces a stable integer key for up to 256 lines
/// per page. This allows the cache to use a single flat map.
int parsedLineKey(int pageIndex, int lineIndex) =>
    (pageIndex << 8) | (lineIndex & 0xFF);

/// Computes the set of line indices within [page] that contain a surah header.
///
/// A surah header appears on the line that starts with verse 1 of a new surah.
/// Each surah header is only counted once per page.
Set<int> computeHeaderLineIndices(QuranPage page) {
  final indices = <int>{};
  final seen = <String>{};
  for (int l = 0; l < page.lines.length; l++) {
    final line = page.lines[l];
    if (line.ayahs.isNotEmpty &&
        line.ayahs[0].ayahNumber == 1 &&
        !seen.contains(line.ayahs[0].surahNameAr)) {
      seen.add(line.ayahs[0].surahNameAr);
      indices.add(l);
    }
  }
  return indices;
}

/// A singleton cache for parsed line results.
///
/// With preloading enabled, this cache is populated once during app startup
/// and every subsequent lookup is O(1). If a line is not in the cache, it is
/// parsed on demand and stored for future use.
class ParsedLineCache {
  /// Private constructor to enforce the singleton pattern.
  ParsedLineCache._();

  /// The singleton instance of the cache.
  static final ParsedLineCache instance = ParsedLineCache._();

  /// Internal storage: maps a composite line key to its parsed data.
  final Map<int, List<ParsedAyahData>> _cache = {};

  /// Bulk-loads precomputed parsed lines produced by the isolate.
  ///
  /// This replaces any existing cache content.
  void prefill(Map<int, List<ParsedAyahData>> precomputed) {
    _cache
      ..clear()
      ..addAll(precomputed);
  }

  /// Fast path used when the data is already preloaded.
  ///
  /// Returns the cached parsed data for the given page and line, or `null`
  /// if the line has not been parsed yet.
  List<ParsedAyahData>? tryGet(int pageIndex, int lineIndex) {
    return _cache[parsedLineKey(pageIndex, lineIndex)];
  }

  /// Returns a cached parse result when available; otherwise parses the line.
  ///
  /// After startup preloading, this always hits the cache.
  List<ParsedAyahData> getOrParse(
    int pageIndex,
    int lineIndex,
    Line line,
    Map<String, int>? startingWordIndices,
  ) {
    final int k = parsedLineKey(pageIndex, lineIndex);
    final cached = _cache[k];
    if (cached != null) return cached;

    final parsed = parseLine(line, startingWordIndices);
    _cache[k] = parsed;
    return parsed;
  }

  /// Clears the cache. Intended for tests only.
  void debugClear() => _cache.clear();
}