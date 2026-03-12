# 🕌 qcf_quran_plus

[![Pub Version](https://img.shields.io/pub/v/qcf_quran_plus?color=blue&style=flat-square)](https://pub.dev/packages/qcf_quran_plus)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A **lightweight, high-performance Flutter Quran package** powered by the official **QCF (Hafs) font**.

Designed for professional Islamic applications, this package provides a fully offline, 60fps optimized Quran rendering engine complete with Uthmani Tajweed rules, smart search, and a comprehensive metadata API.

---

## 📸 Screenshots

<p align="center">
  <img width="250" alt="Screenshot_20260310_231226" src="https://github.com/user-attachments/assets/482a0b7f-f048-4434-86af-c40e301dc503" />
  <img width="250" alt="Screenshot_20260310_231212" src="https://github.com/user-attachments/assets/65dc7b33-e80e-4cd4-ac4e-8d80957ae654" />
</p>

<p align="center">
  <img width="250" alt="Screenshot_20260310_230854" src="https://github.com/user-attachments/assets/5a4652cf-9b53-4521-991f-304afd91a6cd" />
  <img width="250" alt="Screenshot_20260310_230445" src="https://github.com/user-attachments/assets/da1d0f89-41e2-4e2e-8c21-6a50bece6786" />
</p>

<p align="center">
  <img width="250" alt="Screenshot_20260310_230424" src="https://github.com/user-attachments/assets/4bac8673-06e8-4478-bf2f-55f331cd61f2" />
  <img width="250" alt="Screenshot_20260310_230313" src="https://github.com/user-attachments/assets/8caa32df-7168-48e3-8c1e-657710b6f5ad" />
</p>

---

## ✨ Key Features

- **📖 Authentic Mushaf Rendering:** Full 604-page Quran with exact Madinah Mushaf layout.
- **⚡ High Performance:** Zero network requests, built for 60fps smooth scrolling, and memory-optimized.
- **🎨 Uthmani Tajweed Rules:** Native coloring for Tajweed in both Light & Dark modes without performance drops.
- **🔍 Smart Offline Search:** Fast, diacritic-insensitive Arabic search with automatic text normalization.
- **🎯 Reactive Highlighting:** Perfect for audio-sync and bookmarks using `ValueNotifier` (no full UI rebuilds).
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

### ⚙️ 1. App Startup Font Initialization
To eliminate any lag when rendering complex Othmanic text for the first time, initialize the fonts during your app's loading/splash screen.

```dart
void _initializeFonts() async {
  await QcfFontLoader.setupFontsAtStartup(
    onProgress: (double progress) {
      print('Font Loading Progress: ${(progress * 100).toStringAsFixed(1)}%');
    },
  );
  // Continue to Main App...
}
```

### 📖 2. Authentic Mushaf Page Mode
Display the exact 604 pages of the Quran with customizable builders, Tajweed support, and smart headers.

```dart
final PageController _controller = PageController(initialPage: 0);
final ValueNotifier<List<HighlightVerse>> _highlights = ValueNotifier([]);

QuranPageView(
pageController: _controller,
scaffoldKey: GlobalKey<ScaffoldState>(),
highlightsNotifier: _highlights,
isDarkMode: false,
isTajweed: true, // Enables Uthmani Tajweed colors
onPageChanged: (pageNumber) {
print(getCurrentHizbTextForPage(pageNumber)); // e.g., "نصف الحزب ١"
},
onLongPress: (surahNumber, verseNumber, details) {
// Show Tafsir or Ayah options bottom sheet
},
);
```

### 📜 3. Vertical Surah List Mode
Perfect for reading continuous Surahs, translating, or syncing with an audio player.

```dart
final ItemScrollController _itemScrollController = ItemScrollController();

QuranSurahListView(
surahNumber: 1, // Al-Fatihah
itemScrollController: _itemScrollController,
highlightsNotifier: _highlights,
fontSize: 25,
isTajweed: true,
isDarkMode: Theme.of(context).brightness == Brightness.dark,
ayahBuilder: (context, surahNumber, verseNumber, pageNumber, othmanicText, isHighlighted, highlightColor) {
// Fully customize how each Ayah looks!
return Container(
color: isHighlighted ? highlightColor.withOpacity(0.2) : Colors.transparent,
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Text('Ayah $verseNumber', style: TextStyle(color: Colors.grey)),
othmanicText, // The highly optimized QCF Text Widget
],
),
);
},
);
```

### 🎯 4. Real-time Highlighting (Audio Sync)
Change highlights instantly without calling `setState()` to keep your app extremely fast.

```dart
// Highlight Ayatul Kursi (Surah 2, Ayah 255)
_highlights.value = [
HighlightVerse(
surah: 2,
verseNumber: 255,
page: 42,
color: Colors.amber.withOpacity(0.4),
),
];

// Clear all highlights
// _highlights.value = [];
```

### 🔍 5. Smart Arabic Search
A fast, diacritic-insensitive search engine that normalizes Arabic text (Alef, Ya, Hamza).

```dart
// 1. Clean user input
String query = normalise("الرحمن");

// 2. Search (Max 50 results)
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
Access comprehensive Quranic data instantly.

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
String verseEndSymbol = getaya_noQCF(2, 255); // Returns optimized "۝" glyph
```

---

## ⚡ Performance Optimization Guide

To ensure your app runs at maximum performance:
1. **Font Preloading:** Always use `QcfFontLoader.setupFontsAtStartup` to cache fonts in memory before the user opens the Mushaf.
2. **Ayah Rendering in Lists:** `getaya_noQCF` has an internal caching mechanism. Always use it instead of `getAyaNoQCFLite` when rendering lists of Ayahs to prevent stuttering.
3. **Audio Syncing:** When syncing highlights with audio players, **do not** use `setState`. Rely completely on the `highlightsNotifier` passed to the widgets.

---

## 👨‍💻 Built For

- Quran Reading & Memorization Apps
- Tafsir & Translation Apps
- Audio-Synced Quran Players

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

*Made with ❤️ for serious Islamic application developers.*
