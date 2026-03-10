/// A lightweight, high-performance, and professional Flutter package to display the Holy Quran.
///
/// This library provides customizable widgets (`QuranPageView`) and comprehensive
/// data models/helpers to render Quranic pages using the official QCF font.
/// It includes built-in functions for searching, statistics, and metadata retrieval.
library qcf_quran_plus;

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
// ---------------------------------------------------------------------------
// 2. Models Exports
// ---------------------------------------------------------------------------
export 'src/models/highlight_verse.dart';
export 'src/models/ayah.dart';
export 'src/models/quran_page.dart';
export 'src/models/surah.dart';
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
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  return pageData[pageNumber - 1];
}

/// Returns the total number of Surahs present on a specific [pageNumber].
int getSurahCountByPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  return pageData[pageNumber - 1].length;
}

/// Returns the total number of verses (Ayahs) present on a specific [pageNumber].
int getVerseCountByPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  int totalVerseCount = 0;
  for (int i = 0; i < pageData[pageNumber - 1].length; i++) {
    totalVerseCount += int.parse(
      pageData[pageNumber - 1][i]!["end"].toString(),
    );
  }
  return totalVerseCount;
}

/// Converts an integer to an Arabic numeral string.
String _convertToArabicNumber(int number) {
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
  return number.toString().split('').map((e) => arabicNumbers[e] ?? e).join('');
}

/// Returns the Hizb/Quarter text ONLY if a new quarter starts exactly on this [pageNumber].
///
/// If no quarter starts on this page, it returns an empty string.
/// Pass [isArabic] as `true` (default) for Arabic text, or `false` for English.
String getHizbTextByPage(int pageNumber, {bool isArabic = true}) {
  int quarterIndex = quarters.indexWhere(
        (q) => getPageNumber(q['surah']!, q['ayah']!) == pageNumber,
  );

  final bool showHizbText = quarterIndex != -1;

  if (!showHizbText) return "";

  int quarter = quarterIndex + 1;
  int hizb = ((quarter - 1) ~/ 4) + 1;
  int quarterInHizb = ((quarter - 1) % 4) + 1;

  String hizbNumber = isArabic ? _convertToArabicNumber(hizb) : hizb.toString();

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

/// Returns the Quarter (Rub el Hizb) number (1-240) based on the [surahNumber] and [aya_no].
int getQuarterNumber(int surahNumber, int aya_no) {
  int currentQuarter = 1;
  for (int i = 0; i < quarters.length; i++) {
    int qSurah = quarters[i]["surah"]!;
    int qAyah = quarters[i]["ayah"]!;

    if (surahNumber > qSurah || (surahNumber == qSurah && aya_no >= qAyah)) {
      currentQuarter = i + 1;
    } else {
      break;
    }
  }
  return currentQuarter;
}

/// Returns the Juz number (1-30) for a specific [surahNumber] and [aya_no].
int getJuzNumber(int surahNumber, int aya_no) {
  for (var juz in juz) {
    if (juz["verses"].keys.contains(surahNumber)) {
      if (aya_no >= juz["verses"][surahNumber][0] &&
          aya_no <= juz["verses"][surahNumber][1]) {
        return int.parse(juz["id"].toString());
      }
    }
  }
  return -1;
}

/// Returns the Surah name in transliterated format for a given [surahNumber].
String getSurahName(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['name'].toString();
}

/// Returns the translated Surah name in English for a given [surahNumber].
String getSurahNameEnglish(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['english'].toString();
}

/// Returns the Surah name in Arabic for a given [surahNumber].
String getSurahNameArabic(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['arabic'].toString();
}

/// Returns the page number (1-604) of the Quran where the specific [surahNumber] and [aya_no] is located.
int getPageNumber(int surahNumber, int aya_no) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  for (int pageIndex = 0; pageIndex < pageData.length; pageIndex++) {
    for (
    int surahIndexInPage = 0;
    surahIndexInPage < pageData[pageIndex].length;
    surahIndexInPage++
    ) {
      final e = pageData[pageIndex][surahIndexInPage];
      if (e['surah'] == surahNumber &&
          e['start'] <= aya_no &&
          e['end'] >= aya_no) {
        return pageIndex + 1;
      }
    }
  }

  throw "Invalid verse number.";
}

/// Returns the place of revelation ('Makkah' or 'Madinah') for a given [surahNumber].
String getPlaceOfRevelation(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['place'].toString();
}

/// Returns the total count of verses in a specific [surahNumber].
int getVerseCount(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No verse found with given surahNumber";
  }
  return int.parse(surah[surahNumber - 1]['aya'].toString());
}

/// Returns the Arabic text of a specific verse based on [surahNumber] and [aya_no].
///
/// Set [verseEndSymbol] to `true` if you want the Ayah number symbol appended to the text.
String getVerse(int surahNumber, int aya_no, {bool verseEndSymbol = false}) {
  String verse = "";
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == aya_no) {
      verse = i['aya_text'].toString();
      break;
    }
  }

  if (verse == "") {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  return verse;
}

