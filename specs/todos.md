# Bastion: TODO List

**Updated**: 2026-03-31

Derived from [open-questions.md](open-questions.md), the individual spec files, and current `lib/` state. See [features.md](features.md) for broader feature status.

---

## Next Up

The most impactful unblocked work. These are preconditions for most other features.

- [x] ~~**`~H` triple-quoted sigil**~~ — **Not a blocker.** `read_triple_string` in the lexer returns the same `STRING` token as regular strings; the existing `SIGIL_PREFIX STRING` parser rule already handles `~H"""..."""`. No fix needed.
- [ ] **`.march.spans` sidecar support** (March compiler) — Accept a span-override sidecar file alongside a `.march` source so the lowering pass can map generated node positions back to `.march.html` line/col. Errors then report positions in the original template file. See [template-file-format.md](template-file-format.md) §Layer 1b.
- [x] ~~**`[preprocessors]` hook in forge**~~ — Already in `forge.toml` as `[preprocessors] ".march.html" = "bastion lower"`.
- [x] ~~**`bastion lower` CLI subcommand**~~ — Implemented in `lib/forge/lower.march`.
- [x] ~~**`Html` runtime module**~~ — Implemented in `lib/html.march`.
- [x] ~~**`IOList` runtime module**~~ — Implemented in `lib/io_list.march`.
- [x] ~~**`Css.style/1` helper**~~ — Implemented in `lib/css.march`.
- [ ] **Islands data flow implementation** — Implement the `Server` / `Client` dataflow modes, parent-child prop binding, and explicit event dispatch as specced in [islands-data-flow.md](islands-data-flow.md). Depends on `~H` for template rendering in islands.
- [ ] **Kill `window.marchIslands.send` global bus** — Replace with the parent-child dispatch model from [islands-data-flow.md](islands-data-flow.md). See wasm-islands.md current design.
- [x] **Channel server implementation** — `lib/pubsub.march` (`Bastion.PubSub`), `lib/channel.march` (`Bastion.Channel`), `lib/channel_server.march` (`Bastion.ChannelServer`), `lib/test_channel.march` (`Bastion.Test.Channel`); Vault-backed PubSub, multiplexed topic WS loop, join/leave/handle_in dispatch, test interception helpers.
- [ ] **Auth/session/database stack** — See [auth-session-database.md](auth-session-database.md) for the full sequenced plan, API design, error handling, security checklist, and end-to-end example. Build in this order:
  - [x] Step 0: Conn prerequisites — `get_req_cookie`, `put_resp_cookie`, `delete_resp_cookie`, `register_after_send`, `get_form_param` added to `lib/conn.march`
  - [x] Step 0b: Wire `Conn.after_send_hooks` dispatch in `bastion_server.march`; call `Session.commit_from_conn` for "session_commit" hook
  - [x] Step 1: `lib/crypto.march` — wraps stdlib `Crypto`; adds `hmac_sha256/2`, `derive_key/2`, `generate_token/1`, `bytes_to_string/1`; note: AES-256-GCM and true HKDF deferred pending runtime builtins
  - [x] Step 1b: Upgrade `session.march` crypto — replace `stub_hmac` with `Crypto.hmac_sha256` + `Crypto.derive_key`; fix `base64_decode` to handle `Ok(Bytes)`; use `Crypto.secure_compare`
  - [x] Step 2: Add Depot as a `[deps]` entry in Bastion's `forge.toml` — `depot = { path = "/Users/80197052/code/depot" }`
  - [x] Step 2b: `lib/depot_middleware.march` — `with_pool` checks out conn + registers "pool_checkin" hook; `get_conn`, `get_pool`, `checkin_from_conn`; BastionServer now dispatches "pool_checkin" → `Depot.Middleware.checkin_from_conn`
  - [x] Step 2c: Wire `Depot.Query` SQL generation — extended Query type with `sql_conds` 7th field; `where_eq/ne/gt/lt/gte/lte/like/ilike/is_null/is_not_null`; `to_sql/1`, `to_params/1`, `exec_sql/2` (exec_prepared + zip cols), `count_sql/2`
  - [x] Step 3: `lib/session.march` — cookie session API complete; real HMAC-SHA256 signing via `Crypto.hmac_sha256` + derived key
  - [x] Step 4: `lib/flash.march` — `put`, `get`, `loaded_flashes`, `clear`, `delete`; `Form.FlashGroup` component
  - [x] Step 5: `lib/csrf.march` — token generation uses `Crypto.generate_token(32)`; validation uses `Crypto.secure_compare`
  - [x] Step 6: `lib/auth_middleware.march` — `load_current_user` (+ remember-me variant), `require_auth`, `authenticated`, `log_in` (with optional remember-me cookie), `log_out`, `current_user`, `redirect_after_login`; wraps `Session`+`Conn`+`Crypto`
  - [x] Step 7: `lib/vault.march` — wraps stdlib `Vault`; Bastion naming (`put`/`delete`/`open`); adds `put_new` (atomic insert-if-absent), `put_ttl`, `ns_*` helpers
  - [x] Step 8: `lib/rate_limit.march` — sliding window counter in Vault; `check/5` returns `Ok(conn)|Error(conn)`; `limit/5` pipeline helper; `ip_key` built-in; `x-ratelimit-*` + `retry-after` headers; 429 on exceed
  - [x] Step 9: `forge depot.migrate` / `forge depot.rollback` wired in Bastion — `lib/forge/depot_migrate.march`, `depot_rollback.march`, `depot_migrations.march`, `depot_reset.march` wrap `CmdDepot.*`; registered in `forge.toml` as `bastion.depot.migrate/rollback/migrations/reset`
  - [x] Step 10: `forge gen.auth session` generator — `lib/forge/gen_auth.march`; generates users+user_tokens migrations, Accounts context, Auth middleware, Registration/Session/Settings/Confirmation/PasswordReset controllers with rate limiting (RateLimit.check on login/register/reset), AccountsFixtures test support; router route hints printed on run
  - [x] Step 11: `Bastion.Test.Depot.checkout` test sandbox + `Bastion.Test.Auth.log_in_user` helper — `lib/test_depot.march` wraps `Depot.Test` sandbox; `lib/test_auth.march` provides `log_in_user/2`, `log_in_user_with_secret/3`, `logged_in?/1`, `assert_redirects_to_login/2`

