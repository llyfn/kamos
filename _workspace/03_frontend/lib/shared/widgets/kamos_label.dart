// KAMOS — Beverage label thumbnail. Pure-Dart styled rectangle so the kit
// works without a network image. When `imageUrl` is set, we render the real
// label instead.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum LabelTone { navy, koh, matcha, sky }

LabelTone labelToneFromCategory(String slug) {
  switch (slug) {
    case 'shochu':
      return LabelTone.koh;
    case 'liqueur':
      return LabelTone.matcha;
    case 'nihonshu':
    default:
      return LabelTone.navy;
  }
}

class KamosLabel extends StatelessWidget {
  const KamosLabel({
    super.key,
    this.width = 56,
    this.height = 72,
    this.tone = LabelTone.navy,
    this.kanji,
    this.romaji,
    this.imageUrl,
  });

  final double width;
  final double height;
  final LabelTone tone;
  final String? kanji;
  final String? romaji;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(),
          placeholder: (_, __) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    const t = KamosTokens.light;
    LinearGradient gradient;
    switch (tone) {
      case LabelTone.koh:
        gradient = const LinearGradient(
          colors: [Color(0xFFC97B5A), Color(0xFF8B4A2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case LabelTone.matcha:
        gradient = const LinearGradient(
          colors: [Color(0xFF8FAA7C), Color(0xFF4F6B40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case LabelTone.sky:
        gradient = LinearGradient(
          colors: [t.sora, t.ai],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case LabelTone.navy:
        gradient = const LinearGradient(
          colors: [Color(0xFF2A4A6B), Color(0xFF0F2350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 0,
            offset: Offset.zero,
            spreadRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (kanji != null)
            Text(
              kanji!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: width * 0.22,
                height: 1.05,
              ),
            ),
          if (romaji != null && romaji!.isNotEmpty)
            Text(
              romaji!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: width * 0.13,
                height: 1.05,
              ),
            ),
        ],
      ),
    );
  }
}
