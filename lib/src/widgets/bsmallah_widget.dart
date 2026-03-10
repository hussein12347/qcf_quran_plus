import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// A widget that renders the Basmallah (Bismillah) with specific calligraphic styles.
class BasmallahWidget extends StatelessWidget {
  const BasmallahWidget(this.surahNumber, {super.key});

  /// The index of the Surah used to determine the correct Basmallah glyph.
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Text(
          // Some Surahs (like 97 and 95) require a specific glyph variant
          // depending on the font's character mapping for optimal layout.
          surahNumber == 97 || surahNumber == 95
              ? "齃𧻓𥳐龎"
              : '齃𧻓𥳐𥉉',
          // Utilizing the helper class for consistent Quranic typography
          style: QuranTextStyles.basmallahStyle(
            fontSize: 20,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}

