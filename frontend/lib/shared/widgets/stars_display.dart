// KAMOS — Read-only star rating display at half-star granularity.
//
// Renders five fixed star slots. Each slot is either filled, half, or empty.
// Half-stars use a custom CustomPainter rather than the U+2BE8 codepoint
// (which renders inconsistently across OS — flagged in design HANDOFF.md).
// Compose-side ratings are KamosSpec.ratingStep precision; this read-only
// widget quantizes down to half-star for display.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/spec/spec.dart';

enum _StarKind { full, half, empty }

// Half-star display threshold derived from the compose step so the two
// stay symmetric with rating_slider.dart's _kTickSpacing.
const double _kHalfStarThreshold = KamosSpec.ratingStep * 2;

class StarsDisplay extends StatelessWidget {
  const StarsDisplay({super.key, required this.value, this.size = 14});

  /// Rating in [0.0, KamosSpec.ratingMax]; `null` renders as five empty stars.
  final double? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = v - i;
        final kind = fill >= 1
            ? _StarKind.full
            : fill >= _kHalfStarThreshold
            ? _StarKind.half
            : _StarKind.empty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: CustomPaint(
            size: Size(size, size),
            painter: _StarPainter(
              kind: kind,
              fillColor: tokens.yamabuki,
              emptyColor: tokens.gray200,
            ),
          ),
        );
      }),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.kind,
    required this.fillColor,
    required this.emptyColor,
  });

  final _StarKind kind;
  final Color fillColor;
  final Color emptyColor;

  Path _starPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final outerR = math.min(w, h) / 2;
    final innerR = outerR * 0.42;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final angle = (-90 + i * 36) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final star = _starPath(size);
    canvas.drawPath(star, Paint()..color = emptyColor);
    if (kind == _StarKind.empty) return;
    if (kind == _StarKind.full) {
      canvas.drawPath(star, Paint()..color = fillColor);
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
    canvas.drawPath(star, Paint()..color = fillColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.kind != kind ||
      old.fillColor != fillColor ||
      old.emptyColor != emptyColor;
}
