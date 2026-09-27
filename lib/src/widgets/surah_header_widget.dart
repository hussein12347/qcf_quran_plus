import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// Displays the banner header for a Quran surah.
///
/// This widget renders a preloaded surah banner with the numeric identifier
/// centered over it. The image is resized to the visible size using
/// [ResizeImage] so the widget avoids decoding the full asset for large
/// resolutions, while [RichText] keeps the typography consistent with the
/// project's custom Qur'anic text styling.
class SurahHeaderWidget extends StatelessWidget {
  /// The surah number displayed in the header.
  final int suraNumber;

  const SurahHeaderWidget({super.key, required this.suraNumber});

  static const String _imagePath = 'assets/surah_banner.png';

  static const AssetImage _asset = AssetImage(
    _imagePath,
    package: 'qcf_quran_plus',
  );

  /// Preloads the banner asset for the header.
  ///
  /// Call this once from a parent screen, for example during dependency
  /// changes, to avoid visible jank when the widget is first displayed.
  static Future<void> precache(BuildContext context) {
    return precacheImage(_asset, context);
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isInfinite
            ? MediaQuery.of(context).size.width
            : constraints.maxWidth;

        final double headerWidth = availableWidth * 0.9;
        final double fontSize = headerWidth * 0.085;

        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image(
                  image: ResizeImage(
                    _asset,
                    width: (headerWidth * dpr).round(),
                    allowUpscaling: false,
                  ),
                  width: headerWidth,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),

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
          ),
        );
      },
    );
  }
}
