// Unified check-in compose + edit screen.

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
import '../../../core/models/category_label.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/flavor_tag.dart';
import '../../../core/models/venue.dart';
import '../../../core/observability/sentry_observer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_chip.dart';
import '../../../shared/widgets/kamos_label.dart';
import '../../../shared/widgets/kamos_pill_button.dart';
import '../../beverages/providers/beverage_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../venues/widgets/venue_picker_sheet.dart';
import '../providers/checkin_providers.dart';
import '../repository/checkin_repository.dart';
import '../widgets/rating_slider.dart';

const int _kPhotoCap = 1;

enum CheckInMode { compose, edit }

enum PhotoUploadStatus { idle, uploading, done, failed }

class PhotoUploadState {
  const PhotoUploadState({
    this.status = PhotoUploadStatus.idle,
    this.progress = 0.0,
    this.photoRef,
  });

  final PhotoUploadStatus status;
  final double progress;
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

/// Diffs the form state against [original] and emits the tri-state PATCH body
/// from SPEC §4.4 (absent = no change, explicit null = clear, value = set).
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

  if (rating != original.rating) {
    body['rating'] = rating;
  }

  final newReview = review.isEmpty ? null : review;
  if (newReview != original.review) {
    body['review'] = newReview;
  }

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

  if (purchaseType != original.purchaseType) {
    body['purchase_type'] = purchaseType;
  }

