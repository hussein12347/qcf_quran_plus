import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// A widget that displays the Basmallah ornament used as a separator between
/// surah sections in the Quran.
///
/// The Basmallah is the phrase "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ" that
/// appears at the beginning of most surahs (except Surah At-Tawbah, 9).
/// This widget renders a decorative glyph representation of the Basmallah
/// using a special font, styled to match the surrounding text.
///
/// For Surahs 95 (At-Tin) and 97 (Al-Qadr), a variant glyph set is used
/// (see [_twinGlyphs]) that visually differs from the standard Basmallah
/// ornament (see [_defaultGlyphs]).
class BasmallahWidget extends StatelessWidget {
  /// Creates a [BasmallahWidget] for the given [surahNumber].
  ///
  /// The [surahNumber] determines which glyph variant is rendered.
  /// An optional [fontSize] can be provided by the parent to avoid an extra
  /// layout pass; if omitted, it is derived from the current [MediaQuery]
  /// width and clamped between 18.0 and 23.0.
  const BasmallahWidget(this.surahNumber, {super.key, this.fontSize});

  /// The 1-based surah number (1-114) this Basmallah belongs to.
  final int surahNumber;

  /// An optional font size provided by the parent widget.
  ///
  /// When supplied, it avoids the need to read [MediaQuery] and perform an
  /// additional layout calculation. When `null`, the size is computed from
  /// the current screen width.
  final double? fontSize;

  /// Glyph sequence used for Surahs 95 and 97 (the "twin" Basmallah variant).
  static const String _twinGlyphs = "齃𧻓𥳐龎";

  /// Default glyph sequence used for all other surahs.
  static const String _defaultGlyphs = "齃𧻓𥳐𥉉";

  @override
  Widget build(BuildContext context) {
    // Inherit the text color from the current theme so the Basmallah blends
    // naturally with the rest of the page content.
    final Color? color = Theme.of(context).textTheme.bodyLarge?.color;

    // Resolve the font size: prefer the provided value, otherwise compute
    // a responsive size based on screen width and clamp it to a readable range.
    final double resolved = fontSize ??
        (MediaQuery.sizeOf(context).width * 0.0533).clamp(18.0, 23.0);

    // Wrap in RepaintBoundary to isolate this decorative widget from
    // repaints in the rest of the page, improving rendering performance.
    return RepaintBoundary(
      child: Padding(
        // A small top padding separates the Basmallah from the surah header.
        padding: const EdgeInsets.only(top: 5.0),
        child: Text(
          // Use the twin glyphs for Surahs 95 and 97, otherwise the default.
          surahNumber == 97 || surahNumber == 95 ? _twinGlyphs : _defaultGlyphs,
          textAlign: TextAlign.center,
          maxLines: 1,
          // Prevent the glyphs from wrapping or being truncated.
          softWrap: false,
          overflow: TextOverflow.visible,
          style: QuranTextStyles.basmallahStyle(
            fontSize: resolved,
            color: color,
          ),
        ),
      ),
    );
  }
}