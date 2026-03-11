/// A model class representing a single Ayah (verse) of the Holy Quran.
///
/// Contains all necessary metadata for displaying and managing the Ayah,
/// including its location (Surah, page, Juzz), script variations (Uthmani, plain),
/// and formatting flags.
class Ayah {
  /// Unique identifier for the Ayah.
  final int id;

  /// The Juzz (part) number where the Ayah is located (1-30).
  final int jozz;

  /// The Surah (chapter) number (1-114).
  final int surahNumber;

  /// The Mushaf page number where the Ayah appears.
  final int page;

  /// The starting line number on the page.
  final int lineStart;

  /// The ending line number on the page.
  final int lineEnd;

  /// The number of the Ayah within its Surah.
  final int ayahNumber;

  /// The Rub el Hizb (quarter of a Hizb) number.
  final int quarter;

  /// The Hizb number.
  final int hizb;

  /// The English transliterated or translated name of the Surah.
  final String surahNameEn;

  /// The Arabic name of the Surah.
  final String surahNameAr;

  /// The plain spelling (Emlaey) text of the Ayah, usually without diacritics.
  final String ayahText;

  /// The standard text of the Ayah.
  String ayah;

  /// The Uthmani script text of the Ayah.
  String othmanicAyah;

  /// Data mapping required for QCF (Quran Complex Font) rendering.
  String qcfData;

  /// Indicates whether reading this Ayah requires a prostration (Sajda Tilawah).
  final bool sajda;

  /// Indicates if the Ayah text should be horizontally centered on the page.
  bool centered;

  /// Indicates if the user has marked this Ayah as a favorite/bookmark.
  bool isFavorite;

  /// Creates a new [Ayah] instance.
  Ayah({
    required this.id,
    required this.jozz,
    required this.surahNumber,
    required this.page,
    required this.lineStart,
    this.isFavorite = false,
    required this.lineEnd,
    required this.ayahNumber,
    required this.quarter,
    required this.hizb,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.ayah,
    required this.othmanicAyah,
    required this.qcfData,
    required this.ayahText,
    required this.sajda,
    required this.centered,
  });

  /// Converts the [Ayah] instance into a JSON map.
  ///
  /// Useful for local storage (like SQLite or SharedPreferences) or network payloads.
  Map<String, dynamic> toJson() => {
    'id': id,
    'jozz': jozz,
    'sora': surahNumber,
    'page': page,
    'line_start': lineStart,
    'line_end': lineEnd,
    'aya_no': ayahNumber,
    'sora_name_en': surahNameEn,
    'sora_name_ar': surahNameAr,
    'aya_text': ayah,
    'aya_text_othmanic': othmanicAyah,
    'qcfData': qcfData,
    'aya_text_emlaey': ayahText,
    'centered': centered,
  };

  /// Creates an [Ayah] instance from a JSON map.
  ///
  /// Automatically parses and cleans up the text spacing for standard, 
  /// Uthmani, and QCF formats.
  factory Ayah.fromJson(Map<String, dynamic> json) {
    /// Helper function to process and format line text.
    /// It ensures proper spacing, especially handling newline characters.
    String parseText(String? input) {
      String text = input ?? '';
      if (text.isNotEmpty) {
        if (text.endsWith('\n')) {
          text = text.insert(' ', text.length - 1);
        } else {
          text = '$text ';
        }
      }
      return text;
    }

    return Ayah(
      id: json['id'],
      jozz: json['jozz'],
      surahNumber: json['sora'] ?? 0,
      page: json['page'],
      lineStart: json['line_start'],
      lineEnd: json['line_end'],
      ayahNumber: json['aya_no'],
      quarter: -1, // Defaulting to -1 if not provided in JSON
      isFavorite: false,
      hizb: -1, // Defaulting to -1 if not provided in JSON
      surahNameEn: json['sora_name_en'] ?? '',
      surahNameAr: json['sora_name_ar'] ?? '',
      ayah: parseText(json['aya_text']),
      ayahText: json['aya_text_emlaey'] ?? '',
      sajda: false, // Defaulting to false if not provided in JSON
      centered: json['centered'] ?? false,
      othmanicAyah: parseText(json['aya_text_othmanic']),
      qcfData: parseText(json['qcfData']),
    );
  }

  /// Creates a copy of an existing [Ayah] instance but overrides its text properties.
  ///
  /// This is particularly useful when dynamically updating fonts, scripts, 
  /// or applying tajweed rules to an existing Ayah without losing its metadata.
  factory Ayah.fromAya({
    required Ayah ayah,
    required String aya,
    required String othmanicAyah,
    required String qcfData,
    required String ayaText,
    bool centered = false,
  }) =>
      Ayah(
        id: ayah.id,
        jozz: ayah.jozz,
        surahNumber: ayah.surahNumber,
        page: ayah.page,
        lineStart: ayah.lineStart,
        lineEnd: ayah.lineEnd,
        ayahNumber: ayah.ayahNumber,
        quarter: ayah.quarter,
        hizb: ayah.hizb,
        surahNameEn: ayah.surahNameEn,
        surahNameAr: ayah.surahNameAr,
        isFavorite: ayah.isFavorite,
        othmanicAyah: othmanicAyah,
        qcfData: qcfData,
        ayah: aya,
        ayahText: ayaText,
        sajda: false,
        centered: centered,
      );
}

/// List of standard Western Arabic numerals (English digits).
const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

/// List of Eastern Arabic numerals used in Quranic text.
const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Extension providing helpful string manipulation methods.
extension StringExtensions on String {
  /// Inserts a given [text] into the current string at the specified [index].
  /// 
  /// Example:
  /// ```dart
  /// 'Hello'.insert(' World', 5); // returns 'Hello World'
  /// ```
  String insert(String text, int index) =>
      substring(0, index) + text + substring(index);

  /// Converts all standard Western (English) digits in the string 
  /// to Eastern Arabic numerals.
  /// 
  /// Useful for displaying Ayah numbers or page numbers in Arabic script.
  String toArabic() {
    String number = this;
    for (int i = 0; i < english.length; i++) {
      number = number.replaceAll(english[i], arabic[i]);
    }
    return number;
  }
}