// KAMOS — Beverage models (OpenAPI `Beverage`, `BeverageRef`, `BeverageDetail`).
//
// Migration 016 dropped the per-beverage `prefecture` / `region` free-text
// columns. A beverage's locality is derived through `producer.prefecture`
// (which itself nests `region`).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'category_label.dart';
import 'flavor_tag.dart';
import 'i18n_text.dart';
import 'photo_ref.dart';
import 'producer.dart';

part 'beverage.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class Beverage with _$Beverage {
  const factory Beverage({
    required String id,
    required I18nText name,
    required Producer producer,
    required CategoryLabel category,
    Subcategory? subcategory,
    double? abv,
    int? polishingRatio,
    @Default(<String>[]) List<String> flavorProfile,
    I18nText? description,
    String? labelImageUrl,
    double? avgRating,
    @Default(0) int checkInCount,
    @Default('') String createdAt,
  }) = _Beverage;

  factory Beverage.fromJson(Map<String, dynamic> json) => Beverage(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    producer: Producer.fromJson(
      (json['producer'] as Map<String, dynamic>?) ?? const {},
    ),
    category: CategoryLabel.fromJson(
      (json['category'] as Map<String, dynamic>?) ?? const {},
    ),
    subcategory: json['subcategory'] is Map<String, dynamic>
        ? Subcategory.fromJson(json['subcategory'] as Map<String, dynamic>)
        : null,
    abv: (json['abv'] as num?)?.toDouble(),
    polishingRatio: (json['polishing_ratio'] as num?)?.toInt(),
    flavorProfile: ((json['flavor_profile'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    description: json['description'] is Map<String, dynamic>
        ? I18nText.fromJson(json['description'] as Map<String, dynamic>)
        : null,
    labelImageUrl: json['label_image_url'] as String?,
    avgRating: (json['avg_rating'] as num?)?.toDouble(),
    checkInCount: (json['check_in_count'] as int?) ?? 0,
    createdAt: (json['created_at'] as String?) ?? '',
  );
}

// Slice C — `beverages.subcategory` is now a slim FK reference to the
// `beverage_subcategories` table (see migration 005 + OpenAPI `Subcategory`).
// During the dual-source release window the server may emit a Subcategory
// where only `name` is populated (id/categoryId/categorySlug/slug fall back
// to empty strings) for legacy rows that still carry the old
// `subcategory_i18n` JSONB. Treat id/slug as optional during that window.
@Freezed(fromJson: false, toJson: false)
abstract class Subcategory with _$Subcategory {
  const factory Subcategory({
    required String id,
    required String categoryId,
    required String categorySlug,
    required String slug,
    required I18nText name,
    @Default(0) int sortOrder,
  }) = _Subcategory;

  factory Subcategory.fromJson(Map<String, dynamic> json) => Subcategory(
    id: (json['id'] as String?) ?? '',
    categoryId: (json['category_id'] as String?) ?? '',
    categorySlug: (json['category_slug'] as String?) ?? '',
    slug: (json['slug'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class BeverageRef with _$BeverageRef {
  const factory BeverageRef({
    required String id,
    required I18nText name,
    required ProducerRef producer,
    required CategoryLabel category,
    Subcategory? subcategory,
    String? labelImageUrl,
  }) = _BeverageRef;

  factory BeverageRef.fromJson(Map<String, dynamic> json) => BeverageRef(
    id: (json['id'] as String?) ?? '',
    name: I18nText.fromJson(
      (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
    ),
    producer: ProducerRef.fromJson(
      (json['producer'] as Map<String, dynamic>?) ?? const {},
    ),
    category: CategoryLabel.fromJson(
      (json['category'] as Map<String, dynamic>?) ?? const {},
    ),
    subcategory: json['subcategory'] is Map<String, dynamic>
        ? Subcategory.fromJson(json['subcategory'] as Map<String, dynamic>)
        : null,
    labelImageUrl: json['label_image_url'] as String?,
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class FlavorAggregate with _$FlavorAggregate {
  const factory FlavorAggregate({
    required String slug,
    required String dimension,
    required I18nText name,
    @Default(0) int uses,
  }) = _FlavorAggregate;

  factory FlavorAggregate.fromJson(Map<String, dynamic> json) =>
      FlavorAggregate(
        slug: (json['slug'] as String?) ?? '',
        dimension: (json['dimension'] as String?) ?? '',
        name: I18nText.fromJson(
          (json['name'] as Map<String, dynamic>?) ?? const {'en': ''},
        ),
        uses: (json['uses'] as int?) ?? 0,
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class BeverageDetail with _$BeverageDetail {
  const factory BeverageDetail({
    required Beverage beverage,
    @Default(<FlavorAggregate>[]) List<FlavorAggregate> aggregatedFlavor,
    @Default(<CheckinSummary>[]) List<CheckinSummary> recentCheckIns,
  }) = _BeverageDetail;

  factory BeverageDetail.fromJson(Map<String, dynamic> json) => BeverageDetail(
    beverage: Beverage.fromJson(json),
    aggregatedFlavor: ((json['aggregated_flavor'] as List?) ?? const [])
        .map((e) => FlavorAggregate.fromJson(e as Map<String, dynamic>))
        .toList(),
    recentCheckIns: ((json['recent_check_ins'] as List?) ?? const [])
        .map((e) => CheckinSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// CheckinSummary lives here to avoid a circular import; the full Checkin is
// in `checkin.dart`. Stage post-MVP widened the projection to include
// `photos` and `tags` so beverage-detail recent-check-in rows render rich
// cards without a second round trip.
@Freezed(fromJson: false, toJson: false)
abstract class CheckinSummary with _$CheckinSummary {
  const factory CheckinSummary({
    required String id,
    required CheckinUser user,
    double? rating,
    String? review,
    @Default(<PhotoRef>[]) List<PhotoRef> photos,
    @Default(<FlavorTag>[]) List<FlavorTag> tags,
    @Default('') String createdAt,
  }) = _CheckinSummary;

  factory CheckinSummary.fromJson(Map<String, dynamic> json) => CheckinSummary(
    id: (json['id'] as String?) ?? '',
    user: CheckinUser.fromJson(
      (json['user'] as Map<String, dynamic>?) ?? const {},
    ),
    rating: (json['rating'] as num?)?.toDouble(),
    review: json['review'] as String?,
    photos: ((json['photos'] as List?) ?? const [])
        .map((e) => PhotoRef.fromJson(e as Map<String, dynamic>))
        .toList(),
    tags: ((json['tags'] as List?) ?? const [])
        .map((e) => FlavorTag.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: (json['created_at'] as String?) ?? '',
  );
}

@Freezed(fromJson: false, toJson: false)
abstract class CheckinUser with _$CheckinUser {
  const factory CheckinUser({
    required String id,
    required String username,
    required String displayUsername,
    required String displayName,
    String? avatarUrl,
  }) = _CheckinUser;

  factory CheckinUser.fromJson(Map<String, dynamic> json) => CheckinUser(
    id: (json['id'] as String?) ?? '',
    username: (json['username'] as String?) ?? '',
    displayUsername:
        (json['display_username'] as String?) ??
        (json['username'] as String? ?? ''),
    displayName: (json['display_name'] as String?) ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );
}
