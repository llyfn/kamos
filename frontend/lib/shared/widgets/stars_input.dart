// KAMOS — StarsInput (SPEC §4.2). 0.5-step rating input (10 levels).
//
// Tap the left half of a star to select 0.5, the right half for 1.0. Tapping
// the already-selected value clears it (rating is optional — null is valid).
//
// Returns `double?` to keep nullability honest. Never rounds to integer.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class StarsInput extends StatelessWidget {
  const StarsInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 32,
  });

  /// 0.5 / 1.0 / ... / 5.0, or null for "no rating".
  final double? value;
  final ValueChanged<double?> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final v = value ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final pos = i + 1; // star number 1..5
        final full = v >= pos;
        final half = !full && v >= pos - 0.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarPainter(
                      filled: full,
                      halfFilled: half,
                      fillColor: tokens.yamabuki,
                      emptyColor: tokens.gray200,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: size / 2,
                  height: size,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final next = pos - 0.5;
                      onChanged(value == next ? null : next);
                    },
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  width: size / 2,
                  height: size,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final next = pos.toDouble();
                      onChanged(value == next ? null : next);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.filled,
    required this.halfFilled,
    required this.fillColor,
    required this.emptyColor,
  });
  final bool filled;
  final bool halfFilled;
  final Color fillColor;
  final Color emptyColor;

  Path _star(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = math.min(size.width, size.height) / 2;
    final inner = outer * 0.42;
    final p = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = (-90 + i * 36) * math.pi / 180;
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final star = _star(size);
    canvas.drawPath(star, Paint()..color = emptyColor);
    if (filled) {
      canvas.drawPath(star, Paint()..color = fillColor);
    } else if (halfFilled) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
      canvas.drawPath(star, Paint()..color = fillColor);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.filled != filled ||
      old.halfFilled != halfFilled ||
      old.fillColor != fillColor ||
      old.emptyColor != emptyColor;
}
