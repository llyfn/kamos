// KAMOS — Shared followers/following list body.
//
// Used by both `FollowersScreen` and `FollowingScreen`. The screens
// differ only in the AppBar title, empty-state copy, and the `kind`
// flag passed to `socialListProvider`. Search is debounced ~250 ms
// before flipping the family key.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../navigation.dart';
import '../providers/social_list_provider.dart';

class SocialListView extends ConsumerStatefulWidget {
  const SocialListView({
    super.key,
    required this.username,
    required this.kind,
    required this.title,
    required this.emptyTitle,
  });

  final String username;
  final SocialListKind kind;
  final String title;
  final String emptyTitle;

  @override
  ConsumerState<SocialListView> createState() => _SocialListViewState();
}

class _SocialListViewState extends ConsumerState<SocialListView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _q = '';

  SocialListArgs get _args =>
      SocialListArgs(username: widget.username, kind: widget.kind, q: _q);

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
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _q = value.trim());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(socialListProvider(_args).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(socialListProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
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
              textInputAction: TextInputAction.search,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: l.socialSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: AsyncWidget(
              value: async,
              center: true,
              onRetry: () => ref.invalidate(socialListProvider(_args)),
              data: (state) {
                if (state.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(socialListProvider(_args).future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyView(
                          glyph: '人',
                          title: _q.isEmpty
                              ? widget.emptyTitle
                              : l.socialSearchNoMatch,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(socialListProvider(_args).future),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: KamosSpacing.sm,
                    ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
            ),
          ),
        ],
      ),
    );
  }
}
