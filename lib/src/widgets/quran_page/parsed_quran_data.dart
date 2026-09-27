import '../../../qcf_quran_plus.dart';

/// Matches Quranic symbols used in the normalized text representation.
final _symbolRegex = RegExp(r'[\u06D6-\u06DC\u06DE\u06E9]');

/// Splits ayah text into logical word tokens using whitespace as the separator.
final _wordSplitRegex = RegExp(r'\s+');

/// Matches standalone digit sequences that should be ignored when building logical words.
final _digitsRegex = RegExp(r'^[\d٠-٩]+$');

/// Represents a single token extracted from an ayah.
class ParsedWordData {
  /// The raw character or token text.
  final String text;

  /// Indicates whether this token is a whitespace separator.
  final bool isSpace;

  /// Indicates whether this token represents a Quranic symbol.
  final bool isSymbol;

  /// The logical word index to which this token belongs.
  final int? wordIndex;

  /// The original logical word value before symbol decomposition.
  final String? logicalWord;

  const ParsedWordData({
    required this.text,
    this.isSpace = false,
    this.isSymbol = false,
    this.wordIndex,
    this.logicalWord,
  });
}

/// Represents a fully parsed ayah and its derived tokens.
class ParsedAyahData {
  /// Surah number for this ayah.
  final int surahNumber;

  /// Ayah number within the surah.
  final int ayahNumber;

  /// Parsed tokens for the current ayah.
  final List<ParsedWordData> words;

  /// Optional glyph appended to the ayah output.
  final String? glyph;

  const ParsedAyahData({
    required this.surahNumber,
    required this.ayahNumber,
    required this.words,
    this.glyph,
  });
}

/// Parses a [Line] into a structured representation of ayahs and tokens.
///
/// The parser normalizes whitespace, removes trailing glyph markers, and maps
/// QCF character data back to the logical words extracted from the ayah text.
List<ParsedAyahData> parseLine(
  Line line,
  Map<String, int>? startingWordIndices,
) {
  final result = <ParsedAyahData>[];

  for (final ayah in line.ayahs.toList().reversed) {
    final ayaText = ayah.ayah.replaceAll('\n', ' ').trim();
    final logicalWords = ayaText.split(_wordSplitRegex).where((w) {
      return w.isNotEmpty && !_digitsRegex.hasMatch(w);
    }).toList();

    final rawQcf = ayah.qcfData.replaceAll('\n', '').trimRight();
    final glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);
    final hasGlyph = rawQcf.endsWith(glyph);
    final cleanQcf = hasGlyph
        ? rawQcf.substring(0, rawQcf.length - glyph.length)
        : rawQcf;

    final ayahKey = '${ayah.surahNumber}-${ayah.ayahNumber}';
    int currentWordIndex = startingWordIndices?[ayahKey] ?? 0;

    final wordsData = <ParsedWordData>[];
    int qcfCharIndex = 0;

    for (int i = 0; i < logicalWords.length; i++) {
      final logicalWord = logicalWords[i];
      final symbolCount = _symbolRegex.allMatches(logicalWord).length;
      final glyphsNeeded = 1 + symbolCount;

      for (int k = 0; k < glyphsNeeded; k++) {
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

/// Caches parsed line results so repeated page rendering can reuse the same
/// structured output without re-parsing the underlying data.
class ParsedLineCache {
  ParsedLineCache._();

  /// Singleton instance of the parsed-line cache.
  static final ParsedLineCache instance = ParsedLineCache._();

  final Map<String, List<ParsedAyahData>> _cache = {};

  /// Returns a cached parse result when available; otherwise it parses the line
  /// and stores the result for future reuse.
  List<ParsedAyahData> getOrParse(
    int pageIndex,
    int lineIndex,
    Line line,
    Map<String, int>? startingWordIndices,
  ) {
    final indicesHash =
        startingWordIndices?.entries
            .map((e) => '${e.key}=${e.value}')
            .join(',') ??
        'null';

    final key = '$pageIndex:$lineIndex:$indicesHash';
    final cached = _cache[key];
    if (cached != null) return cached;

    final parsed = parseLine(line, startingWordIndices);
    _cache[key] = parsed;
    return parsed;
  }

  /// Clears the cache. Intended primarily for debugging and testing.
  @visibleForTestingOnly
  void debugClear() => _cache.clear();
}

/// Marker type used to indicate that a declaration is intended for testing only.
class _VisibleForTestingOnly {
  const _VisibleForTestingOnly();
}

/// Public instance of the test-only marker.
const visibleForTestingOnly = _VisibleForTestingOnly();
