#!/usr/bin/env python3
"""Generator: specs/invariants.yaml -> Go + Dart constants.

The YAML reader handles the subset used by specs/invariants.yaml:
nested maps, inline flow arrays, scalars, '#' comments. It is NOT a
general YAML parser. If you reach for anchors / multi-line scalars /
flow maps, extend `_parse_yaml` instead of swapping to PyYAML — keeping
the generator dep-free is intentional.
"""
from __future__ import annotations
import json
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "specs" / "invariants.yaml"
GO_OUT = ROOT / "backend" / "internal" / "spec" / "spec.go"
DART_OUT = ROOT / "frontend" / "lib" / "core" / "spec" / "spec.dart"


def _strip_comment(line: str) -> str:
    in_single = in_double = False
    out = []
    for ch in line:
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            break
        out.append(ch)
    return "".join(out).rstrip()


def _coerce(s: str):
    s = s.strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        return [] if not inner else [_coerce(x) for x in _split_flow(inner)]
    if s in ("true", "false"):
        return s == "true"
    if s in ("null", "~", ""):
        return None
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        pass
    return s


def _split_flow(s: str):
    parts, depth, buf, in_str, q = [], 0, [], False, ""
    for ch in s:
        if in_str:
            buf.append(ch)
            if ch == q:
                in_str = False
            continue
        if ch in ("'", '"'):
            in_str, q = True, ch
            buf.append(ch)
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    if buf:
        parts.append("".join(buf).strip())
    return parts


def _parse_yaml(text: str):
    lines = []
    for raw in text.splitlines():
        s = _strip_comment(raw)
        if not s.strip():
            continue
        indent = len(s) - len(s.lstrip(" "))
        lines.append((indent, s.strip()))

    root: dict = {}
    stack = [(-1, root)]
    pending_list_key = None

    for i, (indent, content) in enumerate(lines):
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]

        if content.startswith("- "):
            item_raw = content[2:].strip()
            container_key = stack[-1][0]
            # The parent dict's last key should hold a list. Find it.
            if pending_list_key is None:
                raise ValueError(f"orphan list item: {content!r}")
            parent_list = stack[-1][1][pending_list_key]
            if ":" in item_raw and not (item_raw.startswith('"') or item_raw.startswith("'")):
                k, v = item_raw.split(":", 1)
                obj = {k.strip(): _coerce(v.strip())}
                parent_list.append(obj)
            else:
                parent_list.append(_coerce(item_raw))
            continue

        key, _, val = content.partition(":")
        key = key.strip()
        val = val.strip()
        if val == "":
            # Block — could be a map or list. Peek next line.
            nxt = lines[i + 1] if i + 1 < len(lines) else None
            if nxt and nxt[1].startswith("- "):
                parent[key] = []
                pending_list_key = key
                stack.append((indent, parent))
            else:
                child = {}
                parent[key] = child
                stack.append((indent, child))
                pending_list_key = None
        else:
            parent[key] = _coerce(val)
            pending_list_key = None
    return root


HEADER_NOTE = (
    "DO NOT EDIT. Generated from specs/invariants.yaml by scripts/gen-spec.py.\n"
    "Edit the YAML and re-run the generator; CI fails on drift."
)


def _go_lit(v):
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return '""'
    return str(v)


def _dart_lit(v):
    if isinstance(v, str):
        return "'" + v.replace("\\", "\\\\").replace("'", r"\'") + "'"
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "null"
    return str(v)


