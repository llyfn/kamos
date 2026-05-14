// KAMOS — CheckInRepository. Photo upload is URL-by-reference for MVP (the
// backend has not yet wired blob storage — QA MAJOR #1). The Flutter UI
// uses `image_picker` to capture the image; production wiring will swap the
// URL field for the result of a presigned-upload call.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';

class CheckInRepository {
  CheckInRepository({required this.dio});
  final Dio dio;

  Future<Checkin> create({
    required String beverageId,
    double? rating,
    String? review,
    List<String> tags = const [],
    List<String> photos = const [],
    Price? price,
    String? purchaseType,
    String? servingStyle,
  }) async {
    final res = await dio.post(
      '/v1/check-ins',
      data: {
        'beverage_id': beverageId,
        'rating': ?rating,
        if (review != null && review.isNotEmpty) 'review': review,
        if (tags.isNotEmpty) 'tags': tags,
        if (photos.isNotEmpty) 'photos': photos,
        'price': ?price?.toJson(),
        'purchase_type': ?purchaseType,
        'serving_style': ?servingStyle,
      },
    );
    return Checkin.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<FlavorTag>> tags() async {
    final res = await dio.get('/v1/flavor-tags');
    final raw = (res.data as List?) ?? const [];
    return raw
        .map((e) => FlavorTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => CheckInRepository(dio: ref.read(dioProvider)),
);
