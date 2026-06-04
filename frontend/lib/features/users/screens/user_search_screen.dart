// KAMOS — User search screen.
//
// Wires a debounced TextField to `userSearchProvider(query)`. The result list
// is cursor-paginated and infinite-scrolls; each row taps to `/users/:username`.
//
// Debounce: 300 ms. The provider is autoDispose + family-keyed by the trimmed
// query string, so each debounced keystroke creates a fresh notifier and the
// in-flight notifier for the previous query is dropped when the user moves on.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../navigation.dart';
import '../providers/users_providers.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_query.length < 2) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(userSearchProvider(_query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final canSearch = _query.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.userSearchTitle,
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontWeight: FontWeight.w600,
            color: t.fg1,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KamosSpacing.lg,
              KamosSpacing.sm,
              KamosSpacing.lg,
              KamosSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: l.userSearchPlaceholder,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: canSearch
                ? _Results(query: _query, scrollController: _scrollController)
                : EmptyView(
                    glyph: '人',
                    body: l.userSearchPlaceholder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.scrollController});

  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(userSearchProvider(query));

    return AsyncWidget(
      value: async,
      onRetry: () => ref.invalidate(userSearchProvider(query)),
      data: (state) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(userSearchProvider(query).future),
          child: state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyView(glyph: '人', title: l.userSearchNoResults),
                  ],
                )
              : ListView.separated(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: KamosSpacing.sm),
          itemCount: state.items.length + 1,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: t.border1, indent: 72),
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              return PagingFooter(
                isLoading: state.isLoadingMore,
                hasMore: state.hasMore,
              );
            }
            final u = state.items[i];
            final primary = u.displayName.isEmpty
                ? u.displayUsername
                : u.displayName;
            return InkWell(
              onTap: () => pushUserProfile(context, u.username),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KamosSpacing.lg,
                  vertical: KamosSpacing.md,
                ),
                child: Row(
                  children: [
                    KamosAvatar(
                      initial: u.displayUsername,
                      size: 40,
                      imageUrl: u.avatarUrl,
                    ),
                    const SizedBox(width: KamosSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primary,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.fg1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${u.username}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                              color: t.fg3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        );
      },
    );
  }
}
