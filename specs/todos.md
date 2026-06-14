# Bastion: TODO List

**Updated**: 2026-03-31

Derived from [open-questions.md](open-questions.md), the individual spec files, and current `lib/` state. See [features.md](features.md) for broader feature status.

---

## Next Up

The most impactful unblocked work. These are preconditions for most other features.

- [x] ~~**`~H` triple-quoted sigil**~~ — **Not a blocker.** `read_triple_string` in the lexer returns the same `STRING` token as regular strings; the existing `SIGIL_PREFIX STRING` parser rule already handles `~H"""..."""`. No fix needed.
- [x] **`.march.spans` sidecar support** (March compiler) — **Already in compiler.** `lib/ast/span_remap.ml` loads the `.march.spans` sidecar, parses tab-separated gen→orig mappings, and remaps all AST spans before error reporting. `main.ml` calls it automatically. No Bastion work needed.
- [x] ~~**`[preprocessors]` hook in forge**~~ — Already in `forge.toml` as `[preprocessors] ".march.html" = "bastion lower"`.
- [x] ~~**`bastion lower` CLI subcommand**~~ — Implemented in `lib/forge/lower.march`.
- [x] ~~**`Html` runtime module**~~ — Implemented in `lib/html.march`.
- [x] ~~**`IOList` runtime module**~~ — provided by the stdlib `IOList` module (no Bastion-local file; used directly, e.g. in `csrf.march` / `forge/lower.march`).
- [x] ~~**`Css.style/1` helper**~~ — Implemented in `lib/css.march`.
- [x] **Islands data flow implementation** — `lib/island_server.march` (`Bastion.IslandServer`): `push/2`, `push_from/3`, `subscriber_count/1`, `has_subscribers/1`; `IslandSocket` wired to `Bastion.PubSub`: `init`+channel subscribes instance, `destroy` unsubscribes, WS close calls `PubSub.unsubscribe_all`; `channel_push` forwarded to PubSub (LWW sync); JS `init` message now carries `channel` field; `Bastion.IslandServer.push/2` fans out to all connected instances via PubSub.
- [x] **Kill `window.marchIslands.send` global bus** — The rewritten `march-islands.js` never exposed a global send bus; `window.__bastionIslands` is debug-only. Parent-child dispatch and channel push are the only send paths.
- [x] **Channel server implementation** — `lib/pubsub.march` (`Bastion.PubSub`), `lib/channel.march` (`Bastion.Channel`), `lib/channel_server.march` (`Bastion.ChannelServer`), `lib/test_channel.march` (`Bastion.Test.Channel`); Vault-backed PubSub, multiplexed topic WS loop, join/leave/handle_in dispatch, test interception helpers.
- [ ] **Auth/session/database stack** — See [auth-session-database.md](auth-session-database.md) for the full sequenced plan, API design, error handling, security checklist, and end-to-end example. Build in this order:
  - [x] Step 0: Conn prerequisites — `get_req_cookie`, `put_resp_cookie`, `delete_resp_cookie`, `register_after_send`, `get_form_param` added to `lib/conn.march`
  - [x] Step 0b: Wire `Conn.after_send_hooks` dispatch in `bastion_server.march`; call `Session.commit_from_conn` for "session_commit" hook
  - [x] Step 1: `lib/crypto.march` — wraps stdlib `Crypto`; adds `hmac_sha256/2`, `derive_key/2`, `generate_token/1`, `bytes_to_string/1`; note: AES-256-GCM still deferred pending runtime builtins; HKDF-SHA256 is now implemented in `lib/security/hkdf.march` and used by `Crypto.derive_key`
  - [x] Step 1b: Upgrade `session.march` crypto — replace `stub_hmac` with `Crypto.hmac_sha256` + `Crypto.derive_key`; fix `base64_decode` to handle `Ok(Bytes)`; use `Crypto.secure_compare`
  - [x] Step 2: Add Depot as a `[deps]` entry in Bastion's `forge.toml` — `depot = { git = "https://github.com/march-language/depot.git", branch = "main" }`
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
- [x] Route helpers — `forge bastion.routes --gen` writes `lib/<app>_routes.march` with typed path helpers (`root_path`, `users_path`, `user_path(id)`, etc.); singularizes last literal segment before a param; deduplicates by path. Compile-time verification of helper calls requires compiler integration (still pending).
- [x] **CSP nonce auto-injection** — `inject_csp_nonces/1` in `lib/forge/lower.march`; every `<script>` and `<style>` opening tag in `.march.html` templates gets `nonce="${BastionCSP.nonce(conn)}"` injected before the closing `>` unless already present; follows same CSRF-injection convention (assumes `conn` in scope); inline `~H` in `.march` files would need a parallel `desugar.ml` change (deferred)
- [ ] Island prop serialization — decide JSON vs binary fast-path for large datasets ([open-questions.md](open-questions.md) §3)
- [ ] Island WASM hot-swap in dev without state loss ([open-questions.md](open-questions.md) §4)

