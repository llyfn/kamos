// KAMOS — Pill-shaped action button. Primary (filled, Ai-iro) and
// Secondary (outlined, transparent) variants share identical paddings,
// shape, and minimum height so a [Row] of one of each renders without
// a visible height mismatch.
//
// Before this widget, Profile used `FilledButton` (vertical:12) + a bare
// `OutlinedButton` (theme padding), and Beverage Detail used
// `FilledButton` (vertical:14) + `OutlinedButton.icon` (theme padding) —
// in both cases the two pills rendered at different heights. Use this
// widget for any two-action pill row to keep the rhythm consistent.
//
// Implementation note: this widget renders directly via Material +
// InkWell + Container (NOT FilledButton / OutlinedButton). The Material
// button widgets pick up font / padding / minimumSize indirectly from
// `ElevatedButtonTheme`, `OutlinedButtonTheme`, and `_InputPadding`,
// which makes "give both variants the same height" surprisingly hard
// to guarantee. A handwritten container-based pill removes that whole
// surface and the height contract becomes "padding + text intrinsic
// height + a `minHeight: 44` floor", which both variants share verbatim.

import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum _Variant { primary, secondary }

class KamosPillButton extends StatelessWidget {
  /// Filled variant — Ai-iro (`t.ai`) background, white foreground.
  /// Use for the primary call to action.
  const KamosPillButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  }) : _variant = _Variant.primary;

  /// Outlined variant — transparent background, `t.border1` border,
  /// `t.fg1` foreground. Use for the secondary action that lives next
  /// to a [KamosPillButton.primary].
  const KamosPillButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  }) : _variant = _Variant.secondary;

  /// Button label. Rendered with the theme's `labelLarge` style so both
  /// variants share identical typography and vertical metrics.
  final String label;

  /// Tap handler. Passing `null` puts the button in its disabled state
  /// (foreground/background colors mute and the tap surface is inert).
  final VoidCallback? onPressed;

  /// Optional leading icon. Rendered at a fixed 16 px so the icon row's
  /// vertical extent does not push the button taller than the no-icon
  /// variant beside it.
  final IconData? icon;

  /// When `true` (default), wraps the button in [Expanded]. Set to
  /// `false` when the button is used outside a [Row]/[Column] flex.
  final bool expand;

  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null;

    // Shared visual contract — every dimension that contributes to the
    // pill's intrinsic height is identical across variants:
    //   * padding         — symmetric(vertical:12, horizontal:16)
    //   * shape           — stadium (radius 999)
    //   * minHeight       — 44 px HIG tap target
    //   * label text style — theme.textTheme.labelLarge (no per-variant
    //                        font size or line-height override)
    //   * leading icon     — 16 px (when present), with a fixed 8 px gap
    const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    // Variant tokens.
    final Color bg;
    final Color fg;
    final Border? border;
    switch (_variant) {
      case _Variant.primary:
        bg = enabled ? t.ai : t.ai.withValues(alpha: 0.4);
        fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.7);
        border = null;
        break;
      case _Variant.secondary:
        bg = Colors.transparent;
        fg = enabled ? t.fg1 : t.fgMuted;
        border = Border.all(color: t.border1);
        break;
    }

    final Widget content = icon == null
        ? Text(label, style: labelStyle?.copyWith(color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(label, style: labelStyle?.copyWith(color: fg)),
            ],
          );

    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );

    if (!expand) return button;
    return Expanded(child: button);
  }
}
