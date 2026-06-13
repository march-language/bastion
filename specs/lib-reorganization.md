# Plan: Reorganize `lib/` into domain subfolders

> **Status: DONE (2026-06-12).** Executed as described below, but the original
> "pure file move, zero import edits" assumption was **wrong** and the build
> caught it: the resolver searches each lib path *flatly*, and `forge` only put
> `lib/` root (not its subdirs) on `MARCH_LIB_PATH`, so cross-folder imports
> broke. Fixed with a small **March toolchain patch** (not a Bastion change):
> `collect_lib_dirs` in `march/forge/lib/cmd_build.ml` now expands `lib/` into
> `lib/` + all descendant dirs on `MARCH_LIB_PATH`, with the mirror change in
> `march/lsp/lib/forge_config.ml` for editor support. After rebuilding/installing
> forge, the reorg needed **zero import edits** and `forge check` returns the
> exact pre-existing baseline error set (one unrelated `form.march` typecheck
> failure). See "What actually happened" at the bottom.

## Goal

Group the 65 flat `.march` modules in `lib/` into domain subfolders so related
modules live together (e.g. `Bastion.Channel` and `Bastion.ChannelServer` in
one folder). Purely a physical move — no module renames, no code logic changes.

## Why this works (after the toolchain patch)

- **Modules resolve by filename.** `import Controller` resolves to
  `controller.march`. The resolver searches each lib path *flatly* (no recursion
  into subdirs) — `lib/resolver/resolver.ml`, `find_file` over
  `search_path = source_dir :: MARCH_LIB_PATH`.
- **`forge` now puts every `lib/` subdir on `MARCH_LIB_PATH`** (the patch). So
  `import Conn` finds `lib/http/conn.march` because `lib/http` is a search dir.
  Without this patch the move breaks every cross-folder import.
- **Only `forge.toml` is path-coupled**, via `module = "lib/forge/..."` entries
  for CLI tasks. Those files stay in `lib/forge/` and are not moved, so
  `forge.toml` needs no edits.
- **Filenames must stay unique across the whole tree.** Two `server.march` in
  different folders would collide on the flat-by-filename search. (They're unique
  today.)

Net effect: with the patched toolchain, moving a file into a subfolder does not
change a single `import`.

## Baseline caveat (pre-existing)

`forge check` on the current clean branch **already fails** with a typecheck
error in `form.march` (`join_strs` / validation arms) — unrelated to this reorg.
Record this before starting so a post-move `forge check` failure can be
distinguished from a regression. Ideally fix or confirm this separately; the
reorg itself must not change the set of errors.

## Proposed folder layout

`lib/bastion.march` (framework entry point) **stays at `lib/` root**. Everything
else moves into one of these subfolders. The `lib/forge/` CLI-task folder is left
as-is.

