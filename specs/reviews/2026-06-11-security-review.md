# Security Review — 2026-06-11

Scope: framework core (`lib/`) — crypto, csrf, session, auth, security_headers,
csp, cors, rate_limit, upload, static, request, router, error views.
Produced by a read-only review agent; verify line numbers before fixing.

## Critical

1. **Rate limiter keying spoofable via `X-Forwarded-For`** — `lib/rate_limit.march:60-73`.
   `ip_key()` trusts the leftmost XFF hop unconditionally. Direct-to-internet
   deployments can bypass limits entirely. Fix: only consult XFF when a
   `trusted_proxies` option is configured; default to peer address.
2. **Session cookie missing `Secure` flag** — `lib/session.march:163`.
   Spec (specs/cookies.md) says Secure defaults on in prod; code hardcodes
   `Path/HttpOnly/SameSite=Lax` only. Fix: env-gated `Secure` attribute.
3. **Weak key derivation** — `lib/crypto.march:191`. `derive_key` is
   `sha256(secret ++ ":" ++ context)`; should be HKDF-SHA256 (or at minimum a
   structured, versioned derivation) so derived keys are independent.

## High

4. **Static path traversal check order** — `lib/static.march:81-88`. `..`
   check runs before/without percent-decoding; `%2e%2e` can slip through.
   Correct order: url-decode → normalize → reject `..`/backslash → join root.
5. **Error overlay lacks runtime prod guard** — `lib/error_overlay.march:53-69`.
   `/_bastion/debug/` plug relies on docs ("never use in production") instead
   of a `dev_env?` gate.
6. **Remember-me re-establishment doesn't rewrite session** — `lib/auth_middleware.march:119-130`.
   Valid remember-token logs user in without persisting a fresh session, so
   every request re-authenticates via the long-lived token.
7. **CSP `wasm-unsafe-eval` breadth** — `lib/bastion_csp.march:39`. Required
   for islands, but document the trade-off; consider `strict-dynamic`.

## Medium

8. CSRF form token not URL-decoded before compare — `lib/csrf.march:132-147`.
9. Query/body params never URL-decoded — `lib/request.march:100-127` (affects
   validation consistency everywhere).
10. `escape_html` private to error_view — export a single canonical escaper.
11. CORS reflects `Origin` without format validation — `lib/cors.march:132-147`.
12. Session user-id parse failure is silent — `lib/auth_middleware.march:82-84`; log it.
13. Signed-cookie format uses `.` delimiter + no length validation — `lib/session.march:256-259`.

## Low

14. Upload filenames unsanitized in error messages — `lib/upload.march:283`.
15. Rate-limit reset math assumes ms timestamps — `lib/rate_limit.march:113-117`.
16. `assign_nonce` not idempotent — `lib/bastion_csp.march:131`.
17. Unmatched routes not logged — `lib/router.march:174`.
18. Dev dashboard `/_bastion` has no origin/dev gate — `lib/dev.march:203-210`.

## Done right (keep)

- Constant-time `secure_compare` (crypto.march) used for CSRF/session checks.
- Auto-escaping by default + opaque `Html.Safe` type for trusted fragments.
- Segment-wise `..` rejection incl. backslashes in static serving.
- Session cleared on login (fixation defense).
- CORS off by default, wildcard+credentials rejected.
- 32-byte random CSRF tokens, per-session.
- Default security-header suite; 1MB default body limit; Vault TTLs bound
  rate-limiter memory; upload MIME whitelisting.
