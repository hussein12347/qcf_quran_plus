import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// Displays the basmallah ornament used as a separator between surah sections.
///
/// The text size is derived from the available width and clamped to a safe
/// range to avoid repeated measurement/layout churn.
class BasmallahWidget extends StatelessWidget {
  const BasmallahWidget(this.surahNumber, {super.key});

  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    final Color? color = Theme.of(context).textTheme.bodyLarge?.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isInfinite
            ? MediaQuery.of(context).size.width
            : constraints.maxWidth;

        final double fontSize = (availableWidth * 0.0533).clamp(18.0, 23.0);

        return RepaintBoundary(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Text(
                surahNumber == 97 || surahNumber == 95 ? "齃𧻓𥳐龎" : "齃𧻓𥳐𥉉",
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: QuranTextStyles.basmallahStyle(
                  fontSize: fontSize,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
