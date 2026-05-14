// KAMOS — Avatar widget. Falls back to a Kinari tile with the user's first
// initial in display type, per design README "avatars" rules.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum AvatarTone { kinari, mizu, kon }

class KamosAvatar extends StatelessWidget {
  const KamosAvatar({
    super.key,
    required this.initial,
    this.size = 36,
    this.tone = AvatarTone.kinari,
    this.imageUrl,
  });

  final String initial;
  final double size;
  final AvatarTone tone;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Color bg;
    Color fg;
    switch (tone) {
      case AvatarTone.kon:
        bg = t.kon;
        fg = Colors.white;
        break;
      case AvatarTone.mizu:
        bg = t.mizu;
        fg = t.fg1;
        break;
      case AvatarTone.kinari:
        bg = t.kinari;
        fg = t.fg1;
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) =>
              _initialBox(bg, fg, t.border1, initial, size),
          placeholder: (_, _) => _initialBox(bg, fg, t.border1, '', size),
        ),
      );
    }
    return _initialBox(bg, fg, t.border1, initial, size);
  }

  static Widget _initialBox(
    Color bg,
    Color fg,
    Color border,
    String initial,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Text(
        initial.isEmpty ? '?' : initial.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontFamily: 'ShipporiMincho',
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
