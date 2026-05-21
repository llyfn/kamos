// KAMOS — Check-in controller + flavor-tag taxonomy provider.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';
import '../repository/checkin_repository.dart';

final flavorTagsProvider = FutureProvider<List<FlavorTag>>((ref) async {
  return ref.read(checkInRepositoryProvider).tags();
});

/// Single check-in by id for the detail screen.
final checkInDetailProvider = FutureProvider.autoDispose
    .family<Checkin, String>((ref, id) async {
      return ref.read(checkInRepositoryProvider).getOne(id);
    });

class CheckInControllerNotifierState {
  const CheckInControllerNotifierState({
    this.isSubmitting = false,
    this.posted,
    this.error,
  });
  final bool isSubmitting;
  final Checkin? posted;
  final String? error;
}

class CheckInControllerNotifier extends Notifier<CheckInControllerNotifierState> {
  @override
  CheckInControllerNotifierState build() => const CheckInControllerNotifierState();

  Future<Checkin?> submit({
    required String beverageId,
    double? rating,
    String? review,
    List<String> tags = const [],
    List<String> photos = const [],
    Price? price,
    String? purchaseType,
    String? servingStyle,
    Map<String, dynamic>? venue,
  }) async {
    state = const CheckInControllerNotifierState(isSubmitting: true);
    try {
      final posted = await ref
          .read(checkInRepositoryProvider)
          .create(
            beverageId: beverageId,
            rating: rating,
            review: review,
            tags: tags,
            photos: photos,
            price: price,
            purchaseType: purchaseType,
            servingStyle: servingStyle,
            venue: venue,
          );
      state = CheckInControllerNotifierState(posted: posted);
      return posted;
    } on DioException catch (e) {
      final err = e.error is ApiException
          ? (e.error as ApiException).message
          : (e.message ?? 'Request failed');
      state = CheckInControllerNotifierState(error: err);
      return null;
    } catch (e) {
      state = CheckInControllerNotifierState(error: e.toString());
      return null;
    }
  }
}

final checkInControllerProvider =
    NotifierProvider.autoDispose<CheckInControllerNotifier, CheckInControllerNotifierState>(
      CheckInControllerNotifier.new,
    );
