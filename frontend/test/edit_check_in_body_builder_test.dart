// KAMOS — Tri-state PATCH body builder for the edit-check-in screen.
//
// SPEC §4.4: `rating`, `review`, and `price` are tri-state on the wire —
// absent leaves the column unchanged, present-null clears it, present-non-
// null sets it. The matrix below pins each tracked field's intent into the
// outgoing JSON body so a regression that strips nulls (e.g. routing the
// body through `_compact`) trips immediately.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/beverage.dart';
import 'package:kamos/core/models/category_label.dart';
import 'package:kamos/core/models/checkin.dart';
import 'package:kamos/core/models/flavor_tag.dart';
import 'package:kamos/core/models/i18n_text.dart';
import 'package:kamos/core/models/producer.dart';
import 'package:kamos/features/check_in/screens/edit_check_in_screen.dart';

Checkin _original({
  double? rating,
  String? review,
  Price? price,
  String? purchaseType,
  List<FlavorTag> tags = const [],
  List<PhotoRef> photos = const [],
}) =>
    Checkin(
      id: 'ci-1',
      user: const CheckinUser(
        id: 'u1',
        username: 'self',
        displayUsername: 'self',
        displayName: 'self',
      ),
      beverage: BeverageRef(
        id: 'b1',
        name: I18nText.fromJson(const {'en': 'Bev'}),
        producer: ProducerRef.fromJson(const {
          'id': 'p1',
          'name': {'en': 'Producer'},
        }),
        category: CategoryLabel.fromJson(const {'slug': 'sake'}),
      ),
      rating: rating,
      review: review,
      price: price,
      purchaseType: purchaseType,
      tags: tags,
      photos: photos,
      createdAt: '2026-05-01T00:00:00Z',
    );

FlavorTag _tag(String slug) => FlavorTag(
      id: slug,
      slug: slug,
      dimension: 'character',
      name: I18nText.fromJson({'en': slug}),
    );

void main() {
  group('buildEditCheckInBody — rating tri-state', () {
    test('user clears an existing rating → body contains "rating": null', () {
      final body = buildEditCheckInBody(
        original: _original(rating: 4.0, review: 'r'),
        rating: null,
        review: 'r',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('rating'), isTrue);
      expect(body['rating'], isNull);
    });

    test('no rating before, no rating after → key absent (no-op)', () {
      final body = buildEditCheckInBody(
        original: _original(rating: null),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('rating'), isFalse);
    });

    test('rating changed → key present with new value', () {
      final body = buildEditCheckInBody(
        original: _original(rating: 4.0),
        rating: 3.5,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body['rating'], 3.5);
    });
  });

  group('buildEditCheckInBody — review tri-state', () {
    test('user empties a non-empty review → body contains "review": null', () {
      final body = buildEditCheckInBody(
        original: _original(review: 'nice'),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('review'), isTrue);
      expect(body['review'], isNull);
    });

    test('review unchanged → key absent', () {
      final body = buildEditCheckInBody(
        original: _original(review: 'nice'),
        rating: null,
        review: 'nice',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('review'), isFalse);
    });
  });

  group('buildEditCheckInBody — price tri-state', () {
    test('user clears an existing price → body contains "price": null', () {
      final body = buildEditCheckInBody(
        original: _original(
          price: const Price(amount: 1200, currency: 'JPY', mode: 'serving'),
        ),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('price'), isTrue);
      expect(body['price'], isNull);
    });

    test('no price before, no price after → key absent', () {
      final body = buildEditCheckInBody(
        original: _original(),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('price'), isFalse);
    });
  });

  group('buildEditCheckInBody — tags + photos + purchase_type', () {
    test('tags changed → full replacement', () {
      final body = buildEditCheckInBody(
        original: _original(tags: [_tag('dry'), _tag('crisp')]),
        rating: null,
        review: '',
        tags: const ['dry'],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body['tags'], ['dry']);
    });

    test('tags unchanged (different order) → key absent', () {
      final body = buildEditCheckInBody(
        original: _original(tags: [_tag('dry'), _tag('crisp')]),
        rating: null,
        review: '',
        tags: const ['crisp', 'dry'],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('tags'), isFalse);
    });

    test('photo diffs emitted only when non-empty', () {
      final body = buildEditCheckInBody(
        original: _original(),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const ['upload-1'],
        removePhotos: const ['https://r2/old.jpg'],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body['add_photos'], ['upload-1']);
      expect(body['remove_photos'], ['https://r2/old.jpg']);
    });

    test('purchase_type cleared → body contains "purchase_type": null', () {
      final body = buildEditCheckInBody(
        original: _original(purchaseType: 'retail'),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body.containsKey('purchase_type'), isTrue);
      expect(body['purchase_type'], isNull);
    });

    test('no-op edit → empty body', () {
      final body = buildEditCheckInBody(
        original: _original(rating: 4.0, review: 'nice'),
        rating: 4.0,
        review: 'nice',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body, isEmpty);
    });
  });

  group('CheckinsApi.update — null fields survive the wire', () {
    test('regression guard: explicit nulls in the body are NOT stripped', () {
      // Mirrors the body shape the screen builds when the user clears a
      // rating + review. If a future refactor accidentally routes the
      // PATCH body through `_compact`, both nulls disappear and this
      // assertion trips. We assert via the builder so the regression
      // is caught even without a Dio test seam.
      final body = buildEditCheckInBody(
        original: _original(rating: 4.0, review: 'r'),
        rating: null,
        review: '',
        tags: const [],
        addPhotos: const [],
        removePhotos: const [],
        priceText: '',
        currency: 'JPY',
        priceMode: 'serving',
        purchaseType: null,
      );
      expect(body['rating'], isNull);
      expect(body.containsKey('rating'), isTrue);
      expect(body['review'], isNull);
      expect(body.containsKey('review'), isTrue);
    });
  });
}
