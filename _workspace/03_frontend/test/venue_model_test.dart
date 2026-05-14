// KAMOS — Smoke test for Phase 4 venue model wiring on Checkin / FeedItem.
// Confirms `venue: null` round-trips and `venue: {...}` decodes into a
// `VenueRef`.

import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/models/checkin.dart';
import 'package:kamos/core/models/venue.dart';

void main() {
  group('Checkin.venue', () {
    test('absent venue parses as null', () {
      final c = Checkin.fromJson(const {
        'id': 'chk-1',
        'user': {'id': 'u1', 'username': 'a', 'display_username': 'a'},
        'beverage': {'id': 'b1', 'name': {'en': 'X'}},
      });
      expect(c.venue, isNull);
    });

    test('venue object decodes to VenueRef with locality + country', () {
      final c = Checkin.fromJson(const {
        'id': 'chk-1',
        'user': {'id': 'u1', 'username': 'a', 'display_username': 'a'},
        'beverage': {'id': 'b1', 'name': {'en': 'X'}},
        'venue': {
          'id': 'ven-1',
          'name': 'Daikoku',
          'locality': 'Shibuya',
          'country': 'JP',
        },
      });
      expect(c.venue, isA<VenueRef>());
      expect(c.venue!.id, 'ven-1');
      expect(c.venue!.name, 'Daikoku');
      expect(c.venue!.locality, 'Shibuya');
      expect(c.venue!.country, 'JP');
    });
  });

  group('FoursquarePlace.toCheckinVenueJson', () {
    test('drops empty/null fields but always emits foursquare_id and name',
        () {
      final p = const FoursquarePlace(
        foursquareId: 'fsq-1',
        name: 'Daikoku',
        lat: 35.0,
        lng: 139.0,
        locality: 'Shibuya',
      );
      final json = p.toCheckinVenueJson();
      expect(json['foursquare_id'], 'fsq-1');
      expect(json['name'], 'Daikoku');
      expect(json['lat'], 35.0);
      expect(json['lng'], 139.0);
      expect(json['locality'], 'Shibuya');
      expect(json.containsKey('address'), isFalse);
      expect(json.containsKey('country'), isFalse);
      expect(json.containsKey('prefecture'), isFalse);
    });
  });

  group('FeedItem.venue', () {
    test('absent venue parses as null (current backend)', () {
      final f = FeedItem.fromJson(const {
        'id': 'chk-1',
        'user': {'id': 'u1', 'username': 'a', 'display_username': 'a'},
        'beverage': {'id': 'b1', 'name': {'en': 'X'}},
      });
      expect(f.venue, isNull);
    });
  });
}