/// Returns the ornate end-of-verse symbol ('۝') enclosing the [aya_no].
///
/// Set [arabicNumeral] to `false` to use standard western numerals instead of Arabic numerals.
String getVerseEndSymbol(int aya_no, {bool arabicNumeral = true}) {
  var arabicNumeric = '';
  var digits = aya_no.toString().split("").toList();

  if (!arabicNumeral) return '\u06dd${aya_no.toString()}';

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

  for (var e in digits) {
    arabicNumeric += arabicNumbers[e];
  }

  return '$arabicNumeric';
}

/// Returns the specific QCF font glyph representing the [aya_no] for rendering purposes.
String getaya_noQCFLite(int surahNumber, int aya_no, {bool verseEndSymbol = true}) {
  String glyph = "";
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == aya_no) {
      final String qcfData = i['aya_text_othmanic'].toString();

      final bool endsWithNewline = qcfData.endsWith('\n');
      glyph = endsWithNewline
          ? qcfData.substring(qcfData.length - 2, qcfData.length - 1)
          : qcfData.substring(qcfData.length - 1);
      break;
    }
  }

  if (glyph == "") {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  return glyph;
}
// تعريف Map لتخزين أرقام الآيات لعدم البحث عنها مرة أخرى (Cache)
final Map<String, String> _verseGlyphCache = {};

/// دالة سريعة جداً لجلب رمز رقم الآية باستخدام qcfData
String getaya_noQCF(int surahNumber, int aya_no) {
  // مفتاح البحث المخصص للآية
  final key = '${surahNumber}_${aya_no}';

  // إذا بحثنا عنها من قبل، أعدها فوراً (هذا يمنع الـ Lag)
  if (_verseGlyphCache.containsKey(key)) {
    return _verseGlyphCache[key]!;
  }

  String glyph = "";

  // حلقة البحث ستعمل مرة واحدة فقط لكل آية في التطبيق كله
  for (var i in quran) {
    if (i['sora'] == surahNumber && i['aya_no'] == aya_no) {
      // نستخدم حقل qcfData كما هو موجود في الـ JSON الخاص بك
      final String qcfData = i['qcfData'].toString().trim();

      // الرمز هو دائماً الحرف الأخير في النص بعد التنظيف من المسافات أو \n
      if (qcfData.isNotEmpty) {
        glyph = qcfData.substring(qcfData.length - 1);
      }
      break;
    }
  }

  if (glyph.isEmpty) {
    throw "No verse found with given surahNumber and aya_no.\n\n";
  }

  // حفظ الرمز في الذاكرة لتسريع المرات القادمة
  _verseGlyphCache[key] = glyph;

  return glyph;
}

/// Searches the Quran text for the specified [words].
///
/// Returns a [Map] containing:
/// - `occurences`: The total number of matches found.
/// - `result`: A [List] of [Map]s containing the `sora` and `aya_no` of the matches.
String normalizeArabicText(String text) {
  if (text.isEmpty) return text;

  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

  text = text.replaceAll(RegExp(r'[إأآا]'), 'ا');

  text = text.replaceAll(RegExp(r'[يى]'), 'ي');

  text = text.replaceAll(RegExp(r'ة'), 'ه');

  return text;
}

// 2. دالة البحث الرئيسية
Map<String, dynamic> searchWords(String query, {int limit = 50}) {
  if (query.trim().isEmpty) {
    return {"occurences": 0, "result": []};
  }

  List<Map<String, dynamic>> result = [];

  String normalizedQuery = normalizeArabicText(query.toLowerCase());

  for (var aya in quran) {
    String emlaeyText = aya['aya_text_emlaey']?.toString() ?? "";
    String normalizedEmlaey = normalizeArabicText(emlaeyText.toLowerCase());

    if (normalizedEmlaey.contains(normalizedQuery)) {
      result.add({
        "sora": aya["sora"],
        "aya_no": aya["aya_no"],
        "text": emlaeyText.replaceAll('\n', '').trim(),
      });

      if (result.length >= limit) break;
    }
  }

  if (result.isEmpty) {
    for (var aya in quran) {
      String othmanicText = aya['aya_text']?.toString() ?? "";
      String normalizedOthmanic = normalizeArabicText(othmanicText.toLowerCase());

      if (normalizedOthmanic.contains(normalizedQuery)) {
        result.add({
          "sora": aya["sora"],
          "aya_no": aya["aya_no"],
          "text": othmanicText.replaceAll('\n', '').trim(),
        });

        if (result.length >= limit) break;
      }
    }
  }

  return {
    "occurences": result.length,
    "result": result
  };
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
  Map<String, String> diacriticsMap = {
    'َ': '',
    'ُ': '',
    'ِ': '',
    'ّ': '',
    'ً': '',
    'ٌ': '',
    'ٍ': '',
  };

  String diacriticsPattern = diacriticsMap.keys
      .map((e) => RegExp.escape(e))
      .join('|');
  RegExp exp = RegExp('[$diacriticsPattern]');

  String textWithoutDiacritics = input.replaceAll(exp, '');

  return textWithoutDiacritics;
}
