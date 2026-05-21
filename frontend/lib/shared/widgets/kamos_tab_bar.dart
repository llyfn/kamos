// KAMOS — Bottom tab bar (Shell.jsx parity). 5 tabs: Feed, Search, Check in,
// Lists, Me. The center "Check in" tab is a raised circular Ai-iro button.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

class KamosTabBar extends StatelessWidget {
  const KamosTabBar({super.key, required this.location});
  final String location;

  int _indexFor() {
    if (location.startsWith('/search')) return 1;
    if (location == '/check-in') return 2;
    if (location.startsWith('/collections')) return 3;
    if (location.startsWith('/me')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final idx = _indexFor();
    final tabs = [
      (Icons.home_outlined, l.tabFeed, '/'),
      (Icons.search, l.tabSearch, '/search'),
      (Icons.add, l.tabCheckIn, '/check-in'),
      (Icons.bookmark_outline, l.tabLists, '/collections'),
      (Icons.person_outline, l.tabMe, '/me'),
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
          final (icon, label, path) = tabs[i];
          final active = idx == i;
          if (i == 2) {
            // Center "Check in" button — needs a beverage to actually fire,
            // so it links to /search where the user picks one first.
            return Expanded(
              child: InkWell(
                onTap: () => context.go('/search'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: t.ai,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140F2350),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: t.fg3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Expanded(
            child: InkWell(
              onTap: () => context.go(path),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: active ? t.ai : t.fg3),
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
