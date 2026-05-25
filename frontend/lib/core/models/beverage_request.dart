// KAMOS — BeverageRequest model (user-side, OpenAPI
// `submitBeverageRequest`).
//
// The backend body shape is `{ "payload": { ... } }` — see openapi.yaml line
// 1085-1095. The server is intentionally schema-free on `payload`; it only
// validates that the object is non-empty. The user-side Flutter form pins the
// payload shape to four fields so admin review has consistent inputs to look
// at:
//
// {
// "name": string, // beverage name as the user typed it
// "producer_name": string, // producer/maker as the user typed it
// "category_slug": one of 'nihonshu' | 'shochu' | 'liqueur',
// "notes": string? // optional free-form, omitted when empty
// }
//
// `notes` is dropped from the JSON when null/empty so the admin tool can
// rely on `notes` being present == user-supplied.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'beverage_request.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class BeverageRequest with _$BeverageRequest {
  const BeverageRequest._();
  const factory BeverageRequest({
    required String name,
    required String producerName,
    required String categorySlug,
    String? notes,
  }) = _BeverageRequest;

  /// Body shape sent to `POST /v1/beverage-requests`. Always wraps the four
  /// fields inside a `payload` object — that wrapper is enforced by the
  /// backend's `domain.BeverageRequest{Payload map[string]any}` shape.
  Map<String, dynamic> toJson() {
    final n = notes;
    final hasNotes = n != null && n.trim().isNotEmpty;
    return {
      'payload': {
        'name': name,
        'producer_name': producerName,
        'category_slug': categorySlug,
        if (hasNotes) 'notes': n.trim(),
      },
    };
  }
}
