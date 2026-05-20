// KAMOS — Pill-shaped chip used for category filters, flavor tags, and
// segmented option groups.

import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum KamosChipKind { defaultChip, tag, category }

class KamosChip extends StatelessWidget {
  const KamosChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.kind = KamosChipKind.defaultChip,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final KamosChipKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Color bg;
    Color fg;
    Color border;
    switch (kind) {
      case KamosChipKind.tag:
        bg = t.bgTintMizu;
        fg = t.kon;
        border = Colors.transparent;
        break;
      case KamosChipKind.category:
        bg = t.kinari;
        fg = t.fg1;
        border = Colors.transparent;
        break;
      case KamosChipKind.defaultChip:
        if (selected) {
          bg = t.ai;
          fg = Colors.white;
          border = t.ai;
        } else {
          bg = t.bgSurface;
          fg = t.fg1;
          border = t.border2;
        }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoSansJP',
            fontSize: 13,
            color: fg,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
