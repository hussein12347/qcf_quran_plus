import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// A specialized utility class for managing dynamic loading of Quran Complex Fonts (QCF).
class QcfFontLoader {
  /// Tracks active loading tasks to prevent redundant network/file requests.
  static final Map<int, Future<void>> _loadingTasks = {};

  /// Stores the numbers of pages whose fonts have successfully been registered.
  static final Set<int> _loadedPages = {};

  /// Pre-extracts all fonts at startup, tracks progress, and ensures files are complete.
  static Future<void> setupFontsAtStartup({required Function(double progress) onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${dir.path}/qcf_fonts');

    // Create the directory if it doesn't exist
    if (!fontDir.existsSync()) {
      fontDir.createSync(recursive: true);
    }

    const int totalPages = 604;

    for (int i = 1; i <= totalPages; i++) {
      String pageStr = i.toString().padLeft(3, '0');
      final String fontName = 'QCF4_tajweed_$pageStr';
      File ttfFile = File('${fontDir.path}/$fontName.ttf');

      bool isFileValid = ttfFile.existsSync() && ttfFile.lengthSync() > 15000;

      if (!isFileValid) {
        try {
          final data = await rootBundle.load(
            'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
          );
          final bytes = data.buffer.asUint8List();

          // Unzip in an isolate to avoid blocking the main UI thread
          final Uint8List fontBytes = await Isolate.run(() => _extractFont(bytes));

          // Save the full extracted TTF file to local storage
          await ttfFile.writeAsBytes(fontBytes, flush: true);
        } catch (e) {
          debugPrint("❌ Error extracting $fontName: $e");
        }
      }

      onProgress(i / totalPages);
    }
  }

  /// Ensures that the font for a specific [pageNumber] is loaded and registered.
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

  static bool isFontLoaded(int pageNumber) {
    return _loadedPages.contains(pageNumber);
  }

  /// Internal logic to fetch the font. Heavy File I/O is moved to an Isolate.
  static Future<void> _loadFontInternal(int pageNumber) async {
    String pageStr = pageNumber.toString().padLeft(3, '0');
    final String fontName = 'QCF4_tajweed_$pageStr';

    final dir = await getApplicationDocumentsDirectory();
    final fontPath = '${dir.path}/qcf_fonts/$fontName.ttf';

    // 1. We move the file checking and reading to a background Isolate.
    // Reading large files on the main thread during swipe causes jank.
    Uint8List? fontBytes = await Isolate.run(() {
      File ttfFile = File(fontPath);
      if (ttfFile.existsSync() && ttfFile.lengthSync() > 15000) {
        return ttfFile.readAsBytesSync(); // Read on background isolate
      }
      return null;
    });

    // 2. If it wasn't found in local storage, extract it from assets.
    if (fontBytes == null) {
      final data = await rootBundle.load(
        'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
      );
      final zipBytes = data.buffer.asUint8List();

      fontBytes = await Isolate.run(() {
        final extractedBytes = _extractFont(zipBytes);
        // Also save it inside the isolate to avoid main thread blockage
        File ttfFile = File(fontPath);
        ttfFile.parent.createSync(recursive: true);
        ttfFile.writeAsBytesSync(extractedBytes, flush: true);
        return extractedBytes;
      });
    }

    // Register the font with the Flutter Engine dynamically (Must be on main thread)
    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(fontBytes!.buffer)));
    await loader.load();
  }

  static Uint8List _extractFont(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.name.endsWith('.ttf')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw Exception("Font not found in zip");
  }

  // static void preloadNearbyPages(int currentPage) {
  //   for (int i = currentPage - 1; i <= currentPage + 3; i++) {
  //     if (i > 0 && i <= 604) ensureFontLoaded(i);
  //   }
  // }
}