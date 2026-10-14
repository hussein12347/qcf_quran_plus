/// A lightweight, high-performance, and professional Flutter package to display the Holy Quran.
///
/// This library provides customizable widgets (`QuranPageView`) and comprehensive
/// data models/helpers to render Quranic pages using the official QCF font.
/// It includes built-in functions for searching, statistics, and metadata retrieval.
library;

import 'package:qcf_quran_plus/src/data/juzs.dart';
import 'package:qcf_quran_plus/src/data/page_data.dart';
import 'package:qcf_quran_plus/src/data/quarters.dart';
import 'package:qcf_quran_plus/src/data/quran_data.dart';
import 'package:qcf_quran_plus/src/data/suwar.dart';

// ---------------------------------------------------------------------------
// 1. UI Widgets Exports
// ---------------------------------------------------------------------------
export 'src/widgets/quran_page_view.dart';
export 'src/widgets/quran_surah_list_view.dart';
export 'src/utils/quran_text_styles.dart';
export 'src/widgets/surah_header_widget.dart';
export 'src/utils/font_loader_service.dart';

// ---------------------------------------------------------------------------
// 2. Models Exports
// ---------------------------------------------------------------------------
export 'src/models/highlight_verse.dart';
export 'src/models/ayah.dart';
export 'src/models/quran_page.dart';
export 'src/models/surah.dart';
export 'src/models/highlight_word.dart';
export 'src/data/quarters.dart';
export 'src/data/juzs.dart';
export 'src/data/page_data.dart';
export 'src/data/suwar.dart';

// ---------------------------------------------------------------------------
// 3. Quran Data Helper Functions
// ---------------------------------------------------------------------------

/// The most standard and common copy of Arabic only Quran total pages count.
const int totalPagesCount = 604;

/// The constant total number of Makki surahs.
const int totalMakkiSurahs = 89;

/// The constant total number of Madani surahs.
const int totalMadaniSurahs = 25;

/// The constant total Juz count in the Holy Quran.
const int totalJuzCount = 30;

/// The constant total Surah count in the Holy Quran.
const int totalSurahCount = 114;

/// The constant total verse (Ayah) count in the Holy Quran.
const int totalVerseCount = 6236;

/// Retrieves the raw page data mapping for a specific [pageNumber].
///
/// Throws an exception if the [pageNumber] is out of valid bounds (1-604).
List getPageData(int pageNumber) {
  // Validate that the requested page is within the supported Quran page range.
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }

  // Convert the one-based page number into a zero-based list index.
  return pageData[pageNumber - 1];
}

/// Returns the total number of Surahs present on a specific [pageNumber].
int getSurahCountByPage(int pageNumber) {
  // Ensure the page number is valid before accessing page data.
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }

  // Each item in the page data list represents one Surah section on the page.
  return pageData[pageNumber - 1].length;
}

/// Returns the total number of verses (Ayahs) present on a specific [pageNumber].
int getVerseCountByPage(int pageNumber) {
  // Validate the requested page before reading its verse ranges.
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }

  int totalVerseCount = 0;

  // Sum the verse ranges for every Surah section that appears on the page.
  for (int i = 0; i < pageData[pageNumber - 1].length; i++) {
    totalVerseCount += int.parse(
      pageData[pageNumber - 1][i]!["end"].toString(),
    );
  }

  return totalVerseCount;
}

/// Converts an integer to an Arabic numeral string.
String _convertToArabicNumber(int number) {
  // Mapping from Western digits to Arabic-Indic digits.
  const Map<String, String> arabicNumbers = {
    "0": "٠",
    "1": "١",
    "2": "٢",
    "3": "٣",
    "4": "٤",
    "5": "٥",
    "6": "٦",
    "7": "٧",
    "8": "٨",
    "9": "٩",
  };

  // Convert every digit individually, then join the result back into a string.
  return number.toString().split('').map((e) => arabicNumbers[e] ?? e).join('');
}

