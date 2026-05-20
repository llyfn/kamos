// KAMOS — JWT claim decoder (client-side, signature NOT verified).
//
// The client only needs a stable per-user discriminator (the `sub` claim) to
// namespace local caches. Signature verification is the server's job — every
// authenticated request is checked there. Doing it again on the client would
// require shipping the signing key, which we explicitly don't.
//
// This helper is deliberately tiny: standard base64url-decode of the JWT's
// middle segment, JSON-decode, return `sub` as a String. It returns `null` for
// anything malformed so callers fall back to the 'anon' bucket.

import 'dart:convert';

/// Decodes the `sub` claim from a JWT without verifying its signature.
///
/// Returns `null` if the token is null/empty, not a three-segment JWT, the
/// payload segment is not valid base64url-encoded JSON, or `sub` is missing
/// or not a string.
///
/// This is intentionally permissive on error — the caller (cache keyBuilder)
/// substitutes the 'anon' bucket on null, so a malformed token can never
/// merge a logged-in user's cache with another user's.
String? decodeUserIdFromJwt(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = parts[1];
    // JWT uses base64url WITHOUT padding; `base64Url.decode` requires
    // length%4==0, so pad manually.
    final padded = payload.padRight(payload.length + ((4 - payload.length % 4) % 4), '=');
    final bytes = base64Url.decode(padded);
    final json = utf8.decode(bytes);
    final map = jsonDecode(json);
    if (map is! Map<String, dynamic>) return null;
    final sub = map['sub'];
    return sub is String && sub.isNotEmpty ? sub : null;
  } catch (_) {
    return null;
  }
}
