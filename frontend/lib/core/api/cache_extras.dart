// KAMOS — Per-request HTTP-cache opt-out.
//
// The cache contract is documented in `api_client.dart`'s header: the server's
// `Cache-Control` directive is the source of truth (policy is
// `CachePolicy.request`), and the cache interceptor will not see endpoints
// the server has marked `no-store`/`private`. POST/PATCH/DELETE bypass the
// cache by default (`allowPostMethod: false`).
//
// This file adds a belt-and-suspenders escape hatch for the rare case where
// a specific GET on an otherwise-cacheable route must skip the cache — e.g.
// a "pull to refresh" gesture that should always re-hit the origin even if
// the local entry is still fresh per `max-age`.
//
// Usage:
//
//   await dio.get(
//     '/v1/categories',
//     options: Options(extra: kBypassCache),
//   );
//
// Sentinel key/value are taken from `dio_cache_interceptor`'s `CacheOptions`
// extras shape, so the interceptor recognises and honours them without any
// extra wiring on the Dio singleton.

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Per-request extras that force `dio_cache_interceptor` to bypass the cache
/// for a single call. Internally this rebuilds the request's `CacheOptions`
/// with `CachePolicy.noCache`, which the interceptor reads via the same
/// `Options.extra` channel as the global config.
///
/// The store reference here is intentionally null — `noCache` means "do not
/// hit and do not store", so the store is not used by the interceptor for
/// this request. The global default (see `api_client.dart`) keeps the real
/// `MemCacheStore` for every other call.
final Map<String, dynamic> kBypassCache = const CacheOptions(
  store: null,
  policy: CachePolicy.noCache,
).toExtra();
