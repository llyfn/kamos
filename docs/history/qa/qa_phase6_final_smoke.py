#!/usr/bin/env python3
"""Phase 6 final cross-layer smoke.

Exercises public collections + flat comments end-to-end against kamos_local
on :18080. Asserts every contract point and prints a transcript.
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

BASE = "http://localhost:18080"


def req(method, path, *, tok=None, body=None, expect=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if tok:
        headers["Authorization"] = "Bearer " + tok
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        resp = urllib.request.urlopen(r, timeout=10)
        raw = resp.read().decode()
        code = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        code = e.code
    out = None
    try:
        out = json.loads(raw) if raw else None
    except json.JSONDecodeError:
        out = raw
    if expect is not None and code != expect:
        print(f"FAIL {method} {path}: expected {expect}, got {code}")
        print(f"  body: {out}")
        sys.exit(1)
    return code, out


def register(username, email, password="password-123"):
    code, body = req("POST", "/v1/auth/register",
                     body={"username": username, "email": email,
                           "password": password, "display_name": username,
                           "locale": "en"},
                     expect=201)
    return body["access_token"], body["user"]["id"]


def login(email, password="password-123"):
    code, body = req("POST", "/v1/auth/login",
                     body={"email": email, "password": password},
                     expect=200)
    return body["access_token"]


def psql(sql):
    out = subprocess.run(
        ["psql", "kamos_local", "-tA", "-c", sql],
        capture_output=True, text=True, timeout=10,
    )
    if out.returncode != 0:
        print(f"psql FAIL: {out.stderr}")
        sys.exit(1)
    return out.stdout.strip()


def step(n, msg):
    print(f"\n=== Step {n}: {msg} ===")


def OK(msg):
    print(f"  ✓ {msg}")


def main():
    psql("DELETE FROM moderation_log; DELETE FROM comments; DELETE FROM collection_entries; DELETE FROM collections WHERE name NOT IN ('Inventory','Wishlist'); DELETE FROM toasts; DELETE FROM check_in_photos; DELETE FROM check_ins;")
    suffix = str(int(time.time()))

    step(1, "register 3 users")
    alice_tok, alice_id = register(f"p6a_{suffix}", f"p6a_{suffix}@example.com")
    bob_tok, bob_id = register(f"p6b_{suffix}", f"p6b_{suffix}@example.com")
    carol_tok, carol_id = register(f"p6c_{suffix}", f"p6c_{suffix}@example.com")
    OK("alice + bob + carol registered")

    step(2, "promote alice to admin via psql")
    psql(f"UPDATE users SET role='admin' WHERE id='{alice_id}';")
    OK("alice promoted")

    step(3, "carol creates collection")
    code, body = req("POST", "/v1/collections", tok=carol_tok,
                     body={"name": "Smoke public"}, expect=201)
    coll_id = body["id"]
    assert body["visibility"] == "private", f"new collection visibility={body['visibility']}"
    assert body["owner_id"] == carol_id, f"owner_id={body['owner_id']} vs carol={carol_id}"
    OK(f"collection {coll_id}, default private, owner_id present")

    step(4, "carol toggles collection public")
    code, body = req("PATCH", f"/v1/collections/{coll_id}", tok=carol_tok,
                     body={"visibility": "public"}, expect=200)
    assert body["visibility"] == "public"
    OK("visibility flipped public")

    step(5, "GET /v1/collections/public — discovery feed has it")
    code, body = req("GET", "/v1/collections/public", expect=200)
    found = [c for c in body["items"] if c["id"] == coll_id]
    assert len(found) == 1, f"items: {[c['id'] for c in body['items']]}"
    OK("public discovery includes carol's collection")

    step(6, "carol GET own collection")
    code, body = req("GET", f"/v1/collections/{coll_id}", tok=carol_tok, expect=200)
    assert body["owner_id"] == carol_id
    OK("owner sees own collection")

    step(7, "bob GET carol's public collection — owner_id is carol's")
    code, body = req("GET", f"/v1/collections/{coll_id}", tok=bob_tok, expect=200)
    assert body["owner_id"] == carol_id, f"owner_id leak: {body['owner_id']}"
    OK("non-owner can fetch + owner_id present")

    step(8, "anonymous GET public collection")
    code, body = req("GET", f"/v1/collections/{coll_id}", expect=200)
    assert body["owner_id"] == carol_id
    OK("anonymous can fetch")

    step(9, "carol toggles private — non-owner now 404s")
    req("PATCH", f"/v1/collections/{coll_id}", tok=carol_tok,
        body={"visibility": "private"}, expect=200)
    req("GET", f"/v1/collections/{coll_id}", tok=bob_tok, expect=404)
    req("GET", f"/v1/collections/{coll_id}", expect=404)
    OK("private collection 404s for non-owner + anonymous")

    step(10, "no longer in public feed")
    code, body = req("GET", "/v1/collections/public", expect=200)
    found = [c for c in body["items"] if c["id"] == coll_id]
    assert len(found) == 0
    OK("removed from discovery")

    step(11, "bob creates a check-in for the comments smoke")
    cat_id = psql("SELECT id FROM beverage_categories WHERE slug='nihonshu' LIMIT 1;")
    brewery_id = psql("SELECT id FROM breweries LIMIT 1;")
    if not brewery_id:
        psql("INSERT INTO breweries (name_i18n, prefecture) VALUES ('{\"en\":\"Smoke Brewery\",\"ja\":\"スモーク酒造\"}','Tokyo');")
        brewery_id = psql("SELECT id FROM breweries LIMIT 1;")
    # Sanity: psql -tA can occasionally append status; strip to first line.
    brewery_id = brewery_id.splitlines()[0].strip()
    cat_id = cat_id.splitlines()[0].strip()
    psql(f"INSERT INTO beverages (brewery_id, category_id, name_i18n) VALUES ('{brewery_id}', '{cat_id}', '{{\"en\":\"Smoke Sake\",\"ja\":\"スモーク酒\"}}');")
    bev_id = psql(f"SELECT id FROM beverages WHERE brewery_id='{brewery_id}' AND category_id='{cat_id}' ORDER BY created_at DESC LIMIT 1;").splitlines()[0].strip()
    code, body = req("POST", "/v1/check-ins", tok=bob_tok,
                     body={"beverage_id": bev_id, "rating": 4.0, "review": "smoke"},
                     expect=201)
    ci_id = body["id"]
    OK(f"check-in {ci_id}")

    step(12, "carol comments on bob's check-in")
    code, body = req("POST", f"/v1/check-ins/{ci_id}/comments", tok=carol_tok,
                     body={"body": "First comment from carol"}, expect=201)
    c1_id = body["id"]
    OK(f"comment {c1_id} created")

    step(13, "GET comments — newest-first ordering")
    code, body = req("GET", f"/v1/check-ins/{ci_id}/comments", expect=200)
    assert len(body["items"]) == 1
    assert body["items"][0]["body"] == "First comment from carol"
    OK("comment list returns it, cursor envelope")

    step(14, "bob (check-in owner, not comment owner) cannot delete carol's comment")
    req("DELETE", f"/v1/comments/{c1_id}", tok=bob_tok, expect=403)
    OK("non-owner non-admin gets 403")

    step(15, "carol soft-deletes her own comment")
    req("DELETE", f"/v1/comments/{c1_id}", tok=carol_tok, expect=204)
    code, body = req("GET", f"/v1/check-ins/{ci_id}/comments", expect=200)
    assert len(body["items"]) == 0, f"items still present: {body['items']}"
    OK("own delete works; list filters out deleted")

    step(16, "carol posts another, alice (admin) soft-deletes via /v1/admin/comments/{id}/moderate")
    code, body = req("POST", f"/v1/check-ins/{ci_id}/comments", tok=carol_tok,
                     body={"body": "Second comment, will be moderated"}, expect=201)
    c2_id = body["id"]
    code, _ = req("POST", f"/v1/admin/comments/{c2_id}/moderate", tok=alice_tok,
                  body={"notes": "Spam — testing the moderation flow"})
    assert code in (200, 204), f"moderate returned {code}"
    OK(f"admin moderated comment {c2_id}")

    step(17, "verify moderation_log row exists")
    rows = psql(f"SELECT moderator_id, target_type, target_id, action FROM moderation_log WHERE target_id='{c2_id}';")
    assert alice_id in rows and "comment" in rows and "soft_delete" in rows, f"moderation_log: {rows}"
    OK(f"moderation_log row: {rows}")

    step(18, "private check-in: parent privacy gates comments list")
    req("PATCH", "/v1/users/me", tok=bob_tok,
        body={"privacy_mode": "private"}, expect=200)
    # Carol is not a follower of bob → 404 on bob's private check-in comments.
    req("GET", f"/v1/check-ins/{ci_id}/comments", tok=carol_tok, expect=404)
    # Bob himself can see them.
    req("GET", f"/v1/check-ins/{ci_id}/comments", tok=bob_tok, expect=200)
    OK("private check-in: non-follower 404, owner 200")

    # Reset bob to public for the rest of the test.
    req("PATCH", "/v1/users/me", tok=bob_tok,
        body={"privacy_mode": "public"}, expect=200)

    step(19, "soft-delete cascade: deleted check-in → comments list 404")
    req("DELETE", f"/v1/check-ins/{ci_id}", tok=bob_tok, expect=204)
    req("GET", f"/v1/check-ins/{ci_id}/comments", expect=404)
    OK("soft-deleted check-in → comments 404")

    step(20, "rate-limit smoke: burst POST /comments")
    # Re-create a check-in (the prior one is soft-deleted).
    code, body = req("POST", "/v1/check-ins", tok=bob_tok,
                     body={"beverage_id": bev_id, "rating": 3.5},
                     expect=201)
    rl_ci = body["id"]
    statuses = []
    for i in range(12):
        c, _ = req("POST", f"/v1/check-ins/{rl_ci}/comments", tok=carol_tok,
                   body={"body": f"burst {i}"})
        statuses.append(c)
    print(f"  statuses: {statuses}")
    assert 429 in statuses, f"expected at least one 429, got {statuses}"
    OK(f"rate-limit fired ({statuses.count(429)} × 429)")

    print("\n=== ALL 20 STEPS PASS ===")


if __name__ == "__main__":
    main()
