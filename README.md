# 🕌 qcf_quran_plus

[![Pub Version](https://img.shields.io/pub/v/qcf_quran_plus?color=blue&style=flat-square)](https://pub.dev/packages/qcf_quran_plus)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A **lightweight, high-performance Flutter Quran package** powered by the official **QCF (Hafs) font**.

Built for professional Quran, memorization, Tafsir, translation, audio, and Islamic applications, `qcf_quran_plus` provides a complete offline Quran rendering engine with:

- Authentic **604-page Mushaf rendering**
- **Single-page** and **two-page** layouts
- Native **QCF / Hafs** rendering
- **Uthmani Tajweed** colors
- **Light & Dark mode**
- **Ayah highlighting**
- **Word-level highlighting**
- Interactive **word tapping**
- **Long-press Ayah interactions**
- Scrollable **Surah List / Vertical Reader**
- Smart **Arabic search and normalization**
- Quran **page / Surah / Juz / Quarter / revelation metadata**
- Optimized font loading and page preloading
- Custom builders for **Surah headers, Basmallah, page headers, Ayah containers, top bars, and bottom bars**

---

## 📸 Screenshots

<p align="center">
  <img width="250" alt="Mushaf View" src="https://github.com/user-attachments/assets/482a0b7f-f048-4434-86af-c40e301dc503" />
  <img width="250" alt="Tajweed Support" src="https://github.com/user-attachments/assets/65dc7b33-e80e-4cd4-ac4e-8d80957ae654" />
</p>

<p align="center">
  <img width="250" alt="Surah List Mode" src="https://github.com/user-attachments/assets/5a4652cf-9b53-4521-991f-304afd91a6cd" />
  <img width="250" alt="Dark Mode" src="https://github.com/user-attachments/assets/da1d0f89-41e2-4e2e-8c21-6a50bece6786" />
</p>

<p align="center">
  <img width="250" alt="Search Engine" src="https://github.com/user-attachments/assets/4bac8673-06e8-4478-bf2f-55f331cd61f2" />
  <img width="250" alt="Metadata Details" src="https://github.com/user-attachments/assets/8caa32df-7168-48e3-8c1e-657710b6f5ad" />
</p>

---

## ✨ Key Features

### 📖 Authentic Mushaf Rendering

Render the complete Quran using the package's QCF data and page engine.

- 604 Mushaf pages
- 114 Surahs
- 6,236 Ayahs
- 30 Juz
- Exact page-based rendering through `QuranPageView`
- Dedicated handling for the first two Mushaf pages
- Automatic Surah headers
- Automatic Basmallah rendering
- RTL Quran rendering
- Page-aware QCF font selection

The package's page engine works from structured `QuranPage` data and pre-parsed line information rather than rebuilding the Quran text from scratch on every frame.

---

### ⚡ High Performance & Offline Rendering

`qcf_quran_plus` is designed for Quran applications where smooth rendering matters.

- Offline Quran data
- No network dependency for Quran rendering
- `QcfFontLoader` for startup font initialization
- Page font preloading around the current page
- Cached word/line offsets
- Parsed line caching
- `RepaintBoundary` around Quran pages
- Memoized indexes for Ayah and word highlights
- Optimized page construction for continuous swiping

For best results, initialize the fonts during your splash/loading phase before opening the Mushaf.

---

### 🎨 Uthmani Tajweed

Enable native Tajweed rendering through:

```dart
isTajweed: true,
```

The page renderer selects the appropriate QCF font for the requested page and supports:

- Tajweed colors in Light mode
- Tajweed colors in Dark mode
- Non-Tajweed rendering when disabled
- Page-specific font selection
- Dark-mode-aware Quran text rendering

---

### 🌙 Light & Dark Mode

Both Quran widgets support dark mode.

```dart
isDarkMode: Theme.of(context).brightness == Brightness.dark,
```

For the Mushaf page renderer, the package internally builds its QCF text style from the page number, Tajweed setting, and dark-mode setting.

> **Important:** Avoid overriding `ayahStyle` unless you intentionally want to replace the package's default QCF style selection.

---

### 🎯 Dynamic Ayah Highlighting

Use `HighlightVerse` to highlight any Ayah dynamically.

This is useful for:

- Audio synchronization
- Memorization sessions
- Bookmarks
- Active recitation
- Search results
- Tafsir navigation
- Temporary selection states

```dart
List<HighlightVerse> _activeHighlights = [];

setState(() {
  _activeHighlights = [
    HighlightVerse(
      surah: 2,
      verseNumber: 255,
      page: 42,
      color: Colors.amber.withValues(alpha: 0.4),
    ),
  ];
});
```

Clear the highlights:

```dart
setState(() {
  _activeHighlights = [];
});
```

The package indexes the supplied highlights internally so the Quran lines can determine which Ayahs are active without repeatedly scanning the whole list.

---

### 🖍️ Word-Level Highlighting

The package also supports `WordHighlight` for highlighting individual words inside an Ayah.

You can control:

- `textColor`
- `backgroundColor`
- Surah
- Ayah
- Word index

Example:

```dart
final wordHighlights = <WordHighlight>[
  WordHighlight(
    surah: 2,
    verseNumber: 255,
    wordIndex: 3,
    textColor: Colors.white,
    backgroundColor: Colors.amber,
  ),
];
```

Pass the list directly to the page or Surah reader:

```dart
QuranPageView(
  pageController: controller,
  highlights: _activeHighlights,
  wordHighlights: wordHighlights,
  isDarkMode: isDark,
  isTajweed: true,
);
```

Word highlights are especially useful for:

- Word-by-word recitation tracking
- Quran teaching tools
- Pronunciation feedback
- Memorization assistants
- Vocabulary applications
- Audio word synchronization

---

### 👆 Word Interaction

`QuranPageView` and `QuranSurahListView` expose `onWordTap`:

```dart
QuranPageView(
  pageController: controller,
  highlights: _activeHighlights,
  onWordTap: (surahNumber, verseNumber, wordIndex, word) {
    debugPrint(
      'Surah: $surahNumber | Ayah: $verseNumber | Word: $wordIndex | $word',
    );
  },
  isDarkMode: false,
  isTajweed: true,
);
```

This gives you the exact:

- Surah number
- Ayah number
- Word index
- Raw logical word

---

### 🤲 Long-Press Ayah Interaction

Both Quran rendering modes support Ayah long press.

```dart
QuranPageView(
  pageController: controller,
  highlights: _activeHighlights,
  onLongPress: (surahNumber, verseNumber, details) {
    debugPrint(
      'Long pressed Surah $surahNumber, Ayah $verseNumber',
    );

    final position = details.globalPosition;

    // Show your own menu, bottom sheet, popup, tafsir dialog, etc.
    debugPrint('Pressed at: $position');
  },
  isDarkMode: false,
);
```

The callback gives you `LongPressStartDetails`, allowing you to build context menus relative to the exact press location.

Typical use cases:

- Copy Ayah
- Add bookmark
- Show Tafsir
- Start audio
- Share Ayah
- Start memorization
- Open translation

---

## 📖 Mushaf Page Mode

Use `QuranPageView` when you need an authentic page-based Quran experience.

```dart
final PageController _controller = PageController(initialPage: 0);

List<HighlightVerse> _activeHighlights = [];

QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: Theme.of(context).brightness == Brightness.dark,
  isTajweed: true,
  enableTwoPageLayout: true,

  onPageChanged: (pageNumber) {
    debugPrint('Navigated to page: $pageNumber');
  },

  onLongPress: (surahNumber, verseNumber, details) {
    debugPrint(
      'Long pressed Surah $surahNumber, Verse $verseNumber',
    );
  },
);
```

### Single Page

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  isTajweed: true,
  enableTwoPageLayout: false,
);
```

### Two-Page Layout

On wide screens, the package can render two Mushaf pages side-by-side:

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  isTajweed: true,
  enableTwoPageLayout: true,
);
```

The widget keeps the two-page controller synchronized with the external `PageController`.

---

## 🧩 Mushaf Customization

`QuranPageView` supports custom builders for integrating Quran pages into your own application UI.

### Top Bar

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  topBar: const SizedBox(
    height: 50,
    child: Center(
      child: Text('Quran'),
    ),
  ),
);
```

### Bottom Bar

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  bottomBar: const SizedBox(
    height: 60,
    child: Center(
      child: Text('Player'),
    ),
  ),
);
```

