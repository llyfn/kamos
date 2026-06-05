// Shared page-title row for top-of-screen headers on main tab pages.

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class KamosPageTitle extends StatelessWidget {
  const KamosPageTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = Text(
      text,
      style: TextStyle(
        fontFamily: 'ShipporiMincho',
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: t.fg1,
        height: 1.1,
      ),
    );
    if (trailing == null) {
      return Align(alignment: Alignment.centerLeft, child: title);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [title, trailing!],
    );
  }
}
