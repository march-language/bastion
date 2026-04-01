# Forge Scaffolder Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `lib/forge/scaffold.march` so `forge bastion.new <name>` generates a complete, API-correct Bastion application skeleton.

**Architecture:** All changes are in one file — `lib/forge/scaffold.march`. The file contains private template functions that return generated source-file strings, plus a `scaffold/1` function that creates the directory tree and writes every file. We replace stale templates with correct ones (aligned to `lib/bastion.march`), add two new template functions, delete five dead ones, update the directory layout in `scaffold/1`, and remove old write calls.

**Tech Stack:** March language, forge build tool. No external dependencies. The March compiler is at `/Users/80197052/code/march` if parse-checking is needed.

---

## File Map

| File | Action |
|---|---|
| `lib/forge/scaffold.march` | Modify — all changes in this one file |

No other files are created or modified.

---

### Task 1: Update `gitignore`, `readme`, and `app_css` templates

These are small, self-contained changes to existing functions.

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Open the file and confirm current state**

  Read `lib/forge/scaffold.march` lines 94–104. Confirm:
  - `gitignore()` returns `"/.march/\n"` (one line)
  - `readme(name)` returns `"# " ++ capitalize(name) ++ "\n"` (one line)
  - `app_css(name)` starts with `"/* app.css — " ++ name ++ " styles */\n"` and uses the `name` arg only in that comment

- [ ] **Step 2: Update `gitignore` to include island build artifacts**

  Replace the body of `pfn gitignore()` with:
  ```
  "/.march/\n/islands/*.wasm\n/islands/*.glue.js\n"
  ```

