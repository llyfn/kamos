// KAMOS — RatingSlider (SPEC §4.2, post-redesign per
// `docs/history/03_checkin_compose_redesign/00_brief.md`).
//
// Continuous 0.25-step rating slider for the check-in compose screen.
// Replaces the half-star tap-zones with a Material `Slider` snapping to
// 19 stops (0.5..5.0 in 0.25 increments → 18 segments). Rating is
// nullable; the trailing "Clear" affordance returns the value to `null`.
//
// Mirrors the JSX primitive in
// `design/ui_kits/mobile/components/CheckInScreen.jsx::RatingSlider`.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';

/// Lowest selectable value.
const double _kRatingMin = 0.5;

/// Highest selectable value.
const double _kRatingMax = 5.0;

/// 0.25-step → 19 stops, i.e. 18 divisions on the Material slider.
const int _kRatingDivisions = 18;

class RatingSlider extends StatelessWidget {
  const RatingSlider({super.key, required this.value, required this.onChanged});

  /// 0.5 / 0.75 / 1.0 / ... / 5.0, or `null` for unrated.
  final double? value;

  /// Fires with the new value when the slider moves; fires with `null` when
  /// the user taps "Clear".
  final ValueChanged<double?> onChanged;

  /// Snaps a free-running slider position to the canonical 0.25 step grid.
  /// The `Slider` with `divisions: 18` already snaps internally, but we
  /// re-normalize so floating-point arithmetic (`0.5 + i * 0.25`) never
  /// leaks `1.7500000001`-style values into the persistence layer.
  static double _snap(double raw) {
    final clamped = raw.clamp(_kRatingMin, _kRatingMax);
    final index = ((clamped - _kRatingMin) / 0.25).round();
    final snapped = _kRatingMin + index * 0.25;
    // Round to 2 decimals — the wire shape is `NUMERIC(3,2)` and the readout
    // formats with `toStringAsFixed(2)`.
    return double.parse(snapped.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;

    // When unrated, park the slider visually at the low rail (0.5) but
    // keep the readout muted.
    final sliderValue = value ?? _kRatingMin;
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: t.ai,
                  inactiveTrackColor: t.gray200,
                  thumbColor: t.ai,
                  overlayColor: t.ai.withValues(alpha: 0.12),
                  trackHeight: 4,
                  // Hide tick marks — the JSX kit uses a clean track.
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: sliderValue,
                  min: _kRatingMin,
                  max: _kRatingMax,
                  divisions: _kRatingDivisions,
                  onChanged: (v) => onChanged(_snap(v)),
                ),
              ),
            ),
            // Right-side readout, mono font, fixed-width so the slider
            // doesn't reflow as the value changes.
            SizedBox(
              width: 76,
              child: Text(
                hasValue
                    ? '${value!.toStringAsFixed(2)} / 5.0'
                    : '— / 5.0',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: hasValue ? t.fg1 : t.fg3,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: hasValue ? () => onChanged(null) : null,
            style: TextButton.styleFrom(
              foregroundColor: t.fgBrand,
              disabledForegroundColor: t.fgMuted,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.ratingClear,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
