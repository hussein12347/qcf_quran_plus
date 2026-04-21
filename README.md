# 🕌 qcf_quran_plus

[![Pub Version](https://img.shields.io/pub/v/qcf_quran_plus?color=blue&style=flat-square)](https://pub.dev/packages/qcf_quran_plus)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A **lightweight, high-performance Flutter Quran package** powered by the official **QCF (Hafs) font**.

Designed for professional Islamic applications, this package provides a fully offline, 60fps optimized Quran rendering engine complete with Uthmani Tajweed rules, smart search, and a comprehensive metadata API.

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

- **📖 Authentic Mushaf Rendering:** Full 604-page Quran with exact Madinah Mushaf layout.
- **⚡ High Performance:** Zero network requests, built for 60fps smooth scrolling, with an isolated font-loading engine.
- **🎨 Uthmani Tajweed Rules:** Native coloring for Tajweed in both Light & Dark modes without performance drops.
- **🔍 Smart Offline Search:** Fast, diacritic-insensitive Arabic search with automatic text normalization.
- **🎯 Dynamic Highlighting:** Pass a list of highlights to seamlessly integrate audio-syncing and bookmarks.
- **📜 Vertical Reading Mode:** Scrollable Surah lists ideal for Tafsir, translation, and audio players.
- **📊 Comprehensive Metadata:** Instant access to Surah names, Juz, Quarter (Rub al-Hizb), Makki/Madani info, and page lookups.

---

## 🚀 Getting Started

### 1. Add Dependencies

Update your `pubspec.yaml`:

```yaml
dependencies:
  qcf_quran_plus: ^latest_version
  scrollable_positioned_list: ^0.3.8
```

### 2. Import

```dart
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
```

---

## 🧩 Usage & Examples

### ⚙️ 1. App Startup Font Initialization (Required for Performance)
To eliminate any lag when rendering complex Othmanic text for the first time, initialize the fonts during your app's loading or splash screen.

```dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeFonts();
  }

  void _initializeFonts() async {
    await QcfFontLoader.setupFontsAtStartup(
      onProgress: (double progress) {
        print('Font Loading Progress: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );
    // Navigate to your main Quran screen once loaded...
  }
  
  // ... build method
}
```

### 📖 2. Authentic Mushaf Page Mode
Display the exact 604 pages of the Quran with customizable builders, Tajweed support, and smart headers.

```dart
final PageController _controller = PageController(initialPage: 0);
List<HighlightVerse> _activeHighlights = [];

QuranPageView(
  pageController: _controller,
  highlights: _activeHighlights,
  isDarkMode: Theme.of(context).brightness == Brightness.dark,
  isTajweed: true, // Enables Uthmani Tajweed colors
  onPageChanged: (pageNumber) {
    print("Navigated to page: $pageNumber");
  },
  onLongPress: (surahNumber, verseNumber, details) {
    // Show Tafsir, copy options, or add a bookmark
    print("Long pressed Surah: $surahNumber, Verse: $verseNumber");
  },
);
```

### 📜 3. Vertical Surah List Mode
Perfect for reading continuous Surahs, translating, or syncing with an audio player.

```dart
final ItemScrollController _itemScrollController = ItemScrollController();
List<HighlightVerse> _activeHighlights = [];

QuranSurahListView(
  surahNumber: 1, // Al-Fatihah
  itemScrollController: _itemScrollController,
  highlights: _activeHighlights,
  fontSize: 25,
  isTajweed: true,
  isDarkMode: Theme.of(context).brightness == Brightness.dark,
  // Fully customize how each Ayah looks!
  ayahBuilder: (context, surahNumber, verseNumber, pageNumber, ayahWidget, isHighlighted, highlightColor) {
    return Container(
      color: isHighlighted ? highlightColor.withOpacity(0.2) : Colors.transparent,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ayah $verseNumber (Page $pageNumber)', style: const TextStyle(color: Colors.grey)),
          ayahWidget, // The highly optimized QCF Text Widget pre-built by the package
        ],
      ),
    );
  },
);
```

### 🎯 4. Dynamic Ayah Highlighting
Change highlights dynamically to keep your audio-sync tracking smooth or to mark saved bookmarks.

```dart
// Highlight Ayatul Kursi (Surah 2, Ayah 255)
setState(() {
  _activeHighlights = [
    HighlightVerse(
      surah: 2,
      verseNumber: 255,
      page: 42,
      color: Colors.amber.withOpacity(0.4),
    ),
  ];
});

// Clear all highlights
// setState(() => _activeHighlights = []);
```

### 🔍 5. Smart Arabic Search
A fast, diacritic-insensitive search engine that normalizes Arabic text (Alef, Ya, Hamza).

```dart
// 1. Clean user input
String query = normalise("الرحمن");

// 2. Search (Returns occurrences and matches)
Map results = searchWords(query);

print("Matches found: ${results['occurences']}");

for (var match in results['result']) {
  int surah = match['sora'];
  int ayah = match['aya_no'];
  String cleanText = match['text'];

  print('${getSurahNameArabic(surah)} : $ayah => $cleanText');
}
```

### 📊 6. Core Metadata API & Helpers
Access comprehensive Quranic data instantly without parsing large JSON files.

```dart
// --- Surah Info ---
getSurahNameArabic(1);        // الفاتحة
getSurahNameEnglish(1);       // Al-Faatiha
getPlaceOfRevelation(1);      // Makkah
getVerseCount(1);             // 7

// --- Locations ---
getPageNumber(2, 255);        // 42
getJuzNumber(2, 255);         // 3
getQuarterNumber(2, 255);     // 19

// --- Text Formatting ---
String rawVerse = getVerse(2, 255);
String noTashkeel = removeDiacritics(rawVerse);
String verseEndSymbol = getAyaNoQCFLite(2, 255); // Returns optimized "۝" glyph
```

---

## ⚡ Performance Optimization Guide

To ensure your app runs at maximum performance:
1. **Font Preloading:** You **must** use `QcfFontLoader.setupFontsAtStartup` to cache fonts in memory before the user opens the Mushaf. Failing to do so will cause UI stuttering when the engine attempts to load 600+ font files on the fly.
2. **Ayah Rendering in Lists:** Use `getAyaNoQCFLite` when rendering lists of Ayahs to prevent stuttering. It contains an internal caching mechanism tailored for fast list scrolling.
3. **Widget State:** Use standard State Management (like `setState`, `Bloc`, or `Riverpod`) to update the `highlights` list passed to the package widgets. The package uses `RepaintBoundary` internally to ensure only necessary parts of the screen are redrawn.

---

## 👨‍💻 Built For

- Quran Reading & Memorization Apps
- Tafsir & Translation Apps
- Audio-Synced Quran Players

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

*Made with ❤️ for serious Islamic application developers.*