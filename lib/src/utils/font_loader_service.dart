import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Defines how fonts are stored and loaded
enum FontStorageMode {
  /// Stores extracted fonts permanently on disk (best performance)
  permanentDisk,

  /// Keeps fonts only in RAM (no storage usage, slower startup)
  memoryOnly,
}

class QcfFontLoader {
  /// Prevent duplicate loading for same page
  static final Map<int, Future<void>> _loadingTasks = {};

  /// Tracks already loaded fonts in engine
  static final Set<int> _loadedPages = {};

  /// Current storage mode
  static FontStorageMode _currentMode = FontStorageMode.permanentDisk;

  /// Total Quran pages
  static const int totalPages = 604;

  /// Pages loaded on startup for fast UX

  /// ================= INITIALIZATION =================
  /// Initializes fonts with fast startup strategy:
  /// - Loads only first pages immediately
  /// - Loads remaining fonts in background
  /// ================= INITIALIZATION =================
  static Future<void> setupFontsAtStartup({
    required Function(double progress) onProgress,
    FontStorageMode mode = FontStorageMode.permanentDisk,
  }) async {
    _currentMode = mode;

    Directory? fontDir;
    if (_currentMode == FontStorageMode.permanentDisk) {
      fontDir = await _getFontDirectory();
    }

    int existingFontsCount = 0;
    if (fontDir != null) {
      for (int i = 1; i <= totalPages; i++) {
        final fontName = _getFontName(i);
        final file = File('${fontDir.path}/$fontName.ttf');
        if (file.existsSync() && file.lengthSync() > 1000) {
          existingFontsCount++;
        }
      }
    }

    if (existingFontsCount == totalPages) {
      const int batchSize = 50;

      for (int i = 1; i <= totalPages; i += batchSize) {
        int end = (i + batchSize - 1 < totalPages) ? i + batchSize - 1 : totalPages;

        List<Future<void>> batchTasks = [];
        for (int j = i; j <= end; j++) {
          batchTasks.add(ensureFontLoaded(j));
        }

        await Future.wait(batchTasks);
        onProgress(end / totalPages);
      }
    }
    else {
      for (int i = 1; i <= totalPages; i++) {
        await ensureFontLoaded(i);
        onProgress(i / totalPages);
      }
    }
  }

  /// ================= STORAGE =================
  /// Returns directory where fonts are stored
  static Future<Directory> _getFontDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${dir.path}/qcf_fonts');

    if (!fontDir.existsSync()) {
      fontDir.createSync(recursive: true);
    }
    return fontDir;
  }

  /// ================= BACKGROUND PROCESS =================
  /// Extracts remaining fonts gradually without blocking UI
  static Future<void> _processRemainingFonts(
      int start,
      int end,
      Directory? fontDir,
      ) async {
    for (int i = start; i <= end; i++) {
      try {
        await _prepareFontFileIfNeeded(i, fontDir);
      } catch (_) {}

      /// Yield to UI thread to avoid frame drops
      await Future(() {});
    }
  }

  /// ================= PUBLIC METHODS =================
  /// Ensures font is loaded once (safe for multiple calls)
  static Future<void> ensureFontLoaded(int pageNumber) {
    if (_loadedPages.contains(pageNumber)) return Future.value();

    if (_loadingTasks.containsKey(pageNumber)) {
      return _loadingTasks[pageNumber]!;
    }

    final task = _loadFontInternal(pageNumber);

    _loadingTasks[pageNumber] = task;

    task.then((_) {
      _loadedPages.add(pageNumber);
    }).whenComplete(() {
      _loadingTasks.remove(pageNumber);
    });

    return task;
  }

  /// Checks if font is already loaded
  static bool isFontLoaded(int pageNumber) {
    return _loadedPages.contains(pageNumber);
  }

  /// ================= SMART PRELOADING =================
  /// Preloads nearby pages for smooth scrolling
  static Future<void> preloadPages(int currentPage,
      {int radius = 5}) async {
    List<int> pages = [];

    for (int i = 0; i <= radius; i++) {
      if (i == 0) {
        pages.add(currentPage);
      } else {
        int next = currentPage + i;
        int prev = currentPage - i;

        if (next <= totalPages) pages.add(next);
        if (prev >= 1) pages.add(prev);
      }
    }

    for (int page in pages) {
      if (_loadedPages.contains(page) ||
          _loadingTasks.containsKey(page)) continue;

      await ensureFontLoaded(page);

      /// Small delay for smoother scrolling
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  /// ================= CORE LOADING =================
  /// Loads font from disk or extracts it if missing

  static Future<void> _loadFontInternal(int pageNumber) async {
    final fontName = _getFontName(pageNumber);
    Uint8List? fontBytes;

    if (_currentMode == FontStorageMode.permanentDisk) {
      final fontDir = await _getFontDirectory();
      final fontPath = '${fontDir.path}/$fontName.ttf';
      final file = File(fontPath);

      // 1. فحص سريع وقراءة مباشرة من الذاكرة بدون Isolate (سريع جداً)
      if (await file.exists() && await file.length() > 1000) {
        fontBytes = await file.readAsBytes();
      }
      // 2. لو الملف مش موجود، هنا بس نستخدم Isolate عشان نفك الضغط (أول مرة فقط)
      else {
        final zipBytes = await _loadZip(fontName);

        fontBytes = await Isolate.run(() {
          final extracted = _extractFont(zipBytes);
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(extracted, flush: true);
          return extracted;
        });
      }
    } else {
      /// Memory-only mode: extract directly
      final zipBytes = await _loadZip(fontName);
      fontBytes = await Isolate.run(() => _extractFont(zipBytes));
    }

    /// Register font dynamically in Flutter engine
    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(fontBytes!.buffer)));
    await loader.load();
  }

  /// ================= HELPERS =================
  /// Ensures font file exists on disk (background preparation)
  static Future<void> _prepareFontFileIfNeeded(
      int page, Directory? dir) async {
    if (_currentMode != FontStorageMode.permanentDisk) return;

    final fontName = _getFontName(page);
    final path = '${dir!.path}/$fontName.ttf';
    final file = File(path);

    if (file.existsSync() && file.lengthSync() > 1000) return;

    final zipBytes = await _loadZip(fontName);

    final extracted = await Isolate.run(() => _extractFont(zipBytes));
    await file.writeAsBytes(extracted, flush: true);
  }

  /// Loads zipped font from assets
  static Future<Uint8List> _loadZip(String fontName) async {
    final data = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
    );
    return data.buffer.asUint8List();
  }

  /// Generates font name based on page number
  static String _getFontName(int page) {
    return 'QCF4_tajweed_${page.toString().padLeft(3, '0')}';
  }

  /// Extracts TTF font from ZIP archive
  static Uint8List _extractFont(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.name.endsWith('.ttf')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw Exception("Font not found in archive");
  }
}