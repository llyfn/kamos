// KAMOS — BeverageRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/page.dart';

class BeverageRepository {
  BeverageRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  Future<Page<Beverage>> list({
    String? q,
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    final data = await _api.beverages.list(
      q: q,
      category: category,
      cursor: cursor,
      limit: limit,
    );
    return Page.fromJson(
      data,
      (raw) => Beverage.fromJson(raw as Map<String, dynamic>),
    );
  }

  Future<BeverageDetail> get(String id) async {
    final data = await _api.beverages.get(id);
    return BeverageDetail.fromJson(data);
  }
}

final beverageRepositoryProvider = Provider<BeverageRepository>(
  (ref) => BeverageRepository(dio: ref.read(dioProvider)),
);
