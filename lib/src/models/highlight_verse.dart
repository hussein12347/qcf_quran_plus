import 'dart:ui';

/// A model representing a highlighted state for a specific Quranic verse.
///
/// This class is used to define which verse should be visually emphasized
/// on a specific page and Surah, along with the specific [Color] of the highlight.
class HighlightVerse {
  /// The number of the verse (Ayah) to be highlighted.
  final int verseNumber;

  /// The number of the Surah (1-114) containing the verse.
  final int surah;

  /// The Mushaf page number where this highlight should appear.
  final int page;

  /// The color used to highlight the verse background or border.
  final Color color;

  /// Creates a constant [HighlightVerse] instance.
  const HighlightVerse({
    required this.verseNumber,
    required this.page,
    required this.surah,
    required this.color,
  });

  /// Creates a copy of this [HighlightVerse] but with the given fields replaced
  /// with the new values.
  ///
  /// This is useful for changing the [color] of an existing highlight without
  /// manually copying every other field.
  HighlightVerse copyWith({
    int? verseNumber,
    int? page,
    int? surah,
    Color? color,
  }) {
    return HighlightVerse(
      surah: surah ?? this.surah,
      verseNumber: verseNumber ?? this.verseNumber,
      page: page ?? this.page,
      color: color ?? this.color,
    );
  }

  /// Converts the [HighlightVerse] into a Map.
  ///
  /// The [color] is stored as its [Color.value] (an integer representation)
  /// to make it compatible with JSON and database storage.
  Map<String, dynamic> toMap() {
    return {
      'verseNumber': verseNumber,
      'surah': surah,
      'page': page,
      'color': color.value,
    };
  }

  /// Creates a [HighlightVerse] instance from a Map.
  ///
  /// Expects the 'color' key to be an [int] value.
  factory HighlightVerse.fromMap(Map<String, dynamic> map) {
    return HighlightVerse(
      verseNumber: map['verseNumber'] as int,
      page: map['page'] as int,
      surah: map['surah'] as int,
      color: Color(map['color'] as int),
    );
  }

  /// Returns a string representation of the [HighlightVerse] for debugging.
  @override
  String toString() =>
      'HighlightVerse(surah: $surah, verseNumber: $verseNumber, page: $page, color: ${color.value})';

  /// Compares this object to another for equality.
  ///
  /// Two highlights are considered equal if they target the same verse,
  /// page, and have the same color value.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HighlightVerse &&
        other.verseNumber == verseNumber &&
        other.surah == surah &&
        other.page == page &&
        other.color.value == color.value;
  }

  /// Generates a hash code for the [HighlightVerse] instance.
  @override
  int get hashCode =>
      verseNumber.hashCode ^ surah.hashCode ^ page.hashCode ^ color.value.hashCode;
}