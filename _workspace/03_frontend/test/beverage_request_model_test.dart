// KAMOS — BeverageRequest.toJson tests (Phase 5 user-side).
//
// The server expects `{ "payload": { ... } }`. The Flutter form pins the
// payload to four fields; `notes` is omitted when null/empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/beverage_request.dart';

void main() {
  group('BeverageRequest.toJson', () {
    test('wraps fields in a payload object with notes included', () {
      const req = BeverageRequest(
        name: 'Dassai 45',
        breweryName: 'Asahi Shuzo',
        categorySlug: 'nihonshu',
        notes: 'Junmai Daiginjo',
      );
      expect(req.toJson(), {
        'payload': {
          'name': 'Dassai 45',
          'brewery_name': 'Asahi Shuzo',
          'category_slug': 'nihonshu',
          'notes': 'Junmai Daiginjo',
        },
      });
    });

    test('omits notes when null', () {
      const req = BeverageRequest(
        name: 'Iichiko',
        breweryName: 'Sanwa Shurui',
        categorySlug: 'shochu',
      );
      final json = req.toJson();
      expect(json['payload'], isA<Map<String, dynamic>>());
      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload.containsKey('notes'), isFalse);
      expect(payload['category_slug'], 'shochu');
    });

    test('omits notes when whitespace-only', () {
      const req = BeverageRequest(
        name: 'Choya Umeshu',
        breweryName: 'Choya',
        categorySlug: 'liqueur',
        notes: '   \n  ',
      );
      final payload = req.toJson()['payload'] as Map<String, dynamic>;
      expect(payload.containsKey('notes'), isFalse);
    });

    test('trims notes when present', () {
      const req = BeverageRequest(
        name: 'X',
        breweryName: 'Y',
        categorySlug: 'nihonshu',
        notes: '  fresh tasting  ',
      );
      final payload = req.toJson()['payload'] as Map<String, dynamic>;
      expect(payload['notes'], 'fresh tasting');
    });
  });
}
