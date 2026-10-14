import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';

/// Defines where QCF fonts are stored after extraction.
enum FontStorageMode {
  /// Fonts are persisted to the application documents directory so they can
  /// be reused across app launches without re-extracting from the bundle.
  permanentDisk,

  /// Fonts are kept only in memory for the current session. Nothing is
  /// written to disk. Useful for environments where disk access is restricted.
  memoryOnly,
}

/// A service responsible for loading, extracting, and registering QCF
/// (Quran Complex Font) font families for every page of the Quran.
///
/// The loader supports multiple variants per page:
/// - Tajweed light (default colored Tajweed rendering).
/// - Tajweed dark (recolored for dark backgrounds).
/// - No-Tajweed light (uniform black glyphs).
/// - No-Tajweed dark (uniform white glyphs).
/// - Red variant (uniform red glyphs, used for special highlights).
///
/// Fonts are shipped gzip-compressed inside the package assets. They can be
/// extracted and cached either to disk ([FontStorageMode.permanentDisk]) or
/// kept in memory ([FontStorageMode.memoryOnly]).
///
/// All public methods are static and thread-safe with respect to repeated
/// calls, since in-flight loads are coalesced through [_loadingTasks].
class QcfFontLoader {
  /// Private constructor to prevent instantiation.
  QcfFontLoader._();

  /// In-flight font load tasks, keyed by page number.
  /// Used to prevent duplicate work when the same page is requested
  /// multiple times concurrently.
  static final Map<int, Future<void>> _loadingTasks = {};

  /// Set of pages whose fonts have already been fully registered.
  static final Set<int> _loadedPages = {};

  /// Current storage mode. Set by [setupFontsAtStartup] and reused elsewhere.
  static FontStorageMode _currentMode = FontStorageMode.permanentDisk;

  /// Total number of pages in the standard Quran.
  static const int totalPages = 604;

  /// Cached directory where font files are stored when using
  /// [FontStorageMode.permanentDisk]. Reused to avoid repeated IO lookups.
  static Directory? _fontDirCache;

  /// Monotonic generation counter used to cancel stale preload operations.
  static int _generation = 0;

  /// Returns the base font family name for the given [pageNumber].
  ///
  /// Example: page 7 → `QCF4007_COLOR-Regular`.
  static String getBaseFontFamily(int pageNumber) {
    return 'QCF4${pageNumber.toString().padLeft(3, '0')}_COLOR-Regular';
  }

  /// Returns the family name for the Tajweed light variant.
  ///
  /// This is identical to the base family (the packaged font already
  /// contains the light Tajweed colors).
  static String getTajweedLightFamily(int pageNumber) {
    return getBaseFontFamily(pageNumber);
  }

  /// Returns the family name for the Tajweed dark variant.
  static String getTajweedDarkFamily(int pageNumber) {
    return '${getBaseFontFamily(pageNumber)}-d';
  }

  /// Returns the family name for the no-Tajweed light variant.
  static String getNoTajweedLightFamily(int pageNumber) {
    return '${getBaseFontFamily(pageNumber)}-n';
  }

  /// Returns the family name for the no-Tajweed dark variant.
  static String getNoTajweedDarkFamily(int pageNumber) {
    return '${getBaseFontFamily(pageNumber)}-nd';
  }

  /// Returns the family name for the red variant.
  static String getRedFamily(int pageNumber) {
    return '${getBaseFontFamily(pageNumber)}-nr';
  }

