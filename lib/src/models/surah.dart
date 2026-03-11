import 'ayah.dart';

/// Represents a Surah (Chapter) of the Holy Quran.
///
/// This class acts as a container for a collection of [Ayah] objects and
/// includes metadata such as the Surah's name in both Arabic and English,
/// and its page range within the Mushaf.
class Surah {
  /// The unique index of the Surah (1 to 114).
  final int index;

  /// The page number where this Surah begins in the standard Mushaf.
  final int startPage;

  /// The page number where this Surah ends.
  int endPage;

  /// The English transliteration or translation of the Surah's name.
  final String nameEn;

  /// The Arabic name of the Surah (e.g., الفاتحة).
  final String nameAr;

  /// The list of [Ayah] objects belonging to this Surah.
  List<Ayah> ayahs;

  /// Creates a [Surah] instance.
  Surah({
    required this.index,
    required this.startPage,
    required this.endPage,
    required this.nameEn,
    required this.nameAr,
    required this.ayahs,
  });

  /// Creates a [Surah] instance from a JSON map.
  ///
  /// This factory expects the 'ayahs' key to contain a list of maps
  /// compatible with [Ayah.fromJson].
  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
    index: json['index'],
    startPage: json['start_page'],
    endPage: json['end_page'],
    nameEn: json['name_en'],
    nameAr: json['name_ar'],
    ayahs: (json['ayahs'] as List)
        .map<Ayah>((ayah) => Ayah.fromJson(ayah))
        .toList(),
  );

  /// Converts the [Surah] instance into a JSON map.
  ///
  /// Includes the serialized list of all [ayahs] within this Surah.
  Map<String, dynamic> toJson() => {
    "index": index,
    "start_page": startPage,
    "end_page": endPage,
    "name_en": nameEn,
    "name_ar": nameAr,
    "ayahs": ayahs.map((ayah) => ayah.toJson()).toList(),
  };
}