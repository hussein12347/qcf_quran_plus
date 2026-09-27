import '../../../qcf_quran_plus.dart';

/// ---------------------------------------------------------------------
/// WordHighlightIndex / BookmarkIndex   (section E)
/// ---------------------------------------------------------------------
/// OLD COST (inside QuranLine.build, per word, per build):
///   widget.wordHighlights.where((w) => w.surah == ... && w.verseNumber
///       == ... && w.wordIndex == ...).firstOrNull
///   -> O(words_on_line * wordHighlights.length) EVERY build. During audio
///   playback, wordHighlights (or the "current word" list) changes on
///   every tick, so this ran dozens of times per second.
///
/// NEW COST: O(1) map lookup per word, O(n) to (re)build the map only
/// when the underlying highlight list actually changed content.
/// ---------------------------------------------------------------------
class WordHighlightIndex {
  final Map<String, WordHighlight> _byWord;
  final int signature;

  WordHighlightIndex._(this._byWord, this.signature);

  static const empty = _EmptyWordHighlightIndex();

  factory WordHighlightIndex.build(List<WordHighlight> highlights) {
    final map = <String, WordHighlight>{};
    for (final h in highlights) {
      map['${h.surah}-${h.verseNumber}-${h.wordIndex}'] = h;
    }
    return WordHighlightIndex._(map, _signatureOf(highlights));
  }

  WordHighlight? lookup(int surah, int verse, int wordIndex) =>
      _byWord['$surah-$verse-$wordIndex'];

  static int _signatureOf(List<WordHighlight> list) {
    // Cheap content signature (NOT identity-based) so callers that rebuild
    // a new list each frame with the *same content* still hit the cache -
    // this list is expected to be small (a handful of active/highlighted
    // words), so this is O(n) with a tiny n, nowhere near the old
    // O(words_on_page * n) cost.
    int hash = list.length;
    for (final h in list) {
      hash = 0x1fffffff & (hash + Object.hash(h.surah, h.verseNumber, h.wordIndex, h.textColor, h.backgroundColor));
    }
    return hash;
  }
}

class _EmptyWordHighlightIndex implements WordHighlightIndex {
  const _EmptyWordHighlightIndex();
  @override
  Map<String, WordHighlight> get _byWord => const {};
  @override
  int get signature => 0;
  @override
  WordHighlight? lookup(int surah, int verse, int wordIndex) => null;
}

class BookmarkIndex {
  final Map<String, HighlightVerse> _byAyah;
  final int signature;

  BookmarkIndex._(this._byAyah, this.signature);

  static const empty = _EmptyBookmarkIndex();

  factory BookmarkIndex.build(List<HighlightVerse> bookmarks) {
    final map = <String, HighlightVerse>{};
    for (final b in bookmarks) {
      map['${b.surah}-${b.verseNumber}'] = b;
    }
    return BookmarkIndex._(map, _signatureOf(bookmarks));
  }

  bool isHighlighted(int surah, int verse) => _byAyah.containsKey('$surah-$verse');

  HighlightVerse? lookup(int surah, int verse) => _byAyah['$surah-$verse'];

  static int _signatureOf(List<HighlightVerse> list) {
    int hash = list.length;
    for (final b in list) {
      hash = 0x1fffffff & (hash + Object.hash(b.surah, b.verseNumber, b.color));
    }
    return hash;
  }
}

class _EmptyBookmarkIndex implements BookmarkIndex {
  const _EmptyBookmarkIndex();
  @override
  Map<String, HighlightVerse> get _byAyah => const {};
  @override
  int get signature => 0;
  @override
  bool isHighlighted(int surah, int verse) => false;
  @override
  HighlightVerse? lookup(int surah, int verse) => null;
}

/// Small helper a State object can hold on to: rebuilds the index only
/// when the source list's *content signature* changes, otherwise returns
/// the previously-built index instance (so children relying on
/// `identical()` / `==` for shouldRebuild checks also benefit).
class MemoizedWordHighlightIndex {
  WordHighlightIndex _current = WordHighlightIndex.empty;

  WordHighlightIndex refresh(List<WordHighlight> highlights) {
    final sig = WordHighlightIndex._signatureOf(highlights);
    if (sig != _current.signature) {
      _current = WordHighlightIndex.build(highlights);
    }
    return _current;
  }
}

class MemoizedBookmarkIndex {
  BookmarkIndex _current = BookmarkIndex.empty;

  BookmarkIndex refresh(List<HighlightVerse> bookmarks) {
    final sig = BookmarkIndex._signatureOf(bookmarks);
    if (sig != _current.signature) {
      _current = BookmarkIndex.build(bookmarks);
    }
    return _current;
  }
}
