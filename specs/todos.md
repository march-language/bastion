# Bastion: TODO List

**Updated**: 2026-03-31

Derived from [open-questions.md](open-questions.md), the individual spec files, and current `lib/` state. See [features.md](features.md) for broader feature status.

---

## Next Up

The most impactful unblocked work. These are preconditions for most other features.

- [ ] **`~H` sigil parser** — Design spike on March lexer changes needed to support `~H"""..."""` and `~CSS"""..."""`. This unblocks: templates, CSP nonce injection, scoped CSS, compile-time XSS prevention, and type-checked markup. See [open-questions.md](open-questions.md) §1.
- [ ] **Islands data flow implementation** — Implement the `Server` / `Client` dataflow modes, parent-child prop binding, and explicit event dispatch as specced in [islands-data-flow.md](islands-data-flow.md). Depends on `~H` for template rendering in islands.
- [ ] **Kill `window.marchIslands.send` global bus** — Replace with the parent-child dispatch model from [islands-data-flow.md](islands-data-flow.md). See wasm-islands.md current design.
- [ ] **Channel server implementation** — Spec is complete ([channels.md](channels.md)), implementation needed. Unblocks: island-to-server sync, real-time features, Presence.
- [ ] **Session middleware** — Cookie-based sessions with signing + encryption. Unblocks: auth generators, CSRF. See [auth.md](auth.md).
- [ ] **CSRF protection** — Double-submit cookie. Needs session middleware first. See [security.md](security.md).

---

## Planned

Specced and queued. Roughly priority order within each group.

### Compiler Integration
- [ ] Route helpers + compile-time route verification ([route-verification.md](route-verification.md))
- [ ] CSP nonce auto-injection via `~H` compiler pass ([csp.md](csp.md))
- [ ] Island prop serialization — decide JSON vs binary fast-path for large datasets ([open-questions.md](open-questions.md) §3)
- [ ] Island WASM hot-swap in dev without state loss ([open-questions.md](open-questions.md) §4)

### WASM / Islands
- [ ] Tier 4 WASM browser target (`wasm32-unknown-unknown`) in March compiler ([open-questions.md](open-questions.md) §2) — this is the big blocker
- [ ] WASM actor runtime — green threads / mailboxes / `Pid(a)` in WASM target. Decide: per-island instance or shared with cooperative scheduling ([open-questions.md](open-questions.md) §5)
- [ ] JS glue sidecar generation (`Counter.glue.js`) alongside `.wasm`
- [ ] `march_alloc` / `march_dealloc` for string passing across WASM boundary
- [ ] `forge gen.island` generator

### Auth & Security
- [ ] Auth generators — `forge gen.auth` (session / token / OAuth / magic_link) ([auth.md](auth.md), [generators.md](generators.md))
- [ ] Auth middleware plug-in ([auth.md](auth.md))
- [ ] Security headers middleware — HSTS, X-Frame-Options, X-Content-Type-Options ([security.md](security.md))
- [ ] CORS middleware ([security.md](security.md))
- [ ] Rate limiting ([security.md](security.md))

### Storage
- [ ] Vault implementation — decide underlying data structure (HAMT?), TTL sweeper design ([vault.md](vault.md), [open-questions.md](open-questions.md) §6)
- [ ] Vault multi-node question — strictly per-node or optional replication? ([open-questions.md](open-questions.md) §7)
- [ ] Depot pool middleware ([depot-integration.md](depot-integration.md))
- [ ] Depot test sandbox (per-test transaction rollback) ([test-sandbox.md](test-sandbox.md))
- [ ] HTTP ETag + response caching ([caching.md](caching.md))
- [ ] Fragment caching ([caching.md](caching.md))

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
- [ ] `forge gen.handler` ([generators.md](generators.md))
- [ ] `forge gen.context` ([generators.md](generators.md))
- [ ] `forge gen.channel` ([generators.md](generators.md))
- [ ] `forge gen.migration` ([generators.md](generators.md))

### Testing
- [ ] Channel testing helpers ([testing.md](testing.md))
- [ ] Island integration tests (SSR + update, no WASM) ([testing.md](testing.md))

### Operations
- [ ] Deployment guide — single binary, env config, health checks, graceful shutdown ([deployment.md](deployment.md))
- [ ] Structured logging + request ID propagation ([logging-observability.md](logging-observability.md))
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
