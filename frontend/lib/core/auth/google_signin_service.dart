// KAMOS — Google sign-in scaffold.
//
// Server-verified OAuth (SPEC §3.1). The Flutter app only ever transmits the
// Google-issued ID token; the client secret never leaves the server (brief
// §6.10).
//
// Activation is gated behind a dart-define flag:
//
//     --dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true
//
// We use a separate flag (not just the OAuth client ID) because the mobile
// flow relies on the platform-native config files
// (`GoogleService-Info.plist` on iOS + reversed-client-ID URL scheme,
// `google-services.json` / referenced client ID on Android). The Dart layer
// has no way to detect those statically, so opting in is explicit.
//
// When the flag is false, `signInAndGetIdToken()` returns `null` immediately
// and the SDK is never touched. This keeps `flutter test`, dev runs, and the
// no-config developer-onboarding case 100% no-op.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Compile-time gate. The native platform config must also be in place — see
/// README "Google sign-in setup".
const bool kIsGoogleConfigured = bool.fromEnvironment(
  'KAMOS_GOOGLE_SIGN_IN_ENABLED',
  defaultValue: false,
);

/// Optional web/server OAuth client ID. Most mobile flows do not need this on
/// the Dart side (platform config files carry the iOS/Android client IDs);
/// it is exposed here in case a downstream backend needs the server client ID
/// echoed on the request. Empty by default.
const String kGoogleClientId = String.fromEnvironment(
  'KAMOS_GOOGLE_CLIENT_ID',
  defaultValue: '',
);

class GoogleSignInService {
  GoogleSignInService();

  bool _initialized = false;

  /// Attempts the Google sign-in handshake. Returns the raw ID token on
  /// success, or `null` on:
  ///   - dart-define gate disabled
  ///   - user cancelled the OS prompt
  ///   - any SDK or network error (caller treats this the same as cancel)
  ///
  /// Never throws. The caller (`auth_screen.dart`) is responsible for showing
  /// the appropriate UX when the result is null.
  Future<String?> signInAndGetIdToken() async {
    if (!kIsGoogleConfigured) return null;
    try {
      if (!_initialized) {
        // 7.x requires a one-time `initialize` before any other call.
        // `serverClientId` is honoured on Android when the server-side
        // verifier expects a specific audience; harmless when empty.
        await GoogleSignIn.instance.initialize(
          serverClientId: kGoogleClientId.isEmpty ? null : kGoogleClientId,
        );
        _initialized = true;
      }
      if (!GoogleSignIn.instance.supportsAuthenticate()) return null;
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) return null;
      return idToken;
    } catch (_) {
      // Cancel, network failure, missing platform config — treat all the same.
      return null;
    }
  }
}

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);
