# Bastion: Feature Status

**Updated**: 2026-07-05

This document tracks the implementation status of every Bastion feature area. Use it to understand what's ready, what's specced but not built, and what's deferred to later phases. The `Notes` column lists the actual public API of each module — verified against `lib/` source, not the specs.

> **Note on the `Files` column.** As of the 2026-06-12 reorganization, `lib/`
> modules live in domain subfolders (`lib/http/`, `lib/security/`, etc.). The
> filenames below are bare basenames — `forge` puts every `lib/` subfolder on
> the module search path, so imports are unchanged. Use `forge search` to
> locate a module by name.

> **Note on Vault.** Bastion no longer ships a `vault.march` wrapper — it was
> removed in commit `b0d2013` and merged into the March **stdlib `Vault`**
> module, which Bastion now calls directly (`Vault.new/set/set_ttl/get/get_or/`
> `drop/has/update/size/keys/all/whereis` plus `ns_set/ns_get/ns_drop`). Every
> "Vault-backed" feature below uses that stdlib module.

---

## Implemented

These features have corresponding code in `lib/` and are usable today (within the limits of the March compiler's current maturity).

### HTTP core

| Feature | Files | Notes |
|---------|-------|-------|
| HTTP conn abstraction | `conn.march`, `conn_states.march` | Wraps `HttpServer.Conn`: accessors (`method`/`path`/`path_info`/`req_headers`/`req_body`/`status`/`resp_*`/`halted`), `assign`/`get_assign`, `send_resp`/`halt`, cookies (`get_req_cookie`/`put_resp_cookie`/`delete_resp_cookie`), `register_after_send`/`after_send_hooks`, `get_form_param`. `conn_states.march` holds **compile-time** state-tag types (`Raw`/`Parsed`/`WithSession`/`Authenticated`/`WithDB`) + a `TypedConn(s)` phantom wrapper and `Session`/`User` records — not a runtime state machine |
| Request parsing | `request.march` | `query_params`/`get_query_param`, `path_param`/`get_path_param`, `get_header`, `content_type`, `authorization`, `user_agent`, `body`/`body_params`, `json_body` → `Result(JsonValue, String)` |
| Response building | `response.march` | `html`/`json`/`text`/`raw`; `redirect`/`redirect_permanent`; `ok`/`created`/`no_content`; `bad_request`/`unauthorized`/`forbidden`/`not_found`(`_`)/`method_not_allowed`/`unprocessable`/`internal_error`(`_`)/`service_unavailable` |
| Pattern-matched routing | `router.march` | `Router.new`/`get`/`post`/`put`/`patch`/`delete`/`action`/`scope`/`dispatch`/`to_plug`; `:param` path patterns; per-router `fallback` |
| Reversible routing | `bastion_routes.march` | Named-route registry → URL builder: `register`, `all`, `path`, `static_path`, `path1`, `path2` (the inverse of `dispatch` — build links from route names) |
| Controller helpers | `controller.march` | `action`, `render`/`render_ok`, `render_iolist`/`render_iolist_ok`, `json`, `text`, `redirect`; `ActionResult` error handling. (`send_resp`/`assign`/`get_assign` live in `conn.march`, **not** here) |
| Middleware pipeline | `middleware.march` | `pipeline`/`compose`; `logger`, `request_id` (+ `request_id_counter`/`start_id_counter`), `default_content_type`, `cors`, `allow_methods` |
| Typed middleware | `typed_middleware.march` | Phantom-typed pipeline enforcing plug order at compile time: `wrap`/`unwrap`, `parse_body`, `load_session`, `load_current_user`, `require_auth`/`authenticated`, `with_db`, request-kind predicates, `web_pipeline`/`full_pipeline` |
| Error views | `error_view.march`, `fallback_controller.march` | `ErrorView.render`/`render_default`/`status_text`/`default_message`; `FallbackController.call`/`call_json`/`new` (HTML or JSON error dispatch) |
| Framework entry + server | `bastion.march`, `bastion_server.march` | `Opts` + `default_opts`/`with_port`/`with_max_connections`/`with_idle_timeout`; `BastionServer.start`/`start_plug`/`spawn_n`/`wait_for`; after-send hook dispatch (`session_commit`, `pool_checkin`). No process-supervisor tree |

### Views & assets

| Feature | Files | Notes |
|---------|-------|-------|
| HTML safety primitives | `html.march` | `Safe` type; `escape`/`safe`/`to_string`/`is_empty`; `html_auto_escape_string`/`_int`/`_bool`/`_safe` template helpers |
| CSS style builder | `css.march` | `Css.style/1` — inline style string from `(property, Option(value))` pairs |
| JS FFI (WASM → browser) | `js.march` | `Bastion.JS`: `call`/`global`/`eval`/`query_selector`/`get_attribute`/`set_attribute`/`remove_attribute`/`add_event_listener`/`event_detail`; value wrappers `string_val`/`int_val`/`bool_val`/`json_val`/`null_val`/`to_string`/`to_int`/`is_null` |
| Forms | `form.march` | `form_tag`/`input_tag`/`textarea_tag`/`select_tag`/`error_tag`/`field_tag` + `Form.Wrapper`/`Input`/`Textarea`/`Select`/`Field`/`Error` ~H components; reads value/error from Gate |
| Flash messages | `flash.march` | `Flash.put`/`get`/`loaded_flashes`/`clear`/`delete`/`render_one` + `Flash.FlashGroup.render/1` component; session-backed across redirects |
| Static file serving | `static.march` | `StaticConfig`; `serve`/`serve_with_prefix`/`serve_with_config`; `path`/`css_tag`/`js_tag` (manifest lookup); `mime_type`; `looks_fingerprinted`; content-hash URLs from `priv/static/` |
| Multipart uploads | `upload.march` | `Bastion.Upload`: `parse_conn/2`, `parse/3`, `default_opts/0`, `error_message/1`; `UploadedFile`/`UploadOpts`/`UploadResult`/`UploadError` types |
| `~H` templates | `desugar.ml` (March compiler), `forge/lower.march` | `~H` sigils lower in any `.march` file; component system (`<.Component>`, named slots) in the lowering pass |
| `.march.html` template files | `forge/lower.march`, `span_remap.ml` | `.march.html` → `.march` + span map; registered as the `bastion lower` preprocessor in `forge.toml`; error line remapping via `span_remap.ml` |

### Security

| Feature | Files | Notes |
|---------|-------|-------|
| Gate validation | `gate.march` | Changeset-style: `cast`/`cast_record`, `validate_required`/`_format`/`_length`/`_number`/`_inclusion`/`_confirmation`, `unique_constraint`, `valid`, `errors`/`error_for`, `get_change`/`get_field`, `put_change`/`delete_change`, `add_error` |
| Cookie sessions | `session.march` | `Bastion.Session` — HMAC-SHA256-signed cookie (`<hmac_hex>.<base64_payload>`): `load`, `get`/`put`/`delete`/`clear`, `commit`/`commit_from_conn`, `persist`; signing key via `Crypto.derive_key(secret, "session_signing")`; auto-commit via after-send hook |
| CSRF protection | `csrf.march` | `generate_token`/`token`/`ensure_token`, `tag`/`tag_string`, `validate`, `protect` (mutating methods; exempts JSON), `skip`; URL-safe base64 token; constant-time compare |
| Crypto primitives | `crypto.march` | `random_bytes`/`random_hex`/`generate_token`; `sha256`/`hmac_sha256`/`hkdf_sha256`; `derive_key` (HKDF-SHA256, salt `bastion.hkdf.v1`); `hash_password`/`verify_password` (PBKDF2-SHA256, 600k iters); `secure_compare`; `base64_encode`/`_decode`, `base64_url_encode`/`_decode`; `bytes_to_string` |
| HKDF key derivation | `hkdf.march` | `Hkdf.hkdf_sha256`/`extract`/`expand` — RFC 5869 over the `hmac_sha256_bytes` builtin; raw `Bytes` end-to-end |
| Auth middleware | `auth.march` | `Auth.load_current_user/2`, `load_current_user_with_remember/3`, `current_user`, `require_auth` (→ `/login`), `authenticated`, `log_in/3` (optional 60-day remember-me), `log_out/2` (optional token deleter), `redirect_after_login` |
| Rate limiting | `rate_limit.march` | Sliding window in Vault; `check/5` → `Ok|Err`, `limit/5` pipeline helper; `ip_key`, `ip_key_forwarded/2` (trusted-proxy XFF); `x-ratelimit-*` + `retry-after` headers; 429 on exceed |
| Security headers | `security_headers.march` | `defaults/1` (x-frame-options, x-content-type-options, x-xss-protection, referrer-policy, permissions-policy, COOP, COEP); `hsts/2`; `csp_base/1`, `csp_with_ws/2`; `x_frame_options`/`referrer_policy`/`permissions_policy` overrides |
| CORS middleware | `cors.march` | `Cors.allow/2` + `CorsConfig`; `config/1`, `config_open/0`, `config_credentialed/1`; preflight (OPTIONS), origin match, vary, credentials |
| CSP nonce injection | `bastion_csp.march` | `BastionCSP.protect` (`assign_nonce` + `set_header`), `protect_with_overrides`, `report_only`, `disable`, `get_nonce`/`nonce`; policy includes `'wasm-unsafe-eval'`; nonce injected into script/style during lowering |

### Islands

| Feature | Files | Notes |
|---------|-------|-------|
| Islands SSR core | `islands.march` | `Islands.wrap/4` + 11 more wrap variants (`wrap_eager`/`_with_dataflow`/`_with_css`/`_with_channel`/`wrap_child`(`_with_event`/`_with_id`)/`wrap_server`/`wrap_form`/`client_only`); hydration constructors `eager`/`lazy_hydrate`/`on_idle`/`on_interaction`/`on_visible`; `bootstrap_script`(`_with_nonce`), `preload_hint`; descriptor `Registry` (`register`/`find_island`/…); `validate_server_html`/`validate_server_island` |
| Island view helpers | `island_view.march` | Template helpers: `island`/`island_ssr` (+ `_server`, `_child`, `_with_channel`, `_with_dataflow`, `_with_strategy` variants); `scripts`/`ws_scripts`(`_with_base`) runtime includes; Server/Client dataflow modes |
| Island asset serving | `island_assets.march` | `AssetConfig`; `plug/1`; `serve_js`/`serve_ws_js`/`serve_manifest`/`serve_wasm_file`; `wasm_url`; `wasm_cache_control` |
| Island scoped CSS | `island_css.march` | `scope_css`/`attribute_for`/`attr_name`/`to_kebab` — CSS scoping only (asset serving is in `island_assets.march`) |
| Island WebSocket glue | `island_socket.march` | `SocketConfig` + `IslandHandler` registry: `register`(`_with_dataflow`/`_with_merge`/`_with_child_handler`/`_with_event_handler`/`_full`), `find_handler`, `plug/2`, `process_msg_for_test`; server↔island message loop |
| Island server push | `island_server.march` | `Bastion.IslandServer`: `push/2`, `push_from/2`, `subscriber_count/1`, `has_subscribers/1` — broadcast state updates to connected Server-mode islands via `PubSub` |
| Island JS runtime | `priv/js/march-islands.js`, `wasm-bridge.js`, `form-enhance.js` | Hydration strategies (`lazy`/`idle`/`interaction`/`on-visible`); `window.Bastion.getIsland(name)` handle (`.send`/`.getState`/`.all`/`.count`) + `onDispatch`; WASM msg fast path via `march_island_msg_from_name`; JS handle table; `data-enhance` form interception |
| Cmd (WASM → JS effects) | `cmd.march`, `priv/js/*.js` | `Bastion.Cmd` + `none`/`batch`/`http_get`/`http_post`/`after`/`every`/`focus`/`blur`/`push_url`/`replace_url`/`store_local`/`load_local`/`remove_local`/`channel_push` + `is_none`/`map`; JS `executeCmd` runtime; `updateWithCmd()` reads `march_island_last_cmd` |

### Channels & PubSub

| Feature | Files | Notes |
|---------|-------|-------|
| PubSub | `pubsub.march` | `Bastion.PubSub`: `subscribe`/`unsubscribe`/`unsubscribe_all`/`broadcast`/`broadcast_from`/`subscriber_count`/`has_subscribers`; Vault-backed send_fn registry; inline delivery |
| Named PubSub instances | `bastion_pubsub.march` | `BastionPubSub`: named Vault-backed instances with **wildcard topics** (`topic_matches "room:*"`): `subscribe`/`unsubscribe`/`subscribers`/`broadcast`/`broadcast_from` + `inbox`/`clear_inbox`/`local_broadcast_sync` test helpers |
| Channel connection | `channel.march` | `Bastion.Channel`: `ChannelConn` type; `assign`/`get_assign`/`topic`/`conn_id`/`push`/`broadcast_from`/`sub_id` |
| Channel server | `channel_server.march` | `Bastion.ChannelServer`: `new_routes`/`add_route`/`plug`/`plug_at`; multiplexed topic WS loop (join/heartbeat/handle_in are internal `pfn`); PubSub integration |

### Caching & idempotency

| Feature | Files | Notes |
|---------|-------|-------|
| HTTP caching | `cache.march` | `Cache.cache_control/2`, `etag_from/2` (compute + 304 short-circuit), `etag/2` (explicit), `cached/4` (Vault response cache), `fragment/3` (fragment cache), `invalidate`/`invalidate_prefix`/`invalidate_fragment`. A parallel table-parameterized variant lives in `bastion_cache.march` (`etag`/`cached`/`fragment`/`invalidate(_prefix)`/`cache_control`/`no_cache`/`public_cache`) |
| Idempotency keys | `idempotency.march` | `Bastion.Idempotency`: `protect/2`, `protect_with/3`, `default_opts`/`opts`, `is_cached`/`is_cached_with_scope`, `invalidate`/`invalidate_with_scope`; `X-Idempotent-Replayed: true` on replay. Low-level primitives (`get_key`/`lookup`/`mark_in_progress`/`complete_entry`/`replay_response`) in `bastion_idempotency.march` |

### Observability

| Feature | Files | Notes |
|---------|-------|-------|
| Structured logging | `logger.march` | `Bastion.Logger`: `debug`/`info`/`warn`/`error(msg, meta)` + `*_conn/3` (auto request_id); `parse_level`; `configure(level, format)` → logfmt / JSON / text (explicit call, not MARCH_ENV-detected) |
| Request metrics | `metrics.march` | `Bastion.Metrics`: `instrument/1` (timing plug), `record/1`; `summary`/`total`/`error_count`/`recent_requests`/`reset`; Vault ring buffer (last 100) |
| Health check | `health.march` | `Bastion.Health`: `plug/1`, `plug_with_checks/2`, `check/2`, `start_drain/0`, `draining/0`; `/health` returns 503 while draining |
| Telemetry | `telemetry.march` | `Bastion.Telemetry`: `attach/3`, `detach/1`, `attached_handlers/0`, `execute/3`, `span/3` (start/stop + duration), `request_start/1`, `request_stop/2`; Vault handler registry; prefix-match subscriptions |
| Telemetry aggregator | `telemetry_aggregator.march` | `Bastion.Telemetry.Aggregator`: `start/1`, `recent_requests/1`, `request_waterfall/1`, `counters/0`, `reset/0`; Vault ring buffer (default 100) |
| Telemetry event coverage | `channel_server.march`, `depot_middleware.march`, `bastion_server.march` | `["bastion","channel","message"]` span emitted in `handle_in`. `["bastion","endpoint","exception"]` is **specced but not emitted** (`safe_call_plug` is a no-op). `depot_middleware.query_with_telemetry` is a **stub** (not yet wrapping SQL) — both pending `HttpServer.try_call` |
| OpenTelemetry export (partial) | `otel.march` | `Bastion.OpenTelemetry`: `default_config/1`, `start/1`; attaches to stop/exception events and builds valid OTLP `resourceSpans` JSON. **Stub:** `export_span/4` discards the payload (no HTTP POST) — blocked on a stdlib async `HttpClient` |

### Runtime & dev

| Feature | Files | Notes |
|---------|-------|-------|
| Live reload + dev tools | `dev.march` | `Bastion.Dev`: `live_reload` plug (`/_bastion/reload` WS + `/_bastion/live-reload.js`), `live_reload_tag`, `dashboard` (`/_bastion`), `request_timer`, `server_timing`, `conn_inspector`, `dev_env/0` |
| Dev error overlay (partial) | `error_overlay.march` | `Bastion.ErrorOverlay`: 500 page (`render_error_page`) + `router_plug/1`. **Stub:** `rescue_errors/1` is a no-op and `debug_socket/2` returns 404 — the crash REPL is blocked on `HttpServer.try_call` (+ `March.Repl`) |
| Actor registry | `registry.march` | `Registry`: `register`/`whereis`/`unregister` — Vault-backed name → actor-pid lookup (synchronous, no process) |
| Zero-downtime drain | `bastion_hot_deploy.march` | `BastionHotDeploy`: `DrainStatus` (`Starting`/`Serving`/`Draining`/`Stopped`) + `mark_starting`/`mark_serving`/`start_drain`/`stop_drain`, `get_status`/`is_draining`/`should_drain_request`, in-flight counters, `health_status`/`drain_response`, `DrainConfig` |
| Depot integration | `depot_middleware.march` | `Depot.Middleware.with_pool` (checks out a conn + registers `pool_checkin` hook), `get_conn`/`get_pool`, `checkin_from_conn`; auto-checkin after send. (`bastion_depot.march` is a trivial parallel wrapper whose `with_pool` only stores the pool in assigns — no checkout) |
| Depot SQL queries | Depot repo `depot_query.march` | `where_eq`/`ne`/`gt`/`lt`/`gte`/`lte`/`like`/`ilike`/`is_null`/`is_not_null`; `to_sql`/`to_params`; `exec_sql`; `count_sql` (provided by the Depot dependency) |

### Tooling (`forge bastion.*`)

| Feature | Files | Notes |
|---------|-------|-------|
| App scaffolding | `forge/new.march`, `scaffold.march`, `project.march` | `forge bastion.new <app>` → `Scaffold.scaffold` generates a full project; `project.march` parses `forge.toml` (internal helpers) |
| Dev server | `forge/server.march` | `forge bastion.server` — file-watch + auto-restart dev server |
| Route table / helpers | `forge/routes.march` | `forge bastion.routes` prints the route table; `--gen` (`run_gen`) emits a typed path-helper `Routes` module |
| Asset pipeline | `forge/assets.march` | `forge bastion.assets` — esbuild wrapper: `build`/`deploy`/`watch` (dev/prod bundle + fingerprinting) |
| Island build | `forge/build_islands.march`, `gen_island.march` | `forge bastion.build.islands` compiles all `@island` modules to WASM + manifest; `forge bastion.gen.island` scaffolds an island (optional `--compile`). WASM output pending the compiler target (see In Progress) |
| Generators | `forge/gen_handler.march`, `gen_channel.march`, `gen_migration.march`, `gen_schema.march` | `forge bastion.gen.handler` (controller + CRUD stubs), `gen.channel` (WS channel), `gen.migration` (blank up/down migration), `gen.schema` (schema + migration + context) |
| Auth scaffold generator | `forge/gen_auth.march` | `forge bastion.gen.auth` — Users+UserTokens migrations, Accounts context, Auth middleware, Registration/Session/Settings/Confirmation/PasswordReset controllers, UserNotifier, AccountsFixtures (`RateLimit` on login/register/reset); prints router wiring |
| Context generator | `forge/gen_context.march` | `forge bastion.gen.context <Context> <Schema> <table> [field:type …]` — schema + Gate + CRUD context + migration |
| Depot migration CLI | `forge/depot_migrate.march`, `depot_rollback.march`, `depot_migrations.march`, `depot_reset.march` | `forge bastion.depot.migrate`/`rollback`/`migrations`/`reset` — delegate to the Depot lib (`cmd_depot.march` in `lib/runtime/` is a compile-time stub; the real runner is in `depot/`) |
| Template lowering CLI | `forge/lower.march` | `bastion lower` — `.march.html` → `.march` + spans; registered `[preprocessors]` in `forge.toml` |
| Interactive console | `forge/console.march` | `forge bastion.console` — loads the app; `--server` also starts HTTP; March REPL with a `march(app)>` prompt; `:quit` to exit |
| Release builder | `forge/release.march` | `forge bastion.release` — binary (release mode) + WASM islands + static assets → `_build/release/<name>/`; `--embed-assets`, `--dockerfile` (with HEALTHCHECK), `--clean`; warns if `SECRET_KEY_BASE` unset |

### Testing

| Feature | Files | Notes |
|---------|-------|-------|
| Assertions | `test.march` | `Test`: `fail`, `assert_true`/`false`, `assert_eq_int`/`_str`/`_bool`, `assert_some`/`none`, `assert_ok`/`err` |
| HTTP test conn | `test_conn.march` | `Bastion.Test.Conn`: `build_conn`/`build_conn_with_body`, `put_req_header`/`put_req_body`/`put_req_cookie`, `put_query_params`, `with_api_token`; `assert_status`/`assert_header`/`assert_html_contains`/`assert_redirected_to`/`assert_json`; `get_resp_header`/`resp_status`/`resp_body`/`responded` |
| Auth test helpers | `test_auth.march` | `Bastion.Test.Auth`: `log_in_user/2`, `log_in_user_with_secret/3`, `logged_in/1`, `assert_redirects_to_login/2` |
| Channel test helpers | `test_channel.march` | `Bastion.Test.Channel`: `join/3`, `join_as/4`, `push/4`, `intercept/1`, `assert_broadcast/3`, `refute_broadcast/3`, `clear_broadcasts/1`, `captured_broadcasts/1`, `assert_assign/3` |
| Depot sandbox | `test_depot.march` | `Bastion.Test.Depot`: `start_sandbox`/`stop_sandbox`, `checkout(tables)`/`checkin`, `sandboxed(tables, fn)`, `active`; per-test Vault rollback |
| Island test helpers | `test_island.march` | `TestIsland` (note: **not** `Bastion.Test.Island`): `render_island/3`, `update_island/3`, `assert_renders_contains/4`, `cmd_type/1`, `assert_no_server_event_attrs/1` |
| Island e2e suite | `test/test_island_e2e.march`, `e2e/` | Pure-March island pipeline tests + Playwright suite (server-mode SSR, WASM handoff, parent-child, offline reconnect, lifecycle) |

---

## In Progress

Partially implemented — the March-side code exists, but a piece is blocked on a
lower-level March toolchain primitive.

| Feature | Spec | Status | Blocker |
|---------|------|--------|---------|
| WASM island compilation | [wasm-islands.md](wasm-islands.md) | JS runtime complete; pure-March island tests + Playwright e2e suite done. Actual WASM binary output not yet possible | March compiler `wasm32-unknown-unknown` target (Tier 4) |
| Route-helper call-site verification | [route-verification.md](route-verification.md) | `forge bastion.routes --gen` generates typed path helpers (and `bastion_routes.march` builds URLs at runtime); **compile-time verification of call sites** is not yet wired | March compiler integration |
| OpenTelemetry export | [telemetry.md](telemetry.md) | `otel.march` attaches to events and builds valid OTLP JSON, but `export_span` discards the payload (no HTTP POST yet) | Stdlib async `HttpClient` |
| Panic recovery / crash REPL | [error-handling.md](error-handling.md) | `safe_call_plug`, `ErrorOverlay.rescue_errors`, and `depot_middleware.query_with_telemetry` are no-ops/stubs; the `["bastion","endpoint","exception"]` telemetry event is specced but not emitted; the `/_bastion/debug/:id` crash REPL returns 404 | `HttpServer.try_call` catch primitive (+ `March.Repl` for the REPL) |

---

## Planned (Specced, Not Started)

Full specs exist. Implementation is queued but not yet started.

### Templates & Styling
- `~CSS` sigil — scoped island CSS with compile-time extraction ([css-styling.md](css-styling.md))
- CSS variables / theming system ([css-styling.md](css-styling.md))

### Performance
- Benchmarking targets and baseline measurements ([performance.md](performance.md))
- Compiled route dispatch (trie-based, vs current linear scan) ([performance.md](performance.md))

### Configuration
- Runtime config — environment-variable binding, `forge.toml` schema ([configuration.md](configuration.md))

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
| Mailer / email | External library |
| GraphQL | Dedicated library on top of Bastion |
| OpenAPI / Swagger generation | Deferred |
