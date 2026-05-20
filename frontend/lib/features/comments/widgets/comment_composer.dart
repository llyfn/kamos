// KAMOS — Comment composer (Phase 6).
//
// Multi-line text field with a 500-character hard cap, live char counter, and
// a submit button. Submit is disabled while the input is empty or while a
// request is in flight. On success the text is cleared.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';

const int commentMaxChars = 500;

class CommentComposer extends StatefulWidget {
  const CommentComposer({super.key, required this.onSubmit});

  /// Returns `true` on success — on success the field is cleared. Returns
  /// `false` (or throws) on failure; the caller is responsible for showing a
  /// toast / inline error.
  final Future<bool> Function(String body) onSubmit;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  bool _submitting = false;

  // Stage 5 (PERF-033): the previous shape called setState on every
  // keystroke through controller.addListener(setState). That rebuilt
  // the entire composer (TextField + counter + button) for every
  // character typed. We now scope rebuilds to the counter + button
  // via ValueListenableBuilder; the TextField itself is rebuild-free.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final ok = await widget.onSubmit(text);
      if (ok && mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            maxLength: commentMaxChars,
            // Hide the default character counter; we render a localized one.
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: [
              LengthLimitingTextInputFormatter(commentMaxChars),
            ],
            decoration: InputDecoration(
              hintText: l.commentsComposerHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final length = value.text.length;
              final canSubmit = !_submitting && value.text.trim().isNotEmpty;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.commentsCharCount(length, commentMaxChars),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: length >= commentMaxChars ? t.fgDanger : t.fg3,
                    ),
                  ),
                  FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.commentsSubmit),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
