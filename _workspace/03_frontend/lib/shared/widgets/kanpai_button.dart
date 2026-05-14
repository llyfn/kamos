// KAMOS — Toast (kanpai) reaction button. Embeds the brand mark image as
// per design README "no emoji in UI"; the white logo overlays a Koh-tinted
// pill when active.

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class KanpaiButton extends StatelessWidget {
  const KanpaiButton({
    super.key,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? t.koh : Colors.transparent,
          border: Border.all(color: active ? t.koh : t.border2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: ColorFiltered(
                colorFilter: active
                    ? const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      )
                    : ColorFilter.mode(t.fg2, BlendMode.srcIn),
                child: Image.asset(
                  'assets/images/logo_white.png',
                  width: 18,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : t.fg2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
