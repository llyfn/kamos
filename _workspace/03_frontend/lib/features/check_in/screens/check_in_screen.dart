// KAMOS — Check-in screen (SPEC §4).
//
// - Optional 0.5-step rating (null = "I tried this")
// - 500-char review hard cap with live counter
// - Flavor tag chips, multi-select
// - Up to 4 photos (UI cap; the server is the backstop)
// - Price (amount + currency + per-serving|per-bottle)
// - Purchase type, serving style

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/beverage.dart';
import '../../../core/models/checkin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_input.dart';
import '../providers/checkin_providers.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, required this.beverage});
  final Beverage beverage;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  double? _rating;
  final _review = TextEditingController();
  final _price = TextEditingController();
  final Set<String> _tags = {};
  final List<XFile> _photos = [];
  String _currency = 'JPY';
  String _priceMode = 'serving';
  String? _purchase;
  String? _serving;

  // STUB: tag selection is by english label until /v1/flavor-tags is queried.
  // The future-version queries `flavorTagsProvider` for the canonical list
  // and uses tag.slug as the value sent to the server. For MVP, we still
  // POST these strings — the backend treats them as tag slugs.
  // NOTE: clean wiring is part of the qa-inspector follow-ups.
  final _tagDimensions = const {
    'flavorSweetness': ['Dry', 'Off-dry', 'Sweet', 'Very sweet'],
    'flavorBody': ['Light', 'Medium', 'Full'],
    'flavorAcidity': ['Low', 'Crisp', 'Bright', 'Sharp'],
    'flavorCharacter':
        ['Fruity', 'Floral', 'Earthy', 'Umami', 'Smoky', 'Nutty', 'Woody'],
    'flavorFinish': ['Short', 'Clean', 'Lingering', 'Warming'],
  };

  @override
  void dispose() {
    _review.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.checkInPhotoLimitReached)),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null && mounted) {
        setState(() => _photos.add(file));
      }
    } catch (_) {
      // Image picker not available (sim/test) — silently no-op.
    }
  }

  void _toggleTag(String t) {
    setState(() {
      if (_tags.contains(t)) {
        _tags.remove(t);
      } else {
        _tags.add(t);
      }
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    Price? price;
    final amount = double.tryParse(_price.text);
    if (amount != null && amount > 0) {
      price = Price(amount: amount, currency: _currency, mode: _priceMode);
    }
    // NOTE: photos are uploaded URL-by-reference per QA MAJOR #1. Until the
    // backend wires blob storage, this screen does not actually transmit
    // photo bytes — only the count. The future flow swaps in a presigned-URL
    // request before POST /v1/check-ins.
    final posted =
        await ref.read(checkInControllerProvider.notifier).submit(
              beverageId: widget.beverage.id,
              rating: _rating,
              review: _review.text.isEmpty ? null : _review.text,
              tags: _tags.toList(),
              price: price,
              purchaseType: _purchase,
              servingStyle: _serving,
            );
    if (posted != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.checkInFirstToast)),
      );
      context.pop();
    } else if (mounted) {
      final err = ref.read(checkInControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final state = ref.watch(checkInControllerProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final beverageName = resolveI18n(widget.beverage.name, locale);
    final brewery = resolveI18n(widget.beverage.brewery.name, locale);
    final slug = categorySlugFromString(widget.beverage.category.slug);
    final catLabel = slug == null
        ? resolveI18n(widget.beverage.category.labelI18n, locale)
        : categoryLabel(context, slug);

    final canPost = !state.isSubmitting && _review.text.length <= 500;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(l.checkInTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: FilledButton(
              onPressed: canPost ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: t.ai,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                visualDensity: VisualDensity.compact,
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l.checkInSubmit),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.bgSurface,
                border: Border.all(color: t.border1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  KamosLabel(
                    width: 48,
                    height: 64,
                    tone: labelToneFromCategory(widget.beverage.category.slug),
                    imageUrl: widget.beverage.labelImageUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beverageName,
                          style: const TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(brewery, style: TextStyle(fontSize: 12, color: t.fg2)),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            catLabel.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'NotoSansJP',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: t.fg3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Section(text: l.ratingLabel),
            const SizedBox(height: 8),
            StarsInput(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
              size: 32,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _rating == null
                    ? l.ratingTapToRate
                    : l.ratingValue(_rating!.toStringAsFixed(1)),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: t.fg2,
                ),
              ),
            ),
            _Section(text: l.checkInReviewLabel),
            TextField(
              controller: _review,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: l.checkInReviewPlaceholder,
              ),
              onChanged: (_) => setState(() {}),
            ),
            _Section(text: l.checkInFlavorTags),
            for (final entry in _tagDimensions.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _tagDimensionLabel(l, entry.key).toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.3,
                          color: t.fg3,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.value
                          .map((tag) => KamosChip(
                                label: tag,
                                selected: _tags.contains(tag),
                                onTap: () => _toggleTag(tag),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            _Section(text: l.checkInPhotosLabel),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(4, (i) {
                if (i < _photos.length) {
                  return _PhotoTile(
                    filled: true,
                    onRemove: () => setState(() => _photos.removeAt(i)),
                  );
                }
                return _PhotoTile(filled: false, onTap: _addPhoto);
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l.checkInPhotoCounter(_photos.length),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: t.fg3,
                  ),
                ),
              ),
            ),
            _Section(text: l.checkInPriceLabel),
            Row(
              children: [
                _SegmentedControl(
                  value: _currency,
                  options: const [
                    ('JPY', '¥'),
                    ('KRW', '₩'),
                    ('USD', '\$'),
                  ],
                  onChanged: (v) => setState(() => _currency = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '1200'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SegmentedControl(
              value: _priceMode,
              options: [
                ('serving', l.checkInPriceServing),
                ('bottle', l.checkInPriceBottle),
              ],
              onChanged: (v) => setState(() => _priceMode = v),
            ),
            _Section(text: l.checkInPurchaseType),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ('on_premise', l.checkInPurchaseOnPremise),
                ('retail', l.checkInPurchaseRetail),
                ('gift', l.checkInPurchaseGift),
                ('other', l.checkInPurchaseOther),
              ]
                  .map((o) => KamosChip(
                        label: o.$2,
                        selected: _purchase == o.$1,
                        onTap: () => setState(() {
                          _purchase = _purchase == o.$1 ? null : o.$1;
                        }),
                      ))
                  .toList(),
            ),
            _Section(text: l.checkInServingStyle),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ('glass', l.checkInServingGlass),
                ('carafe', l.checkInServingCarafe),
                ('bottle', l.checkInServingBottle),
                ('can', l.checkInServingCan),
                ('other', l.checkInServingOther),
              ]
                  .map((o) => KamosChip(
                        label: o.$2,
                        selected: _serving == o.$1,
                        onTap: () => setState(() {
                          _serving = _serving == o.$1 ? null : o.$1;
                        }),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _tagDimensionLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'flavorSweetness':
        return l.flavorSweetness;
      case 'flavorBody':
        return l.flavorBody;
      case 'flavorAcidity':
        return l.flavorAcidity;
      case 'flavorCharacter':
        return l.flavorCharacter;
      case 'flavorFinish':
        return l.flavorFinish;
      default:
        return key;
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          color: t.fg3,
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.filled, this.onTap, this.onRemove});
  final bool filled;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: filled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: filled ? t.kinari : t.bgSunken,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? t.border1 : t.border2,
            style: filled ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.photo_camera_outlined,
                color: filled ? t.fg2 : t.fgMuted,
                size: filled ? 24 : 20,
              ),
            ),
            if (filled)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xCC0F2350),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.gray100,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final active = value == o.$1;
          return InkWell(
            onTap: () => onChanged(o.$1),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? t.bgSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? t.fg1 : t.fg2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
