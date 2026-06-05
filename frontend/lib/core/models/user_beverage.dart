// KAMOS — UserBeverageRow model (OpenAPI `UserBeverageRow`).
//
// One row of `GET /v1/users/{username}/beverages` — the distinct-beverage
// aggregation across a single user's check-ins. The user's mean rating
// (across their non-null check-ins for this beverage) sits beside the
// beverage's global average so the client can render the "you 4.5 /
// global 4.2" comparison without a second fetch. Both averages are
// nullable (the user case is null when every one of their check-ins
// was rating-less; the global case can be null on a brand-new beverage).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'beverage.dart';

part 'user_beverage.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class UserBeverageRow with _$UserBeverageRow {
  const factory UserBeverageRow({
    required BeverageRef beverage,
    double? userAvgRating,
    @Default(0) int userCheckinCount,
    @Default('') String lastCheckinAt,
    double? globalAvgRating,
    @Default(0) int globalCheckinCount,
  }) = _UserBeverageRow;

  factory UserBeverageRow.fromJson(Map<String, dynamic> json) => UserBeverageRow(
    beverage: BeverageRef.fromJson(
      (json['beverage'] as Map<String, dynamic>?) ?? const {},
    ),
    userAvgRating: (json['user_avg_rating'] as num?)?.toDouble(),
    userCheckinCount: (json['user_checkin_count'] as int?) ?? 0,
    lastCheckinAt: (json['last_checkin_at'] as String?) ?? '',
    globalAvgRating: (json['global_avg_rating'] as num?)?.toDouble(),
    globalCheckinCount: (json['global_check_in_count'] as int?) ?? 0,
  );
}
