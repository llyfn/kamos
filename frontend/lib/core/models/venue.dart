// KAMOS — Venue models.
//
// `Venue` is the full row returned by venue endpoints. `VenueRef` is the
// lightweight projection embedded on `Checkin`. `FoursquarePlace` is what
// `GET /v1/venues/search` returns — NOT a venue row, just a search result
// that can be attached to a check-in by `foursquare_id`.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Venue with _$Venue {
  const factory Venue({
    required String id,
    required String name,
    String? foursquareId,
    String? address,
    double? lat,
    double? lng,
    String? country,
    String? prefecture,
    String? locality,
  }) = _Venue;

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    foursquareId: json['foursquare_id'] as String?,
    address: json['address'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    country: json['country'] as String?,
    prefecture: json['prefecture'] as String?,
    locality: json['locality'] as String?,
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class VenueRef with _$VenueRef {
  const factory VenueRef({
    required String id,
    required String name,
    String? locality,
    String? country,
  }) = _VenueRef;

  factory VenueRef.fromJson(Map<String, dynamic> json) => VenueRef(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    locality: json['locality'] as String?,
    country: json['country'] as String?,
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class FoursquarePlace with _$FoursquarePlace {
  const FoursquarePlace._();
  const factory FoursquarePlace({
    required String foursquareId,
    required String name,
    String? address,
    double? lat,
    double? lng,
    String? country,
    String? prefecture,
    String? locality,
  }) = _FoursquarePlace;

  factory FoursquarePlace.fromJson(Map<String, dynamic> json) =>
      FoursquarePlace(
        foursquareId: (json['foursquare_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        address: json['address'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        country: json['country'] as String?,
        prefecture: json['prefecture'] as String?,
        locality: json['locality'] as String?,
      );

  /// Body shape used when attaching this place to a check-in via the
  /// `venue` field of `POST /v1/check-ins`. Only the populated fields are
  /// emitted; the backend's `CheckinVenueInput` accepts any subset.
  Map<String, dynamic> toCheckinVenueJson() => {
    'foursquare_id': foursquareId,
    'name': name,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (country != null && country!.isNotEmpty) 'country': country,
    if (prefecture != null && prefecture!.isNotEmpty) 'prefecture': prefecture,
    if (locality != null && locality!.isNotEmpty) 'locality': locality,
  };
}
