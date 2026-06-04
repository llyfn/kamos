// KAMOS — Edit check-in screen (Slice 01 / SPEC §4.4).
//
// Mirrors `CheckInScreen` for visual continuity but pre-fills the form from
// the live row fetched via `checkInDetailProvider(id)`. The beverage is
// rendered read-only (SPEC §4.4: beverage_id is immutable). Photo edits
// produce two diffs the PATCH body carries:
//
//   * `add_photos`: upload_id values returned from the presign + R2 PUT
//     flow on `CheckInRepository.uploadPhotoOnly` (the attach happens
//     server-side inside the PATCH transaction).
//   * `remove_photos`: `PhotoRef.url` values for photos the user removed
//     from the original set.
//
// The 4-photo cap is enforced client-side (current − removed + added ≤ 4);
// the server is the backstop and returns 422 PHOTO_CAP_EXCEEDED.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/beverage_name.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';
import '../../../core/observability/sentry_observer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_input.dart';
import '../../beverages/providers/beverage_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/checkin_providers.dart';
import '../repository/checkin_repository.dart';

/// Builds the PATCH /v1/check-ins/{id} body with the tri-state contract
/// SPEC §4.4 demands on `rating` / `review` / `price`:
///
///   * key absent     → backend leaves the column unchanged
///   * key present null → backend clears the column
///   * key present non-null → backend sets the column
///
/// We diff each tracked field against [original] so a user who clears a
/// previously-set rating, review, or price sends an explicit `null`, and a
/// user who never touched the field sends nothing at all. Hoisted to
/// top-level (rather than buried in `_save`) so unit tests can exercise the
/// table without spinning up a widget.
@visibleForTesting
Map<String, dynamic> buildEditCheckInBody({
  required Checkin original,
  required double? rating,
  required String review,
  required List<String> tags,
  required List<String> addPhotos,
  required List<String> removePhotos,
  required String priceText,
  required String currency,
  required String priceMode,
  required String? purchaseType,
}) {
  final body = <String, dynamic>{};

  // rating: tri-state. Send the key only when the value differs from the
  // original; emit explicit `null` for "had a rating → now cleared".
  if (rating != original.rating) {
    body['rating'] = rating;
  }

  // review: tri-state with empty-string normalised to `null` so the clear
  // intent is preserved across the wire. The composer's allowEmpty=true
  // would otherwise leave a blank review on the row.
  final originalReview = original.review;
  final newReview = review.isEmpty ? null : review;
  if (newReview != originalReview) {
    body['review'] = newReview;
  }

  // tags: full replacement semantics. Always present when the set differs.
  final origTags = original.tags.map((t) => t.slug).toSet();
  final newTags = tags.toSet();
  if (origTags.length != newTags.length || !origTags.containsAll(newTags)) {
    body['tags'] = tags;
  }

  if (addPhotos.isNotEmpty) {
    body['add_photos'] = addPhotos;
  }
  if (removePhotos.isNotEmpty) {
    body['remove_photos'] = removePhotos;
  }

  // price: tri-state. Compose the new Price up front so we can compare.
  final amount = double.tryParse(priceText);
  final hasPrice = amount != null && amount > 0;
  final newPrice = hasPrice
      ? Price(amount: amount, currency: currency, mode: priceMode)
      : null;
  final originalPrice = original.price;
  final priceChanged =
      (newPrice == null) != (originalPrice == null) ||
      (newPrice != null &&
          originalPrice != null &&
          (newPrice.amount != originalPrice.amount ||
              newPrice.currency != originalPrice.currency ||
              newPrice.mode != originalPrice.mode));
  if (priceChanged) {
    body['price'] = newPrice?.toJson();
  }

  // purchase_type: nullable enum. The PATCH schema treats absent =
  // unchanged. Emit only when changed; emit `null` to clear.
  if (purchaseType != original.purchaseType) {
    body['purchase_type'] = purchaseType;
  }

  return body;
}

class EditCheckInScreen extends ConsumerWidget {
  const EditCheckInScreen({super.key, required this.checkInId});

  final String checkInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(checkInDetailProvider(checkInId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(l.checkInEdit),
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        onRetry: () => ref.invalidate(checkInDetailProvider(checkInId)),
        data: (checkin) => _EditCheckInForm(original: checkin),
      ),
    );
  }
}

class _EditCheckInForm extends ConsumerStatefulWidget {
  const _EditCheckInForm({required this.original});
  final Checkin original;

  @override
  ConsumerState<_EditCheckInForm> createState() => _EditCheckInFormState();
}

class _EditCheckInFormState extends ConsumerState<_EditCheckInForm> {
  late double? _rating;
  late final TextEditingController _review;
  late final TextEditingController _price;
  late final Set<String> _tags;
  late String _currency;
  late String _priceMode;
  late String? _purchase;

