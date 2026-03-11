import '../data/quran_data.dart';
import '../models/ayah.dart';
import '../models/quran_page.dart';
import '../models/surah.dart';

/// A service class responsible for processing raw Quranic data into
/// structured [QuranPage] and [Surah] objects.
///
/// This class handles the complex logic of:
/// * Parsing raw JSON into [Ayah] objects.
/// * Grouping Ayahs into their respective Surahs.
/// * Distributing Ayahs across pages and calculating line breaks.
/// * Detecting special symbols like the Hizb (۞) and Sajda (۩).
class GetPage {
  /// The list of fully processed pages for the Mushaf.
  List<QuranPage> staticPages = [];

  /// A list of page numbers where a Hizb or Quarter starts.
  List<int> quranStops = [];

  /// A list of indices indicating the starting pages of each Surah.
  List<int> surahsStart = [];

  /// The list of all Surahs with their associated Ayahs and page ranges.
  List<Surah> surahs = [];

  /// A flat list of every Ayah in the Quran.
  final List<Ayah> ayahs = [];

  /// Tracking the total number of pages processed.
  int lastPage = 0;

  /// Entry point to initialize the Quranic data structure.
  ///
  /// [quranPagesCount] defines the total pages (e.g., 604 for Madina Mushaf).
  /// This method avoids re-processing if [staticPages] is already populated.
  void getQuran(int quranPagesCount) {
    if (staticPages.isNotEmpty && quranPagesCount == staticPages.length) {
      return;
    }

    final List<Ayah> result = getQuranData();
    _processQuranData(result, quranPagesCount);
  }

  /// Fetches the raw data and maps it into a list of [Ayah] objects.
  List<Ayah> getQuranData() {
    final List<Ayah> othmanQuran = quran.map((e) => Ayah.fromJson(e)).toList();
    return othmanQuran;
  }

  /// Orchestrates the data processing: calculates Surah ranges,
  /// detects Hizb marks, and manages page allocation.
  void _processQuranData(List<Ayah> quranAyahsList, int quranPagesCount) {
    staticPages = List.generate(
      quranPagesCount,
          (index) => QuranPage(pageNumber: index + 1, ayahs: [], lines: []),
    );

    int hizb = 1;
    int surahsIndex = 1;
    List<Ayah> thisSurahAyahs = [];

    for (var ayah in quranAyahsList) {
      // Logic for Surah transition and tracking
      if (ayah.surahNumber != surahsIndex) {
        if (surahs.isNotEmpty) {
          surahs.last.endPage = ayahs.last.page;
          surahs.last.ayahs = List.from(thisSurahAyahs);
        }
        surahsIndex = ayah.surahNumber;
        thisSurahAyahs = [];
      }

      ayahs.add(ayah);
      thisSurahAyahs.add(ayah);
      staticPages[ayah.page - 1].ayahs.add(ayah);

      // Detect Hizb (۞) marks and Sajda (۩)
      if (ayah.ayah.contains('۞')) {
        staticPages[ayah.page - 1].hizb = hizb++;
        quranStops.add(ayah.page);
      }
      if (ayah.ayah.contains('۩')) {
        staticPages[ayah.page - 1].hasSajda = true;
      }

      // Handle the start of a new Surah (Ayah 1)
      if (ayah.ayahNumber == 1) {
        // Remove the Hizb mark if it appears at the start of a Surah
        // to avoid visual clutter in the title.
        ayah.ayah = ayah.ayah.replaceAll('۞', '');
        staticPages[ayah.page - 1].numberOfNewSurahs++;
        surahs.add(
          Surah(
            index: ayah.surahNumber,
            startPage: ayah.page,
            endPage: 0,
            nameEn: ayah.surahNameEn,
            nameAr: ayah.surahNameAr,
            ayahs: [],
          ),
        );
        surahsStart.add(ayah.page - 1);
      }
    }

    // Close out the final Surah
    if (surahs.isNotEmpty) {
      surahs.last.endPage = ayahs.last.page;
      surahs.last.ayahs = thisSurahAyahs;
    }

    // Proceed to slice Ayahs into visual lines
    _generateLines();
  }

  /// Splits Ayahs into [Line] objects based on newline characters (\n).
  ///
  /// This method is critical for Mushaf layouts where an Ayah spans
  /// multiple lines. It synchronizes the Standard, Othmanic, and QCF
  /// text data so they all break at the same visual point.
  void _generateLines() {
    for (var staticPage in staticPages) {
      staticPage.lines.clear();
      List<Ayah> currentLineAyahs = [];

      for (var aya in staticPage.ayahs) {
        // If it's a new Surah start, force a line break for the header
        if (aya.ayahNumber == 1) {
          if (currentLineAyahs.isNotEmpty &&
              currentLineAyahs.any((a) => a.ayah.trim().isNotEmpty)) {
            staticPage.lines.add(Line(List.from(currentLineAyahs)));
            currentLineAyahs.clear();
          }
        }

        // Handle Ayahs that are split across multiple lines
        if (aya.ayah.contains('\n')) {
          final parts = aya.ayah.split('\n');
          final othmanicParts = aya.othmanicAyah.split('\n');
          final qcfParts = aya.qcfData.split('\n');

          for (int i = 0; i < parts.length; i++) {
            final textPart = parts[i].trim();
            if (textPart.isEmpty) continue;

            String othmanicPart = textPart;
            if (i < othmanicParts.length) {
              othmanicPart = othmanicParts[i].trim();
            }

            String qcfPart = textPart;
            if (i < qcfParts.length) {
              qcfPart = qcfParts[i].trim();
            }

            // Create a sub-Ayah for the specific line segment
            final subAyah = Ayah.fromAya(
              ayah: aya,
              aya: textPart,
              othmanicAyah: othmanicPart,
              qcfData: qcfPart,
              ayaText: textPart,
              centered: aya.centered && i == parts.length - 2,
            );

            currentLineAyahs.add(subAyah);

            // If there's more text after this part, it's a line break
            if (i < parts.length - 1) {
              staticPage.lines.add(Line(List.from(currentLineAyahs)));
              currentLineAyahs.clear();
            }
          }
        } else {
          // Ayah fits on a single line (or is part of a multi-Ayah line)
          currentLineAyahs.add(aya);
        }
      }

      // Add the remaining Ayahs to the final line of the page
      if (currentLineAyahs.isNotEmpty &&
          currentLineAyahs.any((a) => a.ayah.trim().isNotEmpty)) {
        staticPage.lines.add(Line(List.from(currentLineAyahs)));
      }
    }
  }
}