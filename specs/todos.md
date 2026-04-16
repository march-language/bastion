# Bastion: TODO List

**Updated**: 2026-03-31

Derived from [open-questions.md](open-questions.md), the individual spec files, and current `lib/` state. See [features.md](features.md) for broader feature status.

---

## Next Up

The most impactful unblocked work. These are preconditions for most other features.

- [ ] **`~H` triple-quoted sigil** (March compiler) — Add the missing `SIGIL_PREFIX + triple_string` parser production in `lib/parser/parser.mly`. The lexer already tokenises `~H` and triple-quoted strings correctly; the parser just lacks the production that combines them. See [template-file-format.md](template-file-format.md) §Layer 1a.
- [ ] **`.march.spans` sidecar support** (March compiler) — Accept a span-override sidecar file alongside a `.march` source so the lowering pass can map generated node positions back to `.march.html` line/col. Errors then report positions in the original template file. See [template-file-format.md](template-file-format.md) §Layer 1b.
- [ ] **`[preprocessors]` hook in forge** — Add a `[preprocessors]` table to `forge.toml` that maps file extensions to commands. Forge runs matched commands before compilation and adds `.forge/generated/` to `MARCH_LIB_PATH`. Incremental: only re-run when source hash changes. See [template-file-format.md](template-file-format.md) §Layer 2.
- [ ] **`bastion lower` CLI subcommand** (Bastion) — Implement the `.march.html` → `.march` lowering pass: frontmatter extraction, HTML parsing, component resolution, slot assembly, code generation, span table output. See [template-file-format.md](template-file-format.md) §Layer 3b.
- [ ] **`Html` runtime module** — `Html.escape/1`, `Html.safe/1`, `Html.Safe` type, `html_auto_escape/1`. Called by `desugar.ml` already; needs a runtime implementation in `lib/html.march`.
- [ ] **`IOList` runtime module** — Complete `IOList.from_strings/1`, `IOList.empty/0`, `IOList.to_string/1` in `lib/io_list.march`.
- [ ] **`Css.style/1` helper** — New `lib/css.march` module. Builds a CSS string from a `List((String, Option(String)))`, filtering `None` values.
- [ ] **Islands data flow implementation** — Implement the `Server` / `Client` dataflow modes, parent-child prop binding, and explicit event dispatch as specced in [islands-data-flow.md](islands-data-flow.md). Depends on `~H` for template rendering in islands.
- [ ] **Kill `window.marchIslands.send` global bus** — Replace with the parent-child dispatch model from [islands-data-flow.md](islands-data-flow.md). See wasm-islands.md current design.
- [ ] **Channel server implementation** — Spec is complete ([channels.md](channels.md)), implementation needed. Unblocks: island-to-server sync, real-time features, Presence.
- [ ] **Auth/session/database stack** — See [auth-session-database.md](auth-session-database.md) for the full sequenced plan. Build in this order:
  - [ ] Step 1: `lib/crypto.march` — random bytes, HMAC, AES-256-GCM, Argon2id password hashing
  - [ ] Step 2: `lib/depot_middleware.march` — `with_pool`, after-send pool checkin hook on conn
  - [ ] Step 3: `lib/session.march` — cookie session: load, commit, get/put/delete/clear
  - [ ] Step 4: `lib/csrf.march` — token generation, `tag_string` runtime (called by ~H desugarer), validation middleware
  - [ ] Step 5: `lib/auth_middleware.march` — `load_current_user`, `require_auth`, `log_in`, `log_out`
  - [ ] Step 6: `lib/vault.march` — in-memory KV actor, TTL sweeper (core API only: put/get/delete/put_new)
  - [ ] Step 7: `forge gen.auth session` generator — User migration, Accounts context, AuthController, login/register templates
  - [ ] Step 8: Depot migrations + `forge depot.migrate` / `forge depot.rollback`
  - [ ] Step 9: `Bastion.Test.Depot.checkout` — per-test transaction rollback sandbox

---

## Planned

Specced and queued. Roughly priority order within each group.

### Compiler Integration
- [ ] Route helpers + compile-time route verification ([route-verification.md](route-verification.md))
- [ ] CSP nonce auto-injection via `~H` compiler pass ([csp.md](csp.md))
- [ ] Island prop serialization — decide JSON vs binary fast-path for large datasets ([open-questions.md](open-questions.md) §3)
- [ ] Island WASM hot-swap in dev without state loss ([open-questions.md](open-questions.md) §4)

### WASM / Islands
- [ ] Deferred hydration strategies in `march-islands.js` — `data-march-hydrate="lazy|idle|interaction|on-visible"` attributes are set server-side but the JS runtime loads all islands eagerly. Implement: `lazy` (load after page load), `idle` (requestIdleCallback), `interaction` (first click/focus), `on-visible` (IntersectionObserver)
- [ ] Wire `march_island_msg_from_name` in `wasm-bridge.js` — currently the runtime passes JSON message strings directly; should use the exported name-based variant constructor for zero-field enum messages
- [ ] End-to-end island integration test — compile a simple island to WASM, serve it, verify hydration and state update round-trip in a browser
- [ ] `forge gen.island` generator
- [ ] WASM actor runtime — green threads / mailboxes in WASM target. Decide: per-island instance or shared cooperative scheduling ([open-questions.md](open-questions.md) §5) — post-v1

### Auth, Security & Storage
- [ ] Security headers middleware — HSTS, X-Frame-Options, X-Content-Type-Options ([security.md](security.md))
- [ ] CORS middleware ([security.md](security.md))
- [ ] Rate limiting — uses Vault; implement after Step 6 above ([security.md](security.md))
- [ ] `forge gen.auth token / oauth / magic_link` — post-v1 auth strategies ([auth.md](auth.md))
- [ ] Vault full API — bags, ordered sets, bulk ops; after core Vault (Step 6) ships ([vault.md](vault.md))
- [ ] Vault/Depot session backends — alternative to cookie sessions ([auth-session-database.md](auth-session-database.md))
- [ ] HTTP ETag + response caching ([caching.md](caching.md))
- [ ] Fragment caching ([caching.md](caching.md))

### Forms
- [ ] `Bastion.Form` render helpers — `form_tag`, `input_tag`, `error_tag` (low-level, used by `~H` components)
- [ ] `<.form>`, `<.input>`, `<.select>`, `<.textarea>`, `<.field>`, `<.error>` components ([form-handling.md](form-handling.md))
- [ ] `<.flash_group>` component — reads and clears session flash ([form-handling.md](form-handling.md))
- [ ] `put_flash/3`, `get_flash/2`, `clear_flash/1` in `lib/session.march` ([form-handling.md](form-handling.md))
- [ ] Enhanced form JS — intercept `<form enhance>` submit, POST via fetch, swap fragment ([form-handling.md](form-handling.md))

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