  // Photos kept from the original (PhotoRef.url). Removing a row drops the
  // url from this list AND records it in `_removedUrls` so the PATCH body
  // can carry the remove diff.
  late List<PhotoRef> _existingPhotos;
  final Set<String> _removedUrls = {};

  // Newly added photos, pre-upload. After save we upload each via
  // `uploadPhotoOnly`, collect the upload_ids, then PATCH.
  final List<XFile> _newPhotos = [];

  bool _saving = false;

  // Server-canonical dimensions, in display order. Matches CheckInScreen so
  // the tag picker behaves identically.
  static const _dimensionOrder = [
    'sweetness',
    'body',
    'acidity',
    'character',
    'finish',
  ];

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _rating = o.rating;
    _review = TextEditingController(text: o.review ?? '');
    _price = TextEditingController(
      text: o.price != null
          ? (o.price!.amount == o.price!.amount.truncateToDouble()
                ? o.price!.amount.toStringAsFixed(0)
                : o.price!.amount.toString())
          : '',
    );
    _tags = {for (final t in o.tags) t.slug};
    _currency = o.price?.currency ?? 'JPY';
    _priceMode = o.price?.mode ?? 'serving';
    _purchase = o.purchaseType;
    _existingPhotos = List.of(o.photos);
  }

  @override
  void dispose() {
    _review.dispose();
    _price.dispose();
    super.dispose();
  }

  int get _photoCount => _existingPhotos.length + _newPhotos.length;

  Future<void> _addPhoto() async {
    if (_photoCount >= 4) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.checkInPhotoLimitReached)));
      return;
    }
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null && mounted) {
        setState(() => _newPhotos.add(file));
      }
    } catch (_) {
      // Image picker not available (sim/test) — silently no-op.
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      final removed = _existingPhotos.removeAt(index);
      _removedUrls.add(removed.url);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
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

  bool get _isDirty {
    final o = widget.original;
    if (_rating != o.rating) return true;
    if ((_review.text) != (o.review ?? '')) return true;
    final origTags = o.tags.map((t) => t.slug).toSet();
    if (_tags.length != origTags.length || !_tags.containsAll(origTags)) {
      return true;
    }
    if (_purchase != o.purchaseType) return true;
    if (_removedUrls.isNotEmpty || _newPhotos.isNotEmpty) return true;
    final amount = double.tryParse(_price.text);
    final origAmount = o.price?.amount;
    if (amount != origAmount) return true;
    if (o.price != null) {
      if (_currency != o.price!.currency) return true;
      if (_priceMode != o.price!.mode) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final l = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.checkInEditDiscardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionDiscard),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);

    // Upload any new photos first; collect upload_ids for `add_photos`.
    final addIds = <String>[];
    final repo = ref.read(checkInRepositoryProvider);
    for (final file in _newPhotos) {
      try {
        final uploadId = await repo.uploadPhotoOnly(
          file: File(file.path),
          onProgress: (_) {},
        );
        addIds.add(uploadId);
      } on StorageDisabledException {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.photoUploadDisabled)));
        setState(() => _saving = false);
        return;
      } catch (e, st) {
        if (kSentryConfigured) {
          unawaitedSafe(Sentry.captureException(e, stackTrace: st));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.checkInPostFailed)));
        setState(() => _saving = false);
        return;
      }
    }

    final body = buildEditCheckInBody(
      original: widget.original,
      rating: _rating,
      review: _review.text,
      tags: _tags.toList(),
      addPhotos: addIds,
      removePhotos: _removedUrls.toList(),
      priceText: _price.text,
      currency: _currency,
      priceMode: _priceMode,
      purchaseType: _purchase,
    );

    try {
      final updated = await repo.edit(id: widget.original.id, body: body);
      if (!mounted) return;
      // Invalidate every surface that renders this row so the edit shows
      // up immediately on return.
      ref.invalidate(checkInDetailProvider(widget.original.id));
      ref.invalidate(feedProvider);
      ref.invalidate(beverageDetailProvider(updated.beverage.id));
      final username = widget.original.user.username;
      if (username.isNotEmpty) {
        ref.invalidate(userCheckinsProvider(username));
      }
      context.pop();
    } catch (e, st) {
      if (kSentryConfigured) {
        unawaitedSafe(Sentry.captureException(e, stackTrace: st));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.checkInPostFailed)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final beverage = widget.original.beverage;
    final beverageName = resolveI18n(beverage.name, locale);
    final producer = resolveI18n(beverage.producer.name, locale);
    final slug = categorySlugFromString(beverage.category.slug);
    final catLabel = slug == null
        ? resolveI18n(beverage.category.labelI18n, locale)
        : categoryLabel(context, slug);
    final reviewTooLong = _review.text.length > 500;
    final canSave = !_saving && !reviewTooLong;
    final canAddPhoto = _photoCount < 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmDiscardIfDirty();
        if (!mounted) return;
        if (allow && context.mounted) Navigator.of(context).pop();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Locked beverage row — SPEC §4.4 makes beverage_id immutable.
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
                    tone: labelToneFromCategory(beverage.category.slug),
                    imageUrl: beverage.labelImageUrl,
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
                        Text(
                          producer,
                          style: TextStyle(fontSize: 12, color: t.fg2),
                        ),
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
                  Icon(Icons.lock_outline, size: 16, color: t.fg3),
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
              maxLengthEnforcement: MaxLengthEnforcement.none,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: l.checkInReviewPlaceholder,
                errorText: reviewTooLong ? l.checkInReviewTooLong : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            _Section(text: l.checkInFlavorTags),
            _FlavorTagPicker(
              selected: _tags,
              locale: locale,
              dimensionOrder: _dimensionOrder,
              dimensionLabel: (key) => _dimensionLabel(l, key),
              onToggle: _toggleTag,
            ),
            _Section(text: l.checkInPhotosLabel),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(4, (i) {
                if (i < _existingPhotos.length) {
                  return _ExistingPhotoTile(
                    photo: _existingPhotos[i],
                    onRemove: () => _removeExistingPhoto(i),
                  );
                }
                final newIdx = i - _existingPhotos.length;
                if (newIdx < _newPhotos.length) {
                  return _NewPhotoTile(
                    file: _newPhotos[newIdx],
                    onRemove: () => _removeNewPhoto(newIdx),
                  );
                }
                return _AddPhotoTile(onTap: canAddPhoto ? _addPhoto : null);
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l.checkInPhotoCounter(_photoCount),
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
                  options: const [('JPY', '¥'), ('KRW', '₩'), ('USD', '\$')],
                  onChanged: (v) => setState(() => _currency = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '1200'),
                    onChanged: (_) => setState(() {}),
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
              children:
                  [
                        ('on_premise', l.checkInPurchaseOnPremise),
                        ('retail', l.checkInPurchaseRetail),
                        ('gift', l.checkInPurchaseGift),
                        ('other', l.checkInPurchaseOther),
                      ]
                      .map(
                        (o) => KamosChip(
                          label: o.$2,
                          selected: _purchase == o.$1,
                          onTap: () => setState(() {
                            _purchase = _purchase == o.$1 ? null : o.$1;
                          }),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: t.ai,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l.actionSave),
            ),
          ],
        ),
      ),
    );
  }

  String _dimensionLabel(AppLocalizations l, String dimension) {
    switch (dimension) {
      case 'sweetness':
        return l.flavorSweetness;
      case 'body':
        return l.flavorBody;
      case 'acidity':
        return l.flavorAcidity;
      case 'character':
        return l.flavorCharacter;
      case 'finish':
        return l.flavorFinish;
      default:
        return dimension;
    }
  }
}

