import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';

class QcfFontLoader {
  // Caches the Future so concurrent requests for the same font wait for the single task
  static final Map<int, Future<void>> _loadingTasks = {};

  static Future<void> loadFont(int pageNumber) async {
    // If it's already loading or loaded, return the existing Future
    if (_loadingTasks.containsKey(pageNumber)) {
      return _loadingTasks[pageNumber]!;
    }

    // Otherwise, start a new loading task and cache it
    final task = _loadFontInternal(pageNumber);
    _loadingTasks[pageNumber] = task;

    try {
      await task;
    } catch (e) {
      // If it fails, remove it from the cache so we can retry later
      _loadingTasks.remove(pageNumber);
      debugPrint("Error loading font for page $pageNumber: $e");
    }
  }

  static Future<void> _loadFontInternal(int pageNumber) async {
    String pageStr = pageNumber.toString().padLeft(3, '0');
    final String fontName = 'QCF4_tajweed_$pageStr';

    final data = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
    );

    final bytes = data.buffer.asUint8List();

    // Run extraction in an isolate to avoid blocking the main UI thread
    final Uint8List fontBytes = await Isolate.run(() => _extractFont(bytes));

    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
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

  /// Preload pages around the current page
  static void preloadNearbyPages(int currentPage) {
    for (int i = currentPage - 2; i <= currentPage + 2; i++) {
      if (i > 0 && i <= 604) {
        loadFont(i); // Fire and forget
      }
    }
  }
}

