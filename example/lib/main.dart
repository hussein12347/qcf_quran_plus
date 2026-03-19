import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const MyApp());
}

// =============================================================================
// Theme Notifier for Dark/Light Mode Toggle
// =============================================================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'QCF Quran Lite Demo',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          themeMode: currentMode,
          // --- Light Theme ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFFBF6EE),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3E2723),
              secondary: Color(0xFF8D6E63),
              surface: Color(0xFFF9F1E3),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFBF6EE),
              foregroundColor: Color(0xFF3E2723),
              elevation: 0,
            ),
            cardColor: const Color(0xFFF9F1E3),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF212121)),
              bodyMedium: TextStyle(color: Color(0xFF5D4037)),
            ),
            fontFamily: 'Cairo',
          ),
          // --- Dark Theme ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              secondary: Color(0xFFA1887F),
              surface: Color(0xFF1E1E1E),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Color(0xFFD4AF37),
              elevation: 0,
            ),
            cardColor: const Color(0xFF1E1E1E),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
              bodyMedium: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            fontFamily: 'Cairo',
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// =============================================================================
// Splash Screen
// =============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeFonts();
  }

  void _initializeFonts() async {
    await QcfFontLoader.setupFontsAtStartup(
      onProgress: (double progress) {
        setState(() {
          _loadingProgress = progress;
        });
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 100, color: primaryColor),
            const SizedBox(height: 20),
            Text(
              'مكتبة المصحف الذكية',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 8,
                  backgroundColor: primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'جاري تجهيز الخطوط... ${(_loadingProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Dashboard Screen
// =============================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map> _searchResults = [];
  int _searchOccurrences = 0;

  int _selectedSurah = 1;
  int _selectedAyah = 1;

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchOccurrences = 0;
      });
      return;
    }
    String cleanedQuery = normalise(query);
    Map results = searchWords(cleanedQuery);
    setState(() {
      _searchOccurrences = results['occurences'];
      _searchResults = List<Map>.from(results['result']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مكتبة المصحف الذكية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Navigation Buttons ---
            Row(
              children: [
                Expanded(
                  child: _buildNavButton(
                    context,
                    title: 'المصحف الكامل',
                    icon: Icons.menu_book,
                    color: primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MushafScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNavButton(
                    context,
                    title: 'قراءة كقائمة',
                    icon: Icons.format_list_numbered_rtl,
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SurahListReaderScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- Statistics Section ---
            _buildSectionTitle('إحصائيات القرآن', primaryColor),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard(
                  'سور القرآن',
                  '$totalSurahCount',
                  Icons.library_books,
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  'عدد الآيات',
                  '$totalVerseCount',
                  Icons.format_list_numbered_rtl,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard('مكية', '$totalMakkiSurahs', Icons.location_on),
                const SizedBox(width: 10),
                _buildStatCard(
                  'مدنية',
                  '$totalMadaniSurahs',
                  Icons.location_city,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- API Demo Section ---
            _buildSectionTitle('استكشاف دوال الآيات (API Demo)', primaryColor),
            const SizedBox(height: 10),
            _buildAyahExplorerDemo(context),
            const SizedBox(height: 30),

            // --- Search Section ---
            _buildSectionTitle('محرك البحث المدمج', primaryColor),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث (مثال: الله، الرحمن)...',
                hintStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.2)),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 15),

            // --- Search Results ---
            if (_searchOccurrences > 0) ...[
              Text(
                'تم العثور على $_searchOccurrences نتيجة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length > 50
                    ? 50
                    : _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  int sNum = result['sora'];
                  int vNum = result['aya_no'];
                  String sName = getSurahNameArabic(sNum);
                  int pNum = getPageNumber(sNum, vNum);
                  String verseText = getVerse(sNum, vNum, verseEndSymbol: true);

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            verseText,
                            style: QuranTextStyles.hafsStyle(fontSize: 23.55),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'سورة $sName - آية $vNum (صفحة $pNum)',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.menu_book,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 20,
                                    ),
                                    tooltip: 'افتح في المصحف',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MushafScreen(
                                            initialPage: pNum,
                                            highlightSurah: sNum,
                                            highlightAyah: vNum,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.format_list_numbered_rtl,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      size: 20,
                                    ),
                                    tooltip: 'افتح في القائمة',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SurahListReaderScreen(
                                                initialSurah: sNum,
                                                highlightAyah: vNum,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Icon(Icons.brightness_1, size: 12, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahExplorerDemo(BuildContext context) {
    int maxAyahs = getVerseCount(_selectedSurah);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSurah,
                    decoration: InputDecoration(
                      labelText: 'السورة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(
                      114,
                          (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(getSurahNameArabic(i + 1)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _selectedSurah = val!;
                        _selectedAyah = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedAyah,
                    decoration: InputDecoration(
                      labelText: 'رقم الآية',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(
                      maxAyahs,
                          (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _selectedAyah = val!);
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _demoTextRow(
              context,
              'الآية بالتشكيل:',
              getVerse(_selectedSurah, _selectedAyah),
            ),
            _demoTextRow(
              context,
              'بدون تشكيل:',
              removeDiacritics(getVerse(_selectedSurah, _selectedAyah)),
            ),
            _demoTextRow(
              context,
              'اسم السورة:',
              getSurahNameArabic(_selectedSurah),
            ),
            _demoTextRow(
              context,
              'الجزء / الربع:',
              'الجزء ${getJuzNumber(_selectedSurah, _selectedAyah)} - الربع ${getQuarterNumber(_selectedSurah, _selectedAyah)}',
            ),

            const SizedBox(height: 15),
            Text(
              'الرمز العثماني للآية:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
            Center(
              child: Text(
                getAyaNoQCFLite(_selectedSurah, _selectedAyah),
                style: QuranTextStyles.hafsStyle(
                  fontSize: 40,
                  color: isDark ? const Color(0xFFD4AF37) : primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoTextRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 30),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Mushaf Screen
// =============================================================================
class MushafScreen extends StatefulWidget {
  final int initialPage;
  final int? highlightSurah;
  final int? highlightAyah;

  const MushafScreen({
    super.key,
    this.initialPage = 1,
    this.highlightSurah,
    this.highlightAyah,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;
  late ValueNotifier<List<HighlightVerse>> _activeHighlightsNotifier;
  late ValueNotifier<String> _hizbTextNotifier;

  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _activeHighlightsNotifier = ValueNotifier([]);
    _hizbTextNotifier = ValueNotifier(
      getCurrentHizbTextForPage(widget.initialPage, isArabic: true),
    );

    if (widget.highlightSurah != null && widget.highlightAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTemporaryHighlight(
          widget.highlightSurah!,
          widget.highlightAyah!,
          widget.initialPage,
        );
      });
    }
  }

  void _triggerTemporaryHighlight(int surah, int ayah, int page) {
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.amber.withOpacity(0.5)
        : Colors.amber.withOpacity(0.4);

    final newHighlight = HighlightVerse(
      surah: surah,
      verseNumber: ayah,
      page: page,
      color: highlightColor,
    );
    _activeHighlightsNotifier.value = [
      ..._activeHighlightsNotifier.value,
      newHighlight,
    ];

    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _activeHighlightsNotifier.value = _activeHighlightsNotifier.value
            .where((h) => !(h.surah == surah && h.verseNumber == ayah))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _activeHighlightsNotifier.dispose();
    _hizbTextNotifier.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _showAyahDetails(
      BuildContext context,
      int surahNumber,
      int verseNumber,
      int pageNumber,
      ) {
    final String surahAr = getSurahNameArabic(surahNumber);
    final int juz = getJuzNumber(surahNumber, verseNumber);
    final String revelation = getPlaceOfRevelation(surahNumber);
    final int qtr = getQuarterNumber(surahNumber, verseNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'سورة $surahAr',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomSheetCard(
                    context,
                    'الآية',
                    '$verseNumber',
                    Icons.menu_book,
                  ),
                  _buildBottomSheetCard(
                    context,
                    'الصفحة',
                    '$pageNumber',
                    Icons.auto_stories,
                  ),
                  _buildBottomSheetCard(
                    context,
                    'الجزء',
                    '$juz',
                    Icons.pie_chart,
                  ),
                  _buildBottomSheetCard(
                    context,
                    'النزول',
                    revelation == 'Makkah' ? 'مكية' : 'مدنية',
                    Icons.location_on,
                  ),
                  _buildBottomSheetCard(
                    context,
                    'الربع',
                    '$qtr',
                    Icons.data_usage,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetCard(
      BuildContext context,
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      width: 65,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode= Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: _hizbTextNotifier,
          builder: (context, hizbText, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hizbText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.format_color_reset),
            onPressed: () => _activeHighlightsNotifier.value = [],
          ),
        ],
      ),
      body: SafeArea(
        child: QuranPageView(
          isDarkMode: isDarkMode,
          isTajweed: true,
          pageController: _pageController,
          highlights: _activeHighlightsNotifier.value,
          ayahStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
          onPageChanged: (pageNumber) {
            _hizbTextNotifier.value = getCurrentHizbTextForPage(
              pageNumber,
              isArabic: true,
            );
          },
          onLongPress: (surahNumber, verseNumber, details) {
            final currentPage = _pageController.hasClients
                ? _pageController.page!.toInt() + 1
                : widget.initialPage;
            final isHighlighted = _activeHighlightsNotifier.value.any(
                  (e) => e.surah == surahNumber && e.verseNumber == verseNumber,
            );

            if (!isHighlighted) {
              _activeHighlightsNotifier.value = [
                ..._activeHighlightsNotifier.value,
                HighlightVerse(
                  surah: surahNumber,
                  verseNumber: verseNumber,
                  page: currentPage,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                      : const Color(0xFF8D6E63).withValues(alpha: 0.2),
                ),
              ];
            } else {
              _activeHighlightsNotifier.value = _activeHighlightsNotifier.value
                  .where(
                    (e) =>
                e.surah != surahNumber || e.verseNumber != verseNumber,
              )
                  .toList();
            }
            _showAyahDetails(context, surahNumber, verseNumber, currentPage);
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Surah List Reader Screen (With Mock Auto-Playback)
// =============================================================================
class SurahListReaderScreen extends StatefulWidget {
  final int initialSurah;
  final int? highlightAyah;

  const SurahListReaderScreen({
    super.key,
    this.initialSurah = 1,
    this.highlightAyah,
  });

  @override
  State<SurahListReaderScreen> createState() => _SurahListReaderScreenState();
}

class _SurahListReaderScreenState extends State<SurahListReaderScreen> {
  late int _selectedSurah;
  final ValueNotifier<List<HighlightVerse>> _highlightsNotifier = ValueNotifier(
    [],
  );
  final ItemScrollController _itemScrollController = ItemScrollController();

  // --- Auto-Play State ---
  Timer? _playbackTimer;
  bool _isPlaying = false;
  int _currentPlayingAyah = 0;

  @override
  void initState() {
    super.initState();
    _selectedSurah = widget.initialSurah;

    if (widget.highlightAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightAndScrollToAyah(widget.highlightAyah!);
      });
    }
  }

  // Highlights an ayah and scrolls to it
  void _highlightAndScrollToAyah(int ayahNumber) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: ayahNumber,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment: 0.25,
      );
    }

    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.amber.withOpacity(0.5)
        : const Color(0xFF8D6E63).withValues(alpha: 0.3);

    _highlightsNotifier.value = [
      HighlightVerse(
        surah: _selectedSurah,
        verseNumber: ayahNumber,
        page: 0,
        color: highlightColor,
      ),
    ];
  }

  // Toggles the mock audio playback
  void _togglePlay(int startAyah) {
    if (_isPlaying) {
      _stopPlay();
    } else {
      _currentPlayingAyah = startAyah;
      _isPlaying = true;
      setState(() {});

      // Highlight the first Ayah immediately
      _highlightAndScrollToAyah(_currentPlayingAyah);

      // Start the mock playback timer (moves to the next Ayah every 4 seconds)
      _playbackTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _currentPlayingAyah++;
        int maxAyahs = getVerseCount(_selectedSurah);

        if (_currentPlayingAyah > maxAyahs) {
          // Reached the end of the Surah
          _stopPlay();
        } else {
          _highlightAndScrollToAyah(_currentPlayingAyah);
          setState(
                () {},
          ); // Update the UI to show the 'pause' button on the new Ayah
        }
      });
    }
  }

  void _stopPlay() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentPlayingAyah = 0;
    });
    _highlightsNotifier.value = [];
  }

  @override
  void dispose() {
    _highlightsNotifier.dispose();
    _playbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedSurah,
            dropdownColor: Theme.of(context).cardColor,
            iconEnabledColor: primaryColor,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            items: List.generate(114, (index) {
              int surahNum = index + 1;
              return DropdownMenuItem(
                value: surahNum,
                child: Text('سورة ${getSurahNameArabic(surahNum)}'),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                // Stop playback when switching surahs
                _stopPlay();

                setState(() {
                  _selectedSurah = value;
                  _highlightsNotifier.value = [];
                });

                if (_itemScrollController.isAttached) {
                  _itemScrollController.jumpTo(index: 0);
                }
              }
            },
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: QuranSurahListView(
          surahNumber: _selectedSurah,
          highlights: _highlightsNotifier.value,

          itemScrollController: _itemScrollController,
          fontSize: 25,
          initialScrollIndex: widget.highlightAyah ?? 0,
          isTajweed: true,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
          ayahBuilder:
              (
              context,
              surahNumber,
              verseNumber,
              pageNumber,
              othmanicText,
              isHighlighted,
              highlightColor,
              ) {
            // Check if this specific Ayah is currently "playing"
            final bool isCurrentlyPlaying =
                _isPlaying && _currentPlayingAyah == verseNumber;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? highlightColor.withOpacity(0.15)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHighlighted
                      ? highlightColor
                      : primaryColor.withOpacity(0.1),
                  width: isHighlighted ? 1.5 : 1,
                ),
                boxShadow: [
                  if (!isDark && !isHighlighted)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'آية $verseNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Dynamic Play/Pause Button
                            InkWell(
                              onTap: () => _togglePlay(verseNumber),
                              child: Icon(
                                isCurrentlyPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_outline,
                                size: 26,
                                color: isCurrentlyPlaying
                                    ? const Color(0xFFD4AF37)
                                    : primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.copy, size: 18, color: primaryColor),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.share_outlined,
                              size: 18,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: othmanicText
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}