/// Returns the Hizb/Quarter text ONLY if a new quarter starts exactly on this [pageNumber].
///
/// If no quarter starts on this page, it returns an empty string.
/// Pass [isArabic] as `true` (default) for Arabic text, or `false` for English.
String getHizbTextByPage(int pageNumber, {bool isArabic = true}) {
  // Find the index of the quarter that starts exactly on the requested page.
  int quarterIndex = quarters.indexWhere(
    (q) => getPageNumber(q['surah']!, q['ayah']!) == pageNumber,
  );

  final bool showHizbText = quarterIndex != -1;

  // No quarter begins on this page, so there is no Hizb label to show.
  if (!showHizbText) return "";

  int quarter = quarterIndex + 1;
  int hizb = ((quarter - 1) ~/ 4) + 1;
  int quarterInHizb = ((quarter - 1) % 4) + 1;

  String hizbNumber = isArabic ? _convertToArabicNumber(hizb) : hizb.toString();

  // Build the localized Hizb label based on the quarter position inside the Hizb.
  if (isArabic) {
    if (quarterInHizb == 1) return "الحزب $hizbNumber";
    if (quarterInHizb == 2) return "ربع الحزب $hizbNumber";
    if (quarterInHizb == 3) return "نصف الحزب $hizbNumber";
    if (quarterInHizb == 4) return "ثلاثة أرباع الحزب $hizbNumber";
  } else {
    if (quarterInHizb == 1) return "Hizb $hizbNumber";
    if (quarterInHizb == 2) return "1/4 Hizb $hizbNumber";
    if (quarterInHizb == 3) return "1/2 Hizb $hizbNumber";
    if (quarterInHizb == 4) return "3/4 Hizb $hizbNumber";
  }

  return "";
}

/// Returns the current active Hizb/Quarter text for the top of the given [pageNumber].
///
/// This applies even if the quarter started on a previous page.
String getCurrentHizbTextForPage(int pageNumber, {bool isArabic = true}) {
  int currentQuarterIndex = 0;

  // Track the latest quarter that begins on or before the requested page.
  for (int i = 0; i < quarters.length; i++) {
    int qPage = getPageNumber(quarters[i]['surah']!, quarters[i]['ayah']!);

    if (pageNumber >= qPage) {
      currentQuarterIndex = i;
    } else {
      break;
    }
  }

  int quarter = currentQuarterIndex + 1;
  int hizb = ((quarter - 1) ~/ 4) + 1;
  int quarterInHizb = ((quarter - 1) % 4) + 1;

  String hizbNumber = isArabic ? _convertToArabicNumber(hizb) : hizb.toString();

  // Build the localized Hizb label based on the quarter position inside the Hizb.
  if (isArabic) {
    if (quarterInHizb == 1) return "الحزب $hizbNumber";
    if (quarterInHizb == 2) return "ربع الحزب $hizbNumber";
    if (quarterInHizb == 3) return "نصف الحزب $hizbNumber";
    if (quarterInHizb == 4) return "ثلاثة أرباع الحزب $hizbNumber";
  } else {
    if (quarterInHizb == 1) return "Hizb $hizbNumber";
    if (quarterInHizb == 2) return "1/4 Hizb $hizbNumber";
    if (quarterInHizb == 3) return "1/2 Hizb $hizbNumber";
    if (quarterInHizb == 4) return "3/4 Hizb $hizbNumber";
  }

  return "";
}

/// Returns the Quarter (Rub el Hizb) number (1-240) based on the [surahNumber] and [ayaNo].
int getQuarterNumber(int surahNumber, int ayaNo) {
  int currentQuarter = 1;

  // Iterate through quarter boundaries and keep the latest boundary reached.
  for (int i = 0; i < quarters.length; i++) {
    int qSurah = quarters[i]["surah"]!;
    int qAyah = quarters[i]["ayah"]!;

    if (surahNumber > qSurah || (surahNumber == qSurah && ayaNo >= qAyah)) {
      currentQuarter = i + 1;
    } else {
      break;
    }
  }

  return currentQuarter;
}

/// Returns the Juz number (1-30) for a specific [surahNumber] and [ayaNo].
int getJuzNumber(int surahNumber, int ayaNo) {
  // Search each Juz definition for a verse range containing the target ayah.
  for (var juz in juz) {
    if (juz["verses"].keys.contains(surahNumber)) {
      if (ayaNo >= juz["verses"][surahNumber][0] &&
          ayaNo <= juz["verses"][surahNumber][1]) {
        return int.parse(juz["id"].toString());
      }
    }
  }

  // Return -1 when the verse cannot be mapped to a Juz.
  return -1;
}

/// Returns the Surah name in transliterated format for a given [surahNumber].
String getSurahName(int surahNumber) {
  // Validate the Surah number before accessing the Surah list.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  return surah[surahNumber - 1]['name'].toString();
}

