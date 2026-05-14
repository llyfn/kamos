// KAMOS — Secure token storage (SPEC §6.9 / brief §6.9).
//
// JWTs (both access and refresh) live in `flutter_secure_storage`. Touching
// `SharedPreferences` for either token is a SPEC-level violation; this file
// is the only place tokens are read or written.

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
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // --- Access token ---------------------------------------------------------

  Future<String?> readToken() => _storage.read(key: _kJwtKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _kJwtKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _kJwtKey);

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
  }
}

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
