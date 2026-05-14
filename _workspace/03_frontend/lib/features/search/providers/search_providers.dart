// KAMOS — Search providers. Debouncing happens at the screen level.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page.dart';
import '../repository/search_repository.dart';

class SearchQuery {
  const SearchQuery({required this.q, this.type});
  final String q;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.q == q && other.type == type;

  @override
  int get hashCode => Object.hash(q, type);
}

final searchProvider = FutureProvider.autoDispose
    .family<Page<SearchResultItem>, SearchQuery>((ref, query) async {
  if (query.q.isEmpty) {
    return const Page<SearchResultItem>(items: []);
  }
  return ref
      .read(searchRepositoryProvider)
      .search(q: query.q, type: query.type);
});
