import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Application entry point.
///
/// Initializes Flutter bindings, configures the system UI overlay, and
/// launches the root widget [MyApp].
void main() {
  // Ensure Flutter bindings are initialized before using platform channels.
  WidgetsFlutterBinding.ensureInitialized();

  // Make the status bar transparent so the app content extends underneath it.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const MyApp());
}

/// Global notifier controlling the app's [ThemeMode].
///
/// Toggled from the showcase home screen app bar so the whole app can switch
/// between light and dark themes at runtime.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Root application widget.
///
/// Wraps a [MaterialApp] in a [ValueListenableBuilder] so that changes to
/// [themeNotifier] rebuild the app with the appropriate light/dark themes.
class MyApp extends StatelessWidget {
  /// Creates the root [MyApp] widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the global theme mode notifier and rebuild on change.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'QCF Quran Plus Showcase',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          // Light theme configuration.
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            fontFamily: 'Cairo',
            scaffoldBackgroundColor: const Color(0xFFFBF6EE),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4E342E),
              secondary: Color(0xFF8D6E63),
              surface: Color(0xFFF9F1E3),
            ),
            cardColor: const Color(0xFFF9F1E3),
          ),
          // Dark theme configuration.
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: 'Cairo',
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              secondary: Color(0xFFA1887F),
              surface: Color(0xFF1E1E1E),
            ),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: const FontStartupScreen(),
        );
      },
    );
  }
}

/// Splash-like screen that initializes the QCF fonts and Quran data.
///
/// Shows a progress bar while [QcfFontLoader.setupFontsAtStartup] runs, then
/// navigates to [ShowcaseHomeScreen] once initialization completes.
class FontStartupScreen extends StatefulWidget {
  /// Creates the [FontStartupScreen].
  const FontStartupScreen({super.key});

  @override
  State<FontStartupScreen> createState() => _FontStartupScreenState();
}

class _FontStartupScreenState extends State<FontStartupScreen> {
  /// Current progress value between 0.0 and 1.0.
  double _progress = 0;

  /// Human-readable status message shown under the title.
  String _status = 'جاري تجهيز خطوط القرآن...';

  @override
  void initState() {
    super.initState();
    // Kick off font and data initialization as soon as the widget mounts.
    _initializeFonts();
  }

