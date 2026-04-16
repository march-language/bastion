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

---

## In Progress

Specced and designed but not yet fully implemented. These are the active build areas.

| Feature | Spec | Status | Blocker |
|---------|------|--------|---------|
| `~H` templates | [templates.md](templates.md) | Design complete, not implemented | Needs `Html`/`IOList` runtime modules (triple-quoted sigil parsing already works) |
| `.march.html` template files | [template-file-format.md](template-file-format.md) | All layers implemented | Triple-quoted `~H` sigils work; `[preprocessors]` in forge; `.march.spans` sidecar in compiler; lowering pass + runtime in Bastion |
| WASM island compilation | [wasm-islands.md](wasm-islands.md) | Near-complete | Compiler target done; JS runtime ~95% done. Remaining: deferred hydration strategies (lazy/idle/on-visible/on-interaction) + `march_island_msg_from_name` wiring |
| Islands data flow | [islands-data-flow.md](islands-data-flow.md) | Design complete | Depends on `~H` templates; WASM compiler blocker resolved |
| Channels / WebSocket | [channels.md](channels.md) | Draft spec | Needs Channel server implementation |
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
