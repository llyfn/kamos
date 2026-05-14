// KAMOS — BeverageRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/page.dart';

class BeverageRepository {
  BeverageRepository({required this.dio});
  final Dio dio;

  Future<Page<Beverage>> list({
    String? q,
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await dio.get(
      '/v1/beverages',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (category != null && category.isNotEmpty) 'category': category,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Page.fromJson(
      res.data as Map<String, dynamic>,
      (raw) => Beverage.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<BeverageDetail> get(String id) async {
    final res = await dio.get('/v1/beverages/$id');
    return BeverageDetail.fromJson(res.data as Map<String, dynamic>);
  }
}

final beverageRepositoryProvider = Provider<BeverageRepository>(
  (ref) => BeverageRepository(dio: ref.read(dioProvider)),
);
