// KAMOS — Screen: Check-in flow (SPEC §4, post-MVP redesign per
// docs/history/03_checkin_compose_redesign/00_brief.md).
//
// New layout (top → bottom):
//   1. Beverage card header (label image + name + producer + category overline)
//   2. Rating  — continuous slider 0.5..5.0, 0.25 step, nullable; mono "x.xx / 5.0"
//   3. Review + photo — Row: multi-line note on the left (≤500), 1 fixed square photo right
//   4. Flavor tags — flat horizontally-scrolling row of selected chips + "+ Browse";
//                    Browse opens a tall bottom sheet with search + flat tag list
//   5. Location — venue picker row (Foursquare flow unchanged; just renamed from "Where?")
//   6. Price — currency segmented + amount field + serving/bottle toggle
//   7. Submit — full-width primary pill at the bottom of the form (AppBar action removed)
//
// Removed from compose UI: Purchase Type section. (DB column stays — server-side only.)
//
// Photo upload: cap is 1 on submission (SPEC §4.1). On submit, the check-in
// is created first, then the lone photo is uploaded through the 3-step
// presign → PUT → attach flow on `CheckInRepository.uploadPhotoAndAttach`.
// Upload status is tracked in `_photoStates[0]` (single slot). If the
// storage provider is disabled, the upload is skipped and the check-in
// still succeeds.

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
import '../../../core/models/venue.dart';
import '../../../core/observability/sentry_observer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/kamos_pill_button.dart';
import '../../beverages/providers/beverage_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../venues/widgets/venue_picker_sheet.dart';
import '../providers/checkin_providers.dart';
import '../repository/checkin_repository.dart';
import '../widgets/flavor_tag_browse_sheet.dart';
import '../widgets/rating_slider.dart';