- [ ] **Step 3: Replace `readme(name)` with `readme(name, pascal)` — multi-section**

  Replace the entire `pfn readme(name)` function with:
  ```march
  pfn readme(name, pascal) do
    "# " ++ pascal ++ "\n\n" ++
    "A [Bastion](https://github.com/march-lang/bastion) web application.\n\n" ++
    "## Getting started\n\n" ++
    "```bash\n" ++
    "forge deps\n" ++
    "forge run\n" ++
    "```\n\n" ++
    "Visit http://localhost:4000\n\n" ++
    "## Structure\n\n" ++
    "```\n" ++
    "lib/\n" ++
    "  " ++ name ++ ".march          # Router and server entry point\n" ++
    "  page_controller.march  # Page handlers\n" ++
    "  counter.march          # Example island component\n" ++
    "public/                  # Static assets (CSS, JS, images)\n" ++
    "islands/                 # Compiled .wasm island modules\n" ++
    "test/                    # Tests\n" ++
    "```\n\n" ++
    "## Islands\n\n" ++
    "Compile an island to WASM:\n\n" ++
    "```bash\n" ++
    "march --compile --target wasm32-unknown-unknown lib/counter.march -o islands/Counter.wasm\n" ++
    "```\n"
  end
  ```

- [ ] **Step 4: Replace `app_css(name)` with `app_css()` — drop unused `name` arg, use bastion.march content**

  Replace the entire `pfn app_css(name)` with:
  ```march
  pfn app_css() do
    "*, *::before, *::after { box-sizing: border-box; }\n\n" ++
    "body {\n" ++
    "  font-family: system-ui, sans-serif;\n" ++
    "  max-width: 800px;\n" ++
    "  margin: 0 auto;\n" ++
    "  padding: 1rem;\n" ++
    "  color: #1a1a1a;\n" ++
    "}\n\n" ++
    "nav { margin-bottom: 2rem; }\n" ++
    "nav a { margin-right: 1rem; color: #0070f3; text-decoration: none; }\n" ++
    "nav a:hover { text-decoration: underline; }\n\n" ++
    ".counter {\n" ++
    "  display: inline-flex;\n" ++
    "  align-items: center;\n" ++
    "  gap: 0.75rem;\n" ++
    "  font-size: 1.5rem;\n" ++
    "}\n\n" ++
    ".counter button {\n" ++
    "  font-size: 1.5rem;\n" ++
    "  width: 2.5rem;\n" ++
    "  height: 2.5rem;\n" ++
    "  border: 1px solid #ccc;\n" ++
    "  border-radius: 6px;\n" ++
    "  cursor: pointer;\n" ++
    "  background: white;\n" ++
    "}\n\n" ++
    ".counter button:hover { background: #f0f0f0; }\n"
  end
  ```

- [ ] **Step 5: Verify by reading the updated sections**

  Read the three updated functions in `lib/forge/scaffold.march`. Confirm:
  - `gitignore()` now has 3 lines
  - `readme` is now `pfn readme(name, pascal)` and contains "## Getting started"
  - `app_css()` takes no arguments and contains `.counter` CSS class

---

### Task 2: Add `counter_island_source` and `test_source` template functions

These are new functions. Add them after `config_prod()` in the file (before the `-- ── Scaffold ──` separator).

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Add `counter_island_source()` after `config_prod()`**

  Insert after the closing `end` of `pfn config_prod()`.

  **Important escaping note:** Triple-quoted sigil syntax (`~H"""..."""`) cannot appear as literal text inside a March string. The existing file uses `let q = "\"\"\""` to build triple-quote delimiters as string values (see `layout_source` in the current file). Apply the same pattern here. Similarly, `${...}` interpolations that should appear in the *generated* file's source must be produced using the existing `iv/1` helper: `iv("int_to_string(st.count)")` → `"${int_to_string(st.count)}"`.

  ```march
  pfn counter_island_source() do
    let q = "\"\"\""
    "-- Counter — example island component.\n" ++
    "--\n" ++
    "-- Islands follow the create/update/render protocol.\n" ++
    "-- Derive Json on State and Msg to get automatic update_json/render_json\n" ++
    "-- bridge functions generated by the compiler.\n\n" ++
    "mod Counter do\n\n" ++
    "  type Props = { initial : Int }\n" ++
    "  type State = { count : Int }\n" ++
    "  type Msg = Increment | Decrement | Reset\n\n" ++
    "  derive Json for State\n" ++
    "  derive Json for Msg\n\n" ++
    "  fn create(props : Props) : State do\n" ++
    "    { count = props.initial }\n" ++
    "  end\n\n" ++
    "  fn update(st : State, msg : Msg) : State do\n" ++
    "    match msg do\n" ++
    "    Increment -> { count = st.count + 1 }\n" ++
    "    Decrement -> { count = st.count - 1 }\n" ++
    "    Reset     -> { count = 0 }\n" ++
    "    end\n" ++
    "  end\n\n" ++
    "  fn render(st : State) : IOList do\n" ++
    "    ~H" ++ q ++ "\n" ++
    "    <div id=\"counter\" class=\"counter\">\n" ++
    "      <button data-msg=\"Decrement\">-</button>\n" ++
    "      <span class=\"count\">" ++ iv("int_to_string(st.count)") ++ "</span>\n" ++
    "      <button data-msg=\"Increment\">+</button>\n" ++
    "    </div>\n" ++
    "    " ++ q ++ "\n" ++
    "  end\n\n" ++
    "  -- update_json and render_json are auto-generated because State and Msg derive Json.\n\n" ++
    "end\n"
  end
  ```

- [ ] **Step 2: Add `test_source(name, pascal)` after `counter_island_source()`**

  Insert immediately after:
  ```march
  pfn test_source(name, pascal) do
    "mod " ++ pascal ++ "Test do\n\n" ++
    "  import Counter\n\n" ++
    "  describe \"Counter island\" do\n\n" ++
    "    test \"render_json shows initial count\" do\n" ++
    "      let html = Counter.render_json(\"{\\\"count\\\":0}\")\n" ++
    "      assert (String.contains(html, \"0\"))\n" ++
    "    end\n\n" ++
    "    test \"update_json increment increases count\" do\n" ++
    "      let next = Counter.update_json(\"{\\\"count\\\":5}\", \"{\\\"tag\\\":\\\"Increment\\\"}\")\n" ++
    "      assert (String.contains(next, \"6\"))\n" ++
    "    end\n\n" ++
    "    test \"update_json decrement decreases count\" do\n" ++
    "      let next = Counter.update_json(\"{\\\"count\\\":5}\", \"{\\\"tag\\\":\\\"Decrement\\\"}\")\n" ++
    "      assert (String.contains(next, \"4\"))\n" ++
    "    end\n\n" ++
    "    test \"render_json produces correct HTML\" do\n" ++
    "      let html = Counter.render_json(\"{\\\"count\\\":42}\")\n" ++
    "      assert (String.contains(html, \"42\"))\n" ++
    "      assert (String.contains(html, \"data-msg\"))\n" ++
    "      assert (String.contains(html, \"Increment\"))\n" ++
    "      assert (String.contains(html, \"Decrement\"))\n" ++
    "    end\n\n" ++
    "    test \"update_json then render_json round-trip\" do\n" ++
    "      let next = Counter.update_json(\"{\\\"count\\\":0}\", \"{\\\"tag\\\":\\\"Increment\\\"}\")\n" ++
    "      let html = Counter.render_json(next)\n" ++
    "      assert (String.contains(html, \"1\"))\n" ++
    "    end\n\n" ++
    "  end\n\n" ++
    "end\n"
  end
  ```

  > Note: The `name` parameter is available for the module doc comment if wanted, but the test module name uses `pascal`. Keeping `name` in the signature for consistency even if unused is fine.

- [ ] **Step 3: Verify new functions exist**

  Grep `lib/forge/scaffold.march` for `counter_island_source` and `test_source`. Both should appear.

---

### Task 3: Rewrite `main_source(pascal)`

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Replace `pfn main_source(pascal)` entirely**

  The current `main_source` generates code using `BastionDev` and a separate router dispatch. Replace the entire function with:

  ```march
  pfn main_source(pascal) do
    "mod " ++ pascal ++ " do\n\n" ++
    "  import HttpServer\n" ++
    "  import Router\n" ++
    "  import Middleware\n" ++
    "  import Controller\n" ++
    "  import IslandSocket\n" ++
    "  import IslandAssets\n" ++
    "  import Static\n" ++
    "  import PageController\n" ++
    "  import Counter\n\n" ++
    "  pfn build_router() : Router do\n" ++
    "    Router.new()\n" ++
    "    |> Router.action(Get, \"/\",      fn conn -> PageController.home(conn))\n" ++
    "    |> Router.action(Get, \"/about\", fn conn -> PageController.about(conn))\n" ++
    "    |> Router.get(\"/health\", fn conn -> health(conn))\n" ++
    "  end\n\n" ++
    "  pfn health(conn : Conn) : Conn do\n" ++
    "    Controller.json(conn, 200, \"{\\\"status\\\":\\\"ok\\\"}\")\n" ++
    "  end\n\n" ++
    "  pfn build_island_registry() : IslandSocket.Registry do\n" ++
    "    IslandSocket.new_registry()\n" ++
    "    |> IslandSocket.register(\"Counter\",\n" ++
    "         fn (state, msg) -> Counter.update_json(state, msg),\n" ++
    "         fn state -> Counter.render_json(state))\n" ++
    "  end\n\n" ++
    "  fn main() : Unit do\n" ++
    "    let router   = build_router()\n" ++
    "    let plug     = Router.to_plug(router)\n" ++
    "    let registry = build_island_registry()\n\n" ++
    "    let island_ws     = IslandSocket.plug(IslandSocket.default_config(), registry)\n" ++
    "    let island_assets = IslandAssets.plug(IslandAssets.default_config())\n" ++
    "    let static_files  = Static.serve(\"public\")\n\n" ++
    "    let app = fn conn -> do\n" ++
    "      let c = island_ws(conn)\n" ++
    "      match HttpServer.halted(c) do true -> c | false -> do\n" ++
    "      let c = island_assets(c)\n" ++
    "      match HttpServer.halted(c) do true -> c | false -> do\n" ++
    "      let c = static_files(c)\n" ++
    "      match HttpServer.halted(c) do true -> c | false -> do\n" ++
    "      let c = Middleware.logger(c)\n" ++
    "      let c = Middleware.request_id(c)\n" ++
    "      let c = Middleware.cors(c)\n" ++
    "      match HttpServer.halted(c) do\n" ++
    "      true  -> c\n" ++
    "      false -> plug(c)\n" ++
    "      end\n" ++
    "      end end end\n" ++
    "    end\n\n" ++
    "    println(\"" ++ pascal ++ " listening on http://localhost:4000\")\n" ++
    "    HttpServer.new(4000)\n" ++
    "    |> HttpServer.plug(app)\n" ++
    "    |> HttpServer.listen()\n" ++
    "  end\n\n" ++
    "end\n"
  end
  ```

- [ ] **Step 2: Verify the function was updated**

  Read `main_source` in `lib/forge/scaffold.march`. Confirm it contains `"build_island_registry"` and `"IslandSocket.plug"` and does NOT contain `"BastionDev"`.

---

### Task 4: Rewrite `page_controller_source(pascal)`

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Replace `pfn page_controller_source(pascal)` entirely**

  The current version generates nested `{Pascal}.Controllers.PageController` with `HttpServer.html`. Replace with flat `PageController` using `Controller.ActionResult`.

  **Escaping rules (same as in `counter_island_source`):**
  - `~H"""..."""` sigil: use `let q = "\"\"\""` and assemble as `"~H" ++ q ++ "...\n" ++ q`
  - `${varname}` interpolations that must survive into the *generated* file: use `iv("varname")`
  - The `~H"""` that appears inside `home` and `about` action bodies wraps a *string argument* in the generated source — those are `~H""" ... """` calls inside the generated PageController. Use `q` there too.

  ```march
  pfn page_controller_source(pascal) do
    let q = "\"\"\""
    "mod PageController do\n\n" ++
    "  import HttpServer\n" ++
    "  import Controller\n" ++
    "  import Response\n\n" ++
    "  fn home(conn : Conn) : Controller.ActionResult do\n" ++
    "    let html = layout(\"Home\", ~H" ++ q ++ "\n" ++
    "      <h1>Welcome to " ++ pascal ++ "!</h1>\n" ++
    "      <p>Edit <code>lib/page_controller.march</code> to get started.</p>\n" ++
    "      <p><a href=\"/about\">About</a></p>\n" ++
    "      <h2>Interactive Counter (Island)</h2>\n" ++
    "      <div data-march-island=\"Counter\" data-march-state='{\"count\":0}'></div>\n" ++
    "    " ++ q ++ ")\n" ++
    "    Controller.ActionOk(Response.html(conn, 200, html))\n" ++
    "  end\n\n" ++
    "  fn about(conn : Conn) : Controller.ActionResult do\n" ++
    "    let html = layout(\"About\", ~H" ++ q ++ "\n" ++
    "      <h1>About</h1>\n" ++
    "      <p>Built with <a href=\"https://github.com/march-lang/bastion\">Bastion</a>.</p>\n" ++
    "    " ++ q ++ ")\n" ++
    "    Controller.ActionOk(Response.html(conn, 200, html))\n" ++
    "  end\n\n" ++
    "  pfn layout(title : String, body : String) : String do\n" ++
    "    ~H" ++ q ++ "\n" ++
    "    <!DOCTYPE html>\n" ++
    "    <html lang=\"en\">\n" ++
    "    <head>\n" ++
    "      <meta charset=\"utf-8\">\n" ++
    "      <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" ++
    "      <title>" ++ iv("title") ++ " · " ++ pascal ++ "</title>\n" ++
    "      <link rel=\"stylesheet\" href=\"/css/app.css\">\n" ++
    "    </head>\n" ++
    "    <body>\n" ++
    "      <nav><a href=\"/\">Home</a> <a href=\"/about\">About</a></nav>\n" ++
    "      <main>" ++ iv("body") ++ "</main>\n" ++
    "      <script src=\"/_bastion/islands.js\"></script>\n" ++
    "    </body>\n" ++
    "    </html>\n" ++
    "    " ++ q ++ "\n" ++
    "  end\n\n" ++
    "end\n"
  end
  ```

- [ ] **Step 2: Verify the function was updated**

  Read `page_controller_source` in `lib/forge/scaffold.march`. Confirm it contains `"PageController"` (not `{Pascal}.Controllers.PageController`), `"Controller.ActionResult"`, and `"Response.html"`. Confirm it does NOT contain `"HttpServer.html"`.

---

### Task 5: Remove five dead template functions

The following functions are no longer called and should be deleted:
- `router_source(pascal)` — router is now inlined in main_source
- `layout_source(name, pascal)` — layout is now inlined in page_controller_source
- `page_index_source(name, pascal)` — index view is now inlined in page_controller_source
- `app_js()` — replaced by `public/js/.gitkeep`
- `test_helper_source(pascal)` — replaced by `test_source`
- `test_page_controller_source(pascal)` — replaced by `test_source`

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Delete `router_source`**

  Remove the entire `pfn router_source(pascal) do ... end` block.

- [ ] **Step 2: Delete `layout_source`**

  Remove the entire `pfn layout_source(name, pascal) do ... end` block.

- [ ] **Step 3: Delete `page_index_source`**

  Remove the entire `pfn page_index_source(name, pascal) do ... end` block.

- [ ] **Step 4: Delete `app_js`**

  Remove the entire `pfn app_js() do ... end` block.

- [ ] **Step 5: Delete `test_helper_source`**

  Remove the entire `pfn test_helper_source(pascal) do ... end` block.

- [ ] **Step 6: Delete `test_page_controller_source`**

  Remove the entire `pfn test_page_controller_source(pascal) do ... end` block.

- [ ] **Step 7: Verify deletions**

  Grep `lib/forge/scaffold.march` for `router_source`, `layout_source`, `page_index_source`, `app_js`, `test_helper_source`, `test_page_controller_source`. All should return zero results (function definitions gone).

---

### Task 6: Update the `scaffold/1` function

This is the function that creates directories and writes files. Replace the body to match the new file set.

**Files:**
- Modify: `lib/forge/scaffold.march`

- [ ] **Step 1: Replace directory creation lines**

  Inside `fn scaffold(name) do`, in the `else` branch, replace:
  ```march
  let _ = Dir.mkdir_p(name ++ "/lib/" ++ name ++ "/controllers")
  let _ = Dir.mkdir_p(name ++ "/lib/" ++ name ++ "/templates/page")
  let _ = Dir.mkdir_p(name ++ "/config")
  let _ = Dir.mkdir_p(name ++ "/assets/css")
  let _ = Dir.mkdir_p(name ++ "/assets/js")
  let _ = Dir.mkdir_p(name ++ "/test/controllers")
  ```
  with:
  ```march
  let _ = Dir.mkdir_p(name ++ "/lib")
  let _ = Dir.mkdir_p(name ++ "/config")
  let _ = Dir.mkdir_p(name ++ "/public/css")
  let _ = Dir.mkdir_p(name ++ "/public/js")
  let _ = Dir.mkdir_p(name ++ "/islands")
  let _ = Dir.mkdir_p(name ++ "/test")
  ```

- [ ] **Step 2: Replace the write calls**

  After the `let write = fn path -> fn content -> do ... end` definition, replace all `write(...)` calls with:

  ```march
  write("forge.toml")(forge_toml(name))
  write(".editorconfig")(editorconfig())
  write(".gitignore")(gitignore())
  write("README.md")(readme(name, pascal))
  write("lib/" ++ name ++ ".march")(main_source(pascal))
  write("lib/page_controller.march")(page_controller_source(pascal))
  write("lib/counter.march")(counter_island_source())
  write("config/config.march")(config_main())
  write("config/dev.march")(config_dev())
  write("config/test.march")(config_test())
  write("config/prod.march")(config_prod())
  write("public/css/app.css")(app_css())
  write("public/js/.gitkeep")("")
  write("islands/.gitkeep")("")
  write("test/" ++ name ++ "_test.march")(test_source(name, pascal))
  ```

  Note the changes from the current version:
  - `write("README.md")` now passes `(readme(name, pascal))` — two args
  - `write("lib/" ++ name ++ ".march")` is the only file under lib with a dynamic name
  - `write("lib/page_controller.march")` — flat path, no nested dirs
  - `write("lib/counter.march")` — new
  - `write("public/css/app.css")` — was `assets/css/app.css`
  - `write("public/css/app.css")(app_css())` — no arg to app_css
  - `write("public/js/.gitkeep")("")` — new
  - `write("islands/.gitkeep")("")` — new
  - `write("test/" ++ name ++ "_test.march")` — single test file, replaces two
  - All old writes for router.march, templates/*, assets/js/app.js, test/test_helper.march, test/controllers/* are gone

- [ ] **Step 3: Verify scaffold writes match file tree in spec**

  Read `scaffold/1` in `lib/forge/scaffold.march`. Cross-check each `write(...)` call against the "Generated App Structure" table in the spec:
  ```
  forge.toml ✓  .editorconfig ✓  .gitignore ✓  README.md ✓
  lib/{name}.march ✓  lib/page_controller.march ✓  lib/counter.march ✓
  config/config.march ✓  config/dev.march ✓  config/test.march ✓  config/prod.march ✓
  public/css/app.css ✓  public/js/.gitkeep ✓
  islands/.gitkeep ✓
  test/{name}_test.march ✓
  ```

---

### Task 7: Final verification and commit

- [ ] **Step 1: Read the complete updated file**

  Read all of `lib/forge/scaffold.march`. Verify:
  - Module starts with `mod Forge.Scaffold do`
  - Helper functions: `capitalize`, `snake_to_pascal`, `iv` — unchanged
  - Template functions present: `forge_toml`, `main_source`, `page_controller_source`, `counter_island_source`, `config_main`, `config_dev`, `config_test`, `config_prod`, `app_css`, `test_source`, `editorconfig`, `gitignore`, `readme`
  - Template functions absent: `router_source`, `layout_source`, `page_index_source`, `app_js`, `test_helper_source`, `test_page_controller_source`
  - `scaffold/1` function creates: `lib/`, `config/`, `public/css/`, `public/js/`, `islands/`, `test/`
  - `scaffold/1` does NOT create: `lib/{name}/controllers`, `lib/{name}/templates`, `assets/`
  - `git init` call is still present at the end of `scaffold/1`

- [ ] **Step 2: Check for references to deleted functions**

  Grep `lib/forge/scaffold.march` for `router_source`, `layout_source`, `page_index_source`, `app_js(`, `test_helper_source`, `test_page_controller_source`. Each should return zero results.

- [ ] **Step 3: Check for stale asset path references**

  Grep `lib/forge/scaffold.march` for `assets/`. Should return zero results.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/forge/scaffold.march docs/superpowers/specs/2026-04-01-forge-scaffolder-fix-design.md docs/superpowers/plans/2026-04-01-forge-scaffolder-fix.md
  git commit -m "fix: update forge bastion.new scaffolder to current Bastion API

  - Rewrite main_source to use Router.action/get, IslandSocket,
    IslandAssets, Static, and HttpServer.new/plug/listen
  - Rewrite page_controller_source to flat PageController module
    with Controller.ActionResult and inline ~H templates
  - Add counter_island_source (Counter island example with derive Json)
  - Add test_source with Counter island round-trip tests
  - Replace assets/ with public/, add islands/ directory
  - Update .gitignore to exclude island build artifacts
  - Expand README to multi-section getting-started guide
  - Remove dead template functions: router_source, layout_source,
    page_index_source, app_js, test_helper_source, test_page_controller_source"
  ```
