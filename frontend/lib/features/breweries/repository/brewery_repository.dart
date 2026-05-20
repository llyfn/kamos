// KAMOS — BreweryRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/brewery.dart';
import '../../../core/models/page.dart';

/// Combined response from `GET /v1/breweries/{id}` — the brewery plus its
/// page of beverages.
class BreweryDetail {
  BreweryDetail({required this.brewery, required this.beverages});
  final Brewery brewery;
  final Page<Beverage> beverages;
}

class BreweryRepository {
  BreweryRepository({required this.dio});
  final Dio dio;

  Future<BreweryDetail> get(String id) async {
    final res = await dio.get('/v1/breweries/$id');
    final data = res.data as Map<String, dynamic>;
    final beveragesPage = data['beverages'] is Map<String, dynamic>
        ? Page.fromJson(
            data['beverages'] as Map<String, dynamic>,
            (raw) => Beverage.fromJson(raw as Map<String, dynamic>),
          )
        : const Page<Beverage>(items: []);
    return BreweryDetail(
      brewery: Brewery.fromJson(data),
      beverages: beveragesPage,
    );
  }
}

final breweryRepositoryProvider = Provider<BreweryRepository>(
  (ref) => BreweryRepository(dio: ref.read(dioProvider)),
);
