// KAMOS — Check-in screen (SPEC §4).
//
// - Optional 0.5-step rating (null = "I tried this")
// - 500-char review hard cap with live counter
// - Flavor tag chips, multi-select
// - Up to 4 photos (UI cap; the server is the backstop)
// - Price (amount + currency + per-serving|per-bottle)
// - Purchase type, serving style
//
// Photo upload (Phase 3): on submit, the check-in is created first; then each
// selected photo is uploaded sequentially through the 3-step presign → PUT →
// attach flow on `CheckInRepository.uploadPhotoAndAttach`. Per-photo status
// is tracked in `_photoStates`. If the storage provider is disabled, the
// upload is skipped and the check-in still succeeds.

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
import '../../../core/models/beverage.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';
import '../../../core/observability/sentry_observer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/stars_input.dart';
import '../providers/checkin_providers.dart';
import '../repository/checkin_repository.dart';

/// Per-photo upload state machine.
enum PhotoUploadStatus { idle, uploading, done, failed }

/// Snapshot of one selected photo's upload progress.
class PhotoUploadState {
  const PhotoUploadState({
    this.status = PhotoUploadStatus.idle,
    this.progress = 0.0,
    this.photoRef,
  });

  final PhotoUploadStatus status;
  final double progress; // 0.0–1.0
  final PhotoRef? photoRef;

