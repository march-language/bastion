# Design: Fix `forge bastion.new` Scaffolder

**Date**: 2026-04-01
**Status**: In Review
**File**: `lib/forge/scaffold.march`

---

## Problem

`lib/forge/scaffold.march` generates a skeleton Bastion app, but the generated code uses a stale API and is missing key files. A second, more up-to-date scaffolder exists in `lib/bastion.march` that uses the correct Bastion API.

The forge scaffolder already generates `forge.toml` and `config/` (fixed in recent commits bfd3212–ccaa557), so the user-reported missing files are resolved — but the generated code quality needs aligning with the reference scaffolder in `lib/bastion.march`.

---

## Goals

1. Align generated app code with the correct Bastion API (as used in `lib/bastion.march`).
2. Add `islands/` directory with `.gitkeep` and `lib/counter.march` island example.
3. Fix static asset directory: `assets/` → `public/`.
4. Remove `app.js` (replaced by `public/js/.gitkeep`; no generated JS needed).
5. Remove the separate `lib/{name}/router.march` file (router is inlined in the main module).
6. Remove the separate `lib/{name}/templates/` directory (templates are inlined in page_controller).
7. Flatten `lib/` structure: `lib/{name}.march`, `lib/page_controller.march`, `lib/counter.march`.
8. Update `.gitignore` to exclude island build artifacts (`/islands/*.wasm`, `/islands/*.glue.js`).
9. Expand `README.md` to include "Getting started", "Structure", and "Islands" sections.
10. Replace the two test files (test_helper + test_page_controller) with one `test/{name}_test.march` containing Counter island round-trip tests.
11. Keep the config files (`config/config.march`, `dev.march`, `test.march`, `prod.march`) that are unique to the forge scaffolder.
12. Keep `bastion = "*"` in `forge.toml` — not `{ path = "../bastion" }` — because path deps only work in a monorepo layout; scaffolded apps resolve from the registry.

---

## Generated App Structure (After Fix)

```
{name}/
├── forge.toml                      # package manifest, bastion = "*"
├── .editorconfig
├── .gitignore                      # /.march/, /islands/*.wasm, /islands/*.glue.js
├── README.md                       # multi-section: getting started, structure, islands
├── config/
│   ├── config.march                # Config module (base, no env-specific logic)
│   ├── dev.march                   # Config.Dev — port 4000, debug true
│   ├── test.march                  # Config.Test — port 4001, debug false
│   └── prod.march                  # Config.Prod — reads PORT env var
├── lib/
│   ├── {name}.march                # Main module: build_router, build_island_registry, main
│   ├── page_controller.march       # PageController with inline ~H templates
│   └── counter.march               # Counter island (create/update/render + derive Json)
├── public/
│   ├── css/app.css                 # basic reset + nav + counter styles
│   └── js/.gitkeep
├── islands/
│   └── .gitkeep                    # compiled .wasm files go here
└── test/
    └── {name}_test.march           # Counter island round-trip tests
```

---

## Key Changes in Generated Code

### Removed files

| Current file | Disposition |
|---|---|
| `lib/{name}/router.march` | Removed — router inlined in `lib/{name}.march` |
| `lib/{name}/controllers/page_controller.march` | Replaced by flat `lib/page_controller.march` |
| `lib/{name}/templates/layout.march` | Removed — layout inlined in page_controller |
| `lib/{name}/templates/page/index.march` | Removed — index template inlined in page_controller |
| `assets/css/app.css` | Moved to `public/css/app.css` |
| `assets/js/app.js` | Removed — replaced by `public/js/.gitkeep` |
| `test/test_helper.march` | Removed — replaced by `test/{name}_test.march` |
| `test/controllers/test_page_controller.march` | Removed — replaced by `test/{name}_test.march` |

### `lib/{name}.march` — main module

Uses the correct Bastion API with island infrastructure:

```march
mod {Pascal} do

  import HttpServer
  import Router
  import Middleware
  import Controller
  import IslandSocket
  import IslandAssets
  import Static
  import PageController
  import Counter

  pfn build_router() : Router do
    Router.new()
    |> Router.action(Get, "/",      fn conn -> PageController.home(conn))
    |> Router.action(Get, "/about", fn conn -> PageController.about(conn))
    |> Router.get("/health", fn conn -> health(conn))
  end

  pfn health(conn : Conn) : Conn do
    Controller.json(conn, 200, "{\"status\":\"ok\"}")
  end

  pfn build_island_registry() : IslandSocket.Registry do
    IslandSocket.new_registry()
    |> IslandSocket.register("Counter",
         fn (state, msg) -> Counter.update_json(state, msg),
         fn state -> Counter.render_json(state))
  end

  fn main() : Unit do
    let router   = build_router()
    let plug     = Router.to_plug(router)
    let registry = build_island_registry()

    let island_ws     = IslandSocket.plug(IslandSocket.default_config(), registry)
    let island_assets = IslandAssets.plug(IslandAssets.default_config())
    let static_files  = Static.serve("public")

    let app = fn conn -> do
      let c = island_ws(conn)
      match HttpServer.halted(c) do true -> c | false -> do
      let c = island_assets(c)
      match HttpServer.halted(c) do true -> c | false -> do
      let c = static_files(c)
      match HttpServer.halted(c) do true -> c | false -> do
      let c = Middleware.logger(c)
      let c = Middleware.request_id(c)
      let c = Middleware.cors(c)
      match HttpServer.halted(c) do
      true  -> c
      false -> plug(c)
      end
      end end end
    end

    println("{Pascal} listening on http://localhost:4000")
    HttpServer.new(4000)
    |> HttpServer.plug(app)
    |> HttpServer.listen()
  end

end
```

### `lib/page_controller.march`

Flat module (not nested under `{Pascal}.Controllers`). Uses `Controller.ActionResult` and `Response.html`. Layout and page templates are inlined as `~H` sigil strings — no separate template files.

### `lib/counter.march`

Island following the `create/update/render` protocol. `derive Json for State` and `derive Json for Msg` cause the compiler to generate `update_json`/`render_json` bridge functions automatically.

### `test/{name}_test.march`

Replaces the previous two test files. Tests the Counter island via the JSON bridge functions:
- `render_json` shows initial count
- `update_json` with Increment/Decrement produces correct state
- `update_json` then `render_json` round-trip

### `README.md`

Multi-section README with "Getting started" (`forge deps` + `forge run`), "Structure" (directory tree explanation), and "Islands" (WASM compile command). Replaces the single-line `# {Name}` stub.

---

## Scaffold Function Changes

The `scaffold/1` function in `lib/forge/scaffold.march` is updated to:
- Create `public/css/` and `public/js/` instead of `assets/css/` and `assets/js/`
- Create `islands/` directory
- Remove directory creation for `lib/{name}/controllers` and `lib/{name}/templates/page`
- Write the new flat file set; remove calls to write router.march, layout.march, page/index.march, app.js, test_helper.march, test/controllers/
- Write `public/js/.gitkeep` and `islands/.gitkeep`

---

## Out of Scope

- Changing `bastion = "*"` to a path reference (path deps are for monorepo development, not scaffolded apps).
- `~H` sigil implementation (still blocked on March lexer changes per `specs/open-questions.md §1`; the generated code will contain `~H` strings as stubs).
- Config loading at runtime (not yet implemented; the config files are stubs for future use).
- Eliminating the dual-scaffolder situation (`lib/bastion.march` vs `lib/forge/scaffold.march`).