/// SPEC §4.1 — compose-side photo cap. Post-Slice-B this is 1; existing
/// multi-photo check-ins (rows authored before the cap was tightened) keep
/// rendering. Server enforces the same cap.
const int _kPhotoCap = 1;

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
  }) => PhotoUploadState(
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
    @visibleForTesting this.initialVenue,
    @visibleForTesting this.onSubmitted,
  });
  final Beverage beverage;

  /// Pre-seeded photos. Tests use this to bypass `image_picker` (which has no
  /// platform binding in widget tests). If more than [_kPhotoCap] are
  /// supplied, only the first is retained (Slice B tightened the cap to 1).
  @visibleForTesting
  final List<XFile> initialPhotos;

  /// Pre-seeded venue. Tests bypass the bottom-sheet picker via this seam.
  @visibleForTesting
  final FoursquarePlace? initialVenue;

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
  FoursquarePlace? _venue;
  bool _uploadingPhotos = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotos.isNotEmpty) {
      // Clamp to the post-Slice-B 1-photo cap. Tests that seed more than one
      // file now exercise the same code path the picker takes.
      final seeded = widget.initialPhotos.take(_kPhotoCap).toList();
      _photos.addAll(seeded);
      _photoStates.addAll(
        List.generate(seeded.length, (_) => const PhotoUploadState()),
      );
    }
    _venue = widget.initialVenue;
  }

  Future<void> _pickVenue() async {
    final picked = await showVenuePicker(context);
    if (!mounted || picked == null) return;
    setState(() => _venue = picked);
  }

  void _clearVenue() => setState(() => _venue = null);

  @override
  void dispose() {
    _review.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _kPhotoCap) return;
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

  Future<void> _openFlavorSheet() async {
    await showFlavorTagBrowseSheet(
      context: context,
      selected: _tags,
      onToggle: _toggleTag,
    );
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.photoUploadDisabled)));
        }
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
          _photoStates[i] = _photoStates[i].copyWith(
            status: PhotoUploadStatus.failed,
          );
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
    // SPEC §4.4 — purchase_type is no longer sent from the compose flow as
    // of Slice B; the column stays in the DB but is not surfaced anywhere.
    final posted = await ref
        .read(checkInControllerProvider.notifier)
        .submit(
          beverageId: widget.beverage.id,
          rating: _rating,
          review: _review.text.isEmpty ? null : _review.text,
          tags: _tags.toList(),
          price: price,
          venue: _venue?.toCheckinVenueJson(),
        );
    if (posted == null) {
      if (mounted) {
        final err = ref.read(checkInControllerProvider).error;
        if (err != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.checkInPostFailed)));
        }
      }
      return;
    }
    final uploadsOk = await _uploadSelectedPhotos(posted.id);
    if (!mounted) return;
    if (!uploadsOk &&
        _photoStates.any((s) => s.status == PhotoUploadStatus.failed)) {
      // The lone failed upload — keep the screen open so the user can hit
      // the retry button on the photo tile. The check-in itself is saved.
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.checkInFirstToast)));
    // The check-in is now committed server-side. Invalidate every list
    // that surfaces it so a stale cached page never hides the user's
    // own activity: the home Feed, /v1/users/me stats, the
    // user-check-ins list shown on the Me profile, and the beverage
    // detail page's recent-check-ins block.
    final meUsername = ref.read(meProvider).asData?.value.user.username;
    ref.invalidate(feedProvider);
    ref.invalidate(meProvider);
    if (meUsername != null && meUsername.isNotEmpty) {
      ref.invalidate(userCheckinsProvider(meUsername));
    }
    ref.invalidate(beverageDetailProvider(widget.beverage.id));
    final onSubmitted = widget.onSubmitted;
    if (onSubmitted != null) {
      onSubmitted(posted);
    } else {
      context.pop();
    }
  }

  /// Retry the failed photo upload. With the 1-photo cap, this only ever
  /// targets index 0 — but we keep the parameter for clarity at the call site
  /// and in case the cap is ever relaxed.
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
      if (_photoStates.every((s) => s.status == PhotoUploadStatus.done)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.checkInFirstToast)));
        context.pop();
      }
    } on StorageDisabledException {
      if (!mounted) return;
      setState(() {
        _photoStates[index] = _photoStates[index].copyWith(
          status: PhotoUploadStatus.failed,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.photoUploadDisabled)));
    } catch (e, st) {
      if (kSentryConfigured) {
        unawaitedSafe(Sentry.captureException(e, stackTrace: st));
      }
      if (!mounted) return;
      setState(() {
        _photoStates[index] = _photoStates[index].copyWith(
          status: PhotoUploadStatus.failed,
        );
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
    final producer = resolveI18n(widget.beverage.producer.name, locale);
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
        // 40-dp trailing spacer keeps the title centred against the leading
        // `X` now that the AppBar Post action is gone (lives at the bottom).
        actions: const [SizedBox(width: 40)],
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
                ],
              ),
            ),
            _Section(text: l.ratingLabel),
            RatingSlider(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            _Section(text: l.checkInReviewLabel),
            _ReviewAndPhotoRow(
              reviewController: _review,
              reviewTooLong: reviewTooLong,
              hasPhoto: _photos.isNotEmpty,
              photoState: _photos.isNotEmpty ? _photoStates.first : null,
              onAddPhoto: _addPhoto,
              onRemovePhoto: () => _removePhoto(0),
              onRetryPhoto: () => _retryPhoto(0),
              onReviewChanged: () => setState(() {}),
              retryLabel: l.actionRetry,
            ),
            _FlavorTagSectionHeader(
              label: l.checkInFlavorTags,
              onTap: _openFlavorSheet,
            ),
            _FlavorTagChipRow(
              selectedSlugs: _tags,
              locale: locale,
              onToggle: _toggleTag,
              onBrowse: _openFlavorSheet,
              browseLabel: l.checkInFlavorBrowse,
            ),
            _Section(text: l.checkInWhereLabel),
            _VenuePickerRow(
              venue: _venue,
              onPick: _pickVenue,
              onClear: _clearVenue,
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
            const SizedBox(height: 24),
            // Full-width Post pill at the bottom of the scroll body. The
            // AppBar action button moved here per the Slice B redesign.
            Row(
              children: [
                KamosPillButton.primary(
                  label: l.actionPost,
                  onPressed: canPost ? _submit : null,
                ),
              ],
            ),
            if (state.isSubmitting || _uploadingPhotos)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Local `unawaited` replacement that swallows any error from the awaited
/// future. Kept private so we never leak un-handled futures into the harness.
void unawaitedSafe(Future<dynamic> f) {
  f.catchError((_) {});
}

/// Tappable section label for the Flavor Tags row. Mirrors `_Section`'s
/// typography but routes taps into the browse sheet so the user has two
/// entry points (header or "+ Browse" chip).
class _FlavorTagSectionHeader extends StatelessWidget {
  const _FlavorTagSectionHeader({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'NotoSansJP',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: t.fg3,
          ),
        ),
      ),
    );
  }
}

