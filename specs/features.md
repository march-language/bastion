# Bastion: Feature Status

**Updated**: 2026-04-15

This document tracks the implementation status of every Bastion feature area. Use it to understand what's ready, what's specced but not built, and what's deferred to later phases.

---

## Implemented

These features have corresponding code in `lib/` and are usable today (within the limits of the March compiler's current maturity).

| Feature | Files | Notes |
|---------|-------|-------|
| HTTP conn abstraction | `conn.march`, `conn_states.march` | Typed conn with state machine for request lifecycle |
| Request/response | `request.march`, `response.march` | Parsing and building HTTP messages |
| Pattern-matched routing | `router.march` | Route on method + path segments via function heads |
| Middleware pipeline | `middleware.march`, `typed_middleware.march` | Typed pipeline, conn state transitions tracked |
| Islands SSR | `islands.march`, `island_view.march` | `Islands.wrap/4`, hydration markers, bootstrap script |
| Island assets | `island_assets.march`, `island_css.march` | Asset serving and scoped CSS for islands |
| Island WebSocket glue | `island_socket.march` | Channel connection for island-to-server communication |
| Static file serving | `static.march` | Serves `priv/static/`, content-hash URLs |
| Controller helpers | `controller.march` | Render, redirect, send_resp, assign |
| Error views | `error_view.march`, `fallback_controller.march` | Default error pages, custom error handling |
| Testing support | `test.march` | Conn builder, request helpers for test assertions |
| Framework entry point | `bastion.march`, `bastion_server.march` | App startup, supervisor tree |
| Html safety primitives | `html.march` | `Safe` type, `escape/1`, `safe/1`, auto-escape helpers for templates |
| IOList extensions | `io_list.march` | `from_strings/1`, `append/2`, `concat/1` for template assembly |
| CSS style builder | `css.march` | `Css.style/1` — conditional inline styles from property/value pairs |
| Template lowering CLI | `forge/lower.march` | `bastion lower` — .march.html → .march + .march.spans |
| Gate validation | `gate.march` | Changeset-style form validation: `cast`, `validate_required/format/length/number/inclusion/confirmation`, `unique_constraint`, `add_error`, `error_for` |
| Form rendering | `form.march` | Low-level tag builders + `Form.Input/Select/Textarea/Field/Error` ~H components; reads value/error from Gate |
| Flash messages | `flash.march` | `Flash.put/get/loaded_flashes/clear/delete`; `Form.FlashGroup` ~H component; session-backed across redirects |
| Cookie helpers | `conn.march` | `get_req_cookie`, `put_resp_cookie`, `delete_resp_cookie`, `register_after_send`, `get_form_param` |
| Cookie sessions | `session.march` | HMAC-SHA256-signed cookie session: `load`, `get/put/delete/clear`, `commit`, `persist`; auto-commit via after-send hook; derived signing key via `Crypto.derive_key` |
| CSRF protection | `csrf.march` | Per-session token, `protect`/`ensure_token`/`skip`/`tag`; tokens from `Crypto.generate_token`; constant-time compare via `Crypto.secure_compare` |
| Crypto primitives | `crypto.march` | Wraps stdlib `Crypto`: `hmac_sha256`, `derive_key`, `generate_token`, `hash_password`, `verify_password`, `secure_compare`, `bytes_to_string`, Base64 helpers |
| After-send hooks | `bastion_server.march` | `run_after_send` + `dispatch_hook` wired in server plug; "session_commit" hook calls `Session.commit_from_conn` |
| Auth middleware | `auth_middleware.march` | `load_current_user/2` + `load_current_user_with_remember/3`; `require_auth` (redirects to /login); `authenticated` sugar; `log_in` with optional remember-me cookie; `log_out` with optional token deleter; `redirect_after_login` |
| Vault | `vault.march` | Wraps stdlib Vault: `open`, `put`, `put_ttl`, `get`, `get_or`, `delete`, `has`, `put_new` (atomic insert-if-absent), `update`, `size`, `keys`, `all`, `ns_*` helpers |
| Rate limiting | `rate_limit.march` | Sliding window via Vault; `check/5` → `Ok|Error`; `limit/5` pipeline helper; `ip_key`; `x-ratelimit-*` + `retry-after` headers; 429 on exceed |
| Depot integration | `depot_middleware.march`, `forge.toml` | Depot declared as dep; `with_pool` checks out conn + registers "pool_checkin" hook; `get_conn`/`get_pool`; auto-checkin after send |
| Depot SQL queries | Depot repo `depot_query.march` | `where_eq/ne/gt/lt/gte/lte/like/ilike/is_null/is_not_null`; `to_sql`/`to_params`; `exec_sql` (exec_prepared + row→assoc-list); `count_sql` |
| Depot migration CLI | `forge/depot_migrate.march`, `depot_rollback.march`, `depot_migrations.march`, `depot_reset.march` | `forge bastion.depot.migrate/rollback/migrations/reset` — thin wrappers over `CmdDepot.*` from Depot lib; migration files in `priv/depot/migrations/`, log in `.march/depot/migrations.log` |
| Auth scaffold generator | `forge/gen_auth.march` | `forge bastion.gen.auth` — generates Users+UserTokens migrations, Accounts context, Auth middleware, Registration/Session/Settings/Confirmation/PasswordReset controllers (with `RateLimit.check` on login/register/reset), AccountsFixtures; prints router wiring instructions |
| Context generator | `forge/gen_context.march` | `forge bastion.gen.context <Context> <Schema> <table> [field:type …]` — schema + Gate + CRUD context module + migration from field spec |
| HTTP caching | `cache.march` | `Cache.etag_from/2` (SHA-256, 304 short-circuit), `Cache.etag/2`, `Cache.cache_control/2`, `Cache.cached/4` (Vault-backed response cache), `Cache.fragment/3` (Vault fragment cache), `Cache.invalidate/1`, `Cache.invalidate_prefix/1`, `Cache.invalidate_fragment/1` |
| Vault full API | `vault.march` | Added `get_and_delete/2` (atomic read+remove), `select/2` (filter entries by predicate), `clear/1` (empty table) to existing core API |
| Test depot sandbox | `test_depot.march` | `Bastion.Test.Depot` — wraps `Depot.Test`; `start_sandbox`, `checkout(tables)`, `checkin`, `sandboxed(tables, fn)`, `stop_sandbox`; per-test Vault rollback |
| Test auth helpers | `test_auth.march` | `Bastion.Test.Auth` — `log_in_user/2`, `log_in_user_with_secret/3`, `logged_in?/1`, `assert_redirects_to_login/2`; injects session into test conn |
| Security headers | `security_headers.march` | `SecurityHeaders.defaults/1` — x-frame-options, x-content-type-options, x-xss-protection, referrer-policy, permissions-policy, COOP, COEP; `hsts/2`; `csp_base/1`, `csp_with_ws/2`; individual overrides |
| CORS middleware | `cors.march` | `Cors.allow/2` + `CorsConfig` record; `config/1`, `config_open/0`, `config_credentialed/1`; handles preflight (OPTIONS), origin matching, vary header, credentials |
| Deferred island hydration | `priv/js/march-islands.js` | `data-march-hydrate` strategies: `lazy` (window load), `idle` (requestIdleCallback), `interaction` (first click/focus/key), `on-visible` (IntersectionObserver 10%); `_hydrateOne` + `_scheduleHydration` refactor |
| WASM msg fast path | `priv/js/wasm-bridge.js` | `_buildMsgPtr()` uses `march_island_msg_from_name` for zero-field enum messages (plain string / `{tag:…}`); JSON fallback for payloaded variants or missing export |
| Structured logging | `logger.march` | `Logger.debug/info/warn/error(msg, meta)` + `*_conn/3` helpers; human format `HH:MM:SS.mmm [level] msg  k=v` (dev) or JSON one-liner (prod) via MARCH_ENV |
| Request ID middleware | `middleware.march` | `Middleware.request_id` upgraded: `Crypto.generate_token(16)` for new IDs, echoes `x-request-id` response header; `Middleware.logger` uses `Logger.info` with request_id in meta |
| Enhanced form JS | `priv/js/form-enhance.js` | `data-enhance` attribute intercepts POST → fetch; morphs response fragment; follows redirects as full-page nav |
| PubSub | `pubsub.march` | `Bastion.PubSub`: `subscribe`, `unsubscribe`, `unsubscribe_all`, `broadcast`, `broadcast_from`; Vault-backed send_fn registry; inline delivery |
| Channel connection | `channel.march` | `Bastion.Channel`: `ChannelConn` type; `assign`, `get_assign`, `push`, `broadcast_from`, `sub_id`; used by both server and test helpers |
| Channel server | `channel_server.march` | `Bastion.ChannelServer`: `add_route`, `plug`, `plug_at`; multiplexed topic WS loop; join/leave/heartbeat/handle_in; PubSub integration |
| Channel test helpers | `test_channel.march` | `Bastion.Test.Channel`: `join/3`, `push/4`, `intercept/1`, `assert_broadcast/3`, `refute_broadcast/3`, `captured_broadcasts/1` |
| Request metrics | `metrics.march` | `Bastion.Metrics`: `instrument/1` (timing wrapper), `record/1` (plug); `summary()`, `total()`, `error_count()`, `recent_requests()`; Vault ring-buffer (last 100); `reset()` |
| Live reload + dashboard | `dev.march` | `Bastion.Dev`: `live_reload` plug; `live_reload_tag()`; `dashboard` plug (`/_bastion` HTML page with metrics); `request_timer`, `server_timing`, `conn_inspector`; `dev_env?()` |
| Health check | `health.march` | `Bastion.Health`: `plug`, `plug_with_checks`, `check/2`; Vault-backed drain state; `start_drain()`/`draining?()` |
| Multipart uploads | `upload.march` | `Bastion.Upload`: `parse_conn/2`, `parse/3`; `UploadedFile`, `UploadOpts`, `UploadError` types; boundary extraction; part splitting; header parsing; `default_opts/0`, `error_message/1` |
| Idempotency keys | `idempotency.march` | `Bastion.Idempotency`: `protect/2`, `protect_with/3`; Vault-cached POST/PUT responses (TTL, scope prefix); replay with `X-Idempotent-Replayed: true`; `cached?`, `invalidate` |
| Telemetry | `telemetry.march` | `Bastion.Telemetry`: `attach/3`, `detach/1`, `execute/3`; `span/3` (start/stop events with duration); `request_start/1`, `request_stop/2`; Vault-backed handler registry; prefix-match subscriptions |
| HTTP test conn builder | `test_conn.march` | `Bastion.Test.Conn`: `build_conn/2,3`; `put_req_header`, `put_req_body`, `put_req_cookie`, `put_query_params`; `authenticate_as`, `with_api_token`; `assert_status`, `assert_header`, `assert_html_contains`, `assert_redirected_to`, `assert_json`; `get_resp_header`, `resp_status`, `resp_body` |
| JS → island public API | `priv/js/march-islands.js` | `window.Bastion.getIsland(name)` → `IslandHandle` with `.send(msg)`, `.getState()`, `.all()`, `.count`; `Bastion.onDispatch(name, cb)` dispatch observer; allows host-page JS to communicate with islands |
| Cmd abstraction (WASM → JS) | `lib/cmd.march`, `priv/js/march-islands.js`, `priv/js/wasm-bridge.js` | `Bastion.Cmd` type + constructors; `executeCmd` runtime for `HttpGet/Post`, `After/Every`, `Focus/Blur`, `PushUrl/ReplaceUrl`, `StoreLocal/LoadLocal/RemoveLocal`, `ChannelPush`, `Batch`; `WasmIslandModule.updateWithCmd()` reads cmd via `march_island_last_cmd` sidecar export |
| JS FFI layer (WASM → browser) | `lib/js.march`, `priv/js/wasm-bridge.js` | `Bastion.JS`: `call`, `global`, `eval`, `query_selector`, `get/set/remove_attribute`, `add_event_listener`, `string_val/int_val/bool_val/json_val`, `to_string/to_int`; JS handle table in wasm-bridge.js; `extern "bastion" "js_*"` imports; late-bound memory reference |

---

## In Progress

Specced and designed but not yet fully implemented. These are the active build areas.

| Feature | Spec | Status | Blocker |
|---------|------|--------|---------|
| `~H` templates | [templates.md](templates.md) | Design complete, not implemented | Needs `Html`/`IOList` runtime modules (triple-quoted sigil parsing already works) |
| `.march.html` template files | [template-file-format.md](template-file-format.md) | All layers implemented | Triple-quoted `~H` sigils work; `[preprocessors]` in forge; `.march.spans` sidecar in compiler; lowering pass + runtime in Bastion |
| WASM island compilation | [wasm-islands.md](wasm-islands.md) | Near-complete | Compiler target done; JS runtime ~95% done. Remaining: deferred hydration strategies (lazy/idle/on-visible/on-interaction) + `march_island_msg_from_name` wiring |
| Islands data flow | [islands-data-flow.md](islands-data-flow.md) | Design complete | Depends on `~H` templates; WASM compiler blocker resolved |
| Channels / WebSocket | [channels.md](channels.md) | Server + PubSub implemented | Client-side island integration depends on `~H` templates |
| CSP nonce injection | [csp.md](csp.md) | Draft spec | Depends on `~H` for automatic nonce injection |
| Route verification | [route-verification.md](route-verification.md) | Draft spec | Needs compiler integration for route helper generation |

---

## Planned (Specced, Not Started)

Full specs exist. Implementation is queued but not yet started.

### Routing
- Reversible routing / route helpers — typed path helpers, compile-time dead-link detection ([route-verification.md](route-verification.md))

### Middleware & Security
- CSRF protection — token lifecycle, `protect`, `tag_string`, `skip` ([auth-session-database.md](auth-session-database.md) Layer 5, [security.md](security.md))
- Security headers middleware — HSTS, X-Frame-Options, etc. ([security.md](security.md))
- CORS middleware ([security.md](security.md))
- Rate limiting — sliding window, `x-ratelimit-*` headers, Vault-backed ([auth-session-database.md](auth-session-database.md) Layer 5b, [security.md](security.md))
- CSP auto-generation from resource usage ([csp.md](csp.md), [open-questions.md](open-questions.md))

### Auth & Sessions
- Cookie helpers (`get_req_cookie`, `put_resp_cookie`, `after_send`) ([auth-session-database.md](auth-session-database.md) Layer 0)
- Crypto module — AES-256-GCM, HMAC-SHA256, HKDF, Argon2id, SHA-256, CSPRNG ([auth-session-database.md](auth-session-database.md) Layer 1)
- Session middleware — cookie-backed with real crypto, auto-commit, `_session_dirty` tracking ([auth-session-database.md](auth-session-database.md) Layer 3, [auth.md](auth.md))
- Flash messages — one-time session values for UI feedback ([auth-session-database.md](auth-session-database.md) Layer 3)
- Auth middleware — `load_current_user`, `require_auth` (Result gate), `authenticated` sugar, `log_in`, `log_out` ([auth-session-database.md](auth-session-database.md) Layer 6, [auth.md](auth.md))
- Remember-me tokens — hashed, DB-backed, 60-day persistent login ([auth-session-database.md](auth-session-database.md) Layer 6)
- Password reset — single-use tokens, 1-hour expiry, session invalidation on change ([auth-session-database.md](auth-session-database.md) Layer 6)
- `forge gen.auth session` — full auth scaffold (users + user_tokens migrations, Accounts, AuthController, templates, router patch, rate limiting) ([auth-session-database.md](auth-session-database.md) Layer 7)
- Depot session / Vault session backends — post-v1 ([auth-session-database.md](auth-session-database.md))
- `forge gen.auth token / oauth / magic_link` — post-v1 ([auth.md](auth.md), [generators.md](generators.md))

### Storage
- Vault — in-memory KV actor, TTL sweeper (core: `put/get/delete/put_new`) ([auth-session-database.md](auth-session-database.md) Layer 3b, [vault.md](vault.md))
- Depot integration — pool middleware, `after_send` checkin, context modules, migrations ([auth-session-database.md](auth-session-database.md) Layer 2, [depot-integration.md](depot-integration.md))
- Caching — ETags, response caching, fragment caching ([caching.md](caching.md))

### Forms
- Plain server-side forms with `Depot.Gate` validation and built-in `<.form>`, `<.input>` components ([form-handling.md](form-handling.md))
- Enhanced fetch forms — progressive `enhance` attribute, fragment re-render without full-page reload ([form-handling.md](form-handling.md))
- Island forms with shared WASM/server validation — same `validate/1` function compiles to both targets ([form-handling.md](form-handling.md))
- Flash messages — session-backed, consumed on render, `<.flash_group>` component ([form-handling.md](form-handling.md))

### Templates & Styling
- `~CSS` sigil — scoped island CSS with compile-time extraction ([css-styling.md](css-styling.md))
- CSS variables for theming ([css-styling.md](css-styling.md))

### JS Interop
- WASM → JS FFI layer — `Cmd` abstractions, `window.*`, DOM calls ([js-interop.md](js-interop.md))
- JS → WASM message protocol ([js-interop.md](js-interop.md))

### Developer Experience
- `forge dev` live reload ([dev-experience.md](dev-experience.md))
- Dev error overlay (shows stack traces in-browser) ([dev-experience.md](dev-experience.md), [error-handling.md](error-handling.md))
- Hot deploy / connection draining on SIGTERM ([hot-deploy.md](hot-deploy.md))
- `forge dev` dashboard (request log, WebSocket connections) ([dev-experience.md](dev-experience.md))

### Generators
- `forge gen.handler`, `forge gen.context`, `forge gen.channel`, `forge gen.island`, `forge gen.migration` ([generators.md](generators.md))

### Testing
- Depot test sandbox (per-test transaction rollback) ([testing.md](testing.md), [test-sandbox.md](test-sandbox.md))
- Channel testing helpers ([testing.md](testing.md))
- Island testing (SSR + update logic, no WASM needed) ([testing.md](testing.md))

### Operations
- Deployment — single binary, runtime config, health checks, graceful shutdown ([deployment.md](deployment.md))
- Structured logging, request ID tracing ([logging-observability.md](logging-observability.md), [logging.md](logging.md))
- OpenTelemetry integration ([telemetry.md](telemetry.md))
- Uploads — streaming multipart, external storage ([uploads.md](uploads.md))
- Configuration — compile-time vs runtime, `forge.toml` ([configuration.md](configuration.md))

### Performance
- IO list rendering (zero-copy template output) ([performance.md](performance.md))
- Compiled route dispatch ([performance.md](performance.md))
- Benchmarking targets ([performance.md](performance.md))

---

## Future / Phase 2+

Explicitly deferred. Not in scope for v1.

| Feature | Notes |
|---------|-------|
| Collaborative islands (CRDT) | Multi-client simultaneous editing. Separate sync channel. See [islands-data-flow.md](islands-data-flow.md) |
| Bastion.Presence | Online user tracking (Phoenix.Presence analogue), CRDT-based |
| Bastion.LiveDashboard | Built-in admin panel — metrics, connections, actor counts, WASM bundle sizes |
| Distributed PubSub | Cross-node Channel message broadcasting |
| Distributed Vault | Optional cross-node Vault replication |
| Background job system | Persistent queues backed by Depot, retries, scheduling, dead-letter |
| Static site generation | Pre-render pages at build time |
| Edge deployment | Compile Bastion apps to WASM for Cloudflare Workers etc. |
| i18n | Compile-time string extraction |
| Auto-generate TypeScript types | From March island types for typed JS consumers |
| Background jobs / task queues | Separate library |
| Mailer / email | External library |
| GraphQL | Dedicated library on top of Bastion |
| OpenAPI / Swagger generation | Deferred |
| Admin dashboard | See Bastion.LiveDashboard above |
