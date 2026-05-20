// KAMOS — Sentry breadcrumb scrubber (SEC-020).
//
// Breadcrumbs ride along with every captured event, so anything that leaks
// into `breadcrumb.data` ends up at Sentry. The Dio integration places
// request/response data in well-known sub-maps, but error-path breadcrumbs and
// custom integrations also stash data under `extra`, `contexts`, `response`,
// `response_headers`, and `url`. This module walks the whole tree and
// redacts:
//
//   * any key whose name (case-insensitively) contains
//     `authorization`, `token`, `refresh`, `password`, or `secret`, or
//     matches `id_token`
//   * URL query parameters named `token` or `refresh_token`
//
// Recursion is bounded at depth 6 to avoid pathological cycles.

const String _redactionMarker = '[redacted]';

/// Maximum nesting depth the scrubber will walk before giving up. Sentry
/// breadcrumb data is typically <3 levels deep; 6 is a generous ceiling.
const int _maxScrubDepth = 6;

const List<String> _secretKeyNeedles = <String>[
  'authorization',
  'token',
  'refresh',
  'password',
  'secret',
];

bool _keyLooksSecret(String key) {
  final lower = key.toLowerCase();
  if (lower == 'id_token') return true;
  for (final needle in _secretKeyNeedles) {
    if (lower.contains(needle)) return true;
  }
  return false;
}

/// Scrubs a single Sentry breadcrumb data map in place. Walks the well-known
/// Sentry HTTP-integration sub-maps and any nested `extra` / `contexts`
/// payload; redacts secret-looking values and strips `token=`/`refresh_token=`
/// from URLs.
void scrubBreadcrumbData(Map<String, dynamic> data) {
  // Top-level walk: redacts headers/Authorization at the root, plus any
  // secret-looking keys callers placed directly on the breadcrumb data.
  _scrubSecretishStrings(data, 0);

  // The Sentry HTTP integration may nest request headers under
  // `data['request']` as a `Map`. Keep an explicit walk so the existing
  // request-headers contract is documented even after the recursive scrub.
  final request = data['request'];
  if (request is Map) {
    _scrubSecretishStrings(request, 0);
  }

  // Response data: error responses sometimes echo `Authorization` back.
  final response = data['response'];
  if (response is Map) {
    _scrubSecretishStrings(response, 0);
  }
  final responseHeaders = data['response_headers'];
  if (responseHeaders is Map) {
    _scrubSecretishStrings(responseHeaders, 0);
  }

  // Sentry's "extra context" bag — free-form key/value strings.
  final extra = data['extra'];
  if (extra is Map) {
    _scrubSecretishStrings(extra, 0);
  }

  // Sentry contexts (`device`, `app`, `runtime`, etc.); cheap to walk.
  final contexts = data['contexts'];
  if (contexts is Map) {
    _scrubSecretishStrings(contexts, 0);
  }
}

/// Recursive in-place scrub.
///
/// * Maps: redacts any value whose key looks secret; recurses into Map/List
///   values that aren't redacted.
/// * Lists: recurses element-by-element.
/// * Strings: passed through the URL-query scrubber so query-string tokens
///   inside a `url` value get neutralised.
///
/// Stops at depth [_maxScrubDepth] to avoid pathological cycles. Exposed via
/// the top-level [scrubBreadcrumbData]; the recursion itself is internal.
void _scrubSecretishStrings(dynamic node, int depth) {
  if (depth >= _maxScrubDepth) return;
  if (node is Map) {
    for (final key in node.keys.toList()) {
      final value = node[key];
      if (key is String && _keyLooksSecret(key)) {
        node[key] = _redactionMarker;
        continue;
      }
      if (value is Map || value is List) {
        _scrubSecretishStrings(value, depth + 1);
      } else if (value is String) {
        final scrubbed = _scrubSecretishUrl(value);
        if (!identical(scrubbed, value)) {
          node[key] = scrubbed;
        }
      }
    }
    // The legacy `headers_raw` blob is a single string with the raw header
    // list; the recursive walk above already replaces secret-keyed values, but
    // a free-form string under a non-secret-named key still needs the
    // Authorization sweep. Preserve the old behavior explicitly.
    final rawHeaders = node['headers_raw'];
    if (rawHeaders is String &&
        rawHeaders.toLowerCase().contains('authorization')) {
      node['headers_raw'] = _redactionMarker;
    }
    return;
  }
  if (node is List) {
    for (var i = 0; i < node.length; i++) {
      final value = node[i];
      if (value is Map || value is List) {
        _scrubSecretishStrings(value, depth + 1);
      } else if (value is String) {
        final scrubbed = _scrubSecretishUrl(value);
        if (!identical(scrubbed, value)) {
          node[i] = scrubbed;
        }
      }
    }
  }
}

/// If [value] looks like a URL with a `token` or `refresh_token` query
/// parameter, returns a copy with those values redacted. Otherwise returns
/// the original string (by identity, so callers can cheap-check).
String _scrubSecretishUrl(String value) {
  // Cheap reject: not a URL-ish string.
  if (!value.contains('=')) return value;
  final qIndex = value.indexOf('?');
  // We also tolerate fragment-only query strings.
  final hasQuerySep = qIndex >= 0 || value.contains('&');
  if (!hasQuerySep) return value;

  Uri? uri;
  try {
    uri = Uri.parse(value);
  } catch (_) {
    uri = null;
  }
  if (uri != null && uri.hasQuery) {
    final params = Map<String, List<String>>.from(uri.queryParametersAll);
    var mutated = false;
    for (final key in params.keys.toList()) {
      if (_keyLooksSecret(key)) {
        params[key] = <String>[_redactionMarker];
        mutated = true;
      }
    }
    if (!mutated) return value;
    return uri.replace(queryParameters: params).toString();
  }

  // Fallback: hand-roll a query-string scrub for `key=value&key=value`
  // fragments that aren't valid URIs (e.g., a bare query body).
  final parts = value.split('&');
  var mutated = false;
  for (var i = 0; i < parts.length; i++) {
    final eq = parts[i].indexOf('=');
    if (eq <= 0) continue;
    final key = parts[i].substring(0, eq);
    if (_keyLooksSecret(key)) {
      parts[i] = '$key=$_redactionMarker';
      mutated = true;
    }
  }
  if (!mutated) return value;
  return parts.join('&');
}