def emit_go(data: dict) -> str:
    r = data["rating"]
    p = data["photos"]
    rv = data["review_text"]
    cmt = data["comment_text"]
    br = data["beverage_request"]
    cen = data["collection_entry_note"]
    cn = data["collection_name"]
    un = data["username"]
    dn = data["display_name"]
    bio = data["bio"]
    pw = data["password"]
    ev = data["email_verification"]
    pg = data["pagination"]
    loc = data["locales"]
    sd = data["soft_delete"]
    cur = data["cursor"]
    cat = data["categories"]
    dc = data["default_collections"]
    pt = data["purchase_type"]
    price = data["price"]
    mn = data["moderation_notes"]
    sq = data["search_query"]
    soq = data["social_query"]
    vf = data["venue_fields"]

    lines = []
    add = lines.append
    add(f"// {HEADER_NOTE.splitlines()[0]}")
    for ln in HEADER_NOTE.splitlines()[1:]:
        add(f"// {ln}")
    add("")
    add("package spec")
    add("")
    add("// Package spec exposes canonical product invariants.")
    add("//")
    add("// The exported []string / map values below are package-level vars")
    add("// only because Go has no truly-immutable slice/map type. Treat them")
    add("// as read-only: do not append, reslice, or mutate entries — callers")
    add("// share a single backing buffer with every other handler in the")
    add("// process.")
    add("")
    add("// SchemaVersion mirrors specs/invariants.yaml schema_version.")
    add(f"const SchemaVersion = {data['schema_version']}")
    add("")
    add("// Rating bounds and grid step per SPEC §" + r["spec_section"] + ".")
    add("const (")
    add(f"\tRatingMin   = {r['min']}")
    add(f"\tRatingMax   = {r['max']}")
    add(f"\tRatingStep  = {r['step']}")
    add(f"\tRatingLevels = {r['levels']}")
    add(")")
    add("")
    add("// Photos per-submission cap per SPEC §" + p["spec_section"] + ".")
    add(f"const PhotosMaxPerSubmission = {p['max_per_submission']}")
    add(f"const PhotosLegacyReadableCap = {p['legacy_readable_cap']}")
    add("")
    add("// Text caps.")
    add("const (")
    add(f"\tReviewMaxChars            = {rv['max_chars']}")
    add(f"\tCommentMinChars           = {cmt['min_chars']}")
    add(f"\tCommentMaxChars           = {cmt['max_chars']}")
    add(f"\tBeverageRequestNotesMax   = {br['notes_max_chars']}")
    add(f"\tBeverageRequestStringMax  = {br['string_field_max_chars']}")
    add(f"\tBeverageRequestPayloadMax = {br['payload_max_bytes']}")
    add(f"\tCollectionEntryNoteMax    = {cen['max_chars']}")
    add(f"\tCollectionNameMin         = {cn['min_chars']}")
    add(f"\tCollectionNameMax         = {cn['max_chars']}")
    add(f"\tDisplayNameMin            = {dn['min_chars']}")
    add(f"\tDisplayNameMax            = {dn['max_chars']}")
    add(f"\tBioMax                    = {bio['max_chars']}")
    add(f"\tPasswordMin               = {pw['min_chars']}")
    add(f"\tModerationNotesMaxChars   = {mn['max_chars']}")
    add(f"\tSearchQueryMaxChars       = {sq['max_chars']}")
    add(f"\tSocialQueryMaxChars       = {soq['max_chars']}")
    add(")")
    add("")
    add("// Venue field bounds per SPEC §" + vf["spec_section"] + ".")
    add("const (")
    add(f"\tVenueNameMin       = {vf['name_min']}")
    add(f"\tVenueNameMax       = {vf['name_max']}")
    add(f"\tVenueAddressMax    = {vf['address_max']}")
    add(f"\tVenueCountryMax    = {vf['country_max']}")
    add(f"\tVenuePrefectureMax = {vf['prefecture_max']}")
    add(f"\tVenueLocalityMax   = {vf['locality_max']}")
    add(")")
    add("")
    add("// Username regex per SPEC §" + un["spec_section"] + ".")
    add(f"const UsernameRegex = `{un['regex']}`")
    add(f"const UsernameStorageRegex = `{un['storage_regex']}`")
    add(f"const UsernameMinChars = {un['min_chars']}")
    add(f"const UsernameMaxChars = {un['max_chars']}")
    add("")
    add(f"const EmailVerificationLinkTTLHours = {ev['link_ttl_hours']}")
    add("")
    add("// Pagination per SPEC §" + pg["spec_section"] + ".")
    add("const (")
    add(f"\tPageSizeDefault       = {pg['default_page_size']}")
    add(f"\tPageSizeMax           = {pg['max_page_size']}")
    add(f"\tPageSizeFeed          = {pg['feed_page_size']}")
    add(f"\tPageSizeNotifications = {pg['notifications_page_size']}")
    add(f"\tPageSizeFoursquare    = {pg['foursquare_max']}")
    add(")")
    add("")
    add("// Locales per SPEC §" + loc["spec_section"] + ".")
    add(f"var SupportedLocales = []string{{{', '.join(_go_lit(x) for x in loc['supported'])}}}")
    add(f"const LocaleDefault = {_go_lit(loc['default'])}")
    add(f"const LocaleFallback = {_go_lit(loc['fallback'])}")
    add("")
    add(f"const UsernameHoldDays = {sd['username_hold_days']}")
    add(f"const NotificationsReadRetentionDays = {sd['notifications_read_retention_days']}")
    add("")
    add(f"const CursorSecretMinBytes = {cur['secret_min_bytes']}")
    add("")
    add("// Category slugs per SPEC §" + cat["spec_section"] + ".")
    add(f"var CategorySlugs = []string{{{', '.join(_go_lit(x) for x in cat['slugs'])}}}")
    add("")
    add("// CategoryNames[slug][locale] -> localized category label.")
    add("var CategoryNames = map[string]map[string]string{")
    for slug in cat["slugs"]:
        names = cat["names"][slug]
        items = ", ".join(f"{_go_lit(lc)}: {_go_lit(names[lc])}" for lc in loc["supported"])
        add(f"\t{_go_lit(slug)}: {{{items}}},")
    add("}")
    add("")
    add("// DefaultCollectionInventory[locale] / DefaultCollectionWishlist[locale].")
    inv = ", ".join(f"{_go_lit(lc)}: {_go_lit(dc['inventory'][lc])}" for lc in loc["supported"])
    wish = ", ".join(f"{_go_lit(lc)}: {_go_lit(dc['wishlist'][lc])}" for lc in loc["supported"])
    add(f"var DefaultCollectionInventory = map[string]string{{{inv}}}")
    add(f"var DefaultCollectionWishlist = map[string]string{{{wish}}}")
    add("")
    add("// Controlled vocabularies.")
    add(f"var PurchaseTypes = []string{{{', '.join(_go_lit(x) for x in pt['values'])}}}")
    add(f"var PriceCurrencies = []string{{{', '.join(_go_lit(x) for x in price['currencies'])}}}")
    add(f"var PriceModes = []string{{{', '.join(_go_lit(x) for x in price['modes'])}}}")
    add("")
    return "\n".join(lines) + "\n"