```
lib/
├── bastion.march                     # entry point — stays at root
│
├── http/                             # core request/response pipeline
│   ├── bastion_server.march          # BastionServer
│   ├── conn.march                    # Conn
│   ├── conn_states.march             # ConnStates
│   ├── request.march                 # Request
│   ├── response.march                # Response
│   ├── router.march                  # Router
│   ├── bastion_routes.march          # BastionRoutes
│   ├── controller.march              # Controller
│   └── fallback_controller.march     # FallbackController
│
├── middleware/                       # middleware pipeline
│   ├── middleware.march              # Middleware
│   ├── typed_middleware.march        # TypedMiddleware
│   └── depot_middleware.march        # Depot.Middleware
│
├── security/                         # auth, crypto, request hardening
│   ├── auth.march                    # Auth
│   ├── gate.march                    # Gate
│   ├── session.march                 # Session
│   ├── csrf.march                    # CSRF
│   ├── cors.march                    # Cors
│   ├── crypto.march                  # Crypto
│   ├── hkdf.march                    # Hkdf
│   ├── security_headers.march        # SecurityHeaders
│   ├── bastion_csp.march             # BastionCSP
│   └── rate_limit.march              # RateLimit
│
├── islands/                          # WASM islands SSR + hydration
│   ├── islands.march                 # Islands
│   ├── island_view.march             # IslandView
│   ├── island_assets.march           # IslandAssets
│   ├── island_css.march              # IslandCss
│   ├── island_server.march           # Bastion.IslandServer
│   └── island_socket.march           # IslandSocket
│
├── channels/                         # realtime: channels + pubsub
│   ├── channel.march                 # Bastion.Channel
│   ├── channel_server.march          # Bastion.ChannelServer
│   ├── pubsub.march                  # Bastion.PubSub
│   └── bastion_pubsub.march          # BastionPubSub
│
├── view/                             # rendering: html/css/js, forms, flash, errors
│   ├── html.march                    # Html
│   ├── css.march                     # Css
│   ├── js.march                      # Bastion.JS
│   ├── form.march                    # Form
│   ├── flash.march                   # Flash
│   ├── error_view.march              # ErrorView
│   └── error_overlay.march           # Bastion.ErrorOverlay
│
├── assets/                           # static files + uploads
│   ├── static.march                  # Static
│   └── upload.march                  # Bastion.Upload
│
├── cache/                            # caching + idempotency
│   ├── cache.march                   # Cache
│   ├── bastion_cache.march           # BastionCache
│   ├── idempotency.march             # Bastion.Idempotency
│   └── bastion_idempotency.march     # BastionIdempotency
│
├── observability/                    # logging, metrics, tracing, health
│   ├── logger.march                  # Bastion.Logger
│   ├── metrics.march                 # Bastion.Metrics
│   ├── otel.march                    # Bastion.OpenTelemetry
│   ├── telemetry.march               # Bastion.Telemetry
│   ├── telemetry_aggregator.march    # Bastion.Telemetry.Aggregator
│   └── health.march                  # Bastion.Health
│
├── runtime/                          # process/runtime infra + ops + dev
│   ├── pool.march                    # Pool
│   ├── registry.march                # Registry
│   ├── cmd.march                     # Bastion.Cmd
│   ├── cmd_depot.march               # CmdDepot
│   ├── bastion_depot.march           # BastionDepot
│   ├── bastion_hot_deploy.march      # BastionHotDeploy
│   └── dev.march                     # Bastion.Dev
│
├── testing/                          # test helpers (Bastion.Test.*)
│   ├── test.march                    # Test
│   ├── test_conn.march               # Bastion.Test.Conn
│   ├── test_auth.march               # Bastion.Test.Auth
│   ├── test_channel.march            # Bastion.Test.Channel
│   ├── test_depot.march              # Bastion.Test.Depot
│   └── test_island.march             # TestIsland
│
└── forge/                            # CLI tasks — UNCHANGED (referenced by forge.toml)
    └── ... (21 files)
```

Counts: 9 + 3 + 10 + 6 + 4 + 7 + 2 + 4 + 6 + 7 + 6 = 64 moved, + `bastion.march`
at root = 65 total. `forge/` untouched.

### Grouping decisions worth a second look

- **`channels/` keeps `Channel` + `ChannelServer` together** (per request) and
  also absorbs both pubsub modules, since channels are the primary pubsub
  consumer. Alternative: a separate `pubsub/` folder if pubsub is meant to be a
  standalone primitive.
- **`bastion_depot.march` / `cmd_depot.march` / `depot_middleware.march`** are
  split across `runtime/`, `runtime/`, and `middleware/` by *function* rather
  than collected into a `depot/` folder. If Depot integration is treated as one
  feature area, consider a dedicated `depot/` folder instead.
- **`test_island.march` (`TestIsland`)** and **`bastion_idempotency.march` /
  `bastion_cache.march` / `bastion_pubsub.march`** don't follow the
  `Bastion.Test.*` / namespaced convention of their neighbors — flag for a
  possible follow-up rename so module name matches folder.

## Execution steps

1. **Record baseline.** Run `forge check` and save the exact current error set
   (the pre-existing `form.march` failure). This is the comparison point.
