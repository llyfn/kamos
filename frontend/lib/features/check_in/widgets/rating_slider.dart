// Rating slider for check-in compose. Range + step from KamosSpec.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/spec/spec.dart';

const double _kMin = KamosSpec.ratingMin;
const double _kMax = KamosSpec.ratingMax;
const double _kStep = KamosSpec.ratingStep;
const double _kTrackHeight = 4;
const double _kThumbRadius = 10;
const double _kTickHeight = 8;

class RatingSlider extends StatelessWidget {
  const RatingSlider({super.key, required this.value, required this.onChanged});

  /// 0.5..5.0 in 0.25 steps, or `null` for unrated.
  final double? value;

  final ValueChanged<double> onChanged;

  static double _snap(double raw) {
    final clamped = raw.clamp(_kMin, _kMax);
    final index = ((clamped - _kMin) / _kStep).round();
    final snapped = _kMin + index * _kStep;
    return double.parse(snapped.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _RatingTrack(
          width: constraints.maxWidth,
          value: value,
          onChanged: (v) => onChanged(_snap(v)),
        );
      },
    );
  }
}

class _RatingTrack extends StatelessWidget {
  const _RatingTrack({
    required this.width,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final double? value;
  final ValueChanged<double> onChanged;

  double _valueAt(double localX) {
    final usable = width - _kThumbRadius * 2;
    if (usable <= 0) return _kMin;
    final clampedX = (localX - _kThumbRadius).clamp(0.0, usable);
    final ratio = clampedX / usable;
    return _kMin + ratio * (_kMax - _kMin);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value ?? _kMin;
    final hasValue = value != null;
    final usable = width - _kThumbRadius * 2;
    final ratio = ((v - _kMin) / (_kMax - _kMin)).clamp(0.0, 1.0);
    final thumbX = _kThumbRadius + ratio * usable;
    final tickCount = ((_kMax - _kMin) / 0.5).round() + 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => onChanged(_valueAt(d.localPosition.dx)),
      onPanStart: (d) => onChanged(_valueAt(d.localPosition.dx)),
      onPanUpdate: (d) => onChanged(_valueAt(d.localPosition.dx)),
      child: SizedBox(
        height: _kThumbRadius * 2 + _kTickHeight + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _kThumbRadius,
              right: _kThumbRadius,
              top: _kThumbRadius - _kTrackHeight / 2,
              child: Container(
                height: _kTrackHeight,
                decoration: BoxDecoration(
                  color: t.gray200,
                  borderRadius: BorderRadius.circular(_kTrackHeight / 2),
                ),
              ),
            ),
            if (hasValue)
              Positioned(
                left: _kThumbRadius,
                top: _kThumbRadius - _kTrackHeight / 2,
                child: Container(
                  width: ratio * usable,
                  height: _kTrackHeight,
                  decoration: BoxDecoration(
                    color: t.ai,
                    borderRadius: BorderRadius.circular(_kTrackHeight / 2),
                  ),
                ),
              ),
            for (var i = 0; i < tickCount; i++)
              Positioned(
                left: _kThumbRadius + (i * 0.5 / (_kMax - _kMin)) * usable - 0.5,
                top: _kThumbRadius * 2,
                child: Container(
                  width: 1,
                  height: _kTickHeight,
                  color: t.gray200,
                ),
              ),
            Positioned(
              left: thumbX - _kThumbRadius,
              top: 0,
              child: Container(
                width: _kThumbRadius * 2,
                height: _kThumbRadius * 2,
                decoration: BoxDecoration(
                  color: hasValue ? t.ai : t.gray200,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
double snapRatingValue(double raw) => RatingSlider._snap(raw);