/// Returns the translated Surah name in English for a given [surahNumber].
String getSurahNameEnglish(int surahNumber) {
  // Validate the Surah number before accessing the Surah list.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  return surah[surahNumber - 1]['english'].toString();
}

/// Returns the Surah name in Arabic for a given [surahNumber].
String getSurahNameArabic(int surahNumber) {
  // Validate the Surah number before accessing the Surah list.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  return surah[surahNumber - 1]['arabic'].toString();
}

/// Returns the page number (1-604) of the Quran where the specific [surahNumber] and [ayaNo] is located.
int getPageNumber(int surahNumber, int ayaNo) {
  // Validate the Surah number before scanning the page data.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  // Scan all pages and Surah ranges to find the page containing the ayah.
  for (int pageIndex = 0; pageIndex < pageData.length; pageIndex++) {
    for (
      int surahIndexInPage = 0;
      surahIndexInPage < pageData[pageIndex].length;
      surahIndexInPage++
    ) {
      final e = pageData[pageIndex][surahIndexInPage];

      if (e['surah'] == surahNumber &&
          e['start'] <= ayaNo &&
          e['end'] >= ayaNo) {
        return pageIndex + 1;
      }
    }
  }

  throw "Invalid verse number.";
}

/// Returns the place of revelation ('Makkah' or 'Madinah') for a given [surahNumber].
String getPlaceOfRevelation(int surahNumber) {
  // Validate the Surah number before accessing the Surah list.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  return surah[surahNumber - 1]['place'].toString();
}

/// Returns the total count of verses in a specific [surahNumber].
int getVerseCount(int surahNumber) {
  // Validate the Surah number before accessing the Surah list.
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No verse found with given surahNumber";
  }

  return int.parse(surah[surahNumber - 1]['aya'].toString());
}

/// Returns the Arabic text of a specific verse based on [surahNumber] and [ayaNo].
///
/// Set [verseEndSymbol] to `true` if you want the Ayah number symbol appended to the text.
String getVerse(int surahNumber, int ayaNo, {bool verseEndSymbol = false}) {
  String verse = "";

  // Look up the verse in the Quran dataset.
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == ayaNo) {
      verse = i['aya_text'].toString();
      break;
    }
  }

  // Throw when the requested verse does not exist in the dataset.
  if (verse == "") {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  // Remove the sajdah marker from the plain verse text.
  return verse.replaceAll('۩', '');
}

/// Returns the ornate end-of-verse symbol ('۝') enclosing the [ayaNo].
///
/// Set [arabicNumeral] to `false` to use standard western numerals instead of Arabic numerals.
String getVerseEndSymbol(int ayaNo, {bool arabicNumeral = true}) {
  var arabicNumeric = '';
  var digits = ayaNo.toString().split("").toList();

  // If Western numerals are requested, return the end-of-ayah marker directly.
  if (!arabicNumeral) return '\u06dd${ayaNo.toString()}';

  // Mapping used to render Arabic-Indic numerals.
  const Map arabicNumbers = {
    "0": "٠",
    "1": "۱",
    "2": "۲",
    "3": "۳",
    "4": "٤",
    "5": "٥",
    "6": "٦",
    "7": "۷",
    "8": "۸",
    "9": "۹",
  };

  // Convert each digit of the ayah number into its Arabic numeral form.
  for (var e in digits) {
    arabicNumeric += arabicNumbers[e];
  }

  return arabicNumeric;
}

/// Returns the specific QCF font glyph representing the [ayaNo] for rendering purposes.
String getAyaNoQCFLite(
  int surahNumber,
  int ayaNo, {
  bool verseEndSymbol = true,
}) {
  String glyph = "";

  // Search for the target verse and extract its final QCF glyph.
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == ayaNo) {
      final String qcfData = i['aya_text_othmanic'].toString();

      final bool endsWithNewline = qcfData.endsWith('\n');

      // If the text ends with a newline, take the glyph before the newline.
      // Otherwise, take the final character in the string.
      glyph = endsWithNewline
          ? qcfData.substring(qcfData.length - 2, qcfData.length - 1)
          : qcfData.substring(qcfData.length - 1);
      break;
    }
  }

  // Throw when the requested verse or QCF glyph cannot be found.
  if (glyph == "") {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  return glyph;
}