/// Horizontally-scrolling row of selected flavor-tag chips followed by a
/// `+ Browse` chip. The chips read locale-resolved names from
/// `flavorTagsProvider`.
class _FlavorTagChipRow extends ConsumerWidget {
  const _FlavorTagChipRow({
    required this.selectedSlugs,
    required this.locale,
    required this.onToggle,
    required this.onBrowse,
    required this.browseLabel,
  });

  final Set<String> selectedSlugs;
  final String locale;
  final void Function(String slug) onToggle;
  final VoidCallback onBrowse;
  final String browseLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(flavorTagsProvider);
    // Resolve selected slugs to FlavorTag objects so we can render
    // locale-aware labels. If the provider hasn't resolved yet we still
    // render the "+ Browse" chip so the entry point is always available.
    final tags = tagsAsync.asData?.value ?? const <FlavorTag>[];
    final selectedTags = [
      for (final tag in tags)
        if (selectedSlugs.contains(tag.slug)) tag,
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final tag in selectedTags) ...[
            Center(
              child: KamosChip(
                label: resolveI18n(tag.name, locale),
                selected: true,
                onTap: () => onToggle(tag.slug),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Center(
            child: KamosChip(
              label: browseLabel,
              onTap: onBrowse,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row containing the multi-line review note on the left and a single
/// 104×104 photo tile on the right. The two widgets are sized to match
/// heights so the row reads as a coherent block.
class _ReviewAndPhotoRow extends StatelessWidget {
  const _ReviewAndPhotoRow({
    required this.reviewController,
    required this.reviewTooLong,
    required this.hasPhoto,
    required this.photoState,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onRetryPhoto,
    required this.onReviewChanged,
    required this.retryLabel,
  });

  final TextEditingController reviewController;
  final bool reviewTooLong;
  final bool hasPhoto;
  final PhotoUploadState? photoState;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onRetryPhoto;
  final VoidCallback onReviewChanged;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: reviewController,
            maxLength: 500,
            // SPEC §6.4 cap is 500 chars. We allow the field to momentarily
            // exceed so `checkInReviewTooLong` can render as the validator
            // error; the submit button is also gated on `!reviewTooLong`.
            maxLengthEnforcement: MaxLengthEnforcement.none,
            // minLines: 4 matches the 104-dp photo tile height to the right
            // visually; the field can grow past that as the user types.
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              hintText: l.checkInReviewPlaceholder,
              errorText: reviewTooLong ? l.checkInReviewTooLong : null,
            ),
            onChanged: (_) => onReviewChanged(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 104,
          height: 104,
          child: _PhotoTile(
            filled: hasPhoto,
            state: photoState,
            onTap: hasPhoto ? null : onAddPhoto,
            onRemove: hasPhoto ? onRemovePhoto : null,
            onRetry: photoState?.status == PhotoUploadStatus.failed
                ? onRetryPhoto
                : null,
            retryLabel: retryLabel,
          ),
        ),
      ],
    );
  }
}

class _VenuePickerRow extends StatelessWidget {
  const _VenuePickerRow({
    required this.venue,
    required this.onPick,
    required this.onClear,
  });

  final FoursquarePlace? venue;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final picked = venue;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: t.bgSurface,
          border: Border.all(color: t.border1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.place_outlined, color: t.fg2),
            const SizedBox(width: 10),
            Expanded(
              child: picked == null
                  ? Text(l.checkInWhereCta, style: TextStyle(color: t.fg2))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          picked.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.fg1,
                          ),
                        ),
                        if ((picked.locality ?? '').isNotEmpty)
                          Text(
                            picked.locality!,
                            style: TextStyle(fontSize: 12, color: t.fg2),
                          ),
                      ],
                    ),
            ),
            if (picked != null)
              IconButton(
                icon: Icon(Icons.close, color: t.fg3, size: 18),
                onPressed: onClear,
              )
            else
              Icon(Icons.chevron_right, color: t.fg3),
          ],
        ),
      ),
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
    final isUploading = uploadState?.status == PhotoUploadStatus.uploading;
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
            style: BorderStyle.solid,
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
                size: filled ? 32 : 28,
              ),
            ),
            if (isUploading)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
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
                left: 6,
                right: 6,
                bottom: 6,
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
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
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
