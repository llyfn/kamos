// KAMOS — SearchRepository. Beverage + brewery search (SPEC §7).
//
// Endpoint returns SearchResult union items with `type ∈ {beverage,brewery}`.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/brewery.dart';
import '../../../core/models/page.dart';

class SearchResultItem {

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
  SearchResultItem({required this.type, this.beverage, this.brewery});
  final String type;
  final Beverage? beverage;
  final Brewery? brewery;
}

/// Wraps the `search` tag of [KamosApi] (beverages, breweries, users)
/// and lifts `DioException` into typed `core/api/api_exceptions.dart`
/// exceptions. Used by the search feature's typeahead + results screen
/// providers.
class SearchRepository {
  SearchRepository({required Dio dio}) : _api = KamosApi(dio);
  final KamosApi _api;

  Future<Page<SearchResultItem>> search({
    required String q,
    String? type,
    String? cursor,
    int limit = 20,
  }) async {
    final data = await _api.search.query(
      q: q,
      type: type,
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => SearchResultItem.fromJson(raw as Map<String, dynamic>),
    );
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(dio: ref.watch(dioProvider)),
);
