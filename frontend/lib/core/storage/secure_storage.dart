// KAMOS — Secure token storage (SPEC §6.9 / brief §6.9).
//
// JWTs (both access and refresh) live in `flutter_secure_storage`. Touching
// `SharedPreferences` for either token is a SPEC-level violation; this file
// is the only place tokens are read or written.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kJwtKey = 'kamos.jwt';
const _kRefreshKey = 'kamos.refresh';

/// Wrapper around `FlutterSecureStorage` scoped to KAMOS keys.
///
/// Do not extend this class to put any non-secret data under the same store —
/// SharedPreferences is the right surface for everything that is not a
/// credential.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android: EncryptedSharedPreferences was deprecated in v10; the
              // plugin now migrates to custom ciphers automatically.
              // `first_unlock_this_device` keeps the token out of iCloud
              // Keychain backups, so a restored device cannot resurrect a
              // refresh token from a previous OS install. Refresh tokens are
              // long-lived; the `_this_device` variant is the SPEC §6.9 stance.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  /// Last-known access token, refreshed on every read/write. The HTTP cache
  /// `keyBuilder` is synchronous (see `api_client.dart`); it cannot await the
  /// platform-channel call in `_storage.read`. This in-memory snapshot lets
  /// the keyBuilder fold the current user's id into the cache key without
  /// blocking. It is NOT a substitute for the encrypted store — every read
  /// of the truth goes through `readToken()`; this field only mirrors what
  /// the truth most-recently returned.
  static String? _accessTokenSnapshot;

  /// Stage 5 (PERF-018): memoized decoded `sub` claim for
  /// `_accessTokenSnapshot`. The cache keyBuilder fires on every request
  /// — base64-decoding the JWT payload + parsing the JSON was ~30 µs per
  /// hit before the memo. We invalidate by storing the token that
  /// produced the cached sub; if the token changes the keyBuilder
  /// recomputes once and re-fills the memo.
  static String? _subSnapshot;
  static String? _subSnapshotForToken;

  /// Synchronous best-effort accessor for the currently-active access token.
  /// Returns `null` if no token has been observed in this process or after a
  /// `clearToken`/`clearAll`. Used by the cache `keyBuilder` to derive a
  /// per-user discriminator; never use it as the source of truth for auth.
  static String? currentAccessToken() => _accessTokenSnapshot;

  /// Returns the memoized JWT `sub` claim for `currentAccessToken()`. If
  /// the active token has changed since the last call, invokes `decode`
  /// once to re-fill the memo. The decode closure is injected so this
  /// stays decoupled from jwt_claims.dart's exact import path.
  static String? currentSubMemoized(String? Function(String?) decode) {
    final token = _accessTokenSnapshot;
    if (token != _subSnapshotForToken) {
      _subSnapshot = decode(token);
      _subSnapshotForToken = token;
    }
    return _subSnapshot;
  }

  /// Test-only seam: overrides the synchronous token snapshot without going
  /// through the platform-channel-backed `FlutterSecureStorage`. Allows widget
  /// and unit tests to assert `keyBuilder` behavior per token without spinning
  /// up the secure-storage stub.
  @visibleForTesting
  static void setAccessTokenSnapshotForTest(String? token) {
    _accessTokenSnapshot = token;
    _subSnapshot = null;
    _subSnapshotForToken = null;
  }

  // --- Access token ---------------------------------------------------------

  Future<String?> readToken() async {
    final t = await _storage.read(key: _kJwtKey);
    _accessTokenSnapshot = t;
    return t;
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: _kJwtKey, value: token);
    _accessTokenSnapshot = token;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _kJwtKey);
    _accessTokenSnapshot = null;
    _subSnapshot = null;
    _subSnapshotForToken = null;
  }

  // --- Refresh token (Phase 2) ---------------------------------------------

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _kRefreshKey, value: token);

  Future<void> clearRefreshToken() => _storage.delete(key: _kRefreshKey);

  // --- Bulk ----------------------------------------------------------------

  /// Wipe every KAMOS-owned secret. Called on logout and on a hard auth
  /// failure (refresh exchange returned a non-2xx).
  Future<void> clearAll() async {
    await _storage.delete(key: _kJwtKey);
    await _storage.delete(key: _kRefreshKey);
    _accessTokenSnapshot = null;
    _subSnapshot = null;
    _subSnapshotForToken = null;
  }
}

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