  /// Runs the startup initialization pipeline.
  ///
  /// Delegates to [QcfFontLoader.setupFontsAtStartup] for fonts and parallel
  /// Quran data loading, then navigates to the showcase home screen.
  Future<void> _initializeFonts() async {
    await QcfFontLoader.setupFontsAtStartup(
      onProgress: (progress) {
        // Ignore callbacks after the widget has been disposed.
        if (!mounted) return;
        setState(() {
          _progress = progress.clamp(0, 1).toDouble();
          _status =
              'جاري تجهيز الخطوط... ${(_progress * 100).toStringAsFixed(1)}%';
        });
      },
    );

    // Guard against disposal during the async gap.
    if (!mounted) return;
    setState(() {
      _progress = 1;
      _status = 'تم تجهيز خطوط القرآن';
    });

    // Brief pause so the user can see the "complete" state before navigating.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Replace the splash with the main showcase screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShowcaseHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decorative app icon.
              Icon(Icons.menu_book_rounded, size: 92, color: primary),
              const SizedBox(height: 20),
              const Text(
                'QCF Quran Plus',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Status line updated during initialization.
              Text(
                _status,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(height: 24),
              // Determinate progress bar bound to [_progress].
              SizedBox(
                width: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main showcase screen listing every feature exposed by the package.
///
/// Contains shortcuts to the Mushaf demo, the surah list demo, a statistics
/// grid, an offline search card, a metadata/text API demo, and a feature list.
class ShowcaseHomeScreen extends StatefulWidget {
  /// Creates the [ShowcaseHomeScreen].
  const ShowcaseHomeScreen({super.key});

  @override
  State<ShowcaseHomeScreen> createState() => _ShowcaseHomeScreenState();
}

class _ShowcaseHomeScreenState extends State<ShowcaseHomeScreen> {
  /// Controller for the offline search input.
  final TextEditingController _searchController = TextEditingController();

  /// Number of matches reported by the last search.
  int _searchOccurrences = 0;

  /// List of matching verses from the last search.
  List<Map<String, dynamic>> _searchResults = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Executes an offline search for the given [value].
  ///
  /// Uses the package's [normalise] and [searchWords] helpers. Empty queries
  /// clear the current results.
  void _search(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchOccurrences = 0;
        _searchResults = const [];
      });
      return;
    }

    // Normalize the query before searching.
    final normalized = normalise(query);
    final result = searchWords(normalized, limit: 50);

    setState(() {
      _searchOccurrences = (result['occurences'] as int?) ?? 0;
      _searchResults = List<Map<String, dynamic>>.from(
        (result['result'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    });
  }

  /// Opens the Mushaf demo screen, optionally scrolled to a specific ayah.
  void _openMushaf({int page = 1, int? surah, int? ayah}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafDemoScreen(
          initialPage: page,
          highlightSurah: surah,
          highlightAyah: ayah,
        ),
      ),
    );
  }

  /// Opens the surah list demo screen, optionally scrolled to a specific ayah.
  void _openSurahList({int surah = 1, int? ayah}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahListDemoScreen(
          initialSurah: surah,
          highlightAyah: ayah,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QCF Quran Plus Showcase',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Theme toggle button.
          IconButton(
            tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 18),
          // Quick-access shortcut cards to the two demo screens.
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  title: 'المصحف الكامل',
                  subtitle: 'QuranPageView',
                  icon: Icons.menu_book_rounded,
                  onTap: _openMushaf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  context,
                  title: 'قائمة السورة',
                  subtitle: 'QuranSurahListView',
                  icon: Icons.view_list_rounded,
                  onTap: _openSurahList,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'إحصائيات وبيانات الباكدج'),
          const SizedBox(height: 10),
          _buildStatisticsGrid(context),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Smart Offline Search'),
          const SizedBox(height: 10),
          _buildSearchCard(context, primary),
          const SizedBox(height: 10),
          // Only show the results card when there are matches.
          if (_searchOccurrences > 0) _buildSearchResults(context),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Metadata & Text API'),
          const SizedBox(height: 10),
          _MetadataDemoCard(
            onOpenMushaf: _openMushaf,
            onOpenList: _openSurahList,
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Included interaction demos'),
          const SizedBox(height: 10),
          _buildFeatureList(context),
        ],
      ),
    );
  }

  /// Builds the hero card at the top of the screen.
  Widget _buildHeroCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: primary.withValues(alpha: 0.1),
              child:
                  Icon(Icons.auto_stories_rounded, color: primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تجربة شاملة لكل مميزات qcf_quran_plus',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'مصحف • تجويد • Highlight • Search • Metadata • Vertical Mode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a tappable action card used for the main shortcuts.
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, color: primary, size: 36),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a grid of statistics derived from the package's constants.
  Widget _buildStatisticsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _statCard(context, 'الصفحات', totalPagesCount, Icons.auto_stories),
            const SizedBox(width: 10),
            _statCard(context, 'السور', totalSurahCount, Icons.library_books),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard(context, 'الآيات', totalVerseCount,
                Icons.format_list_numbered_rtl),
            const SizedBox(width: 10),
            _statCard(
                context, 'الأجزاء', totalJuzCount, Icons.pie_chart_outline),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard(context, 'مكية', totalMakkiSurahs,
                Icons.location_on_outlined),
            const SizedBox(width: 10),
            _statCard(context, 'مدنية', totalMadaniSurahs,
                Icons.location_city_outlined),
          ],
        ),
      ],
    );
  }

  /// Builds a single statistic card.
  Widget _statCard(
      BuildContext context, String label, int value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            children: [
              Icon(icon,
                  size: 26, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '$value',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the search input card.
  Widget _buildSearchCard(BuildContext context, Color primary) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _searchController,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'اكتب كلمة أو جزءًا من آية…',
            prefixIcon: Icon(Icons.search, color: primary),
            // Clear button resets both the field and the search state.
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _search('');
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: primary.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }

  /// Builds the list of search results.
  Widget _buildSearchResults(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عدد النتائج: $_searchOccurrences',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary),
            ),
            const SizedBox(height: 10),
            // Render each match as a ListTile with quick actions.
            ..._searchResults.map((result) {
              final surah = result['sora'] as int;
              final ayah = result['aya_no'] as int;
              final page = getPageNumber(surah, ayah);
              final text = result['text'].toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: QuranTextStyles.hafsStyle(fontSize: 21),
                  ),
                  subtitle: Text(
                    'سورة ${getSurahNameArabic(surah)} • آية $ayah • صفحة $page',
                  ),
                  trailing: Wrap(
                    children: [
                      // Jump directly to this ayah in the Mushaf demo.
                      IconButton(
                        tooltip: 'فتح في المصحف',
                        icon: const Icon(Icons.menu_book_outlined),
                        onPressed: () => _openMushaf(
                          page: page,
                          surah: surah,
                          ayah: ayah,
                        ),
                      ),
                      // Jump to this ayah in the surah list demo.
                      IconButton(
                        tooltip: 'فتح في القائمة',
                        icon: const Icon(Icons.view_list_outlined),
                        onPressed: () => _openSurahList(
                          surah: surah,
                          ayah: ayah,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Builds the static list of package features.
  Widget _buildFeatureList(BuildContext context) {
    // Tuple of (icon, title, description) for each feature.
    final features = <(IconData, String, String)>[
      (
        Icons.palette_outlined,
        'Tajweed',
        'Light and dark rendering with Tajweed colors.'
      ),
      (
        Icons.touch_app_outlined,
        'Long Press',
        'Context menu anchored to the exact touch location.'
      ),
      (
        Icons.highlight_alt_outlined,
        'Verse Highlighting',
        'Dynamic audio/bookmark-style verse highlights.'
      ),
      (
        Icons.text_fields_outlined,
        'Word Interaction',
        'Word tap callbacks and word highlight support.'
      ),
      (
        Icons.view_carousel_outlined,
        'Two Page Layout',
        'Automatic wide-screen double-page mode.'
      ),
      (
        Icons.speed_outlined,
        'Font Preloading',
        'Startup font initialization plus page preloading.'
      ),
      (
        Icons.format_list_bulleted,
        'Scrollable Surah',
        'Vertical Surah mode with programmatic scrolling.'
      ),
      (
        Icons.data_object,
        'Metadata API',
        'Surah, page, Juz, quarter, revelation, and text helpers.'
      ),
    ];

    return Card(
      elevation: 0,
      child: Column(
        children: features
            .map(
              (item) => ListTile(
                leading: Icon(
                  item.$1,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  item.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(item.$3),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Builds a small section title with a leading bullet dot.
  Widget _buildSectionTitle(BuildContext context, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(Icons.circle, size: 9, color: primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    );
  }
}

/// A demo card that showcases the metadata and text helpers exposed by the
/// package for a user-selectable surah and ayah.
class _MetadataDemoCard extends StatefulWidget {
  /// Callback used to open the Mushaf demo at a specific page/ayah.
  final void Function({int page, int? surah, int? ayah}) onOpenMushaf;

  /// Callback used to open the surah list demo at a specific ayah.
  final void Function({int surah, int? ayah}) onOpenList;

  const _MetadataDemoCard({
    required this.onOpenMushaf,
    required this.onOpenList,
  });

  @override
  State<_MetadataDemoCard> createState() => _MetadataDemoCardState();
}

class _MetadataDemoCardState extends State<_MetadataDemoCard> {
  /// Currently selected surah number (1-114).
  int _surah = 2;

  /// Currently selected ayah number.
  int _ayah = 255;

  @override
  Widget build(BuildContext context) {
    // Clamp the selected ayah to the valid range of the current surah.
    final maxAyahs = getVerseCount(_surah);
    final safeAyah = _ayah.clamp(1, maxAyahs);
    if (safeAyah != _ayah) {
      _ayah = safeAyah;
    }

    // Resolve metadata for the currently selected ayah.
    final page = getPageNumber(_surah, _ayah);
    final rawVerse = getVerse(_surah, _ayah);
    final noDiacritics = removeDiacritics(rawVerse);
    final endGlyph = getAyaNoQCFLite(_surah, _ayah);
    final hizbExact = getHizbTextByPage(page, isArabic: true);
    final hizbCurrent = getCurrentHizbTextForPage(page, isArabic: true);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Surah and ayah selectors.
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _surah,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'السورة'),
                    items: List.generate(
                      totalSurahCount,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(getSurahNameArabic(index + 1)),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _surah = value;
                        _ayah = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: safeAyah,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الآية'),
                    items: List.generate(
                      maxAyahs,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _ayah = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Metadata rows demonstrating the various helper functions.
            _infoRow(context, 'اسم السورة بالعربي',
                getSurahNameArabic(_surah)),
            _infoRow(context, 'اسم السورة بالإنجليزي',
                getSurahNameEnglish(_surah)),
            _infoRow(context, 'مكان النزول', getPlaceOfRevelation(_surah)),
            _infoRow(context, 'عدد آيات السورة', '$maxAyahs'),
            _infoRow(context, 'صفحة الآية', '$page'),
            _infoRow(context, 'الجزء', '${getJuzNumber(_surah, _ayah)}'),
            _infoRow(context, 'الربع', '${getQuarterNumber(_surah, _ayah)}'),
            _infoRow(
              context,
              'Hizb exact on page',
              hizbExact.isEmpty ? 'لا يبدأ هنا' : hizbExact,
            ),
            _infoRow(context, 'Current Hizb on page', hizbCurrent),
            const Divider(height: 24),
            // Uthmanic text with the ayah number glyph appended.
            Text(
              'النص العثماني',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '$rawVerse $endGlyph',
              style: QuranTextStyles.hafsStyle(fontSize: 22),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 10),
            // Same text with diacritics removed.
            Text(
              'بعد إزالة التشكيل',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 5),
            Text(noDiacritics, textAlign: TextAlign.right),
            const SizedBox(height: 14),
            // Shortcut buttons to open this ayah in the demos.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => widget.onOpenMushaf(
                    page: page,
                    surah: _surah,
                    ayah: _ayah,
                  ),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('المصحف'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpenList(
                    surah: _surah,
                    ayah: _ayah,
                  ),
                  icon: const Icon(Icons.view_list),
                  label: const Text('القائمة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a key/value metadata row with a bold label.
  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Demo screen that renders the Quran using [QuranPageView].
///
/// Demonstrates:
/// - Page navigation via an external [PageController].
/// - Tajweed toggle and dark mode.
/// - Verse highlighting, including a temporary highlight applied when the
///   screen is opened with a specific ayah.
/// - Long-press context menu anchored to the touch location.
/// - Custom page header, surah header, and Basmallah builders.
/// - Two-page layout toggle.
class MushafDemoScreen extends StatefulWidget {
  /// The page to open when the screen first appears.
  final int initialPage;

  /// Optional surah to highlight when the screen opens.
  final int? highlightSurah;

  /// Optional ayah to highlight when the screen opens.
  final int? highlightAyah;

  /// Creates a [MushafDemoScreen].
  const MushafDemoScreen({
    super.key,
    this.initialPage = 1,
    this.highlightSurah,
    this.highlightAyah,
  });

  @override
  State<MushafDemoScreen> createState() => _MushafDemoScreenState();
}

class _MushafDemoScreenState extends State<MushafDemoScreen> {
  /// Controller for the underlying [QuranPageView].
  late final PageController _pageController;

  /// Active verse highlights.
  final List<HighlightVerse> _highlights = [];

  /// Whether Tajweed coloring is enabled.
  bool _tajweed = true;

  /// Whether the two-page layout is enabled.
  bool _twoPageLayout = true;

  /// The 1-based page currently visible.
  int _currentPage = 1;

  /// Timer used to remove temporary highlights after a short delay.
  Timer? _temporaryHighlightTimer;

  @override
  void initState() {
    super.initState();

    // Clamp the initial page to the valid range.
    _currentPage = widget.initialPage.clamp(1, totalPagesCount);

    // The controller uses a 0-based index internally.
    _pageController = PageController(initialPage: _currentPage - 1);

    // If the caller requested an initial highlight, apply it once the widget
    // is laid out (so we have a valid context for theme colors).
    if (widget.highlightSurah != null && widget.highlightAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setHighlight(
          widget.highlightSurah!,
          widget.highlightAyah!,
          page: _currentPage,
          temporary: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _temporaryHighlightTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Adds a highlight for the given [surah] and [ayah].
  ///
  /// When [temporary] is `true`, the highlight is removed after 3 seconds.
  void _setHighlight(
    int surah,
    int ayah, {
    required int page,
    bool temporary = false,
  }) {
    // Choose a theme-aware highlight color.
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.35)
        : const Color(0xFF8D6E63).withValues(alpha: 0.24);

    setState(() {
      // Remove any existing highlight for the same verse first.
      _highlights.removeWhere(
        (item) => item.surah == surah && item.verseNumber == ayah,
      );
      _highlights.add(
        HighlightVerse(
          surah: surah,
          verseNumber: ayah,
          page: page,
          color: color,
        ),
      );
    });

    if (temporary) {
      // Cancel any pending removal and schedule a new one.
      _temporaryHighlightTimer?.cancel();
      _temporaryHighlightTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _highlights.removeWhere(
            (item) => item.surah == surah && item.verseNumber == ayah,
          );
        });
      });
    }
  }

  /// Removes the highlight for the given verse if present.
  void _removeHighlight(int surah, int ayah) {
    setState(() {
      _highlights.removeWhere(
        (item) => item.surah == surah && item.verseNumber == ayah,
      );
    });
  }

  /// Opens the ayah context menu anchored to [globalPosition].
  void _showAyahContextMenu(
    BuildContext context,
    int surah,
    int ayah,
    Offset globalPosition,
  ) {
    // Resolve the currently visible page number.
    final page = _pageController.hasClients
        ? (_pageController.page?.round() ?? (_currentPage - 1)) + 1
        : _currentPage;

    _showPositionedAyahMenu(
      context: context,
      surah: surah,
      ayah: ayah,
      page: page,
      globalPosition: globalPosition,
      isHighlighted: _highlights.any(
        (item) => item.surah == surah && item.verseNumber == ayah,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Current Hizb label for the visible page (used in the app bar title).
    final hizb = getCurrentHizbTextForPage(_currentPage, isArabic: true);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المصحف • صفحة $_currentPage'),
            if (hizb.isNotEmpty)
              Text(
                hizb,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Toggle Tajweed rendering.
          IconButton(
            tooltip: 'تبديل التجويد',
            icon: Icon(_tajweed ? Icons.palette : Icons.palette_outlined),
            onPressed: () => setState(() => _tajweed = !_tajweed),
          ),
          // Clear all highlights.
          IconButton(
            tooltip: 'مسح التظليل',
            icon: const Icon(Icons.highlight_remove_outlined),
            onPressed: () => setState(_highlights.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: QuranPageView(
          pageController: _pageController,
          // Pass an unmodifiable view so the child cannot mutate our list.
          highlights: List<HighlightVerse>.unmodifiable(_highlights),
          isDarkMode: isDark,
          isTajweed: _tajweed,
          enableTwoPageLayout: _twoPageLayout,
          pageBackgroundColor:
              isDark ? const Color(0xFF121212) : const Color(0xFFFBF6EE),
          ayahStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          // Custom top bar showing a hint and the layout toggle.
          topBar: _buildMushafTopBar(context),
          // Custom bottom bar showing the swipe hint and highlight count.
          bottomBar: _buildMushafBottomBar(context),
          // Custom page header showing the Hizb label and page number.
          pageHeaderBuilder: (context, pageNumber) {
            final exact = getHizbTextByPage(pageNumber, isArabic: true);
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                exact.isEmpty
                    ? 'صفحة $pageNumber'
                    : '$exact • صفحة $pageNumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            );
          },
          // Custom surah header.
          surahHeaderBuilder: (context, surahNumber) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'سورة ${getSurahNameArabic(surahNumber)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          },
          // Custom Basmallah rendering.
          basmallahBuilder: (context, surahNumber) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                textAlign: TextAlign.center,
                style: QuranTextStyles.hafsStyle(fontSize: 20),
              ),
            );
          },
          // Keep track of the visible page for the app bar title.
          onPageChanged: (pageNumber) {
            setState(() => _currentPage = pageNumber);
          },
          // Long-press opens the anchored context menu.
          onLongPress: (surahNumber, verseNumber, details) {
            _showAyahContextMenu(
              context,
              surahNumber,
              verseNumber,
              details.globalPosition,
            );
          },
        ),
      ),
    );
  }

  /// Builds the Mushaf demo's top bar with a hint and layout toggle.
  Widget _buildMushafTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Long press an Ayah to open the anchored action menu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          // Toggle between single-page and two-page layouts.
          IconButton(
            tooltip: _twoPageLayout ? 'صفحة واحدة' : 'صفحتان',
            icon: Icon(
              _twoPageLayout
                  ? Icons.chrome_reader_mode
                  : Icons.chrome_reader_mode_outlined,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _twoPageLayout = !_twoPageLayout),
          ),
        ],
      ),
    );
  }

  /// Builds the Mushaf demo's bottom bar with a swipe hint and highlight count.
  Widget _buildMushafBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swipe,
            size: 15,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            'Swipe to navigate • ${_highlights.length} highlight(s)',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Demo screen that renders a single surah using [QuranSurahListView].
///
/// Demonstrates:
/// - Surah selection via a dropdown in the app bar.
/// - Verse highlighting and programmatic scrolling to a specific ayah.
/// - Word-level highlights and word-tap callbacks.
/// - Simulated playback: a timer advances the highlighted ayah every 3 seconds.
/// - Custom ayah container via an [ayahBuilder].
/// - Long-press context menu anchored to the touch location.
class SurahListDemoScreen extends StatefulWidget {
  /// The surah to open when the screen first appears.
  final int initialSurah;

  /// Optional ayah to highlight and scroll to when the screen opens.
  final int? highlightAyah;

  /// Creates a [SurahListDemoScreen].
  const SurahListDemoScreen({
    super.key,
    this.initialSurah = 1,
    this.highlightAyah,
  });

  @override
  State<SurahListDemoScreen> createState() => _SurahListDemoScreenState();
}

class _SurahListDemoScreenState extends State<SurahListDemoScreen> {
  /// Currently selected surah number.
  late int _surah;

  /// Controller used for programmatic scrolling to a specific ayah.
  final ItemScrollController _scrollController = ItemScrollController();

  /// Active verse highlights.
  final List<HighlightVerse> _highlights = [];

  /// Active word-level highlights.
  final List<WordHighlight> _wordHighlights = [];

  /// Timer driving the simulated playback.
  Timer? _playTimer;

  /// Whether playback is active.
  bool _playing = false;

  /// The ayah number currently being "played".
  int _playingAyah = 0;

  /// Whether Tajweed coloring is enabled.
  bool _tajweed = true;

  @override
  void initState() {
    super.initState();
    _surah = widget.initialSurah.clamp(1, totalSurahCount);

    // After the first frame: apply initial highlight and seed a demo word highlight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ayah = widget.highlightAyah;
      if (ayah != null) {
        _highlightAyah(ayah, scroll: true);
      }
      _seedWordHighlightDemo();
    });
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  /// Adds a sample word highlight on the first word of the first ayah.
  ///
  /// This demonstrates how to highlight a specific word, e.g. during
  /// word-by-word audio playback.
  void _seedWordHighlightDemo() {
    // Skip if the sample highlight is already present.
    final exists = _wordHighlights.any(
      (item) =>
          item.surah == _surah &&
          item.verseNumber == 1 &&
          item.wordIndex == 0,
    );
    if (exists) return;

    setState(() {
      _wordHighlights.add(
        WordHighlight(
          surah: _surah,
          verseNumber: 1,
          wordIndex: 0,
          textColor: Colors.white,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    });
  }

  /// Switches to a new surah, clearing highlights and resetting scroll.
  void _changeSurah(int? value) {
    if (value == null) return;
    _stopPlayback();
    setState(() {
      _surah = value;
      _highlights.clear();
      _wordHighlights.clear();
    });
    _scrollController.jumpTo(index: 0);
    // Reseed the demo word highlight after the new surah is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedWordHighlightDemo();
    });
  }

  /// Highlights a specific ayah, optionally scrolling it into view.
  void _highlightAyah(int ayah, {bool scroll = false}) {
    final page = getPageNumber(_surah, ayah);

    // Choose a theme-aware highlight color.
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.38)
        : const Color(0xFF8D6E63).withValues(alpha: 0.22);

    setState(() {
      _highlights
        ..clear()
        ..add(
          HighlightVerse(
            surah: _surah,
            verseNumber: ayah,
            page: page,
            color: color,
          ),
        );
    });

    if (scroll && _scrollController.isAttached) {
      _scrollController.scrollTo(
        index: ayah,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        alignment: 0.2,
      );
    }
  }

  /// Toggles simulated playback starting from [startAyah].
  ///
  /// When playing, the highlighted ayah advances every 3 seconds until the
  /// end of the surah is reached.
  void _togglePlayback(int startAyah) {
    if (_playing) {
      _stopPlayback();
      return;
    }

    _playing = true;
    _playingAyah = startAyah;
    setState(() {});
    _highlightAyah(_playingAyah, scroll: true);

    _playTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final maxAyah = getVerseCount(_surah);
      if (_playingAyah >= maxAyah) {
        // Reached the last ayah; stop playback.
        _stopPlayback();
        return;
      }
      _playingAyah++;
      _highlightAyah(_playingAyah, scroll: true);
      setState(() {});
    });
  }

  /// Stops simulated playback and clears the current highlight.
  void _stopPlayback() {
    _playTimer?.cancel();
    _playTimer = null;
    _playing = false;
    _playingAyah = 0;
    _highlights.clear();
    setState(() {});
  }

  /// Opens the ayah context menu anchored to [details.globalPosition].
  void _showAyahContextMenu(
    BuildContext context,
    int surah,
    int ayah,
    LongPressStartDetails details,
  ) {
    final page = getPageNumber(surah, ayah);
    _showPositionedAyahMenu(
      context: context,
      surah: surah,
      ayah: ayah,
      page: page,
      globalPosition: details.globalPosition,
      isHighlighted: _highlights.any(
        (item) => item.surah == surah && item.verseNumber == ayah,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        // Surah selector in the title.
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _surah,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
            dropdownColor: Theme.of(context).cardColor,
            items: List.generate(
              totalSurahCount,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('سورة ${getSurahNameArabic(index + 1)}'),
              ),
            ),
            onChanged: _changeSurah,
          ),
        ),
        centerTitle: true,
        actions: [
          // Toggle Tajweed rendering.
          IconButton(
            tooltip: 'تبديل التجويد',
            icon: Icon(_tajweed ? Icons.palette : Icons.palette_outlined),
            onPressed: () => setState(() => _tajweed = !_tajweed),
          ),
          // Start or stop the simulated playback.
          IconButton(
            tooltip: 'إيقاف التشغيل',
            icon: Icon(
              _playing
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            onPressed: () => _playing ? _stopPlayback() : _togglePlayback(1),
          ),
        ],
      ),
      body: SafeArea(
        child: QuranSurahListView(
          surahNumber: _surah,
          // Pass unmodifiable views so the child cannot mutate our lists.
          highlights: List<HighlightVerse>.unmodifiable(_highlights),
          wordHighlights: List<WordHighlight>.unmodifiable(_wordHighlights),
          itemScrollController: _scrollController,
          initialScrollIndex: widget.highlightAyah ?? 0,
          fontSize: 25,
          isTajweed: _tajweed,
          isDarkMode: isDark,
          // Show a snack bar with the tapped word's details.
          onWordTap: (surah, ayah, wordIndex, word) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('الكلمة رقم ${wordIndex + 1}: $word'),
                duration: const Duration(milliseconds: 900),
              ),
            );
          },
          // Long-press opens the anchored context menu.
          onLongPress: (surah, ayah, details) {
            _showAyahContextMenu(context, surah, ayah, details);
          },
          // Custom surah header.
          surahHeaderBuilder: (context, surahNumber) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'سورة ${getSurahNameArabic(surahNumber)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          },
          // Custom Basmallah rendering.
          basmallahBuilder: (context, surahNumber) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                textAlign: TextAlign.center,
                style: QuranTextStyles.hafsStyle(fontSize: 20),
              ),
            );
          },
          // Custom ayah container with playback and copy actions.
          ayahBuilder: (
            context,
            surahNumber,
            verseNumber,
            pageNumber,
            ayahWidget,
            isHighlighted,
            highlightColor,
          ) {
            final playing = _playing && _playingAyah == verseNumber;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              decoration: BoxDecoration(
                // Background reflects the current highlight state.
                color: isHighlighted
                    ? highlightColor.withValues(alpha: 0.14)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlighted
                      ? highlightColor
                      : primary.withValues(alpha: 0.08),
                  width: isHighlighted ? 1.6 : 1,
                ),
                // Soft shadow only for unhighlighted light-mode cards.
                boxShadow: isDark || isHighlighted
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: ayah number chip and per-ayah actions.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: Icon(
                          Icons.format_list_numbered_rtl,
                          size: 15,
                          color: primary,
                        ),
                        label: Text('آية $verseNumber'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Row(
                        children: [
                          // Play/pause the simulated playback at this ayah.
                          IconButton(
                            tooltip: playing ? 'إيقاف' : 'تشغيل تجريبي',
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle
                                  : Icons.play_circle_outline,
                              color: playing
                                  ? const Color(0xFFD4AF37)
                                  : primary,
                            ),
                            onPressed: () => _togglePlayback(verseNumber),
                          ),
                          // Copy the raw verse text to the clipboard.
                          IconButton(
                            tooltip: 'نسخ',
                            icon:
                                const Icon(Icons.copy_outlined, size: 20),
                            onPressed: () async {
                              final text =
                                  getVerse(surahNumber, verseNumber);
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ الآية'),
                                  duration: Duration(milliseconds: 700),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Small metadata line.
                  Text(
                    'صفحة $pageNumber • ${getPlaceOfRevelation(surahNumber)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The actual rendered ayah content.
                  ayahWidget,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows the anchored ayah context menu at [globalPosition].
///
/// The menu is implemented as a [showGeneralDialog] with a transparent
/// barrier so the user can tap anywhere outside to dismiss it. The position
/// is clamped so the menu always stays within the overlay bounds.
Future<void> _showPositionedAyahMenu({
  required BuildContext context,
  required int surah,
  required int ayah,
  required int page,
  required Offset globalPosition,
  required bool isHighlighted,
}) async {
  final overlayState = Overlay.of(context);
  final renderBox = overlayState.context.findRenderObject() as RenderBox;
  final overlaySize = renderBox.size;

  // Approximate menu size used for boundary clamping.
  const menuWidth = 270.0;
  const estimatedMenuHeight = 320.0;
  const margin = 12.0;

  // Center the menu horizontally around the touch point, then clamp.
  final double left = (globalPosition.dx - menuWidth / 2)
      .clamp(margin, overlaySize.width - menuWidth - margin)
      .toDouble();

  // Place the menu slightly below the touch point, then clamp vertically.
  final double top = (globalPosition.dy + 10)
      .clamp(margin, overlaySize.height - estimatedMenuHeight - margin)
      .toDouble();

  // Capture the navigator so callbacks can pop the dialog safely.
  final navigator = Navigator.of(context);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Ayah menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          // Full-screen tap catcher to dismiss the menu.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          // The menu itself, positioned via clamped left/top.
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: _AyahContextMenu(
                surah: surah,
                ayah: ayah,
                page: page,
                isHighlighted: isHighlighted,
                onClose: () => Navigator.of(dialogContext).pop(),
                // Copy the verse text and show a confirmation snack bar.
                onCopy: () async {
                  final text = getVerse(surah, ayah);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!navigator.context.mounted) return;
                  navigator.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الآية'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
                },
                // Toggle the highlight on the parent state.
                onHighlight: () {
                  navigator.pop();
                  _highlightFromMenu(
                    context,
                    surah,
                    ayah,
                    page,
                    isHighlighted,
                  );
                },
                // Show the details dialog.
                onDetails: () {
                  navigator.pop();
                  _showAyahDetailsDialog(context, surah, ayah, page);
                },
                // Open this ayah in the Mushaf demo.
                onOpenMushaf: () {
                  navigator.pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MushafDemoScreen(
                        initialPage: page,
                        highlightSurah: surah,
                        highlightAyah: ayah,
                      ),
                    ),
                  );
                },
                // Open this ayah in the surah list demo.
                onOpenList: () {
                  navigator.pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurahListDemoScreen(
                        initialSurah: surah,
                        highlightAyah: ayah,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
    // Fade + slight scale-in for a polished appearance.
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

/// Toggles or sets the highlight for the given ayah on whichever demo screen
/// is currently an ancestor of [context].
///
/// This works because both [_MushafDemoScreenState] and
/// [_SurahListDemoScreenState] expose their own highlight management methods.
void _highlightFromMenu(
  BuildContext context,
  int surah,
  int ayah,
  int page,
  bool wasHighlighted,
) {
  // Try the Mushaf demo first.
  final state = context.findAncestorStateOfType<_MushafDemoScreenState>();
  if (state != null) {
    if (wasHighlighted) {
      state._removeHighlight(surah, ayah);
    } else {
      state._setHighlight(surah, ayah, page: page);
    }
    return;
  }

  // Fall back to the surah list demo.
  final listState =
      context.findAncestorStateOfType<_SurahListDemoScreenState>();
  if (listState != null) {
    if (wasHighlighted) {
      listState._highlights.removeWhere(
        (item) => item.surah == surah && item.verseNumber == ayah,
      );
      listState.setState(() {});
    } else {
      listState._highlightAyah(ayah);
    }
  }
}

/// Displays a small dialog with metadata for the given ayah.
void _showAyahDetailsDialog(
  BuildContext context,
  int surah,
  int ayah,
  int page,
) {
  final juz = getJuzNumber(surah, ayah);
  final quarter = getQuarterNumber(surah, ayah);
  final revelation = getPlaceOfRevelation(surah);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('سورة ${getSurahNameArabic(surah)} • آية $ayah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('الصفحة', '$page'),
            _detailRow('الجزء', '$juz'),
            _detailRow('الربع', '$quarter'),
            _detailRow(
              'مكان النزول',
              revelation == 'Makkah' ? 'مكية' : 'مدنية',
            ),
            _detailRow('اسم السورة EN', getSurahNameEnglish(surah)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      );
    },
  );
}

/// Builds a single key/value row inside the ayah details dialog.
Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

/// The anchored popup menu shown when the user long-presses an ayah.
///
/// Each entry invokes one of the callbacks supplied by the caller. The menu
/// has a fixed width and a soft shadow so it visually floats above the page.
class _AyahContextMenu extends StatelessWidget {
  /// Surah number of the pressed ayah.
  final int surah;

  /// Ayah number of the pressed ayah.
  final int ayah;

  /// Page number that contains the pressed ayah.
  final int page;

  /// Whether the pressed ayah is currently highlighted.
  final bool isHighlighted;

  /// Called when the user taps "Close".
  final VoidCallback onClose;

  /// Called when the user taps "Copy". May complete asynchronously.
  final Future<void> Function() onCopy;

  /// Called when the user taps "Highlight" / "Remove highlight".
  final VoidCallback onHighlight;

  /// Called when the user taps "Details".
  final VoidCallback onDetails;

  /// Called when the user taps "Open in Mushaf".
  final VoidCallback onOpenMushaf;

  /// Called when the user taps "Open in surah list".
  final VoidCallback onOpenList;

  const _AyahContextMenu({
    required this.surah,
    required this.ayah,
    required this.page,
    required this.isHighlighted,
    required this.onClose,
    required this.onCopy,
    required this.onHighlight,
    required this.onDetails,
    required this.onOpenMushaf,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: 270,
      decoration: BoxDecoration(
        // Surface color from the theme so it adapts to light/dark mode.
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with surah/ayah and quick metadata.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'سورة ${getSurahNameArabic(surah)} • آية $ayah',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'صفحة $page • جزء ${getJuzNumber(surah, ayah)} • ربع ${getQuarterNumber(surah, ayah)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Menu entries.
              _menuItem(
                context,
                icon: Icons.copy_outlined,
                title: 'نسخ الآية',
                onTap: onCopy,
              ),
              _menuItem(
                context,
                icon: isHighlighted
                    ? Icons.highlight_remove_outlined
                    : Icons.highlight_alt_outlined,
                title: isHighlighted ? 'إزالة التظليل' : 'تظليل الآية',
                onTap: onHighlight,
              ),
              _menuItem(
                context,
                icon: Icons.info_outline,
                title: 'تفاصيل الآية',
                onTap: onDetails,
              ),
              _menuItem(
                context,
                icon: Icons.menu_book_outlined,
                title: 'فتح في المصحف',
                onTap: onOpenMushaf,
              ),
              _menuItem(
                context,
                icon: Icons.view_list_outlined,
                title: 'فتح في قائمة السورة',
                onTap: onOpenList,
              ),
              _menuItem(
                context,
                icon: Icons.close,
                title: 'إغلاق',
                onTap: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single tappable menu row.
  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            const Icon(Icons.chevron_left, size: 17),
          ],
        ),
      ),
    );
  }
}