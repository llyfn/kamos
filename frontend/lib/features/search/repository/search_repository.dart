// KAMOS — SearchRepository. Beverage + brewery search (SPEC §7).
//
// Endpoint returns SearchResult union items with `type ∈ {beverage,brewery}`.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/brewery.dart';
import '../../../core/models/page.dart';

class SearchResultItem {
  SearchResultItem({required this.type, this.beverage, this.brewery});
  final String type;
  final Beverage? beverage;
  final Brewery? brewery;

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? '';
    return SearchResultItem(
      type: type,
      beverage: json['beverage'] is Map<String, dynamic>
          ? Beverage.fromJson(json['beverage'] as Map<String, dynamic>)
          : null,
      brewery: json['brewery'] is Map<String, dynamic>
          ? Brewery.fromJson(json['brewery'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SearchRepository {
  SearchRepository({required this.dio});
  final Dio dio;

  Future<Page<SearchResultItem>> search({
    required String q,
    String? type,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await dio.get(
      '/v1/search',
      queryParameters: {
        'q': q,
        if (type != null && type.isNotEmpty) 'type': type,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => SearchResultItem.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(dio: ref.read(dioProvider)),
);