  /// Loads the configured font set during startup while reporting progress.
  ///
  /// Quran page data (word offsets + parsed lines) is loaded **in parallel**
  /// with the fonts because it runs in a separate isolate via `compute`.
  /// This reduces total startup time to `max(fontsTime, quranTime)` instead
  /// of `fontsTime + quranTime`.
  static Future<void> setupFontsAtStartup({
    required Function(double progress) onProgress,
    FontStorageMode mode = FontStorageMode.permanentDisk,
  }) async {
    _currentMode = mode;

    // ── Start loading the Quran data in parallel with the fonts ──
    // `ensureLoaded` calls `compute(...)` on a separate isolate, so it does
    // not block the main isolate and does not compete with the font loading
    // work on the same CPU.
    final Future<void> quranLoadFuture =
        QuranRepository.instance.ensureLoaded(totalPages);
    // ─────────────────────────────────────────────────────────────

    Directory? fontDir;

    // Resolve the on-disk font directory only when using permanent storage.
    if (_currentMode == FontStorageMode.permanentDisk) {
      fontDir = await _getFontDirectory();
    }

    int existingFontsCount = 0;

    // Count how many font files already exist on disk (batched for speed).
    if (fontDir != null) {
      const probeBatch = 64;

      for (int start = 1; start <= totalPages; start += probeBatch) {
        final end = (start + probeBatch - 1).clamp(1, totalPages);

        final checks = <Future<bool>>[];

        for (int page = start; page <= end; page++) {
          final file =
              File('${fontDir.path}/${getBaseFontFamily(page)}.ttf');

          // A file is considered valid only if it exists and is non-trivial.
          checks.add(() async {
            if (!await file.exists()) {
              return false;
            }
            return await file.length() > 1000;
          }());
        }

        final results = await Future.wait(checks);

        existingFontsCount += results.where((e) => e).length;
      }
    }

    if (existingFontsCount == totalPages) {
      // Fast path: every font file is already on disk. Load them in batches
      // to reduce the number of awaits and report progress after each batch.
      const batchSize = 25;

      for (int start = 1; start <= totalPages; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, totalPages);

        final tasks = <Future<void>>[];

        for (int page = start; page <= end; page++) {
          tasks.add(ensureFontLoaded(page));
        }

        await Future.wait(tasks);

        onProgress(end / totalPages);
      }
    } else {
      // Slow path: some fonts are missing. Load them one by one so progress
      // can be reported accurately.
      for (int page = 1; page <= totalPages; page++) {
        await ensureFontLoaded(page);
        onProgress(page / totalPages);
      }
    }

