// KAMOS — Secure token storage (SPEC §6.9 / brief §6.9).
//
// JWT lives in `flutter_secure_storage`. Touching `SharedPreferences` for a
// token is a SPEC-level violation; this file is the only place tokens are
// read or written.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kJwtKey = 'kamos.jwt';

/// Wrapper around `FlutterSecureStorage` scoped to KAMOS keys.
///
/// Do not extend this class to put any non-secret data under the same store —
/// SharedPreferences is the right surface for everything that is not a
/// credential.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _kJwtKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _kJwtKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _kJwtKey);
}

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