  PhotoUploadState copyWith({
    PhotoUploadStatus? status,
    double? progress,
    PhotoRef? photoRef,
  }) =>
      PhotoUploadState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        photoRef: photoRef ?? this.photoRef,
      );
}

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({
    super.key,
    required this.beverage,
    @visibleForTesting this.initialPhotos = const [],
    @visibleForTesting this.onSubmitted,
  });
  final Beverage beverage;

  /// Pre-seeded photos. Tests use this to bypass `image_picker` (which has no
  /// platform binding in widget tests).
  @visibleForTesting
  final List<XFile> initialPhotos;

  /// When set (only by tests), this replaces the `context.pop()` call at the
  /// end of a successful submit. Production callers leave it null so the
  /// router-driven default runs.
  @visibleForTesting
  final void Function(Checkin posted)? onSubmitted;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  double? _rating;
  final _review = TextEditingController();
  final _price = TextEditingController();
  final Set<String> _tags = {};
  final List<XFile> _photos = [];
  final List<PhotoUploadState> _photoStates = [];
  String _currency = 'JPY';
  String _priceMode = 'serving';
  String? _purchase;
  String? _serving;
  bool _uploadingPhotos = false;

  // Server-canonical dimensions, in display order. The labels for each tag are
  // resolved from `flavorTagsProvider` and rendered per-locale via
  // `resolveI18n`. The selected values stored in `_tags` are slugs (sent to
  // the server as-is in the check-in POST body).
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
    if (widget.initialPhotos.isNotEmpty) {
      _photos.addAll(widget.initialPhotos);
      _photoStates.addAll(
        List.generate(widget.initialPhotos.length, (_) => const PhotoUploadState()),
      );
    }
  }

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
        setState(() {
          _photos.add(file);
          _photoStates.add(const PhotoUploadState());
        });
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

  /// Sequentially upload selected photos. The check-in must already exist.
  /// Returns true if all photos uploaded (or there were none); false if any
  /// failed. A [StorageDisabledException] short-circuits with `false` and a
  /// SnackBar so the caller knows to drop the photos entirely.
  Future<bool> _uploadSelectedPhotos(String checkInId) async {
    if (_photos.isEmpty) return true;
    setState(() => _uploadingPhotos = true);
    final l = AppLocalizations.of(context);
    final repo = ref.read(checkInRepositoryProvider);
    var allOk = true;
    var storageDisabledShown = false;
    for (var i = 0; i < _photos.length; i++) {
      final state = _photoStates[i];
      // Skip already-uploaded photos (retry path).
      if (state.status == PhotoUploadStatus.done) continue;
      final file = File(_photos[i].path);
      if (mounted) {
        setState(() {
          _photoStates[i] = state.copyWith(
            status: PhotoUploadStatus.uploading,
            progress: 0,
          );
        });
      }
      try {
        final photoRef = await repo.uploadPhotoAndAttach(
          checkInId: checkInId,
          file: file,
          onProgress: (pct) {
            if (!mounted) return;
            setState(() {
              _photoStates[i] = _photoStates[i].copyWith(progress: pct);
            });
          },
        );
        if (!mounted) return allOk;
        setState(() {
          _photoStates[i] = _photoStates[i].copyWith(
            status: PhotoUploadStatus.done,
            progress: 1.0,
            photoRef: photoRef,
          );
        });
      } on StorageDisabledException {
        allOk = false;
        if (!storageDisabledShown && mounted) {
          storageDisabledShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.photoUploadDisabled)),
          );
        }
        // Skip the remaining photos — storage is off for everyone.
        if (mounted) {
          setState(() {
            for (var k = i; k < _photoStates.length; k++) {
              if (_photoStates[k].status != PhotoUploadStatus.done) {
                _photoStates[k] = _photoStates[k].copyWith(
                  status: PhotoUploadStatus.failed,
                );
              }
            }
          });
        }
        break;
      } catch (e, st) {
        allOk = false;
        if (kSentryConfigured) {
          unawaitedSafe(Sentry.captureException(e, stackTrace: st));
        }
        if (!mounted) return allOk;
        setState(() {
          _photoStates[i] =
              _photoStates[i].copyWith(status: PhotoUploadStatus.failed);
        });
      }
    }
    if (mounted) setState(() => _uploadingPhotos = false);
    return allOk;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    Price? price;
    final amount = double.tryParse(_price.text);
    if (amount != null && amount > 0) {
      price = Price(amount: amount, currency: _currency, mode: _priceMode);
    }
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
    if (posted == null) {
      if (mounted) {
        final err = ref.read(checkInControllerProvider).error;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.checkInPostFailed)),
          );
        }
      }
      return;
    }
    final uploadsOk = await _uploadSelectedPhotos(posted.id);
    if (!mounted) return;
    if (!uploadsOk && _photoStates.any((s) => s.status == PhotoUploadStatus.failed)) {
      // At least one failed upload — keep the screen open so the user can
      // retry (per-tile retry button). The check-in itself is already saved.
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.checkInFirstToast)),
    );
    final onSubmitted = widget.onSubmitted;
    if (onSubmitted != null) {
      onSubmitted(posted);
    } else {
      context.pop();
    }
  }

  /// Retry one previously-failed photo upload.
  Future<void> _retryPhoto(int index) async {
    final posted = ref.read(checkInControllerProvider).posted;
    if (posted == null) return;
    final l = AppLocalizations.of(context);
    final state = _photoStates[index];
    setState(() {
      _photoStates[index] = state.copyWith(
        status: PhotoUploadStatus.uploading,
        progress: 0,
      );
    });
    try {
      final repo = ref.read(checkInRepositoryProvider);
      final photoRef = await repo.uploadPhotoAndAttach(
        checkInId: posted.id,
        file: File(_photos[index].path),
        onProgress: (pct) {
          if (!mounted) return;
          setState(() {
            _photoStates[index] = _photoStates[index].copyWith(progress: pct);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _photoStates[index] = _photoStates[index].copyWith(
          status: PhotoUploadStatus.done,
          progress: 1.0,
          photoRef: photoRef,
        );
      });
      // If all are done, complete the flow.
      if (_photoStates.every((s) => s.status == PhotoUploadStatus.done)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.checkInFirstToast)),
        );
        context.pop();
      }
    } on StorageDisabledException {
      if (!mounted) return;
      setState(() {
        _photoStates[index] =
            _photoStates[index].copyWith(status: PhotoUploadStatus.failed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.photoUploadDisabled)),
      );
    } catch (e, st) {
      if (kSentryConfigured) {
        unawaitedSafe(Sentry.captureException(e, stackTrace: st));
      }
      if (!mounted) return;
      setState(() {
        _photoStates[index] =
            _photoStates[index].copyWith(status: PhotoUploadStatus.failed);
      });
    }
  }

  void _removePhoto(int i) {
    setState(() {
      _photos.removeAt(i);
      _photoStates.removeAt(i);
    });
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

    final reviewTooLong = _review.text.length > 500;
    final canPost = !state.isSubmitting && !_uploadingPhotos && !reviewTooLong;

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
              child: (state.isSubmitting || _uploadingPhotos)
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l.actionPost),
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
              // SPEC §6.4 cap is 500 chars. We allow the field to momentarily
              // exceed so `checkInReviewTooLong` can render as the validator
              // error; the submit button is also gated on `!reviewTooLong`.
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
                if (i < _photos.length) {
                  return _PhotoTile(
                    filled: true,
                    state: _photoStates[i],
                    onRemove: () => _removePhoto(i),
                    onRetry: _photoStates[i].status == PhotoUploadStatus.failed
                        ? () => _retryPhoto(i)
                        : null,
                    retryLabel: l.actionRetry,
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

/// Renders flavor-tag chips grouped by `dimension`, with locale-resolved
/// labels. The list is fetched from `/v1/flavor-tags` via `flavorTagsProvider`.
/// `selected` holds tag slugs.
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
        // Group tags by dimension, preserving server order within each group.
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.filled,
    this.state,
    this.onTap,
    this.onRemove,
    this.onRetry,
    this.retryLabel,
  });

  final bool filled;
  final PhotoUploadState? state;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final uploadState = state;
    final isUploading =
        uploadState?.status == PhotoUploadStatus.uploading;
    final isDone = uploadState?.status == PhotoUploadStatus.done;
    final isFailed = uploadState?.status == PhotoUploadStatus.failed;

    return InkWell(
      onTap: filled ? (isFailed ? onRetry : null) : onTap,
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
                isDone
                    ? Icons.check
                    : (isFailed
                        ? Icons.error_outline
                        : Icons.photo_camera_outlined),
                color: isDone
                    ? t.fg1
                    : (isFailed ? Colors.red : (filled ? t.fg2 : t.fgMuted)),
                size: filled ? 24 : 20,
              ),
            ),
            if (isUploading)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: uploadState?.progress ?? 0,
                    minHeight: 3,
                  ),
                ),
              ),
            if (isFailed && retryLabel != null)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.red.withValues(alpha: 0.85),
                  child: Text(
                    retryLabel!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (filled && !isUploading)
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