    // ── Ensure Quran data loading has completed before finishing the splash ──
    // In practice the data is already ready (it is faster than the fonts),
    // so this await returns immediately.
    await quranLoadFuture;
    // ────────────────────────────────────────────────────────────────────
  }

  /// Returns the directory used to cache extracted font files.
  ///
  /// The directory is created on first use and cached for subsequent calls.
  static Future<Directory> _getFontDirectory() async {
    final cached = _fontDirCache;

    if (cached != null) {
      return cached;
    }

    final appDir = await getApplicationDocumentsDirectory();

    final fontDir = Directory('${appDir.path}/qcf_fonts');

    // Create the folder if it does not yet exist.
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }

    _fontDirCache = fontDir;

    return fontDir;
  }

  /// Ensures that the fonts for the given [pageNumber] are loaded and
  /// registered with the Flutter engine.
  ///
  /// - Returns an error future if [pageNumber] is out of range.
  /// - Returns immediately if the fonts are already loaded.
  /// - Coalesces concurrent requests for the same page.
  static Future<void> ensureFontLoaded(int pageNumber) {
    if (pageNumber < 1 || pageNumber > totalPages) {
      return Future.error(RangeError('Invalid Quran page: $pageNumber'));
    }

    // Already fully loaded; nothing to do.
    if (_loadedPages.contains(pageNumber)) {
      return Future.value();
    }

    final existingTask = _loadingTasks[pageNumber];

    // Reuse an in-flight task if one exists.
    if (existingTask != null) {
      return existingTask;
    }

    final task = _loadFontInternal(pageNumber);

    _loadingTasks[pageNumber] = task;

    task
        .then((_) {
          // Mark as loaded once the task completes successfully.
          _loadedPages.add(pageNumber);
        })
        .whenComplete(() {
          // Always clear the in-flight entry, whether success or failure.
          _loadingTasks.remove(pageNumber);
        });

    return task;
  }

  /// Whether the fonts for [pageNumber] are already loaded.
  static bool isFontLoaded(int pageNumber) {
    return _loadedPages.contains(pageNumber);
  }

  /// Preloads fonts for pages near [currentPage] within [radius] pages.
  ///
  /// This is typically called as the user navigates to keep the pages
  /// immediately before and after the current one ready to render.
  ///
  /// A generation counter is used so that a newer preload request cancels
  /// any older in-progress preload, avoiding wasted work after rapid swipes.
  static Future<void> preloadPages(int currentPage, {int radius = 5}) async {
    // Clamp the requested page into the valid range.
    if (currentPage < 1) {
      currentPage = 1;
    }

    if (currentPage > totalPages) {
      currentPage = totalPages;
    }

    // Claim a new generation and invalidate previous preloads.
    final myGeneration = ++_generation;

    await ensureFontLoaded(currentPage);

    // Abort if a newer preload has started while we were loading.
    if (myGeneration != _generation) {
      return;
    }

    final neighbors = <int>[];

    // Collect pages around the current one, alternating forward/backward.
    for (int i = 1; i <= radius; i++) {
      final next = currentPage + i;
      final previous = currentPage - i;

      if (next <= totalPages) {
        neighbors.add(next);
      }

      if (previous >= 1) {
        neighbors.add(previous);
      }
    }

    for (final page in neighbors) {
      // Abort the entire preload if a newer one has started.
      if (myGeneration != _generation) {
        return;
      }

      // Skip pages that are already loaded or currently loading.
      if (_loadedPages.contains(page) || _loadingTasks.containsKey(page)) {
        continue;
      }

      // Yield to the event loop so the UI stays responsive.
      await Future<void>.delayed(Duration.zero);

      if (myGeneration != _generation) {
        return;
      }

      await ensureFontLoaded(page);
    }
  }

  /// Performs the actual font loading for a single [pageNumber].
  ///
  /// Steps:
  /// 1. Try to read the extracted font from disk (only in disk mode).
  /// 2. If missing, decompress the bundled `.ttf.gz` and extract it.
  /// 3. Register the base (Tajweed light) family with the engine.
  /// 4. Derive and register the other variants (dark, no-Tajweed, red).
  static Future<void> _loadFontInternal(int pageNumber) async {
    final fontName = getBaseFontFamily(pageNumber);

    Uint8List fontBytes;

    if (_currentMode == FontStorageMode.permanentDisk) {
      final fontDir = await _getFontDirectory();
      final fontPath = '${fontDir.path}/$fontName.ttf';
      final file = File(fontPath);

      if (await file.exists() && await file.length() > 1000) {
        // Fast path: reuse the previously extracted font file.
        fontBytes = await file.readAsBytes();
      } else {
        // Extract the bundled font, then write it to disk off the main isolate.
        final gzipBytes = await _loadCompressedFont(fontName);
        fontBytes = await Isolate.run(() {
          final extracted = _extractFont(gzipBytes);
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(extracted, flush: true);
          return extracted;
        });
      }
    } else {
      // Memory-only mode: always extract from the bundled asset.
      final gzipBytes = await _loadCompressedFont(fontName);
      fontBytes = await Isolate.run(() => _extractFont(gzipBytes));
    }

    // Register the base (Tajweed light) family.
    await _registerFont(fontBytes, getTajweedLightFamily(pageNumber));

    // Derive the Tajweed dark variant by recoloring only the base color.
    final darkBytes = _modifyCpalBaseColor(
      Uint8List.fromList(fontBytes),
      const Color(0xFFFFFFFF),
    );
    await _registerFont(darkBytes, getTajweedDarkFamily(pageNumber));

    // Derive the no-Tajweed light variant (uniform black glyphs).
    final noTajweedLightBytes = _modifyCpalAllColors(
      Uint8List.fromList(fontBytes),
      const Color(0xFF000000),
    );
    await _registerFont(
      noTajweedLightBytes,
      getNoTajweedLightFamily(pageNumber),
    );

    // Derive the no-Tajweed dark variant (uniform white glyphs).
    final noTajweedDarkBytes = _modifyCpalAllColors(
      Uint8List.fromList(fontBytes),
      const Color(0xFFFFFFFF),
    );
    await _registerFont(noTajweedDarkBytes, getNoTajweedDarkFamily(pageNumber));

    // Derive the red variant (uniform red glyphs, used for special highlights).
    final redBytes = _modifyCpalAllColors(
      Uint8List.fromList(fontBytes),
      const Color(0xFFFF0000),
    );
    await _registerFont(redBytes, getRedFamily(pageNumber));
  }

  /// Registers the given [fontBytes] with the Flutter engine under [family].
  static Future<void> _registerFont(Uint8List fontBytes, String family) async {
    final loader = FontLoader(family);
    final byteData = ByteData.view(
      fontBytes.buffer,
      fontBytes.offsetInBytes,
      fontBytes.lengthInBytes,
    );
    loader.addFont(Future<ByteData>.value(byteData));
    await loader.load();
  }

  /// Loads the gzip-compressed font asset for [fontName] from the package.
  static Future<Uint8List> _loadCompressedFont(String fontName) async {
    final data = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.ttf.gz',
    );
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Decompresses a gzip-compressed font byte array.
  static Uint8List _extractFont(Uint8List gzipBytes) {
    final decompressed = const GZipDecoder().decodeBytes(gzipBytes);
    return Uint8List.fromList(decompressed);
  }

  /// Recolors only the "base color" entries of the font's CPAL table.
  ///
  /// A base color is considered to be a near-black entry with high opacity.
  /// This is used to build the Tajweed dark variant, which keeps the Tajweed
  /// palette but swaps the base text color to [newBaseColor].
  static Uint8List _modifyCpalBaseColor(
    Uint8List fontBytes,
    Color newBaseColor,
  ) {
    // The font header must be at least 12 bytes long to contain the numTables field.
    if (fontBytes.length < 12) return fontBytes;

    final bd = ByteData.view(
      fontBytes.buffer,
      fontBytes.offsetInBytes,
      fontBytes.lengthInBytes,
    );
    final numTables = bd.getUint16(4);
    int? cpalOffset;
    int? cpalLength;
    const cpalTag = 0x4350414C; // 'CPAL' in big-endian

    // Walk the table directory to locate the CPAL table.
    for (int i = 0; i < numTables; i++) {
      final recordOffset = 12 + i * 16;
      if (recordOffset + 16 > fontBytes.length) break;
      final tag = bd.getUint32(recordOffset);
      if (tag == cpalTag) {
        cpalOffset = bd.getUint32(recordOffset + 8);
        cpalLength = bd.getUint32(recordOffset + 12);
        break;
      }
    }

    // Bail out safely if the CPAL table is missing or bounds are invalid.
    if (cpalOffset == null || cpalLength == null) return fontBytes;
    if (cpalOffset + cpalLength > fontBytes.length) return fontBytes;
    if (cpalOffset + 12 > fontBytes.length) return fontBytes;

    final numColorRecords = bd.getUint16(cpalOffset + 6);
    final colorRecordsArrayOffset = bd.getUint32(cpalOffset + 8);
    final absoluteOffset = cpalOffset + colorRecordsArrayOffset;

    // Convert the Flutter color into its BGRA byte representation.
    final newR = (newBaseColor.r * 255).round();
    final newG = (newBaseColor.g * 255).round();
    final newB = (newBaseColor.b * 255).round();
    final newA = (newBaseColor.a * 255).round();

    for (int i = 0; i < numColorRecords; i++) {
      final colorOffset = absoluteOffset + i * 4;
      if (colorOffset + 4 > fontBytes.length) break;

      // CPAL stores colors in BGRA order.
      final b = fontBytes[colorOffset];
      final g = fontBytes[colorOffset + 1];
      final r = fontBytes[colorOffset + 2];
      final a = fontBytes[colorOffset + 3];

      // Only replace near-black, opaque entries.
      if (r <= 30 && g <= 30 && b <= 30 && a >= 200) {
        fontBytes[colorOffset] = newB;
        fontBytes[colorOffset + 1] = newG;
        fontBytes[colorOffset + 2] = newR;
        fontBytes[colorOffset + 3] = newA;
      }
    }

    return fontBytes;
  }

  /// Recolors every entry in the font's CPAL table to a uniform [color].
  ///
  /// This is used to build the no-Tajweed and red variants, which need a
  /// single flat color for every glyph regardless of the original palette.
  static Uint8List _modifyCpalAllColors(Uint8List fontBytes, Color color) {
    // The font header must be at least 12 bytes long to contain the numTables field.
    if (fontBytes.length < 12) return fontBytes;

    final bd = ByteData.view(
      fontBytes.buffer,
      fontBytes.offsetInBytes,
      fontBytes.lengthInBytes,
    );
    final numTables = bd.getUint16(4);
    int? cpalOffset;
    int? cpalLength;
    const cpalTag = 0x4350414C; // 'CPAL' in big-endian

    // Walk the table directory to locate the CPAL table.
    for (int i = 0; i < numTables; i++) {
      final recordOffset = 12 + i * 16;
      if (recordOffset + 16 > fontBytes.length) break;
      final tag = bd.getUint32(recordOffset);
      if (tag == cpalTag) {
        cpalOffset = bd.getUint32(recordOffset + 8);
        cpalLength = bd.getUint32(recordOffset + 12);
        break;
      }
    }

    // Bail out safely if the CPAL table is missing or bounds are invalid.
    if (cpalOffset == null || cpalLength == null) return fontBytes;
    if (cpalOffset + cpalLength > fontBytes.length) return fontBytes;
    if (cpalOffset + 12 > fontBytes.length) return fontBytes;

    final numColorRecords = bd.getUint16(cpalOffset + 6);
    final colorRecordsArrayOffset = bd.getUint32(cpalOffset + 8);
    final absoluteOffset = cpalOffset + colorRecordsArrayOffset;

    // Convert the Flutter color into its BGRA byte representation.
    final newR = (color.r * 255).round();
    final newG = (color.g * 255).round();
    final newB = (color.b * 255).round();
    final newA = (color.a * 255).round();

    for (int i = 0; i < numColorRecords; i++) {
      final colorOffset = absoluteOffset + i * 4;
      if (colorOffset + 4 > fontBytes.length) break;

      // CPAL stores colors in BGRA order; overwrite every entry uniformly.
      fontBytes[colorOffset] = newB;
      fontBytes[colorOffset + 1] = newG;
      fontBytes[colorOffset + 2] = newR;
      fontBytes[colorOffset + 3] = newA;
    }

    return fontBytes;
  }

  /// Clears any cached font data.
  ///
  /// - Invalidates any in-flight preload operations by bumping the generation.
  /// - Deletes the on-disk font directory (only in permanent disk mode).
  /// - Clears the in-memory tracking of loaded and loading pages.
  static Future<void> clearCache() async {
    _generation++;

    if (_currentMode == FontStorageMode.permanentDisk) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fontDir = Directory('${appDir.path}/qcf_fonts');

        if (await fontDir.exists()) {
          await fontDir.delete(recursive: true);
        }
      } catch (_) {
        // Best-effort cleanup: ignore any IO errors here.
      }
    }

    _fontDirCache = null;
    _loadedPages.clear();
    _loadingTasks.clear();
  }
}