def emit_dart(data: dict) -> str:
    r = data["rating"]
    p = data["photos"]
    rv = data["review_text"]
    cmt = data["comment_text"]
    br = data["beverage_request"]
    cen = data["collection_entry_note"]
    cn = data["collection_name"]
    un = data["username"]
    dn = data["display_name"]
    bio = data["bio"]
    pw = data["password"]
    ev = data["email_verification"]
    pg = data["pagination"]
    loc = data["locales"]
    sd = data["soft_delete"]
    cur = data["cursor"]
    cat = data["categories"]
    dc = data["default_collections"]
    pt = data["purchase_type"]
    price = data["price"]
    mn = data["moderation_notes"]
    sq = data["search_query"]
    soq = data["social_query"]
    vf = data["venue_fields"]

    lines = []
    add = lines.append
    add(f"// {HEADER_NOTE.splitlines()[0]}")
    for ln in HEADER_NOTE.splitlines()[1:]:
        add(f"// {ln}")
    add("")
    add("// ignore_for_file: constant_identifier_names")
    add("")
    add("class KamosSpec {")
    add("  KamosSpec._();")
    add("")
    add(f"  static const int schemaVersion = {data['schema_version']};")
    add("")
    add("  // Rating (SPEC §" + r["spec_section"] + ")")
    add(f"  static const double ratingMin = {r['min']};")
    add(f"  static const double ratingMax = {r['max']};")
    add(f"  static const double ratingStep = {r['step']};")
    add(f"  static const int ratingLevels = {r['levels']};")
    add("")
    add("  // Photos (SPEC §" + p["spec_section"] + ")")
    add(f"  static const int photosMaxPerSubmission = {p['max_per_submission']};")
    add(f"  static const int photosLegacyReadableCap = {p['legacy_readable_cap']};")
    add("")
    add("  // Text caps")
    add(f"  static const int reviewMaxChars = {rv['max_chars']};")
    add(f"  static const int commentMinChars = {cmt['min_chars']};")
    add(f"  static const int commentMaxChars = {cmt['max_chars']};")
    add(f"  static const int beverageRequestNotesMax = {br['notes_max_chars']};")
    add(f"  static const int beverageRequestStringMax = {br['string_field_max_chars']};")
    add(f"  static const int beverageRequestPayloadMax = {br['payload_max_bytes']};")
    add(f"  static const int collectionEntryNoteMax = {cen['max_chars']};")
    add(f"  static const int collectionNameMin = {cn['min_chars']};")
    add(f"  static const int collectionNameMax = {cn['max_chars']};")
    add(f"  static const int displayNameMin = {dn['min_chars']};")
    add(f"  static const int displayNameMax = {dn['max_chars']};")
    add(f"  static const int bioMax = {bio['max_chars']};")
    add(f"  static const int passwordMin = {pw['min_chars']};")
    add(f"  static const int moderationNotesMaxChars = {mn['max_chars']};")
    add(f"  static const int searchQueryMaxChars = {sq['max_chars']};")
    add(f"  static const int socialQueryMaxChars = {soq['max_chars']};")
    add("")
    add("  // Venue field bounds (SPEC §" + vf["spec_section"] + ")")
    add(f"  static const int venueNameMin = {vf['name_min']};")
    add(f"  static const int venueNameMax = {vf['name_max']};")
    add(f"  static const int venueAddressMax = {vf['address_max']};")
    add(f"  static const int venueCountryMax = {vf['country_max']};")
    add(f"  static const int venuePrefectureMax = {vf['prefecture_max']};")
    add(f"  static const int venueLocalityMax = {vf['locality_max']};")
    add("")
    add("  // Username (SPEC §" + un["spec_section"] + ")")
    add(f"  static const String usernameRegex = r'{un['regex']}';")
    add(f"  static const String usernameStorageRegex = r'{un['storage_regex']}';")
    add(f"  static const int usernameMinChars = {un['min_chars']};")
    add(f"  static const int usernameMaxChars = {un['max_chars']};")
    add("")
    add(f"  static const int emailVerificationLinkTtlHours = {ev['link_ttl_hours']};")
    add("")
    add("  // Pagination (SPEC §" + pg["spec_section"] + ")")
    add(f"  static const int pageSizeDefault = {pg['default_page_size']};")
    add(f"  static const int pageSizeMax = {pg['max_page_size']};")
    add(f"  static const int pageSizeFeed = {pg['feed_page_size']};")
    add(f"  static const int pageSizeNotifications = {pg['notifications_page_size']};")
    add(f"  static const int pageSizeFoursquare = {pg['foursquare_max']};")
    add("")
    add("  // Locales (SPEC §" + loc["spec_section"] + ")")
    supp = ", ".join(_dart_lit(x) for x in loc["supported"])
    add(f"  static const List<String> supportedLocales = [{supp}];")
    add(f"  static const String localeDefault = {_dart_lit(loc['default'])};")
    add(f"  static const String localeFallback = {_dart_lit(loc['fallback'])};")
    add("")
    add(f"  static const int usernameHoldDays = {sd['username_hold_days']};")
    add(f"  static const int notificationsReadRetentionDays = {sd['notifications_read_retention_days']};")
    add("")
    add(f"  static const int cursorSecretMinBytes = {cur['secret_min_bytes']};")
    add("")
    add("  // Category slugs (SPEC §" + cat["spec_section"] + ")")
    slugs = ", ".join(_dart_lit(x) for x in cat["slugs"])
    add(f"  static const List<String> categorySlugs = [{slugs}];")
    add("")
    add("  // CategoryNames[slug]![locale]! -> localized label.")
    add("  static const Map<String, Map<String, String>> categoryNames = {")
    for slug in cat["slugs"]:
        names = cat["names"][slug]
        inner = ", ".join(f"{_dart_lit(lc)}: {_dart_lit(names[lc])}" for lc in loc["supported"])
        add(f"    {_dart_lit(slug)}: {{{inner}}},")
    add("  };")
    add("")
    inv = ", ".join(f"{_dart_lit(lc)}: {_dart_lit(dc['inventory'][lc])}" for lc in loc["supported"])
    wish = ", ".join(f"{_dart_lit(lc)}: {_dart_lit(dc['wishlist'][lc])}" for lc in loc["supported"])
    add(f"  static const Map<String, String> defaultCollectionInventory = {{{inv}}};")
    add(f"  static const Map<String, String> defaultCollectionWishlist = {{{wish}}};")
    add("")
    pts = ", ".join(_dart_lit(x) for x in pt["values"])
    pcurs = ", ".join(_dart_lit(x) for x in price["currencies"])
    pmodes = ", ".join(_dart_lit(x) for x in price["modes"])
    add(f"  static const List<String> purchaseTypes = [{pts}];")
    add(f"  static const List<String> priceCurrencies = [{pcurs}];")
    add(f"  static const List<String> priceModes = [{pmodes}];")
    add("}")
    add("")
    return "\n".join(lines) + "\n"


