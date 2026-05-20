// KAMOS — Collection providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collection.dart';
import '../../../core/models/page.dart';
import '../repository/collection_repository.dart';

final collectionsProvider = FutureProvider<Page<Collection>>((ref) async {
  return ref.read(collectionRepositoryProvider).list();
});

final collectionDetailProvider = FutureProvider.autoDispose
    .family<(Collection, Page<CollectionEntry>), String>((ref, id) async {
  return ref.read(collectionRepositoryProvider).detail(id);
});
