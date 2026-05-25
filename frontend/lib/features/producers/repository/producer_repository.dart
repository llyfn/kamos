// KAMOS — ProducerRepository.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/kamos_api.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/page.dart';
import '../../../core/models/producer.dart';

/// Combined response from `GET /v1/producers/{id}` — the producer plus its
/// page of beverages.
class ProducerDetail {
  ProducerDetail({required this.producer, required this.beverages});
  final Producer producer;
  final Page<Beverage> beverages;
}

/// Wraps the `producers` tag of [KamosApi] (detail + beverages list per
/// producer) and lifts `DioException` into typed `core/api/api_exceptions.dart`
/// exceptions. Used by the producers feature's detail screen.
class ProducerRepository {
  ProducerRepository({required Dio dio}) : _api = KamosApi(dio);

  final KamosApi _api;

  Future<ProducerDetail> get(String id) async {
    final data = await _api.producers.get(id);
    final beveragesPage = data['beverages'] is Map<String, dynamic>
        ? Page.fromJson(
            data['beverages'] as Map<String, dynamic>,
            (raw) => Beverage.fromJson(raw as Map<String, dynamic>),
          )
        : const Page<Beverage>(items: []);
    return ProducerDetail(
      producer: Producer.fromJson(data),
      beverages: beveragesPage,
    );
  }
}

final producerRepositoryProvider = Provider<ProducerRepository>(
  (ref) => ProducerRepository(dio: ref.watch(dioProvider)),
);
