// KAMOS — Cursor page envelope (SPEC §6.6 / OpenAPI `PageBase`).
//
// Generic over the item type. Repositories return `Page<T>` records and
// providers concatenate pages. Never offset.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'page.freezed.dart';

@Freezed(fromJson: false, toJson: false, genericArgumentFactories: true)
class Page<T> with _$Page<T> {
  const factory Page({
    required List<T> items,
    String? nextCursor,
    @Default(false) bool hasMore,
  }) = _Page<T>;

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    final raw = (json['items'] as List?) ?? const [];
    return Page<T>(
      items: raw.map(fromJsonT).toList(),
      nextCursor: json['next_cursor'] as String?,
      hasMore: (json['has_more'] as bool?) ?? false,
    );
  }
}
