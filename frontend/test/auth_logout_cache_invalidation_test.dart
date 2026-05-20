// KAMOS — Phase 7 follow-up. Verifies the belt-and-suspenders defense:
// `ref.invalidate(dioProvider)` on a fresh Riverpod container produces a new
// Dio instance, and `SecureStorageService.clearAll` wipes the synchronous
// `currentAccessToken` snapshot used by `cacheKeyBuilder`.
//
// Together with `cache_key_builder_user_isolation_test.dart`, these close the
// MAJOR #2 finding from qa_report_phase7_flutter.md: even if the in-memory
// MemCacheStore survives a logout for any reason, User B's cache lookups
// land in a different key namespace from User A's.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/core/api/api_client.dart';
import 'package:kamos/core/storage/secure_storage.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey(
          {required String key, required Map<String, String> options}) async =>
      _values.containsKey(key);

  @override
  Future<void> delete(
      {required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }

  @override
  Future<String?> read(
          {required String key, required Map<String, String> options}) async =>
      _values[key];

  @override
  Future<Map<String, String>> readAll(
          {required Map<String, String> options}) async =>
      Map<String, String>.from(_values);

  @override
  Future<void> write(
      {required String key,
      required String value,
      required Map<String, String> options}) async {
    _values[key] = value;
  }
}

void main() {
  test('ref.invalidate(dioProvider) yields a new Dio instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(dioProvider);
    final firstAgain = container.read(dioProvider);
    expect(identical(first, firstAgain), isTrue,
        reason: 'before invalidation, the same Dio instance is returned');

    container.invalidate(dioProvider);
    final second = container.read(dioProvider);

    expect(identical(first, second), isFalse,
        reason: 'after invalidation, a fresh Dio singleton is built; '
            'the previous closure-held MemCacheStore is unreachable');
    expect(second, isA<Dio>());
  });

  test('clearAll wipes the synchronous access-token snapshot', () async {
    FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();
    final storage = SecureStorageService();
    await storage.writeToken('access-A');
    expect(SecureStorageService.currentAccessToken(), 'access-A');

    await storage.clearAll();
    expect(SecureStorageService.currentAccessToken(), isNull,
        reason: 'snapshot must reset so cacheKeyBuilder falls back to anon');
  });
}