---

## Planned

Specced and queued. Roughly priority order within each group.

### Compiler Integration
- [ ] Route helpers + compile-time route verification ([route-verification.md](route-verification.md))
- [ ] CSP nonce auto-injection via `~H` compiler pass ([csp.md](csp.md))
- [ ] Island prop serialization — decide JSON vs binary fast-path for large datasets ([open-questions.md](open-questions.md) §3)
- [ ] Island WASM hot-swap in dev without state loss ([open-questions.md](open-questions.md) §4)

### WASM / Islands
- [x] Deferred hydration strategies in `march-islands.js` — `data-march-hydrate="lazy|idle|interaction|on-visible"`; `_hydrateOne(el)` extracted from discoverIslands; `_scheduleHydration(el, strategy)` dispatches to: `lazy` (window load event or setTimeout), `idle` (requestIdleCallback + Safari fallback), `interaction` (once/capture on click/focus/keypress/touch/pointer), `on-visible` (shared IntersectionObserver with 10% threshold)
- [x] Wire `march_island_msg_from_name` in `wasm-bridge.js` — `_buildMsgPtr()` uses `march_island_msg_from_name(ptr, len)` for zero-field enum messages (plain string or `{tag: "Name"}`); falls back to JSON string for payloaded messages or when export is absent
- [ ] End-to-end island integration test — compile a simple island to WASM, serve it, verify hydration and state update round-trip in a browser
- [ ] `forge gen.island` generator
- [ ] WASM actor runtime — green threads / mailboxes in WASM target. Decide: per-island instance or shared cooperative scheduling ([open-questions.md](open-questions.md) §5) — post-v1

### Auth, Security & Storage
- [x] Security headers middleware — `lib/security_headers.march`; `SecurityHeaders.defaults/1` (x-frame-options, x-content-type-options, x-xss-protection, referrer-policy, permissions-policy, COOP, COEP); `hsts/2`; `csp_base/1`, `csp_with_ws/2`
- [x] CORS middleware — `lib/cors.march`; `Cors.allow/2` with `CorsConfig` record; `config/1`, `config_open/0`, `config_credentialed/1`; handles preflight (OPTIONS) and credentialed requests
- [ ] `forge gen.auth token / oauth / magic_link` — post-v1 auth strategies ([auth.md](auth.md))
- [x] Vault full API — added `get_and_delete/2` (atomic read+remove), `select/2` (filter all entries by predicate), `clear/1` (empty table); core `put/get/delete/put_new/update/has/size/keys/all/ns_*` already complete
- [ ] Vault/Depot session backends — alternative to cookie sessions ([auth-session-database.md](auth-session-database.md))
- [x] HTTP ETag + response caching — `lib/cache.march`; `Cache.etag_from/2` (SHA-256 + 304 short-circuit), `Cache.etag/2` (explicit tag), `Cache.cache_control/2`, `Cache.cached/4` (Vault-backed full response cache), `Cache.invalidate/1`, `Cache.invalidate_prefix/1`
- [x] Fragment caching — `lib/cache.march`; `Cache.fragment/3` (Vault-backed string fragment cache), `Cache.invalidate_fragment/1`

### Forms
- [x] `Gate` changeset validation — `cast`, `validate_required/format/length/number/inclusion/confirmation`, `add_error`, `error_for` (`lib/gate.march`)
- [x] `Form` render helpers + `Form.Input/Select/Textarea/Field/Error` ~H components (`lib/form.march`)
- [x] `Flash` module + `Form.FlashGroup` component (`lib/flash.march`)
- [x] Cookie helpers on `Conn` — `get_req_cookie`, `put_resp_cookie`, `delete_resp_cookie`, `register_after_send` (`lib/conn.march`)
- [x] `Session` — cookie-backed sessions with auto-commit hook (`lib/session.march`)
- [x] Enhanced form JS — `data-enhance` fetch submit + idiomorph fragment swap (`priv/js/form-enhance.js`)
- [ ] `<.Form>` wrapper component — requires slot/inner content support in lowering pass ([form-handling.md](form-handling.md))