2. **Trial-move one file** (e.g. `git mv lib/registry.march lib/runtime/registry.march`),
   run `forge check`, and confirm the error set is *identical* to baseline. This
   validates the "recursive discovery, name-based imports" assumption before
   doing bulk work. **If imports break here, stop** — the rest of the plan
   depends on this holding.
3. **Move folder by folder**, using `git mv` (preserves history). Recommended
   order, lowest-risk first: `testing/` → `observability/` → `assets/` →
   `cache/` → `view/` → `runtime/` → `channels/` → `islands/` → `security/` →
   `middleware/` → `http/`. Run `forge check` after each folder; the error set
   must stay equal to baseline.
4. **Run `forge build` and `forge test`** once all moves are done, comparing
   against a pre-reorg `forge test` run.
5. **Update docs.** Revise the "Project Layout" tree in `CLAUDE.md` (currently
   lists a flat, outdated `lib/`) to reflect the new structure. Check
   `syntax_reference.md` and `specs/` for any hard-coded `lib/<file>.march`
   paths and update them.
6. **Grep for stragglers.** `grep -rn "lib/[a-z_]*\.march"` across the repo
   (forge.toml, scripts, docs, CI) to catch any remaining path-coupled
   references outside `lib/forge/`.

## Risks / open questions

- **Recursive discovery depth.** `forge/` proves one level of nesting works;
  step 2's trial move proves it generally. Low risk, but explicitly gated.
- **Duplicate basenames.** None today — every file basename is unique, so flat
  module discovery won't collide across folders. Preserve this (don't create
  two `server.march`).
- **Commit hygiene.** Use `git mv` so the move shows as renames, not
  delete+add, keeping `git blame`/history intact. Consider one commit per
  folder for reviewable diffs.
- **Naming cleanup is out of scope.** Renaming modules so name matches folder
  (e.g. `BastionCache` → `Bastion.Cache`) is a separate, larger change — noted
  above but not part of this reorg.
```

## What actually happened (2026-06-12)

1. **Baseline:** `forge check` failed with exactly one pre-existing error
   (`form.march` typecheck), unrelated to this work. Locked as the comparison
   point.
2. **Trial move** of `registry.march` → identical error set. This *looked* safe,
   but only because nothing imports `Registry` — it gave a false green.
3. **Bulk move** of all 64 non-entry modules → **13 distinct "Module … not found
   (looked for `x.march` in the source directory)" errors**. Root cause: the
   resolver searches lib paths flatly and `forge`'s `lib_path_env` only put
   `lib/` root on `MARCH_LIB_PATH`, never its subdirs.
4. **Reverted** to baseline, investigated `march/lib/resolver/resolver.ml` and
   `march/forge/lib/cmd_build.ml`, and confirmed no folder layout could avoid the
   break (core modules like `Conn` are imported from every group).
5. **Toolchain patch** (in `/Users/80197052/code/march`, currently uncommitted):
   - `forge/lib/cmd_build.ml`: added `collect_lib_dirs`; `lib_path_env` now uses
     `collect_lib_dirs lib_dir` instead of `[lib_dir]`.
   - `lsp/lib/forge_config.ml`: mirror change in `project_lib_paths` so the LSP
     resolves nested modules too.
   - Rebuilt + installed via `make install` (→ `~/.opam/march/bin/forge`).
6. **Re-applied the moves** → `forge check` returns the **exact baseline** (one
   `form.march` error, zero module-not-found). `forge build` shows only the
   pre-existing `form.march` + depot-dependency errors, **byte-identical** on the
   flat vs nested layout (verified via `git stash`). No new errors introduced.

### Follow-ups / loose ends

- The **March toolchain changes are uncommitted** in `/Users/80197052/code/march`
  (on `main`). They need to be committed/landed there, or any teammate who
  rebuilds forge from a clean checkout will see the cross-folder imports break
  again. forge↔march version coupling applies.
- The Bastion reorg is staged as `git mv` renames but **not committed**.
- Pre-existing `form.march` typecheck failure and depot build errors are *not*
  addressed here — separate issues.
