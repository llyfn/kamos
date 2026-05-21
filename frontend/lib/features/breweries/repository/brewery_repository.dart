// KAMOS — BreweryRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
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

/// Wraps the `breweries` tag of [KamosApi] (detail + beverages list per
/// brewery) and lifts `DioException` into typed `core/api/api_exceptions.dart`
/// exceptions. Used by the breweries feature's detail screen.
class BreweryRepository {
  BreweryRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  Future<BreweryDetail> get(String id) async {
    final data = await _api.breweries.get(id);
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
