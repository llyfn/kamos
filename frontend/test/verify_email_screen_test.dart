// KAMOS — Widget test for `/auth/verify-email`.
// Covers render → loading → mocked-success path. Uses ProviderScope.overrides
// to swap in a fake AuthRepository.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/core/models/auth.dart';
import 'package:kamos/core/storage/secure_storage.dart';
import 'package:kamos/features/auth/repository/auth_repository.dart';
import 'package:kamos/features/auth/screens/verify_email_screen.dart';
import 'package:kamos/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.verified});
  final bool verified;

  @override
  Future<bool> verifyEmail(String token) async {
    // Yield once so the widget's `Future.microtask` lands between mount and
    // call. Returns the configured outcome.
    await Future<void>.delayed(Duration.zero);
    return verified;
  }

  // Everything else is unused by this test.
  @override
  SecureStorageService get storage => throw UnimplementedError();

  @override
  Future<AuthResponse> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
    String locale = 'en',
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> google({
    required String idToken,
    String? username,
    String locale = 'en',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerification() => throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> changeEmail(String newEmail) => throw UnimplementedError();

  @override
  Future<AuthResponse> refresh(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<void> logout({String? refreshToken}) => throw UnimplementedError();
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildKamosTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  testWidgets('verify-email loading → success', (tester) async {
    var redirectCalled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(verified: true),
          ),
        ],
        child: _wrap(
          VerifyEmailScreen(
            token: 'fake-token',
            onSuccessRedirect: (_) => redirectCalled = true,
          ),
        ),
      ),
    );

    // Initial frame: loading state visible.
    expect(find.text('Confirming your verification link…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Drive the microtask + the awaited delayed call inside the fake.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Success state. The same string also appears in the snackbar shown on
    // success, so allow >= 1 match.
    expect(find.text('Your email is verified.'), findsAtLeastNWidgets(1));

    // Drain the post-success redirect delay (600ms) so the test does not
    // exit with a pending Timer assertion.
    await tester.pump(const Duration(milliseconds: 700));
    expect(redirectCalled, isTrue);
  });

  testWidgets('verify-email loading → failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(verified: false),
          ),
        ],
        child: _wrap(const VerifyEmailScreen(token: 'fake-token')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('We could not verify this link. It may have expired.'),
      findsOneWidget,
    );
    expect(find.text('Back to sign in'), findsOneWidget);
  });
}