  return body;
}

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({
    super.key,
    required this.beverage,
    @visibleForTesting this.initialPhotos = const [],
    @visibleForTesting this.initialVenue,
    @visibleForTesting this.onSubmitted,
  }) : mode = CheckInMode.compose,
       original = null;

  const CheckInScreen.edit({
    super.key,
    required Checkin this.original,
    @visibleForTesting this.onSubmitted,
  }) : mode = CheckInMode.edit,
       beverage = null,
       initialPhotos = const [],
       initialVenue = null;

  final CheckInMode mode;
  final Beverage? beverage;
  final Checkin? original;

  @visibleForTesting
  final List<XFile> initialPhotos;

  @visibleForTesting
  final FoursquarePlace? initialVenue;

  @visibleForTesting
  final void Function(Checkin posted)? onSubmitted;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  double? _rating;
  final _review = TextEditingController();
  final _price = TextEditingController();
  final _reviewFocus = FocusNode();
  final Set<String> _tags = {};
  final List<XFile> _photos = [];
  final List<PhotoUploadState> _photoStates = [];
  String _currency = 'JPY';
  String _priceMode = 'serving';
  FoursquarePlace? _venue;
  VenueRef? _existingVenue;
  bool _uploadingPhotos = false;
  bool _saving = false;

  List<PhotoRef> _existingPhotos = const [];
  final Set<String> _removedUrls = {};
  bool _reviewFocused = false;

  bool get _isEdit => widget.mode == CheckInMode.edit;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final o = widget.original!;
      _rating = o.rating;
      _review.text = o.review ?? '';
      if (o.price != null) {
        final amt = o.price!.amount;
        _price.text = amt == amt.truncateToDouble()
            ? amt.toStringAsFixed(0)
            : amt.toString();
        _currency = o.price!.currency;
        _priceMode = o.price!.mode;
      }
      _tags.addAll(o.tags.map((t) => t.slug));
      _existingPhotos = List.of(o.photos);
      _existingVenue = o.venue;
    } else {
      if (widget.initialPhotos.isNotEmpty) {
        final seeded = widget.initialPhotos.take(_kPhotoCap).toList();
        _photos.addAll(seeded);
        _photoStates.addAll(
          List.generate(seeded.length, (_) => const PhotoUploadState()),
        );
      }
      _venue = widget.initialVenue;
    }
    _reviewFocus.addListener(() {
      final focused = _reviewFocus.hasFocus;
      if (focused != _reviewFocused) {
        setState(() => _reviewFocused = focused);
      }
    });
  }

  @override
  void dispose() {
    _review.dispose();
    _price.dispose();
    _reviewFocus.dispose();
    super.dispose();
  }

  int get _photoCount =>
      _isEdit ? _existingPhotos.length + _photos.length : _photos.length;

  bool get _hasPhoto => _photoCount > 0;

  Future<void> _pickVenue() async {
    final picked = await showVenuePicker(context);
    if (!mounted || picked == null) return;
    setState(() => _venue = picked);
  }

  void _clearVenue() => setState(() {
    _venue = null;
    _existingVenue = null;
  });

  Future<void> _addPhoto() async {
    if (_photoCount >= _kPhotoCap) return;
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
      // Image picker not available (sim/test).
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

  Future<void> _openFlavorProfiles() async {
    final result = await context.push<Set<String>>(
      '/check-in/flavor-profiles',
      extra: Set<String>.from(_tags),
    );
    if (result != null) {
      setState(() {
        _tags
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _removePhoto(int i) {
    setState(() {
      _photos.removeAt(i);
      _photoStates.removeAt(i);
    });
  }

  void _removeExistingPhoto(PhotoRef p) {
    setState(() {
      _existingPhotos = _existingPhotos.where((e) => e.url != p.url).toList();
      _removedUrls.add(p.url);
    });
  }

  Future<bool> _uploadSelectedPhotos(String checkInId) async {
    if (_photos.isEmpty) return true;
    setState(() => _uploadingPhotos = true);
    final l = AppLocalizations.of(context);
    final repo = ref.read(checkInRepositoryProvider);
    var allOk = true;
    var storageDisabledShown = false;
    for (var i = 0; i < _photos.length; i++) {
      final state = _photoStates[i];
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

  void _invalidateLists(String beverageId) {
    final meUsername = ref.read(meProvider).asData?.value.user.username;
    ref.invalidate(feedProvider);
    ref.invalidate(meProvider);
    if (meUsername != null && meUsername.isNotEmpty) {
      ref.invalidate(userCheckinsProvider(meUsername));
    }
    ref.invalidate(beverageDetailProvider(beverageId));
  }

  Future<void> _submit() async {
    if (_isEdit) {
      await _saveEdit();
    } else {
      await _submitNew();
    }
  }

  Future<void> _submitNew() async {
    final l = AppLocalizations.of(context);
    Price? price;
    final amount = double.tryParse(_price.text);
    if (amount != null && amount > 0) {
      price = Price(amount: amount, currency: _currency, mode: _priceMode);
    }
    final beverage = widget.beverage!;
    final posted = await ref
        .read(checkInControllerProvider.notifier)
        .submit(
          beverageId: beverage.id,
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
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.checkInFirstToast)));
    _invalidateLists(beverage.id);
    final onSubmitted = widget.onSubmitted;
    if (onSubmitted != null) {
      onSubmitted(posted);
    } else {
      context.pop();
    }
  }

  Future<void> _saveEdit() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);

    final repo = ref.read(checkInRepositoryProvider);
    final addIds = <String>[];
    for (final file in _photos) {
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

    final original = widget.original!;
    final body = buildEditCheckInBody(
      original: original,
      rating: _rating,
      review: _review.text,
      tags: _tags.toList(),
      addPhotos: addIds,
      removePhotos: _removedUrls.toList(),
      priceText: _price.text,
      currency: _currency,
      priceMode: _priceMode,
      purchaseType: original.purchaseType,
    );

    try {
      final updated = await repo.edit(id: original.id, body: body);
      if (!mounted) return;
      ref.invalidate(checkInDetailProvider(original.id));
      _invalidateLists(updated.beverage.id);
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

  bool get _isDirty {
    if (!_isEdit) return true;
    final o = widget.original!;
    if (_rating != o.rating) return true;
    if (_review.text != (o.review ?? '')) return true;
    final origTags = o.tags.map((t) => t.slug).toSet();
    if (_tags.length != origTags.length || !_tags.containsAll(origTags)) {
      return true;
    }
    if (_removedUrls.isNotEmpty || _photos.isNotEmpty) return true;
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final String bevName;
    final String bevProducer;
    final String? bevLabelImageUrl;
    final CategoryLabel bevCategory;
    final String subcat;
    if (_isEdit) {
      final b = widget.original!.beverage;
      bevName = resolveI18n(b.name, locale);
      bevProducer = resolveI18n(b.producer.name, locale);
      bevLabelImageUrl = b.labelImageUrl;
      bevCategory = b.category;
      subcat = '';
    } else {
      final b = widget.beverage!;
      bevName = resolveI18n(b.name, locale);
      bevProducer = resolveI18n(b.producer.name, locale);
      bevLabelImageUrl = b.labelImageUrl;
      bevCategory = b.category;
      subcat = b.subcategory == null
          ? ''
          : resolveI18n(b.subcategory!.name, locale);
    }
    final slug = categorySlugFromString(bevCategory.slug);
    final catLabel = slug == null
        ? resolveI18n(bevCategory.labelI18n, locale)
        : categoryLabel(context, slug);
    final subtitleText = subcat.isEmpty ? catLabel : '$catLabel · $subcat';

    final state = ref.watch(checkInControllerProvider);
    final reviewTooLong = _review.text.length > 500;
    final submitting = _isEdit ? _saving : (state.isSubmitting || _uploadingPhotos);
    final canPost = !submitting && !reviewTooLong;

    return PopScope(
      canPop: !_isEdit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_isEdit) return;
        final allow = await _confirmDiscardIfDirty();
        if (!mounted) return;
        if (allow && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
          title: Text(_isEdit ? l.checkInEdit : l.checkInTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BeverageHeader(
                  name: bevName,
                  subtitle: subtitleText,
                  producer: bevProducer,
                  labelImageUrl: bevLabelImageUrl,
                  categorySlug: bevCategory.slug,
                ),
                const SizedBox(height: 14),
                _RatingRow(
                  label: l.ratingLabel,
                  value: _rating,
                  emptyValue: l.ratingEmptyValue,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 14),
                _LabelText(text: l.checkInReviewLabel),
                const SizedBox(height: 6),
                _ReviewWithPhoto(
                  controller: _review,
                  focus: _reviewFocus,
                  reviewTooLong: reviewTooLong,
                  photoTileVisible: !_reviewFocused,
                  hasPhoto: _hasPhoto,
                  existingPhoto: _isEdit && _existingPhotos.isNotEmpty
                      ? _existingPhotos.first
                      : null,
                  newPhoto: _photos.isNotEmpty ? _photos.first : null,
                  newPhotoState: _photoStates.isNotEmpty ? _photoStates.first : null,
                  hint: l.checkInReviewPlaceholder,
                  tooLongText: l.checkInReviewTooLong,
                  onAddPhoto: _addPhoto,
                  onRemovePhoto: () {
                    if (_isEdit && _existingPhotos.isNotEmpty && _photos.isEmpty) {
                      _removeExistingPhoto(_existingPhotos.first);
                    } else if (_photos.isNotEmpty) {
                      _removePhoto(0);
                    }
                  },
                  onReviewChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _FlavorRow(
                  label: l.checkInFlavorTags,
                  selectedSlugs: _tags,
                  locale: locale,
                  onToggle: _toggleTag,
                  onOpenPicker: _openFlavorProfiles,
                ),
                const SizedBox(height: 12),
                _LabelText(text: l.checkInLocationLabel),
                const SizedBox(height: 6),
                _VenueRow(
                  venue: _venue,
                  existing: _existingVenue,
                  onPick: _pickVenue,
                  onClear: _clearVenue,
                  emptyCta: l.checkInLocationCta,
                ),
                const SizedBox(height: 12),
                _LabelText(text: l.checkInPriceLabel),
                const SizedBox(height: 6),
                _PriceRow(
                  priceController: _price,
                  currency: _currency,
                  priceMode: _priceMode,
                  servingLabel: l.checkInPriceServing,
                  bottleLabel: l.checkInPriceBottle,
                  onCurrencyChanged: (v) => setState(() => _currency = v),
                  onModeChanged: (v) => setState(() => _priceMode = v),
                ),
                const Spacer(),
                _SubmitButton(
                  onPressed: canPost ? _submit : null,
                  submitting: submitting,
                  idleLabel: _isEdit ? l.actionSave : l.actionPost,
                  busyLabel: _isEdit ? l.checkInSavingButton : l.checkInPostingButton,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void unawaitedSafe(Future<dynamic> f) {
  f.catchError((_) {});
}

class _BeverageHeader extends StatelessWidget {
  const _BeverageHeader({
    required this.name,
    required this.subtitle,
    required this.producer,
    required this.labelImageUrl,
    required this.categorySlug,
  });

  final String name;
  final String subtitle;
  final String producer;
  final String? labelImageUrl;
  final String categorySlug;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bgSurface,
        border: Border.all(color: t.border1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          KamosLabel(
            width: 40,
            height: 54,
            tone: labelToneFromCategory(categorySlug),
            imageUrl: labelImageUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  subtitle.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: t.fg3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'ShipporiMincho',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  producer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.fg2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: t.fg1,
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.emptyValue,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final String emptyValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _LabelText(text: label),
            const SizedBox(width: 10),
            Text(
              value == null
                  ? emptyValue
                  : '${value!.toStringAsFixed(2)} / 5.0',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                color: value == null ? t.fg3 : t.fg1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RatingSlider(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ReviewWithPhoto extends StatelessWidget {
  const _ReviewWithPhoto({
    required this.controller,
    required this.focus,
    required this.reviewTooLong,
    required this.photoTileVisible,
    required this.hasPhoto,
    required this.existingPhoto,
    required this.newPhoto,
    required this.newPhotoState,
    required this.hint,
    required this.tooLongText,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onReviewChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool reviewTooLong;
  final bool photoTileVisible;
  final bool hasPhoto;
  final PhotoRef? existingPhoto;
  final XFile? newPhoto;
  final PhotoUploadState? newPhotoState;
  final String hint;
  final String tooLongText;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onReviewChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 3-line TextField. The contentPadding right-side reserves a gap so text
    // doesn't slide under the photo tile.
    final contentRightPadding = photoTileVisible ? 44.0 : 12.0;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: t.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: reviewTooLong ? t.fgBrand : t.border1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focus,
            maxLength: 500,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            maxLines: 3,
            minLines: 3,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.fromLTRB(
                12,
                10,
                contentRightPadding,
                10,
              ),
            ),
            onChanged: (_) => onReviewChanged(),
          ),
        ),
        if (photoTileVisible)
          Positioned(
            top: 6,
            right: 6,
            child: _PhotoMini(
              hasPhoto: hasPhoto,
              existing: existingPhoto,
              newPhoto: newPhoto,
              newPhotoState: newPhotoState,
              onAdd: onAddPhoto,
              onRemove: onRemovePhoto,
            ),
          ),
        if (reviewTooLong)
          Positioned(
            bottom: 6,
            right: 12,
            child: Text(
              tooLongText,
              style: TextStyle(color: t.fgBrand, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _PhotoMini extends StatelessWidget {
  const _PhotoMini({
    required this.hasPhoto,
    required this.existing,
    required this.newPhoto,
    required this.newPhotoState,
    required this.onAdd,
    required this.onRemove,
  });

  final bool hasPhoto;
  final PhotoRef? existing;
  final XFile? newPhoto;
  final PhotoUploadState? newPhotoState;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!hasPhoto) {
      return InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: t.bgSunken,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.border2),
          ),
          child: Icon(Icons.add, color: t.fg2, size: 16),
        ),
      );
    }

    final DecorationImage? image;
    if (newPhoto != null) {
      image = DecorationImage(
        image: FileImage(File(newPhoto!.path)),
        fit: BoxFit.cover,
      );
    } else if (existing != null && existing!.url.isNotEmpty) {
      image = DecorationImage(
        image: NetworkImage(existing!.url),
        fit: BoxFit.cover,
      );
    } else {
      image = null;
    }

    return GestureDetector(
      onTap: onRemove,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: t.kinari,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.border1),
          image: image,
        ),
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Color(0xCC0F2350),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 8),
        ),
      ),
    );
  }
}

class _FlavorRow extends ConsumerWidget {
  const _FlavorRow({
    required this.label,
    required this.selectedSlugs,
    required this.locale,
    required this.onToggle,
    required this.onOpenPicker,
  });

  final String label;
  final Set<String> selectedSlugs;
  final String locale;
  final void Function(String slug) onToggle;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tagsAsync = ref.watch(flavorTagsProvider);
    final tags = tagsAsync.asData?.value ?? const <FlavorTag>[];
    final selected = [
      for (final tag in tags)
        if (selectedSlugs.contains(tag.slug)) tag,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelText(text: label),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final tag in selected) ...[
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
                child: InkWell(
                  onTap: onOpenPicker,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.bgSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: t.border2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.add, color: t.fg2, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({
    required this.venue,
    required this.existing,
    required this.onPick,
    required this.onClear,
    required this.emptyCta,
  });

  final FoursquarePlace? venue;
  final VenueRef? existing;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String emptyCta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pickedName = venue?.name ?? existing?.name;
    final pickedLocality = venue?.locality ?? existing?.locality;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.bgSurface,
          border: Border.all(color: t.border1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.place_outlined, color: t.fg2, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: pickedName == null
                  ? Text(emptyCta, style: TextStyle(color: t.fg2, fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickedName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.fg1,
                          ),
                        ),
                        if ((pickedLocality ?? '').isNotEmpty)
                          Text(
                            pickedLocality!,
                            style: TextStyle(fontSize: 11, color: t.fg2),
                          ),
                      ],
                    ),
            ),
            if (pickedName != null)
              IconButton(
                icon: Icon(Icons.close, color: t.fg3, size: 16),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              )
            else
              Icon(Icons.chevron_right, color: t.fg3, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.priceController,
    required this.currency,
    required this.priceMode,
    required this.servingLabel,
    required this.bottleLabel,
    required this.onCurrencyChanged,
    required this.onModeChanged,
  });

  final TextEditingController priceController;
  final String currency;
  final String priceMode;
  final String servingLabel;
  final String bottleLabel;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        _ModeToggle(
          value: priceMode,
          servingLabel: servingLabel,
          bottleLabel: bottleLabel,
          onChanged: onModeChanged,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: t.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currency,
                    isDense: true,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: t.fg1,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'JPY', child: Text('¥')),
                      DropdownMenuItem(value: 'KRW', child: Text('₩')),
                      DropdownMenuItem(value: 'USD', child: Text('\$')),
                    ],
                    onChanged: (v) {
                      if (v != null) onCurrencyChanged(v);
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.value,
    required this.servingLabel,
    required this.bottleLabel,
    required this.onChanged,
  });

  final String value;
  final String servingLabel;
  final String bottleLabel;
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
        children: [
          for (final entry in [('serving', servingLabel), ('bottle', bottleLabel)])
            InkWell(
              onTap: () => onChanged(entry.$1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: value == entry.$1 ? t.bgSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: value == entry.$1 ? t.fg1 : t.fg2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.onPressed,
    required this.submitting,
    required this.idleLabel,
    required this.busyLabel,
  });

  final VoidCallback? onPressed;
  final bool submitting;
  final String idleLabel;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KamosPillButton.primary(
          label: submitting ? busyLabel : idleLabel,
          onPressed: submitting ? null : onPressed,
        ),
      ],
    );
  }
}

/// Loads the check-in by id, then mounts the unified compose screen in edit
/// mode. Used by the `/check-ins/:id/edit` route so edit reuses the compose
/// surface.
class CheckInEditLoader extends ConsumerWidget {
  const CheckInEditLoader({super.key, required this.checkInId});

  final String checkInId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(checkInDetailProvider(checkInId));
    return AsyncWidget(
      value: async,
      center: true,
      onRetry: () => ref.invalidate(checkInDetailProvider(checkInId)),
      data: (checkin) => CheckInScreen.edit(original: checkin),
    );
  }
}