/// Local `unawaited` replacement that swallows any error from the awaited
/// future. Kept private so we never leak un-handled futures into the harness.
void unawaitedSafe(Future<dynamic> f) {
  f.catchError((_) {});
}

class _FlavorTagPicker extends ConsumerWidget {
  const _FlavorTagPicker({
    required this.selected,
    required this.locale,
    required this.dimensionOrder,
    required this.dimensionLabel,
    required this.onToggle,
  });

  final Set<String> selected;
  final String locale;
  final List<String> dimensionOrder;
  final String Function(String dimension) dimensionLabel;
  final void Function(String slug) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tagsAsync = ref.watch(flavorTagsProvider);
    return tagsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (tags) {
        final byDimension = <String, List<FlavorTag>>{};
        for (final tag in tags) {
          byDimension.putIfAbsent(tag.dimension, () => []).add(tag);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final dim in dimensionOrder)
              if ((byDimension[dim] ?? const []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          dimensionLabel(dim).toUpperCase(),
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
                        children: [
                          for (final tag in byDimension[dim]!)
                            KamosChip(
                              label: resolveI18n(tag.name, locale),
                              selected: selected.contains(tag.slug),
                              onTap: () => onToggle(tag.slug),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
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

class _ExistingPhotoTile extends StatelessWidget {
  const _ExistingPhotoTile({required this.photo, required this.onRemove});

  final PhotoRef photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.kinari,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border1),
        image: photo.url.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(photo.url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xCC0F2350),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewPhotoTile extends StatelessWidget {
  const _NewPhotoTile({required this.file, required this.onRemove});
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.kinari,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border1),
        image: DecorationImage(
          image: FileImage(File(file.path)),
          fit: BoxFit.cover,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xCC0F2350),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: t.bgSunken,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border2),
        ),
        child: Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 20,
            color: disabled ? t.fgMuted : t.fg2,
          ),
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