### WASM / Islands
- [x] Deferred hydration strategies in `march-islands.js` — `data-march-hydrate="lazy|idle|interaction|on-visible"`; `_hydrateOne(el)` extracted from discoverIslands; `_scheduleHydration(el, strategy)` dispatches to: `lazy` (window load event or setTimeout), `idle` (requestIdleCallback + Safari fallback), `interaction` (once/capture on click/focus/keypress/touch/pointer), `on-visible` (shared IntersectionObserver with 10% threshold)
- [x] Wire `march_island_msg_from_name` in `wasm-bridge.js` — `_buildMsgPtr()` uses `march_island_msg_from_name(ptr, len)` for zero-field enum messages (plain string or `{tag: "Name"}`); falls back to JSON string for payloaded messages or when export is absent
- [ ] End-to-end island integration test — compile a simple island to WASM, serve it, verify hydration and state update round-trip in a browser
- [x] `forge gen.island` generator — `lib/forge/gen_island.march`; generates `@island` module stub in `lib/islands/<name>.march`; `--server` flag generates server-handler stub; `--compile` flag builds WASM immediately; updates `priv/static/islands/manifest.json`
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
- [x] **`~H` template component system** — `<.Component />` (self-closing) and `<.Component attr={x}>inner</.Component>` (with inner content) in `lib/forge/lower.march`; self-closing → `Component.render(attrs)`; with-content → `Component.render(attrs, render_inner: fn -> ~H"""...""" end)`; named slots `<:slot>...</:slot>` → `render_<slot>: fn -> ~H"""...""" end`; inner ~H captures ambient vars via closure; nested components handled
- [ ] `~CSS` scoped island CSS ([css-styling.md](css-styling.md))
- [ ] CSS variables / theming conventions ([css-styling.md](css-styling.md))

### JS Interop
- [x] `Cmd` abstraction layer for WASM → JS calls — `lib/cmd.march`: `Bastion.Cmd` type + constructors (`none`, `batch`, `http_get`, `http_post`, `after`, `every`, `focus`, `blur`, `push_url`, `replace_url`, `store_local`, `load_local`, `remove_local`, `channel_push`, `map`); JSON envelope spec documented; requires `march_island_update_cmd`/`march_island_last_cmd` WASM exports from compiler
- [x] Built-in `Cmd` implementations: `window.*`, DOM manipulation, `fetch`, `localStorage` — `executeCmd(instance, cmd)` in `march-islands.js` handles all built-in tags; wired into `IslandInstance.dispatch()` via `updateWithCmd()`; `wasm-bridge.js` `WasmIslandModule.updateWithCmd()` reads cmd JSON via `march_island_last_cmd` sidecar export
- [x] JS FFI layer (WASM → browser) — `lib/js.march`: `Bastion.JS` with `call`, `global`, `eval`, `query_selector`, DOM attribute helpers, value converters; `extern "bastion" "js_*"` declarations; `wasm-bridge.js` handle table + late-bound memory reference wires up the `bastion` import namespace
- [x] JS → WASM message protocol (JSON envelope) — `window.Bastion.getIsland(name)` returns `IslandHandle` with `.send(msg)`, `.getState()`, `.all()`; `Bastion.onDispatch(name, cb)` observer; wired in `march-islands.js` `dispatch()` hook

