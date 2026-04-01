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

Always use `forge search` before grepping or manually reading files when looking for modules, functions, or types in March code.

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
forge build          # compile the project
forge test           # run all tests
forge dev            # start dev server with live reload
forge gen.handler    # generate a new handler
forge gen.island     # generate a new WASM island
forge gen.auth       # generate auth boilerplate
forge gen.migration  # generate a Depot (Postgres) migration
```

---

## Project Layout

```
bastion/
├── CLAUDE.md                  # this file
├── forge.toml                 # build config (deps, targets)
├── syntax_reference.md        # March language quick reference
├── lib/                       # framework source (March)
│   ├── bastion.march          # framework entry point
│   ├── bastion_server.march   # HTTP server + supervisor
│   ├── conn.march             # HTTP conn abstraction
│   ├── conn_states.march      # typed conn state machine
│   ├── router.march           # pattern-matched routing
│   ├── middleware.march       # middleware pipeline
│   ├── typed_middleware.march # type-tracked middleware
│   ├── controller.march       # render/redirect helpers
│   ├── islands.march          # island SSR + hydration
│   ├── island_view.march      # island template helpers
│   ├── island_assets.march    # WASM + CSS asset serving
│   ├── island_css.march       # scoped CSS extraction
│   ├── island_socket.march    # island↔server WebSocket glue
│   ├── static.march           # static file serving
│   ├── request.march          # HTTP request parsing
│   ├── response.march         # HTTP response building
│   ├── error_view.march       # default error pages
│   ├── fallback_controller.march
│   └── test.march             # testing helpers (conn builder)
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

The core request/response pipeline, routing, middleware, island SSR, and static file serving are implemented in `lib/`. Most other features (auth, channels, CSRF, Vault, `~H` templates, WASM compilation) are **specced in `specs/` but not yet implemented**.

The biggest blockers:
1. `~H` sigil — needs March lexer changes (see `specs/open-questions.md` §1)
2. WASM browser target (`wasm32-unknown-unknown`) — Tier 4 in the March compiler roadmap

Check `specs/features.md` for the full picture before starting any feature work.
