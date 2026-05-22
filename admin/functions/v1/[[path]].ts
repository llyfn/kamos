// Cloudflare Pages Function — same-origin proxy for the admin SPA.
//
// The SPA (kamos-admin.pages.dev) and the API (kamos.fly.dev) are different
// registrable domains, so the admin's SameSite=Strict auth cookies cannot
// travel cross-site. This function makes the API same-origin: the browser
// calls kamos-admin.pages.dev/v1/* and we forward to the Fly API, relaying
// Cookie (request) and Set-Cookie (response) verbatim. Cookies are then
// first-party on pages.dev and SameSite=Strict keeps working — no security
// downgrade, no third-party-cookie fragility.
//
// Wrangler compiles admin/functions/ at `pages deploy`; this catch-all owns
// every /v1/* path, taking precedence over the SPA's index.html fallback.

const API_ORIGIN = 'https://kamos.fly.dev';

// PagesFunction is provided by the Workers runtime; type loosely so the file
// needs no @cloudflare/workers-types dependency (it is outside the tsc/biome
// scope and compiled separately by Wrangler).
export async function onRequest(context: { request: Request }): Promise<Response> {
  const { request } = context;
  const url = new URL(request.url);
  const target = API_ORIGIN + url.pathname + url.search;

  // Clone to the upstream origin, preserving method, headers, and body.
  // Drop Host so fetch derives it from the target URL (Fly routes by Host/SNI).
  const proxied = new Request(target, request);
  proxied.headers.delete('host');

  const resp = await fetch(proxied, { redirect: 'manual' });

  // new Response(body, resp) preserves status + all headers, including the
  // multiple Set-Cookie headers the auth endpoints emit.
  return new Response(resp.body, resp);
}