def _gofmt(path: pathlib.Path) -> None:
    # Pipe through goimports first (handles local-prefix grouping per
    # .golangci.yml) when available, else fall back to gofmt for the
    # column-alignment / blank-line rules. Both are required to satisfy CI.
    for tool, args in (("goimports", ["-local", "github.com/kamos/api", "-w", str(path)]),
                       ("gofmt", ["-w", str(path)])):
        if shutil.which(tool):
            subprocess.run([tool, *args], check=True)
            return
    sys.stderr.write("gen-spec: neither goimports nor gofmt on PATH; skipping Go formatting\n")


# Every YAML top-level key consumed by the emitters. New keys must be added
# here AND wired into both emit_go / emit_dart before the generator accepts
# them — silently ignoring a new YAML block would defeat the gate.
KNOWN_KEYS = {
    "schema_version", "spec_doc",
    "rating", "photos", "review_text", "comment_text",
    "beverage_request", "collection_entry_note", "collection_name",
    "moderation_notes", "search_query", "social_query", "venue_fields",
    "username", "display_name", "bio", "password", "email_verification",
    "pagination", "locales", "soft_delete", "cursor",
    "categories", "default_collections", "purchase_type", "price",
}


def _assert_schema_coverage(data: dict) -> None:
    extra = set(data.keys()) - KNOWN_KEYS
    if extra:
        sys.stderr.write(
            "gen-spec: YAML top-level keys not wired into emitters: "
            + ", ".join(sorted(extra))
            + "\nAdd them to gen-spec.py KNOWN_KEYS and emit_go/emit_dart.\n"
        )
        sys.exit(1)


def main(argv):
    text = SRC.read_text(encoding="utf-8")
    data = _parse_yaml(text)
    _assert_schema_coverage(data)
    GO_OUT.parent.mkdir(parents=True, exist_ok=True)
    DART_OUT.parent.mkdir(parents=True, exist_ok=True)
    GO_OUT.write_text(emit_go(data), encoding="utf-8")
    DART_OUT.write_text(emit_dart(data), encoding="utf-8")
    _gofmt(GO_OUT)
    print(f"gen-spec: wrote {GO_OUT.relative_to(ROOT)} and {DART_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv)
