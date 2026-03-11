import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';

/// A specialized utility class for managing dynamic loading of Quran Complex Fonts (QCF).
///
/// Since the Quran has 604 pages and each page may require a unique font file,
/// loading all fonts at startup is memory-intensive. This class provides:
/// * **Lazy Loading**: Fonts are only loaded when needed.
/// * **Isolate-based Extraction**: Unzipping font files happens on a background thread.
/// * **Preloading**: Predictive loading of upcoming pages for a lag-free experience.
class QcfFontLoader {
  /// Tracks active loading tasks to prevent redundant network/file requests.
  static final Map<int, Future<void>> _loadingTasks = {};

  /// Stores the numbers of pages whose fonts have successfully been registered.
  static final Set<int> _loadedPages = {};

  /// Ensures that the font for a specific [pageNumber] is loaded and registered.
  ///
  /// If the font is already loaded, it returns immediately.
  /// If a loading task is already in progress, it returns the existing [Future].
  static Future<void> ensureFontLoaded(int pageNumber) {
    if (_loadedPages.contains(pageNumber)) return Future.value();
    if (_loadingTasks.containsKey(pageNumber)) return _loadingTasks[pageNumber]!;

    final task = _loadFontInternal(pageNumber);
    _loadingTasks[pageNumber] = task;

    task.then((_) {
      _loadedPages.add(pageNumber);
    }).catchError((e) {
      debugPrint("❌ Error loading font $pageNumber: $e");
    }).whenComplete(() {
      _loadingTasks.remove(pageNumber);
    });

    return task;
  }

  /// Synchronously checks if the font for [pageNumber] is already available.
  static bool isFontLoaded(int pageNumber) {
    return _loadedPages.contains(pageNumber);
  }

  /// Internal logic to fetch, unzip, and register the font.
  ///
  /// The font is expected to be located in the package's assets folder
  /// as a `.zip` file to minimize package size.
  static Future<void> _loadFontInternal(int pageNumber) async {
    // Standard format for Quran pages (e.g., 001, 015, 604)
    String pageStr = pageNumber.toString().padLeft(3, '0');
    final String fontName = 'QCF4_tajweed_$pageStr';

    // Loads the zip file from the package assets
    final data = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
    );

    final bytes = data.buffer.asUint8List();

    // Uses Isolate.run to decode the zip on a background thread
    // to prevent UI jank (Flutter 3.7+)
    final Uint8List fontBytes = await Isolate.run(() => _extractFont(bytes));

    // Registers the font with the Flutter Engine dynamically
    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await loader.load();
  }

  /// Helper method used inside the Isolate to find the `.ttf` file within the zip.
  static Uint8List _extractFont(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.name.endsWith('.ttf')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw Exception("Font not found in zip");
  }

  /// Predictively loads fonts for pages near the [currentPage].
  ///
  /// Defaults to loading the previous 2 pages and the next 10 pages.
  /// This ensures that as the user swipes through the Mushaf, the fonts
  /// are usually ready before the page is rendered.
  static void preloadNearbyPages(int currentPage) {
    for (int i = currentPage - 2; i <= currentPage + 10; i++) {
      if (i > 0 && i <= 604) ensureFontLoaded(i);
    }
  }
}