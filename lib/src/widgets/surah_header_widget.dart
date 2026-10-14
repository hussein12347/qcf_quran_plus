import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// A widget that displays the decorative banner header for a Quran surah.
///
/// This widget renders a surah banner image with the surah number overlaid
/// on top. The banner scales responsively based on the available width.
///
/// Typical usage:
/// ```dart
/// SurahHeaderWidget(suraNumber: 1)
/// ```
class SurahHeaderWidget extends StatelessWidget {
  /// The number of the surah (1-114) to display in the header.
  final int suraNumber;

  /// Creates a [SurahHeaderWidget] for the given [suraNumber].
  const SurahHeaderWidget({super.key, required this.suraNumber});

  /// The asset path for the surah banner image.
  static const String _imagePath = 'assets/surah_banner.png';

  /// The asset image used as the surah banner background.
  static const AssetImage _asset = AssetImage(
    _imagePath,
    package: 'qcf_quran_plus',
  );

  /// Builds a [ResizeImage] that matches the exact keys used by the displayed
  /// image, ensuring that precaching hits the same [ImageCache] entry.
  ///
  /// The image is resized based on the device pixel ratio and the available
  /// width (90% of the screen width). Upscaling is disabled to preserve quality.
  static ResizeImage _resizeImage(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double w = MediaQuery.sizeOf(context).width * 0.9;
    return ResizeImage(
      _asset,
      width: (w * dpr).round(),
      allowUpscaling: false,
    );
  }

  /// Preloads the surah banner image into the image cache.
  ///
  /// Call this method from a splash screen before displaying the main UI
  /// to avoid a brief flash when the banner first appears.
  static Future<void> precache(BuildContext context) {
    return precacheImage(_resizeImage(context), context);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in RepaintBoundary to isolate repaints and improve performance.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine the available width, falling back to screen width if unbounded.
          final double availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          // The banner occupies 90% of the available width.
          final double headerWidth = availableWidth * 0.9;

          // Font size scales proportionally to the banner width.
          final double fontSize = headerWidth * 0.085;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background banner image.
                Image(
                  image: _resizeImage(context),
                  width: headerWidth,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
                // Surah number overlaid on the banner.
                SizedBox(
                  width: headerWidth * 0.65,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: '$suraNumber',
                        style: QuranTextStyles.surahHeaderStyle(
                          fontSize: fontSize,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}