### Developer Experience
- [x] `forge dev` live reload — `lib/dev.march`: `Bastion.Dev.live_reload` plug serves `/_bastion/reload` WebSocket (drop on restart triggers browser reload) + `/_bastion/live-reload.js` client; `live_reload_tag()` returns script tag for layouts; `dev_env?()` detects MARCH_ENV
- [x] **Dev error overlay + crash REPL** — `lib/error_overlay.march` (`Bastion.ErrorOverlay`): `rescue_errors/1` plug wraps pipeline via `HttpServer.try_call/1`; on panic stores crash context (conn, params, assigns, error) in Vault with 1hr TTL; renders HTML error page with stack trace, request info, and in-browser crash REPL terminal; `/_bastion/debug/:session_id` WebSocket serves a `March.Repl` session with crash bindings injected; history navigation (↑/↓); `router_plug/1` mounts the WebSocket + info endpoint (dev only)
- [x] Hot deploy / connection draining — `lib/health.march`: `Bastion.Health.plug` serves `GET /health`; `start_drain()`/`draining?()` Vault-backed drain flag; `plug_with_checks/2` runs custom probes; 503 on drain
- [x] `forge dev` dashboard — `lib/metrics.march` (`Bastion.Metrics`): `instrument/1` timing wrapper + `record/1` plug, `summary()`, Vault ring buffer; `lib/dev.march` extended with `dashboard` plug serving `/_bastion` HTML page with request stats and recent request log
- [ ] Embedded asset size limits — determine threshold for `--embed-assets` ([open-questions.md](open-questions.md) §8)

### Generators
- [x] **`forge bastion.console`** — `lib/forge/console.march` (`Forge.Console`); starts March REPL with app supervision tree loaded (Vault tables + Depot pool); `--server` flag starts HTTP server alongside; auto-imports from `[console] imports` in `forge.toml`; prompt `iex(app_name)>` with history; pre-injects `conn` (test conn), Vault, PubSub, Metrics; blocks until `:quit` or Ctrl+C
- [x] `forge gen.handler` — `lib/forge/gen_handler.march`; generates handler module with CRUD action stubs + route snippet
- [x] `forge gen.context` — `lib/forge/gen_context.march`; generates schema + context CRUD API + migration from field spec (`name:string email:string`)
- [x] `forge gen.channel` — `lib/forge/gen_channel.march`; generates channel handler stub
- [x] `forge gen.migration` — `lib/forge/gen_migration.march`; generates timestamped migration stub

### Testing
- [x] Channel testing helpers — `lib/test_channel.march`: `join/3`, `push/4`, `intercept/1`, `assert_broadcast/3`, `refute_broadcast/3`, `captured_broadcasts/1`, `assert_assign/3`
- [x] HTTP test conn builder — `lib/test_conn.march`: `build_conn/2,3`; `put_req_header/body/cookie`, `put_query_params`; `authenticate_as`, `with_api_token`; `assert_status`, `assert_header`, `assert_html_contains`, `assert_redirected_to`, `assert_json`; requires `HttpServer.test_conn/2` stdlib primitive
- [ ] Island integration tests (SSR + update, no WASM) ([testing.md](testing.md))

### Operations
- [x] `forge bastion.release` — `lib/forge/release.march`; builds binary (release mode), compiles WASM islands, copies static assets to `_build/release/<name>/`; `--embed-assets` embeds statics into binary; `--dockerfile` generates Dockerfile with health-check; `--clean` wipes release dir first; warns if `SECRET_KEY_BASE` unset
- [x] **Deployment guide** — `specs/deployment-guide.md`; covers Fly.io (Dockerfile + fly.toml + `release_command` migration hook + fly secrets) and bare VPS (systemd + nginx + env file + `ExecStartPre` migration hook + zero-downtime deploy script); recommends `--embed-assets` single binary; multi-node distributed Vault/PubSub noted as TODO
- [x] Structured logging + request ID propagation — `lib/logger.march`: `Logger.debug/info/warn/error(msg, meta)` + `*_conn` helpers; human format (dev) vs JSON (prod) via MARCH_ENV; `Middleware.request_id` upgraded to use `Crypto.generate_token(16)` + set `x-request-id` response header; `Middleware.logger` uses `Logger.info`
- [x] Telemetry events — `lib/telemetry.march`: `Bastion.Telemetry.attach/3`, `detach/1`, `execute/3`; `span/3` (emits start/stop events around a fn, measures duration_ms); `request_start/1`, `request_stop/2`; Vault-backed handler registry; prefix-match subscriptions (["bastion","request"] matches all sub-events)
- [x] Multipart upload middleware — `lib/upload.march`: `Bastion.Upload.parse_conn/2` + `parse/3`; boundary extraction from Content-Type; part splitting; header/Content-Disposition parsing; `UploadedFile`/`UploadOpts`/`UploadError` types; `default_opts`, `error_message`

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