### Templates & Styling
- [ ] `~H` template component system — components as functions, XSS prevention ([templates.md](templates.md))
- [ ] `~CSS` scoped island CSS ([css-styling.md](css-styling.md))
- [ ] CSS variables / theming conventions ([css-styling.md](css-styling.md))

### JS Interop
- [ ] `Cmd` abstraction layer for WASM → JS calls ([js-interop.md](js-interop.md))
- [ ] Built-in `Cmd` implementations: `window.*`, DOM manipulation, `fetch`, `localStorage` ([js-interop.md](js-interop.md))
- [ ] JS → WASM message protocol (JSON envelope) ([js-interop.md](js-interop.md))

### Developer Experience
- [ ] `forge dev` live reload (file watcher + WebSocket notify) ([dev-experience.md](dev-experience.md))
- [ ] Dev error overlay in-browser ([dev-experience.md](dev-experience.md), [error-handling.md](error-handling.md))
- [ ] Hot deploy / connection draining on SIGTERM ([hot-deploy.md](hot-deploy.md))
- [ ] `forge dev` dashboard ([dev-experience.md](dev-experience.md))
- [ ] Embedded asset size limits — determine threshold for `--embed-assets` ([open-questions.md](open-questions.md) §8)

### Generators
- [x] `forge gen.handler` — `lib/forge/gen_handler.march`; generates handler module with CRUD action stubs + route snippet
- [x] `forge gen.context` — `lib/forge/gen_context.march`; generates schema + context CRUD API + migration from field spec (`name:string email:string`)
- [x] `forge gen.channel` — `lib/forge/gen_channel.march`; generates channel handler stub
- [x] `forge gen.migration` — `lib/forge/gen_migration.march`; generates timestamped migration stub

### Testing
- [x] Channel testing helpers — `lib/test_channel.march`: `join/3`, `push/4`, `intercept/1`, `assert_broadcast/3`, `refute_broadcast/3`, `captured_broadcasts/1`, `assert_assign/3`
- [ ] Island integration tests (SSR + update, no WASM) ([testing.md](testing.md))

### Operations
- [ ] Deployment guide — single binary, env config, health checks, graceful shutdown ([deployment.md](deployment.md))
- [x] Structured logging + request ID propagation — `lib/logger.march`: `Logger.debug/info/warn/error(msg, meta)` + `*_conn` helpers; human format (dev) vs JSON (prod) via MARCH_ENV; `Middleware.request_id` upgraded to use `Crypto.generate_token(16)` + set `x-request-id` response header; `Middleware.logger` uses `Logger.info`
- [ ] OpenTelemetry tracing — decide default sample rate ([telemetry.md](telemetry.md), [open-questions.md](open-questions.md) §9)
- [ ] Streaming multipart upload middleware ([uploads.md](uploads.md))

---

## Future / Phase 2+

Deferred. Do not start until v1 is stable.

- [ ] Collaborative islands — CRDT-based multi-client sync, separate sync channel ([islands-data-flow.md](islands-data-flow.md))
- [ ] Bastion.Presence — CRDT-based online user tracking
- [ ] Bastion.LiveDashboard — built-in admin panel
- [ ] Distributed PubSub — cross-node Channel broadcasting
- [ ] Distributed Vault — optional cross-node replication
- [ ] Background job system — persistent queues backed by Depot
- [ ] Static site generation
- [ ] Edge deployment — compile to WASM for Cloudflare Workers
- [ ] i18n — compile-time string extraction
- [ ] Auto-generate TypeScript types from March island types
- [ ] CSP auto-generation from actual resource usage ([open-questions.md](open-questions.md))
- [ ] PubSub system ([pubsub.md](pubsub.md))

---

## Done

- [x] Core conn abstraction (`conn.march`, `conn_states.march`, `request.march`, `response.march`)
- [x] Pattern-matched routing (`router.march`)
- [x] Middleware pipeline (`middleware.march`, `typed_middleware.march`)
- [x] Islands SSR — `Islands.wrap/4`, hydration markers, bootstrap script (`islands.march`, `island_view.march`)
- [x] Island assets + scoped CSS serving (`island_assets.march`, `island_css.march`)
- [x] Island WebSocket glue (`island_socket.march`)
- [x] Static file serving (`static.march`)
- [x] Controller helpers + error views (`controller.march`, `error_view.march`, `fallback_controller.march`)
- [x] Testing conn builder (`test.march`)
- [x] Framework entry + supervisor (`bastion.march`, `bastion_server.march`)
- [x] Islands data flow spec ([islands-data-flow.md](islands-data-flow.md))
- [x] All bastion spec docs ported to this repo
