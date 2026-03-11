import 'ayah.dart';

/// Represents a single page of the Holy Quran Mushaf.
///
/// This class aggregates [Ayah] and [Line] objects to facilitate the
/// structured rendering of a Quranic page in a digital interface.
class QuranPage {
  /// The physical page number in the Mushaf (typically 1-604).
  final int pageNumber;

  /// The count of Surah headers (start of a new chapter) present on this page.
  /// Useful for rendering "Bismillah" or Surah title banners.
  int numberOfNewSurahs;

  /// A flat list of all [Ayah] objects contained on this page.
  List<Ayah> ayahs;

  /// A structured list of [Line] objects representing the visual rows on the page.
  List<Line> lines;

  /// The Hizb number (part of a Juzz) that this page belongs to or starts with.
  int? hizb;

  /// Indicates if any Ayah on this page contains a prostration mark (Sajda).
  bool hasSajda;

  /// Indicates if this is the final line of a Surah or the Mushaf.
  bool lastLine;

  /// Creates a [QuranPage] with the required layout and content data.
  QuranPage({
    required this.pageNumber,
    required this.ayahs,
    required this.lines,
    this.hizb,
    this.hasSajda = false,
    this.lastLine = false,
    this.numberOfNewSurahs = 0,
  });
}

/// Represents a single horizontal row of text on a Quranic page.
///
/// In high-quality Mushaf layouts, an Ayah can span across multiple lines,
/// and a single line can contain multiple short Ayahs.
class Line {
  /// The collection of [Ayah] segments or full verses present in this specific line.
  List<Ayah> ayahs;

  /// Whether the text in this line should be horizontally centered.
  /// Often true for the start of Surahs (like Al-Fatiha) or very short final lines.
  bool centered;

  /// Creates a [Line] instance containing a list of verses.
  Line(this.ayahs, {this.centered = false});
}