### Page Header

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  pageHeaderBuilder: (context, pageNumber) {
    return Text('Page $pageNumber');
  },
);
```

### Custom Surah Header

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  surahHeaderBuilder: (context, surahNumber) {
    return Text(
      getSurahNameArabic(surahNumber),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  },
);
```

### Custom Basmallah

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  basmallahBuilder: (context, surahNumber) {
    return const Text(
      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    );
  },
);
```

### Custom Text Style

`ayahStyle` is available when you intentionally want to override the package's default Quran text style:

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  ayahStyle: const TextStyle(
    fontSize: 42,
  ),
);
```

Because `ayahStyle` overrides the default QCF style, use it carefully when relying on page-specific QCF font selection.

### Background

```dart
QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: false,
  pageBackgroundColor: const Color(0xFFFBF6EE),
);
```

---

## 📜 Vertical Surah List Mode

Use `QuranSurahListView` for continuous Surah reading.

This mode is especially useful for:

- Tafsir
- Translation
- Audio players
- Memorization
- Word-level interactions
- Custom Ayah cards
- Teaching interfaces

```dart
final ItemScrollController _itemScrollController =
    ItemScrollController();

final List<HighlightVerse> _highlights = [];

QuranSurahListView(
  surahNumber: 1,
  itemScrollController: _itemScrollController,
  highlights: _highlights,
  fontSize: 25,
  isTajweed: true,
  isDarkMode: Theme.of(context).brightness == Brightness.dark,
);
```

