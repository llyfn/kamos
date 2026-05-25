// KAMOS — SearchRepository. Beverage + producer search (SPEC §7).
//
// Endpoint returns SearchResult union items with `type ∈ {beverage,producer}`.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/page.dart';
import '../../../core/models/producer.dart';

class SearchResultItem {

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? '';
    return SearchResultItem(
      type: type,
      beverage: json['beverage'] is Map<String, dynamic>
          ? Beverage.fromJson(json['beverage'] as Map<String, dynamic>)
          : null,
      producer: json['producer'] is Map<String, dynamic>
          ? Producer.fromJson(json['producer'] as Map<String, dynamic>)
          : null,
    );
  }
  SearchResultItem({required this.type, this.beverage, this.producer});
  final String type;
  final Beverage? beverage;
  final Producer? producer;
}

/// Wraps the `search` tag of [KamosApi] (beverages, producers, users)
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
