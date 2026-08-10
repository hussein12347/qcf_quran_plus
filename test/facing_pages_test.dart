import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/src/utils/facing_pages.dart';

void main() {
  group('facing pages helpers', () {
    test('totalFacingSpreads is 303', () {
      expect(totalFacingSpreads, 303);
    });

    test('mushafPageToSpreadIndex maps Madani pages', () {
      expect(mushafPageToSpreadIndex(1), 0);
      expect(mushafPageToSpreadIndex(2), 1);
      expect(mushafPageToSpreadIndex(3), 1);
      expect(mushafPageToSpreadIndex(4), 2);
      expect(mushafPageToSpreadIndex(5), 2);
      expect(mushafPageToSpreadIndex(602), 301);
      expect(mushafPageToSpreadIndex(603), 301);
      expect(mushafPageToSpreadIndex(604), 302);
    });

    test('spreadIndexToPages returns Madani pairs', () {
      expect(spreadIndexToPages(0), (leftPage: null, rightPage: 1));
      expect(spreadIndexToPages(1), (leftPage: 2, rightPage: 3));
      expect(spreadIndexToPages(2), (leftPage: 4, rightPage: 5));
      expect(spreadIndexToPages(301), (leftPage: 602, rightPage: 603));
      expect(spreadIndexToPages(302), (leftPage: 604, rightPage: null));
    });

    test('primaryPageForSpread prefers right page', () {
      expect(primaryPageForSpread(0), 1);
      expect(primaryPageForSpread(1), 3);
      expect(primaryPageForSpread(302), 604);
    });

    test('page <-> spread round-trip for all pages', () {
      for (var page = 1; page <= 604; page++) {
        final spread = mushafPageToSpreadIndex(page);
        final pages = spreadIndexToPages(spread);
        expect(
          page == pages.leftPage || page == pages.rightPage,
          isTrue,
          reason: 'page $page not in spread $spread ($pages)',
        );
      }
    });
  });
}