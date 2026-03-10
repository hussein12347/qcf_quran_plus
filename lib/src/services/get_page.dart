import '../data/quran_data.dart';
import '../models/ayah.dart';
import '../models/quran_page.dart';
import '../models/surah.dart';

class GetPage {
  List<QuranPage> staticPages = [];
  List<int> quranStops = [];
  List<int> surahsStart = [];
  List<Surah> surahs = [];
  final List<Ayah> ayahs = [];
  int lastPage = 0;

  void getQuran(int quranPagesCount) {
    // إذا كانت البيانات محملة مسبقاً لا نكرر العملية
    if (staticPages.isNotEmpty && quranPagesCount == staticPages.length) {
      return;
    }

    final List<Ayah> result = getQuranData();

    _processQuranData(result, quranPagesCount);
  }

  List<Ayah> getQuranData() {
    final List<Ayah> othmanQuran = quran.map((e) => Ayah.fromJson(e)).toList();
    return othmanQuran;
  }

  void _processQuranData(List<Ayah> quranAyahsList, int quranPagesCount) {
    staticPages = List.generate(
      quranPagesCount,
      (index) => QuranPage(pageNumber: index + 1, ayahs: [], lines: []),
    );

    int hizb = 1;
    int surahsIndex = 1;
    List<Ayah> thisSurahAyahs = [];

    for (var ayah in quranAyahsList) {
      // منطق تحديد السور
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

      // علامات الأجزاء والسجدات
      if (ayah.ayah.contains('۞')) {
        staticPages[ayah.page - 1].hizb = hizb++;
        quranStops.add(ayah.page);
      }
      if (ayah.ayah.contains('۩')) {
        staticPages[ayah.page - 1].hasSajda = true;
      }

      // بداية سورة جديدة
      if (ayah.ayahNumber == 1) {
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

    // إغلاق بيانات آخر سورة
    if (surahs.isNotEmpty) {
      surahs.last.endPage = ayahs.last.page;
      surahs.last.ayahs = thisSurahAyahs;
    }

    // منطق تقسيم الأسطر (Line Splitting)
    _generateLines();
  }

  void _generateLines() {
    for (var staticPage in staticPages) {
      staticPage.lines.clear();

      List<Ayah> currentLineAyahs = [];

      for (var aya in staticPage.ayahs) {
        if (aya.ayahNumber == 1) {
          if (currentLineAyahs.isNotEmpty &&
              currentLineAyahs.any((a) => a.ayah.trim().isNotEmpty)) {
            staticPage.lines.add(Line(List.from(currentLineAyahs)));
            currentLineAyahs.clear();
          }
        }

        if (aya.ayah.contains('\n')) {
          final parts = aya.ayah.split('\n');
          final othmanicParts = aya.othmanicAyah.split('\n');
          final qcfParts = aya.qcfData.split('\n'); // ✅ تم إضافة تقسيم QCF

          for (int i = 0; i < parts.length; i++) {
            final textPart = parts[i].trim();
            if (textPart.isEmpty) continue;

            String othmanicPart = textPart;
            if (i < othmanicParts.length) {
              othmanicPart = othmanicParts[i].trim();
            }

            // ✅ استخراج الجزء المقابل من بيانات QCF
            String qcfPart = textPart;
            if (i < qcfParts.length) {
              qcfPart = qcfParts[i].trim();
            }

            final subAyah = Ayah.fromAya(
              ayah: aya,
              aya: textPart,
              othmanicAyah: othmanicPart,
              qcfData: qcfPart, // ✅ تمرير الجزء المقطوع من QCF
              ayaText: textPart,
              centered: aya.centered && i == parts.length - 2,
            );

            currentLineAyahs.add(subAyah);

            if (i < parts.length - 1) {
              staticPage.lines.add(Line(List.from(currentLineAyahs)));
              currentLineAyahs.clear();
            }
          }
        } else {
          currentLineAyahs.add(aya);
        }
      }

      if (currentLineAyahs.isNotEmpty &&
          currentLineAyahs.any((a) => a.ayah.trim().isNotEmpty)) {
        staticPage.lines.add(Line(List.from(currentLineAyahs)));
      }
    }
  }
}
