# Bastion

Bastion is March's web framework — the Phoenix to March's Elixir. It provides server-side rendering, typed WASM islands for client-side interactivity, pattern-matched routing, typed middleware pipelines, and real-time WebSocket support via Channels.

**Compiler dependency**: This repo depends on the March compiler at `/Users/80197052/code/march`.

---

## Searching the codebase

**Use `forge search` to find modules, functions, types, and other code constructs.** This is the primary way to discover what exists in the codebase.

```
forge search "function_name"    # search for a function
forge search "ModuleName"       # search for a module
forge search "type_name"        # search for a type
```

**`forge search` is always the preferred way to search `.march` files.** Use it instead of Grep/grep whenever the target is March code — names, types, docstrings, or constructors.

---

## Language

Bastion is written in March. Before writing any March code:
- Use the **march-lang skill** (`.claude/skills/march-lang/SKILL.md`) for the full language reference — syntax, builtins, stdlib API, testing patterns, and common pitfalls.
- See `syntax_reference.md` in the repo root for a quick reference.

Key March conventions used throughout this codebase:
- Modules: `mod Name do ... end`
- Interfaces / behaviours: `interface` / `impl` (not `@behaviour`)
- Functions: `fn` (public), `pfn` (private)
- No semicolons
- Lambdas: `fn x -> expr` only (no `do...end` block form)
- Templates: `~H"""..."""` sigil (HTML), `~CSS"""..."""` (scoped CSS)
- No `pub` keyword — all `fn` are public, `pfn` are private

---

## Build Commands

Bastion uses `forge` (the March build tool, defined in `forge.toml`):

```bash
forge check          # fast typecheck (use after every .march edit)
forge build          # compile the project
forge lint --strict  # run the linter
forge test           # run all tests
forge bastion.server        # start the dev server with live reload
forge bastion.gen.handler   # generate a new request handler
forge bastion.gen.island    # generate a new WASM island
forge bastion.gen.auth      # generate auth boilerplate
forge bastion.gen.migration # generate a Depot (Postgres) migration
```

> The `bastion.*` tasks are the commands registered in `forge.toml` (see
> `[archive.task.*]`). There is no bare `forge dev` / `forge gen.*`.

**After editing any `.march` file, run `forge check` to typecheck the whole project quickly before proceeding.**

---

## Project Layout

```
bastion/
├── CLAUDE.md                  # this file
├── forge.toml                 # build config (deps, targets)
├── syntax_reference.md        # March language quick reference
├── lib/                       # framework source (March), grouped by domain
│   ├── bastion.march          # framework entry point (stays at lib/ root)
│   ├── http/                  # request/response pipeline, routing, controllers
│   │   ├── conn.march · conn_states.march · request.march · response.march
│   │   ├── router.march · bastion_routes.march · bastion_server.march
│   │   └── controller.march · fallback_controller.march
│   ├── middleware/            # middleware.march, typed_middleware.march, depot_middleware.march
│   ├── security/             # auth, gate, session, csrf, cors, crypto, hkdf,
│   │                          #   security_headers, bastion_csp, rate_limit
│   ├── islands/              # islands, island_view/_assets/_css/_server/_socket
│   ├── channels/             # channel, channel_server, pubsub, bastion_pubsub
│   ├── view/                 # html, css, js, form, flash, error_view, error_overlay
│   ├── assets/               # static.march, upload.march
│   ├── cache/                # cache, bastion_cache, idempotency, bastion_idempotency
│   ├── observability/        # logger, metrics, otel, telemetry(+_aggregator), health
│   ├── runtime/              # registry, pool, cmd(+_depot), bastion_depot,
│   │                          #   bastion_hot_deploy, dev
│   ├── testing/              # test, test_conn/_auth/_channel/_depot/_island
│   └── forge/                # forge CLI tasks (gen.*, build.islands, depot.*, …)
├── priv/
│   └── static/                # static assets (JS runtime, WASM bundles)
├── specs/                     # design specs (source of truth for unimplemented features)
│   ├── README.md              # spec index
│   ├── features.md            # feature status (implemented / in-progress / planned / future)
│   ├── todos.md               # prioritized todo list
│   ├── islands-data-flow.md   # canonical islands data flow design ← READ THIS
│   ├── wasm-islands.md        # island architecture + hydration
│   ├── routing.md
│   ├── middleware.md
│   ├── templates.md
│   ├── channels.md
│   ├── auth.md
│   ├── security.md
│   ├── csp.md
│   ├── vault.md
│   ├── caching.md
│   ├── depot-integration.md
│   ├── static-files.md
│   ├── css-styling.md
│   ├── js-interop.md
│   ├── error-handling.md
│   ├── generators.md
│   ├── dev-experience.md
│   ├── testing.md
│   ├── deployment.md
│   ├── performance.md
│   ├── open-questions.md      # open design questions + v1 exclusions
│   └── ...
├── test/                      # framework tests
└── examples/                  # example Bastion applications
```

> **Module resolution & lib/ subfolders.** Modules are imported by name
> (`import Conn`), and the compiler resolves `import X` to `x.march` by
> filename. `forge` puts `lib/` **and all of its subdirectories** on the
> module search path (`MARCH_LIB_PATH`), so modules can live in any subfolder
> without changing a single `import`. Keep module filenames unique across the
> whole `lib/` tree — two files with the same basename in different folders
> would collide. (This subfolder support comes from a forge patch in the
> March toolchain — see `specs/lib-reorganization.md`.)

---

## Key Design Docs

| Doc | What it covers |
|-----|---------------|
| `specs/islands-data-flow.md` | **Canonical islands data flow design** — Server/Client modes, parent-child binding, event dispatch, forms, channel sync. This supersedes the global `window.marchIslands.send` model. |
| `specs/wasm-islands.md` | Island declaration, SSR, hydration strategies, actor-per-island model |
| `specs/routing.md` | Pattern-matched routing, route delegation |
| `specs/middleware.md` | Typed middleware pipeline, conn state transitions |
| `specs/templates.md` | `~H` sigil design (not yet implemented — needs March lexer changes) |
| `specs/channels.md` | WebSocket channel handlers |
| `specs/open-questions.md` | Open design questions, v1 exclusions, post-v1 roadmap |
| `specs/features.md` | Feature status by area |
| `specs/todos.md` | Prioritized todo list |

---

## Current State

The core request/response pipeline, routing, middleware, island SSR, static file
serving, **auth, sessions, CSRF, channels/PubSub, Vault, caching, security
headers/CORS, observability, and the `forge bastion.*` generators** are
implemented in `lib/`. The `~H` template system is handled by the
`bastion lower` preprocessor (`.march.html` files); see `specs/features.md`
for the precise status of `~H` sigils in plain `.march` files. The remaining
gaps are mostly operational hardening (panic recovery, real OTLP export,
config/TLS) and the WASM browser target.

The biggest blockers:
1. WASM browser target (`wasm32-unknown-unknown`) — Tier 4 in the March compiler roadmap
2. A `HttpServer.try_call` panic-recovery primitive — `safe_call_plug` and the
   error-overlay crash REPL are no-ops without it
3. A stdlib async `HttpClient` — blocks real OTLP export and outbound webhooks

Check `specs/features.md` for the full picture before starting any feature work.
