// KAMOS — Check-in models (OpenAPI `Checkin`, `CreateCheckinRequest`,
// `FeedItem`, `PhotoRef`, `Price`, `ToastState`).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';
import 'flavor_tag.dart';

part 'checkin.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class PhotoRef with _$PhotoRef {
  const factory PhotoRef({
    required String url,
    @Default('') String id,
    @Default(0) int sortOrder,
  }) = _PhotoRef;

  factory PhotoRef.fromJson(Map<String, dynamic> json) => PhotoRef(
        url: (json['url'] as String?) ?? '',
        id: (json['id'] as String?) ?? '',
        sortOrder: (json['sort_order'] as int?) ?? 0,
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class Price with _$Price {
  const Price._();
  const factory Price({
    required double amount,
    required String currency,
    required String mode,
  }) = _Price;

  factory Price.fromJson(Map<String, dynamic> json) => Price(
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: (json['currency'] as String?) ?? 'JPY',
        mode: (json['mode'] as String?) ?? 'serving',
      );

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'mode': mode,
      };
}

@Freezed(fromJson: false, toJson: false)
abstract class Checkin with _$Checkin {
  const factory Checkin({
    required String id,
    required CheckinUser user,
    required BeverageRef beverage,
    double? rating,
    String? review,
    @Default(<FlavorTag>[]) List<FlavorTag> tags,
    @Default(<PhotoRef>[]) List<PhotoRef> photos,
    Price? price,
    String? purchaseType,
    String? servingStyle,
    @Default(0) int toasts,
    @Default(false) bool youToasted,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Checkin;

  factory Checkin.fromJson(Map<String, dynamic> json) => Checkin(
        id: (json['id'] as String?) ?? '',
        user: CheckinUser.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
        beverage: BeverageRef.fromJson(
          (json['beverage'] as Map<String, dynamic>?) ?? const {},
        ),
        rating: (json['rating'] as num?)?.toDouble(),
        review: json['review'] as String?,
        tags: ((json['tags'] as List?) ?? const [])
            .map((e) => FlavorTag.fromJson(e as Map<String, dynamic>))
            .toList(),
        photos: ((json['photos'] as List?) ?? const [])
            .map((e) => PhotoRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        price: json['price'] is Map<String, dynamic>
            ? Price.fromJson(json['price'] as Map<String, dynamic>)
            : null,
        purchaseType: json['purchase_type'] as String?,
        servingStyle: json['serving_style'] as String?,
        toasts: (json['toasts'] as int?) ?? 0,
        youToasted: (json['you_toasted'] as bool?) ?? false,
        createdAt: (json['created_at'] as String?) ?? '',
        updatedAt: (json['updated_at'] as String?) ?? '',
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class FeedItem with _$FeedItem {
  const factory FeedItem({
    required String id,
    required CheckinUser user,
    required BeverageRef beverage,
    double? rating,
    String? review,
    @Default(<FlavorTag>[]) List<FlavorTag> tags,
    @Default(0) int toasts,
    @Default(false) bool youToasted,
    @Default(0) int photoCount,
    @Default('') String createdAt,
  }) = _FeedItem;

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        id: (json['id'] as String?) ?? '',
        user: CheckinUser.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
        beverage: BeverageRef.fromJson(
          (json['beverage'] as Map<String, dynamic>?) ?? const {},
        ),
        rating: (json['rating'] as num?)?.toDouble(),
        review: json['review'] as String?,
        tags: ((json['tags'] as List?) ?? const [])
            .map((e) => FlavorTag.fromJson(e as Map<String, dynamic>))
            .toList(),
        toasts: (json['toasts'] as int?) ?? 0,
        youToasted: (json['you_toasted'] as bool?) ?? false,
        photoCount: (json['photo_count'] as int?) ?? 0,
        createdAt: (json['created_at'] as String?) ?? '',
      );
}

@Freezed(fromJson: false, toJson: false)
abstract class ToastState with _$ToastState {
  const factory ToastState({
    @Default(0) int toasts,
    @Default(false) bool youToasted,
  }) = _ToastState;

  factory ToastState.fromJson(Map<String, dynamic> json) => ToastState(
        toasts: (json['toasts'] as int?) ?? 0,
        youToasted: (json['you_toasted'] as bool?) ?? false,
      );
}
