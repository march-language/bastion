# Bastion: Feature Status

**Updated**: 2026-03-31

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

---

## In Progress

Specced and designed but not yet fully implemented. These are the active build areas.

| Feature | Spec | Status | Blocker |
|---------|------|--------|---------|
| `~H` templates | [templates.md](templates.md) | Design complete, not implemented | Needs: (1) triple-quoted sigil fix in March parser, (2) `Html`/`IOList` runtime modules |
| `.march.html` template files | [template-file-format.md](template-file-format.md) | Design complete, not implemented | Needs: `~H` fix + `bastion lower` CLI + `[preprocessors]` in forge + `.march.spans` sidecar in March compiler |
| WASM island compilation | [wasm-islands.md](wasm-islands.md) | Infrastructure complete | Tier 4 browser target (`wasm32-unknown-unknown`) not yet in March compiler |
| Islands data flow | [islands-data-flow.md](islands-data-flow.md) | Design complete | Depends on WASM compilation + `~H` templates |
| Channels / WebSocket | [channels.md](channels.md) | Draft spec | Needs Channel server implementation |
| CSP nonce injection | [csp.md](csp.md) | Draft spec | Depends on `~H` for automatic nonce injection |
| Route verification | [route-verification.md](route-verification.md) | Draft spec | Needs compiler integration for route helper generation |

---

## Planned (Specced, Not Started)

Full specs exist. Implementation is queued but not yet started.

### Routing
- Reversible routing / route helpers — typed path helpers, compile-time dead-link detection ([route-verification.md](route-verification.md))

### Middleware & Security
- CSRF protection — double-submit cookie pattern ([security.md](security.md))
- Security headers middleware — HSTS, X-Frame-Options, etc. ([security.md](security.md))
- CORS middleware ([security.md](security.md))
- Rate limiting ([security.md](security.md))
- CSP auto-generation from resource usage ([csp.md](csp.md), [open-questions.md](open-questions.md))

### Auth & Sessions
- Session middleware (cookie-based and Depot-backed) ([auth.md](auth.md))
- Auth generators — `forge gen.auth` for session/token/OAuth/magic_link ([auth.md](auth.md), [generators.md](generators.md))
- Auth middleware (plug-in authentication pipeline) ([auth.md](auth.md))

### Storage
- Vault — in-memory ETS-style key-value store with TTL ([vault.md](vault.md))
- Depot integration — pool middleware, context modules, migrations ([depot-integration.md](depot-integration.md))
- Caching — ETags, response caching, fragment caching ([caching.md](caching.md))

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
