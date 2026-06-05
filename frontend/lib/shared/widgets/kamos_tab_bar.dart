// KAMOS — Bottom tab bar (Shell.jsx parity per
// design/notifications_ux.md §1).
//
// Five equal-width tabs in this order:
//   Feed · Lists · Discover · Notifications · Me
//
// Check-in is reached from the Feed CTA and the beverage-detail page.
// The Notifications tab carries an unread dot (var(--c-koh), 8px) when
// any notification row is unread; the dot is presence-only, never a
// count (SPEC §5.4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../../l10n/app_localizations.dart';

class KamosTabBar extends ConsumerWidget {
  const KamosTabBar({super.key, required this.location});
  final String location;

  int _indexFor() {
    if (location.startsWith('/collections')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/me')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final idx = _indexFor();
    final unreadAsync = ref.watch(unreadCountProvider);
    final hasUnread = unreadAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );
    final tabs = <(IconData, String, String, bool)>[
      (Icons.home_outlined, l.tabFeed, '/', false),
      (Icons.bookmark_outline, l.tabLists, '/collections', false),
      (Icons.search, l.tabDiscover, '/discover', false),
      (Icons.notifications_outlined, l.tabNotifications, '/notifications',
        hasUnread),
      (Icons.person_outline, l.tabMe, '/me', false),
    ];

    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: t.bgPage.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: t.border1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (icon, label, path, showDot) = tabs[i];
          final active = idx == i;
          return Expanded(
            child: InkWell(
              onTap: () {
                context.go(path);
                if (path == '/notifications') {
                  // Refreshing on tab focus matches the design's "fetch on
                  // tab-focus into a non-Notifications tab" rule — the dot
                  // should disappear right after marking-on-scroll lands.
                  ref.read(unreadCountProvider.notifier).refresh();
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            icon,
                            size: 22,
                            color: active ? t.ai : t.fg3,
                          ),
                        ),
                        if (showDot)
                          Positioned(
                            top: -2,
                            right: -4,
                            child: AnimatedContainer(
                              duration: t.durBase,
                              curve: Curves.easeOut,
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: t.koh,
                                shape: BoxShape.circle,
                                border: Border.all(color: t.bgPage, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active ? t.ai : t.fg3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: KamosTabBar(location: location),
    );
  }
}
