// KAMOS — Card surface. White or Kinari background, hairline border,
// shadow-1, 12px radius, 16px internal padding.

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class KamosCard extends StatelessWidget {
  const KamosCard({
    super.key,
    required this.child,
    this.warm = false,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final bool warm;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: warm ? t.bgWarm : t.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F2350),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
  }
}