/// In-memory cache used to avoid repeatedly scanning the Quran dataset for
/// the same verse glyph. The key format is `surahNumber_ayaNo`.
final Map<String, String> _verseGlyphCache = {};

/// A very fast helper that returns the ayah number glyph from the `qcfData` field.
///
/// Results are cached in [_verseGlyphCache] so each verse is scanned at most once
/// during the application lifetime. This prevents repeated lookups from causing lag.
String getAyaNoQCF(int surahNumber, int ayaNo) {
  // Build a unique cache key for the requested verse.
  final key = '${surahNumber}_$ayaNo';

  // Return the cached glyph immediately when available.
  if (_verseGlyphCache.containsKey(key)) {
    return _verseGlyphCache[key]!;
  }

  String glyph = "";

  // This lookup runs only once per verse for the entire application.
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == ayaNo) {
      // Use the `qcfData` field exactly as provided by the JSON dataset.
      final String qcfData = i['qcfData'].toString().trim();

      // The glyph is always the final character after trimming whitespace/newlines.
      if (qcfData.isNotEmpty) {
        glyph = qcfData.substring(qcfData.length - 1);
      }
      break;
    }
  }

  // Throw when the requested verse or QCF glyph cannot be found.
  if (glyph.isEmpty) {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  // Store the glyph in memory to speed up future lookups.
  _verseGlyphCache[key] = glyph;

  return glyph;
}

/// Normalizes Arabic text for search and comparison.
///
/// This removes diacritics, unifies alif variants, unifies ya forms, unifies
/// ta marbuta, and collapses repeated whitespace.
String normalizeArabicText(String text) {
  if (text.isEmpty) return text;

  // Remove Arabic diacritics (tashkeel).
  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

  // Unify alif variants.
  text = text.replaceAll(RegExp(r'[إأآا]'), 'ا');

  // Unify ya variants.
  text = text.replaceAll(RegExp(r'[يى]'), 'ي');

  // Unify ta marbuta.
  text = text.replaceAll('ة', 'ه');

  // Collapse repeated whitespace and trim leading/trailing spaces.
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  return text;
}

// ============================================================
// Search
// ============================================================