---

## 🎨 Fully Customizable Ayah Cards

`QuranSurahListView` exposes `ayahBuilder` with all important Ayah information.

```dart
QuranSurahListView(
  surahNumber: 2,
  highlights: _highlights,
  fontSize: 25,
  isTajweed: true,
  isDarkMode: false,
  ayahBuilder: (
    context,
    surahNumber,
    verseNumber,
    pageNumber,
    ayahWidget,
    isHighlighted,
    highlightColor,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? highlightColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ayah $verseNumber • Page $pageNumber',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ayahWidget,
        ],
      ),
    );
  },
);
```

The builder receives:

```text
BuildContext
surahNumber
verseNumber
pageNumber
ayahWidget
isHighlighted
highlightColor
```

This lets you build your own:

- Audio controls
- Bookmark buttons
- Translation containers
- Tafsir cards
- Recitation feedback
- Memorization UI
- Ayah statistics

---

## 🔎 Smart Offline Arabic Search

The package includes a lightweight Quran search engine.

### Normalize User Input

```dart
final query = normalise('الرحمن');
```

### Search

```dart
final results = searchWords(query);

debugPrint(
  'Matches: ${results['occurences']}',
);

for (final match in results['result']) {
  final surah = match['sora'];
  final ayah = match['aya_no'];
  final text = match['text'];

  debugPrint(
    '${getSurahNameArabic(surah)} : $ayah => $text',
  );
}
```

The search engine supports:

- Diacritic-insensitive matching
- Arabic normalization
- Alef normalization
- Ya normalization
- Hamza/Alef variants normalization
- Whitespace normalization
- Search without depending on network requests
- Emlaey search first
- Othmanic fallback when no Emlaey match exists
- Configurable result limit

Example:

```dart
final results = searchWords(
  'وتلك حدود',
  limit: 20,
);
```

The search logic can match phrases after removing spaces and standardizing Arabic forms.

---

## 🧹 Text Normalization Helpers

### `normalise`

General Quran-oriented normalization:

```dart
final cleaned = normalise(text);
```

It removes Quranic annotation characters and common Arabic variants before comparison.

### `normalizeArabicText`

The package also exposes:

```dart
final cleaned = normalizeArabicText(text);
```

This normalization removes basic Arabic diacritics and standardizes selected Arabic letter forms.

### `removeDiacritics`

For lightweight diacritic removal:

```dart
final cleaned = removeDiacritics(text);
```

This is useful for:

- Search
- Comparison
- Matching user input
- Simplified text processing

---

## 📊 Quran Statistics & Constants

The package exposes common Quran constants:

```dart
totalPagesCount;   // 604
totalSurahCount;   // 114
totalVerseCount;   // 6236
totalJuzCount;     // 30

totalMakkiSurahs;  // 89
totalMadaniSurahs; // 25
```

---

## 🧭 Page & Surah Metadata

### Get Page Data

```dart
final data = getPageData(42);
```

### Surah Count on a Page

```dart
final count = getSurahCountByPage(42);
```

### Ayah Count on a Page

```dart
final count = getVerseCountByPage(42);
```

### Get Surah Names

```dart
getSurahName(1);        // Transliteration/name
getSurahNameEnglish(1); // English
getSurahNameArabic(1);  // Arabic
```

### Revelation Place

```dart
getPlaceOfRevelation(1); // Makkah or Madinah
```

### Verse Count

```dart
getVerseCount(1); // Number of Ayahs in the Surah
```

---

## 📍 Quran Location Helpers

### Find the Page of an Ayah

```dart
final page = getPageNumber(2, 255);
```

### Find the Juz

```dart
final juz = getJuzNumber(2, 255);
```

### Find the Quarter

```dart
final quarter = getQuarterNumber(2, 255);
```

These helpers make it easy to build:

- Ayah details dialogs
- Audio players
- Bookmarks
- Search result navigation
- Memorization navigation
- Tafsir navigation

---

## 🕌 Hizb & Quarter Helpers

### Show Only When a New Quarter Starts on the Page

```dart
final text = getHizbTextByPage(
  42,
  isArabic: true,
);
```

Returns an empty string when no new quarter starts exactly on that page.

### Get the Current Hizb/Quarter for a Page

```dart
final text = getCurrentHizbTextForPage(
  42,
  isArabic: true,
);
```

Unlike the exact-page helper, this also resolves the currently active quarter when it started on a previous page.

English output is available:

