// KAMOS — Post-signup "check your email" landing.
//
// The verification flow is end-to-end server-side: the user receives a
// `RESEND_API_KEY`-delivered mail with `/verify?token=...`, opens it in a
// browser, and the backend renders a localized HTML success page. The
// mobile app no longer consumes verification tokens — its job here is
// just to land the just-signed-up user, tell them what to do, and detect
// when `/v1/users/me.email_verified` flips to true.
//
// Detection paths:
//   * a tap on "I've verified" force-refreshes `meProvider` immediately;
//   * a 5-second background poll re-reads `meProvider` so the screen
//     auto-advances if the user verifies in another tab/window.
// When `emailVerified` flips to true, the screen navigates to `/` and
// the router redirect places the user on the home feed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/auth_state.dart';
import '../repository/auth_repository.dart';

class VerifyEmailPendingScreen extends ConsumerStatefulWidget {
  const VerifyEmailPendingScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailPendingScreen> createState() =>
      _VerifyEmailPendingScreenState();
}

class _VerifyEmailPendingScreenState
    extends ConsumerState<VerifyEmailPendingScreen> {
  Timer? _pollTimer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    // Background poll for the verification flip. 5s cadence is short
    // enough to feel responsive and long enough to stay well under any
    // sane rate-limit on /v1/users/me.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _refreshAndMaybeAdvance();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAndMaybeAdvance() async {
    ref.invalidate(meProvider);
    try {
      final me = await ref.read(meProvider.future);
      if (!mounted) return;
      if (me.user.emailVerified) {
        _pollTimer?.cancel();
        context.go('/');
      }
    } catch (_) {
      // Polling failures are silent — the next tick (or the manual
      // "I've verified" tap) will retry.
    }
  }

  Future<void> _onResend() async {
    if (_resending) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.verifyPendingResendSent)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.verifyPendingResendFailed)),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _onBackToSignIn() async {
    // Log the user out so the auth screen renders in its signed-out
    // state and the user can re-sign-up with a corrected email.
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KamosSpacing.xl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: t.ai,
                ),
                const SizedBox(height: KamosSpacing.md),
                Text(
                  l.verifyPendingTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ShipporiMincho',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: t.fg1,
                  ),
                ),
                const SizedBox(height: KamosSpacing.sm),
                Text(
                  l.verifyPendingBody(widget.email),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.fg2),
                ),
                const SizedBox(height: KamosSpacing.lg),
                FilledButton(
                  onPressed: _refreshAndMaybeAdvance,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.ai,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l.verifyPendingICheckedMyMail),
                ),
                const SizedBox(height: KamosSpacing.sm),
                OutlinedButton(
                  onPressed: _resending ? null : _onResend,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.verifyPendingResend),
                ),
                TextButton(
                  onPressed: _onBackToSignIn,
                  child: Text(l.verifyPendingBackToSignIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
