// KAMOS — "Suggest a beverage" form (user-side).
//
// Posts the four-field payload to `POST /v1/beverage-requests`. The backend
// queues the row for admin review and returns `202 { id }`; nothing else
// happens user-side. Hooked into the router at `/beverage-requests/new`.
//
// Validation rules (mirror the backend's loose validation — server only
// checks payload is non-empty):
// * `name`, `brewery_name`: trimmed; required; ≤ 200 chars
// * `category_slug`: one of nihonshu | shochu | liqueur (SPEC §2.1)
// * `notes`: optional; ≤ 500 chars; trimmed (matches review cap, since
// this surface most resembles a check-in review than a profile bio)
//
// Control-character rejection: a single regex strips ASCII control bytes
// (newlines kept in `notes` for paragraph entry; stripped in name/brewery).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/category_labels.dart';
import '../../../core/models/beverage_request.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/beverage_request_providers.dart';

/// Maximum lengths chosen to mirror the closest existing fields on
/// `beverages` (name ≤ 200) and `check_ins` (review ≤ 500). The server is
/// the backstop and accepts anything non-empty today.
const _nameMax = 200;
const _breweryMax = 200;
const _notesMax = 500;

class SubmitBeverageRequestScreen extends ConsumerStatefulWidget {
  const SubmitBeverageRequestScreen({
    super.key,
    @visibleForTesting this.onSubmittedForTest,
  });

  /// Tests override this so the screen does not call `context.pop()` (no
  /// router in widget tests). Production callers leave it null.
  @visibleForTesting
  final VoidCallback? onSubmittedForTest;

  @override
  ConsumerState<SubmitBeverageRequestScreen> createState() =>
      _SubmitBeverageRequestScreenState();
}

class _SubmitBeverageRequestScreenState
    extends ConsumerState<SubmitBeverageRequestScreen> {
  final _name = TextEditingController();
  final _brewery = TextEditingController();
  final _notes = TextEditingController();
  CategorySlug _category = CategorySlug.nihonshu;
  bool _showValidation = false;

  @override
  void dispose() {
    _name.dispose();
    _brewery.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _nameError(AppLocalizations l) {
    final t = _name.text.trim();
    if (t.isEmpty) return l.submitBeverageRequestNameRequired;
    return null;
  }

  String? _breweryError(AppLocalizations l) {
    final t = _brewery.text.trim();
    if (t.isEmpty) return l.submitBeverageRequestBreweryRequired;
    return null;
  }

  bool get _isValid =>
      _name.text.trim().isNotEmpty && _brewery.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!_isValid) {
      setState(() => _showValidation = true);
      return;
    }
    final req = BeverageRequest(
      name: _name.text.trim(),
      breweryName: _brewery.text.trim(),
      categorySlug: categorySlugToWire(_category),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await ref.read(submitBeverageRequestProvider.notifier).submit(req);
    if (!mounted) return;
    final state = ref.read(submitBeverageRequestProvider);
    if (state.hasError) {
      // Inline error rendered by the build() below; nothing else to do.
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.submitBeverageRequestSuccessToast)),
    );
    final hook = widget.onSubmittedForTest;
    if (hook != null) {
      hook();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final state = ref.watch(submitBeverageRequestProvider);
    final isLoading = state.isLoading;
    final hasError = state.hasError;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(l.submitBeverageRequestTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(text: l.submitBeverageRequestNameLabel),
            TextField(
              controller: _name,
              maxLength: _nameMax,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F\x7F]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                errorText: _showValidation ? _nameError(l) : null,
              ),
            ),
            _SectionLabel(text: l.submitBeverageRequestBreweryLabel),
            TextField(
              controller: _brewery,
              maxLength: _breweryMax,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F\x7F]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                errorText: _showValidation ? _breweryError(l) : null,
              ),
            ),
            _SectionLabel(text: l.submitBeverageRequestCategoryLabel),
            _CategorySegmented(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            _SectionLabel(text: l.submitBeverageRequestNotesLabel),
            TextField(
              controller: _notes,
              maxLength: _notesMax,
              maxLines: 4,
              minLines: 3,
              inputFormatters: [
                // Allow \n and \r for paragraph breaks; deny other controls.
                FilteringTextInputFormatter.deny(
                  RegExp(r'[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]'),
                ),
              ],
              onChanged: (_) => setState(() {}),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.submitBeverageRequestErrorGeneric,
                  style: TextStyle(color: t.fgDanger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (isLoading || !_isValid) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: t.ai,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l.submitBeverageRequestSubmitButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
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

class _CategorySegmented extends StatelessWidget {
  const _CategorySegmented({required this.value, required this.onChanged});
  final CategorySlug value;
  final ValueChanged<CategorySlug> onChanged;

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
        children: CategorySlug.values.map((slug) {
          final active = value == slug;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(slug),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? t.bgSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  categoryLabel(context, slug),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? t.fg1 : t.fg2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