/// Searches the Quran text for the specified [query].
///
/// Returns a [Map] containing:
/// - `occurences`: The total number of matches found.
/// - `result`: A [List] of [Map]s containing the `sora` and `aya_no` of the matches.
///
/// The search first checks the `aya_text_emlaey` field. If no results are found,
/// it falls back to searching the `aya_text` field.
Map<String, dynamic> searchWords(String query, {int limit = 50}) {
  // Return an empty result for blank queries.
  if (query.trim().isEmpty) {
    return {"occurences": 0, "result": []};
  }

  final List<Map<String, dynamic>> result = [];

  // Normalize the query by removing diacritics and unifying letters.
  final String normalizedQuery = normalizeArabicText(query.toLowerCase());

  if (normalizedQuery.isEmpty) {
    return {"occurences": 0, "result": []};
  }

  // ------------------------------------------------------------
  // Whitespace-free search version
  // ------------------------------------------------------------
  //
  // Example:
  //
  // "wa tilka hudood"
  //
  // becomes:
  //
  // "watilkahudood"
  //
  final String searchQuery = normalizedQuery.replaceAll(RegExp(r'\s+'), '');

  if (searchQuery.isEmpty) {
    return {"occurences": 0, "result": []};
  }

  // ============================================================
  // Match checker
  // ============================================================

  /// Returns `true` when [text] contains the normalized, whitespace-free query.
  bool containsSearchQuery(String text) {
    final String normalizedText = normalizeArabicText(text.toLowerCase());

    final String searchableText = normalizedText.replaceAll(RegExp(r'\s+'), '');

    return searchableText.contains(searchQuery);
  }

  // ============================================================
  // 1. Search in the Emlaey text field
  // ============================================================

  for (final aya in quran) {
    final String emlaeyText = aya['aya_text_emlaey']?.toString() ?? '';

    if (emlaeyText.isEmpty) continue;

    if (containsSearchQuery(emlaeyText)) {
      result.add({
        "sora": aya["sora"],
        "aya_no": aya["aya_no"],
        "text": emlaeyText
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      });

      if (result.length >= limit) {
        break;
      }
    }
  }

  // ============================================================
  // 2. Fallback search in the Othmanic text field
  // ============================================================

  if (result.isEmpty) {
    for (final aya in quran) {
      final String othmanicText = aya['aya_text']?.toString() ?? '';

      if (othmanicText.isEmpty) continue;

      if (containsSearchQuery(othmanicText)) {
        result.add({
          "sora": aya["sora"],
          "aya_no": aya["aya_no"],
          "text": othmanicText
              .replaceAll('\n', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        });

        if (result.length >= limit) {
          break;
        }
      }
    }
  }

  return {"occurences": result.length, "result": result};
}

/// Converts Quran text to a normalized form suitable for search or comparison.
///
/// Removes Koranic annotations, tatweel, tashkeel, and unifies certain letters
/// (e.g. ya/hamza forms, alif variants). Useful before calling `searchWords()`.
String normalise(String input) => input
    .replaceAll('\u0610', '')
    .replaceAll('\u0611', '')
    .replaceAll('\u0612', '')
    .replaceAll('\u0613', '')
    .replaceAll('\u0614', '')
    .replaceAll('\u0615', '')
    .replaceAll('\u0616', '')
    .replaceAll('\u0617', '')
    .replaceAll('\u0618', '')
    .replaceAll('\u0619', '')
    .replaceAll('\u061A', '')
    .replaceAll('\u06D6', '')
    .replaceAll('\u06D7', '')
    .replaceAll('\u06D8', '')
    .replaceAll('\u06D9', '')
    .replaceAll('\u06DA', '')
    .replaceAll('\u06DB', '')
    .replaceAll('\u06DC', '')
    .replaceAll('\u06DD', '')
    .replaceAll('\u06DE', '')
    .replaceAll('\u06DF', '')
    .replaceAll('\u06E0', '')
    .replaceAll('\u06E1', '')
    .replaceAll('\u06E2', '')
    .replaceAll('\u06E3', '')
    .replaceAll('\u06E4', '')
    .replaceAll('\u06E5', '')
    .replaceAll('\u06E6', '')
    .replaceAll('\u06E7', '')
    .replaceAll('\u06E8', '')
    .replaceAll('\u06E9', '')
    .replaceAll('\u06EA', '')
    .replaceAll('\u06EB', '')
    .replaceAll('\u06EC', '')
    .replaceAll('\u06ED', '')
    .replaceAll('\u0640', '')
    .replaceAll('\u064B', '')
    .replaceAll('\u064C', '')
    .replaceAll('\u064D', '')
    .replaceAll('\u064E', '')
    .replaceAll('\u064F', '')
    .replaceAll('\u0650', '')
    .replaceAll('\u0651', '')
    .replaceAll('\u0652', '')
    .replaceAll('\u0653', '')
    .replaceAll('\u0654', '')
    .replaceAll('\u0655', '')
    .replaceAll('\u0656', '')
    .replaceAll('\u0657', '')
    .replaceAll('\u0658', '')
    .replaceAll('\u0659', '')
    .replaceAll('\u065A', '')
    .replaceAll('\u065B', '')
    .replaceAll('\u065C', '')
    .replaceAll('\u065D', '')
    .replaceAll('\u065E', '')
    .replaceAll('\u065F', '')
    .replaceAll('\u0670', '')
    .replaceAll('\u0624', '\u0648')
    .replaceAll('\u0629', '\u0647')
    .replaceAll('\u064A', '\u0649')
    .replaceAll('\u0626', '\u0649')
    .replaceAll('\u0622', '\u0627')
    .replaceAll('\u0623', '\u0627')
    .replaceAll('\u0625', '\u0627');

/// Removes basic Arabic diacritics (tashkeel) from the input text.
///
/// Keeps base letters intact while removing characters such as Fatha, Damma,
/// Kasra, Shadda, and tanwin marks. Helpful for lightweight fuzzy matching.
String removeDiacritics(String input) {
  // Mapping of diacritic characters to an empty string.
  Map<String, String> diacriticsMap = {
    'َ': '',
    'ُ': '',
    'ِ': '',
    'ّ': '',
    'ً': '',
    'ٌ': '',
    'ٍ': '',
  };

  // Build a regular expression pattern from the diacritic keys.
  String diacriticsPattern = diacriticsMap.keys
      .map((e) => RegExp.escape(e))
      .join('|');

  RegExp exp = RegExp('[$diacriticsPattern]');

  // Remove all matched diacritics from the input.
  String textWithoutDiacritics = input.replaceAll(exp, '');

  return textWithoutDiacritics;
}