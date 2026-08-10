import 'package:flutter/material.dart';

/// Total number of two-page spreads in the Madani Mushaf layout.
///
/// Layout:
/// - Spread 0: page 1 alone (right)
/// - Spreads 1-301: even page on the left, odd page on the right (2|3 ... 602|603)
/// - Spread 302: page 604 alone (left)
const int totalFacingSpreads = 303;

/// Maps a 1-based mushaf [page] (1-604) to a 0-based spread index.
int mushafPageToSpreadIndex(int page) {
  if (page < 1) return 0;
  if (page > 604) return totalFacingSpreads - 1;
  if (page == 1) return 0;
  if (page == 604) return totalFacingSpreads - 1;
  return page ~/ 2;
}

/// Returns the left and right mushaf page numbers for a [spreadIndex].
///
/// Either side may be `null` for the opening (page 1) and closing (page 604)
/// spreads where only one page is shown.
({int? leftPage, int? rightPage}) spreadIndexToPages(int spreadIndex) {
  if (spreadIndex <= 0) {
    return (leftPage: null, rightPage: 1);
  }
  if (spreadIndex >= totalFacingSpreads - 1) {
    return (leftPage: 604, rightPage: null);
  }
  final leftPage = spreadIndex * 2;
  final rightPage = spreadIndex * 2 + 1;
  return (leftPage: leftPage, rightPage: rightPage);
}

/// Primary page for bookmarks/audio focus: prefer the right (recto) page.
int primaryPageForSpread(int spreadIndex) {
  final pages = spreadIndexToPages(spreadIndex);
  return pages.rightPage ?? pages.leftPage ?? 1;
}

/// Whether the current screen is wide enough for a facing-pages mushaf.
///
/// Defaults to Material tablet breakpoint (`shortestSide >= 600`).
bool shouldUseFacingPages(
  BuildContext context, {
  double minShortestSide = 600,
}) {
  return MediaQuery.sizeOf(context).shortestSide >= minShortestSide;
}