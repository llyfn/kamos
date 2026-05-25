// KAMOS — Producer detail provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/producer_repository.dart';

final producerDetailProvider = FutureProvider.autoDispose
    .family<ProducerDetail, String>((ref, id) async {
      return ref.read(producerRepositoryProvider).get(id);
    });
