// KAMOS — PhotoRef (OpenAPI `PhotoRef`).
//
// Hosted at the model-package root so both `checkin.dart` and `beverage.dart`
// (which embeds `CheckinSummary`) can reference it without a cyclic import.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_ref.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class PhotoRef with _$PhotoRef {
  const factory PhotoRef({
    required String url,
    @Default(0) int sortOrder,
  }) = _PhotoRef;

  // The OpenAPI `PhotoRef` schema only carries `url` + `sort_order` (see
  // `openapi.yaml` and `backend/internal/domain/types_checkin.go`). The
  // previous `id` field was speculative — the wire never delivered it.
  factory PhotoRef.fromJson(Map<String, dynamic> json) => PhotoRef(
    url: (json['url'] as String?) ?? '',
    sortOrder: (json['sort_order'] as int?) ?? 0,
  );
}
