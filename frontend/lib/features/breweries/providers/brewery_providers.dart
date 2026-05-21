// KAMOS — Brewery detail provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/brewery_repository.dart';

final breweryDetailProvider = FutureProvider.autoDispose
    .family<BreweryDetail, String>((ref, id) async {
      return ref.read(breweryRepositoryProvider).get(id);
    });