```dart
getCurrentHizbTextForPage(
  42,
  isArabic: false,
);
```

---

## 📖 Verse Text Helpers

### Get Verse Text

```dart
final verse = getVerse(2, 255);
```

### Get Verse-End Symbol

```dart
final symbol = getVerseEndSymbol(
  255,
  arabicNumeral: true,
);
```

### Get the QCF Ayah Glyph

```dart
final glyph = getAyaNoQCFLite(
  2,
  255,
);
```

### Cached QCF Ayah Glyph Lookup

```dart
final glyph = getaya_noQCF(
  2,
  255,
);
```

`getaya_noQCF` keeps an internal cache so repeated Ayah-ending glyph lookups do not repeatedly scan the Quran dataset.

---

## 🚀 Font Initialization

For the smoothest first render, initialize QCF fonts before entering the Quran screen.

```dart
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeFonts();
  }

  Future<void> _initializeFonts() async {
    await QcfFontLoader.setupFontsAtStartup(
      onProgress: (progress) {
        debugPrint(
          'Font loading: ${(progress * 100).toStringAsFixed(1)}%',
        );
      },
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const QuranScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

The font loader exposes page preloading as well:

```dart
QcfFontLoader.preloadPages(
  42,
  radius: 3,
);
```

You can use this when changing pages or building your own advanced Quran navigation flow.

---

## 📦 Installation

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  qcf_quran_plus: ^latest_version
  scrollable_positioned_list: ^0.3.8
```

Then:

```bash
flutter pub get
```

Import:

```dart
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
```

---

## 🧩 Public API Overview

### Widgets

```dart
QuranPageView
QuranSurahListView
```

### Models

```dart
HighlightVerse
WordHighlight
Ayah
QuranPage
Surah
```

### Quran Data

```dart
quran
pageData
suwar
juz
quarters
```

### Utilities

```dart
QuranTextStyles
QcfFontLoader
```

### Search & Normalization

```dart
searchWords
normalise
normalizeArabicText
removeDiacritics
```

### Metadata

```dart
getPageData
getSurahCountByPage
getVerseCountByPage
getSurahName
getSurahNameEnglish
getSurahNameArabic
getPlaceOfRevelation
getVerseCount
getPageNumber
getJuzNumber
getQuarterNumber
getHizbTextByPage
getCurrentHizbTextForPage
```

### Verse Helpers

```dart
getVerse
getVerseEndSymbol
getAyaNoQCFLite
getaya_noQCF
```

---

## 🏗️ Typical Application Architecture

`qcf_quran_plus` is designed to fit into common Flutter architectures.

You can keep Quran UI state in:

- `setState`
- `Bloc / Cubit`
- `Provider`
- `Riverpod`
- Any other state-management solution

For example:

```dart
class QuranController extends ChangeNotifier {
  List<HighlightVerse> highlights = [];

  void highlightAyah({
    required int surah,
    required int ayah,
    required int page,
    required Color color,
  }) {
    highlights = [
      ...highlights,
      HighlightVerse(
        surah: surah,
        verseNumber: ayah,
        page: page,
        color: color,
      ),
    ];

    notifyListeners();
  }
}
```

Then pass the current state directly to the Quran widget.

---

## ⚡ Performance Recommendations

### 1. Initialize Fonts Early

Use:

```dart
QcfFontLoader.setupFontsAtStartup(...)
```

during splash/loading.


when implementing custom navigation or page tracking.

### 3. Keep Highlight State External

Store `HighlightVerse` and `WordHighlight` in your application state and update them as needed.

### 4. Let the Package Control QCF Styling

For authentic Mushaf rendering, prefer:

```dart
isTajweed: true,
isDarkMode: isDark,
```

without replacing `ayahStyle` unless you specifically need a custom text style.

### 5. Use `getaya_noQCF` for Repeated Glyph Lookups

Its internal cache is useful when rendering large Ayah lists.

---

## 🧱 Built For

`qcf_quran_plus` is suitable for:

- 📖 Quran reading applications
- 🧠 Quran memorization applications
- 🎧 Audio-synced Quran players
- 🗣️ Recitation and pronunciation tools
- 🎨 Tajweed learning interfaces
- 🔍 Quran search applications
- 📚 Tafsir applications
- 🌍 Quran translation interfaces
- 📊 Quran statistics and metadata screens
- 🕌 Islamic educational applications

---

## 📄 License

Distributed under the **MIT License**.

See `LICENSE` for more information.

---

## ❤️ Made for Serious Quran Applications

`qcf_quran_plus` combines an authentic page-based Mushaf renderer with a flexible vertical reader, interactive Ayah and word highlighting, offline Arabic search, metadata helpers, and a performance-oriented QCF font engine.

Built with Flutter for developers who want to focus on their Quran application instead of rebuilding the Quran rendering layer from scratch.
