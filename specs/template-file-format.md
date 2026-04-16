# Bastion: Template File Format (`.march.html`)

**Status**: Design | **Version**: 0.1 | **Part of**: [Bastion Design Spec](README.md)

---

## Overview

`.march.html` is Bastion's dedicated template file format. It compiles to the same IOList-producing March module that `~H"""..."""` produces, but optimises for HTML-heavy content: the file is primarily HTML, expressions are interpolated with `{expr}`, and control flow uses block tags that remain visible in the HTML structure.

**Use `.march.html` for:** layouts, page templates, shared components.  
**Use `~H"""..."""` for:** small inline snippets inside handlers or island `render` functions.

Both formats are equivalent in capability. Both desugar to `IOList.from_strings([...])` with auto-escaping.

---

## File Extension and Location

Template files use the `.march.html` extension and live under `templates/` or `components/` by convention:

```
src/
  my_app/
    components/
      nav.march.html
      user_card.march.html
    templates/
      layout.march.html
      pages/
        home.march.html
        about.march.html
```

The build tool (`forge`) discovers `.march.html` files as part of the source tree. Each file is lowered to a `.march` module before the March compiler sees it — `.march.html` is a compile-time transform, not a runtime feature.

---

## Module Mapping

A file's path under `src/` (relative to the app root) determines its module name:

| File | Generated module |
|------|-----------------|
| `src/my_app/templates/layout.march.html` | `MyApp.Templates.Layout` |
| `src/my_app/templates/pages/home.march.html` | `MyApp.Templates.Pages.Home` |
| `src/my_app/components/nav.march.html` | `MyApp.Components.Nav` |

The app module prefix (`MyApp`) is taken from `forge.toml`.

---

## Frontmatter

A `---` delimited frontmatter block at the top of the file declares the render function signature and any imports. This is what enables compile-time type checking of template arguments.

```
---
fn render(title: String, user: User, posts: List(Post))
use Bastion.Helpers
---
<!DOCTYPE html>
<html lang="en">
  <head><title>{title}</title></head>
  <body>
    ...
  </body>
</html>
```

The compiler generates:

```march
mod MyApp.Templates.Pages.Home do
  use Bastion.Helpers

  fn render(title: String, user: User, posts: List(Post)) : IOList do
    -- desugared from the template body
  end
end
```

**If there is no frontmatter**, the compiler generates `fn render(assigns: Map(String, Any))`. This works but loses compile-time type safety — treat it as a prototype escape hatch only.

---

## Expression Interpolation

Inside a `.march.html` file, `{expr}` interpolates a March expression. The result is **auto-escaped** (HTML entities). This is the default for safety.

```html
<h1>{user.name}</h1>
<p class={"card " ++ card_class(user)}>...</p>
<span>{Int.to_string(post.view_count)} views</span>
```

### Raw / trusted HTML

To insert pre-rendered HTML (e.g., a rendered child IOList or trusted Markdown output), prefix with `=`:

```html
{=rendered_body}
```

`{=expr}` skips escaping. The compiler enforces that `expr` has type `IOList` or `Html.Safe` — it will not accept a plain `String` without an explicit `Html.safe(...)` wrap, making unsafety visible at the call site.

### Inline styles

The `style` attribute accepts a March expression that evaluates to a CSS string:

```html
<div style={"color: " ++ brand_color ++ "; font-size: 14px;"}>...</div>
```

A `Css.style/1` helper builds a style string from a list of `(property, value)` pairs, filtering out `None` values:

```html
<div style={Css.style([
  ("color", Some(brand_color)),
  ("font-weight", if user.is_admin do Some("bold") else None end)
])}>
```

`style={...}` is just a special case of attribute expression interpolation — there is no separate mechanism. The `Css.style` helper is convenience sugar.

---

## Control Flow

Control flow uses `{#tag}` / `{/tag}` block delimiters. These are visible in the HTML structure and do not conflict with March tokens.

### `{#if}`

```html
{#if user.is_admin}
  <a href="/admin">Admin panel</a>
{/if}

{#if posts != []}
  <ul>...</ul>
{:else}
  <p>No posts yet.</p>
{/if}
```

`{:else}` is the else branch. There is no `{:else if}` — nest a new `{#if}` inside `{:else}` for multi-branch logic. This keeps the structure explicit.

### `{#for}`

```html
<ul>
  {#for post in posts}
    <li>
      <a href={"/posts/" ++ post.slug}>{post.title}</a>
      <span class="date">{Date.format(post.inserted_at)}</span>
    </li>
  {/for}
</ul>
```

`{#for item in expr}` desugars to `List.map(expr, fn item -> ...)`. The loop body is a template fragment; its output is an IOList chunk that is flattened into the parent.

`{#for}` does not support guards inline. Filter first with a `let` binding in the frontmatter or a `List.filter` call in the expression:

```html
{#for post in List.filter(posts, fn p -> p.published)}
  ...
{/for}
```

### `let` bindings

Local bindings can be introduced with `{let name = expr}`. They are in scope for the remainder of the template body (or the enclosing block tag):

```html
{let initials = String.slice(user.name, 0, 2) |> String.upcase()}
<div class="avatar">{initials}</div>
```

---

## Component Calls

Calling another `.march.html` component or a `~H`-based component function uses dot syntax:

```html
<.Nav user={current_user} active_section="home" />

<.UserCard user={post.author} size="compact" />
```

`<.ComponentName prop={expr} static-prop="value" />` is a self-closing component call. Static string props can be written without braces.

The compiler resolves `<.Nav />` to the module that matches `Nav` in the current scope. To be unambiguous, use the qualified path:

```html
<.MyApp.Components.Nav user={current_user} />
```

---

## Named Slots

Components that wrap content declare named slots in their frontmatter signature as `IOList` parameters:

```
---
fn render(title: String, header: IOList, body: IOList, footer: IOList \\ IOList.empty())
---
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{title}</title>
    <link rel="stylesheet" href="/static/css/app.css">
  </head>
  <body>
    <header class="site-header">{=header}</header>
    <main>{=body}</main>
    <footer>{=footer}</footer>
    <script src="/static/bastion.js"></script>
  </body>
</html>
```

Call sites pass slot content using `<:slot-name>` blocks nested inside the component tag:

```html
<.Layout title="Home">
  <:header>
    <nav>
      <a href="/">Home</a>
      <a href="/about">About</a>
    </nav>
  </:header>
  <:body>
    <h1>Welcome, {user.name}!</h1>
    <p>Here are your recent posts.</p>
  </:body>
</.Layout>
```

Rules:
- Slot names correspond 1:1 to `IOList` parameters in the component's frontmatter signature.
- The compiler type-checks that every required slot is provided. Optional slots use default args (`\\ IOList.empty()`).
- Slot content is compiled as a nested template fragment. It has access to the same bindings as the call site.
- Slot content is inserted with `{=slot_name}` (raw/trusted), since it is already an IOList.
- A component with a single unnamed content area uses a `children` slot by convention:

```
-- In the component's frontmatter:
fn render(children: IOList)
```

```html
-- At the call site (shorthand for a single unnamed slot):
<.Card>
  <p>This is the card body.</p>
</.Card>
```

Content placed directly between the open and close tags (with no `<:name>` wrapper) maps to the `children` parameter.

---

## Islands in Templates

The `<.island>` component embeds a WASM island. It is resolved by the compiler as a special case, not a regular component lookup:

```html
<.island name="Counter" id="counter-1" props={%{count: initial_count}} />

<.island name="SearchBar" id="search" lazy />
```

This is syntactic sugar over `IslandView.island_ssr/4`. See [islands-data-flow.md](islands-data-flow.md) for the full data flow design.

---

## Auto-escaping Rules

| Expression type | Behaviour |
|----------------|-----------|
| `String` | HTML-escaped |
| `Int`, `Float`, `Bool` | Converted to string, then HTML-escaped |
| `Html.Safe` | Inserted verbatim (no escaping) |
| `IOList` | Flattened verbatim (no escaping) |
| `{=expr}` | Requires `IOList` or `Html.Safe`; compiler error if `String` |

The `html_auto_escape` function (called by the desugarer) dispatches on these types at compile time where possible, with a runtime fallback for polymorphic cases.

---

## Source Maps

The `.march.html` lowering pass emits source location metadata that maps each desugared expression back to its line and column in the original `.march.html` file. Type errors, runtime errors, and test failures report positions in `.march.html`, not in the generated `.march` output.

This is a hard requirement — templates without source map support make errors nearly impossible to debug in larger files. The forge build pipeline must preserve these spans through the full compilation chain.

---

## Implementation Architecture

`.march.html` support is split across three repos. Each layer has a narrow, well-defined responsibility.

### Lowering pipeline

```
src/my_app/templates/pages/home.march.html
        │
        │  bastion lower  (Bastion CLI, invoked by forge preprocessor hook)
        ▼
.forge/generated/my_app/templates/pages/home.march
        │   (valid .march with ~H sigils; spans point back to .march.html lines)
        │
        │  march --check / march --compile
        ▼
type errors report: home.march.html:42:7  ✓
              not:  home.march:8:3        ✗
```

The generated `.march` files are build artifacts — never committed, always regenerated. The lowering pass runs before any typecheck or compile step.

---

### Layer 1 — March compiler (minimal changes)

**1a. Fix triple-quoted sigil parsing.**

The parser currently handles `~H"..."` and `~H"...${}"` but not `~H"""..."""`. Add the missing production to `lib/parser/parser.mly`. This is a small change that also unblocks `~H` in `.march` files directly.

**1b. Accept external source spans.**

The lowering pass needs to inject synthetic spans so errors resolve to `.march.html` line/column positions rather than positions in the generated `.march`. March already tracks spans throughout the pipeline — the compiler needs a mechanism (likely a pragma comment or a span-override table sidecar file) to substitute the file and position for a given AST node.

Design options:
- `-- @span home.march.html:42:7` pragma comments that the parser strips and applies as span overrides.
- A `.march.spans` sidecar JSON file that the compiler reads alongside the `.march` source and applies in one pass before typechecking.

Either works. The sidecar file is cleaner (no syntax pollution) and easier to generate from the lowering pass. **Recommendation: `.march.spans` sidecar.**

---

### Layer 2 — Forge (file discovery + preprocessor hook)

**2a. `[preprocessors]` table in `forge.toml`.**

Add a `[preprocessors]` table that maps file extensions to commands. Forge invokes the command for each matching file before passing sources to `march`:

```toml
# Bastion registers this in its own forge.toml, inherited by app projects via the dep
[preprocessors]
".march.html" = "bastion lower"
```

Forge calls `bastion lower <input.march.html> <output.march> <output.march.spans>` for each discovered `.march.html` file. Output goes to `.forge/generated/`.

**2b. Extend `find_march_files` to include generated sources.**

After running preprocessors, forge adds `.forge/generated/` to `MARCH_LIB_PATH` so the March compiler resolves generated modules alongside hand-written ones. No other changes to the compilation or typecheck flow needed.

**2c. Incremental builds.**

Forge should only re-run `bastion lower` on files whose content hash has changed since the last build. The `.forge/generated/` directory already stores the outputs — compare mtime or hash against the source file.

---

### Layer 3 — Bastion (the lowering pass + runtime)

**3a. `bastion lower` CLI subcommand.**

A new subcommand of the `bastion` CLI (the Bastion framework's own build/codegen tool):

```
bastion lower <input.march.html> <output.march> <output.march.spans>
```

It reads the `.march.html` file, runs the lowering pass, writes:
- `<output.march>` — valid March source with `~H` sigils
- `<output.march.spans>` — sidecar span table mapping generated nodes to original positions

The lowering pass itself is implemented in OCaml (same language as the March compiler and forge), either as a library or inline in the Bastion CLI. It does not depend on the March compiler — it only needs to parse `.march.html` syntax and emit text.

**3b. Lowering pass stages.**

The pass runs in order:

1. **Frontmatter extraction** — parse the `---...---` block; extract function signature and `use` declarations.
2. **HTML parsing** — lex the template body into a stream of: literal HTML, `{expr}` interpolations, `{#if}`/`{#for}`/`{let}`/`{=}` block tags, `<.Component>` calls, `<:slot>` blocks.
3. **Component resolution** — resolve unqualified `<.Nav />` names to fully-qualified module paths by scanning `MARCH_LIB_PATH` for matching modules.
4. **Slot assembly** — collect `<:slot-name>` blocks, verify all required slots are present (those without default args in the frontmatter signature), and emit them as IOList arguments.
5. **Code generation** — emit a `.march` module with a `~H"""..."""` body (so the existing `~H` desugarer in `desugar.ml` handles IOList construction, auto-escaping, island tags, and CSRF injection as normal).
6. **Span table generation** — write the `.march.spans` sidecar mapping each generated `~H` interpolation site back to its original `.march.html` position.

**3c. Runtime modules.**

These live in `lib/` and are already partially present or planned:

| Module | File | Status |
|--------|------|--------|
| `Html` — `escape/1`, `safe/1`, `Safe` type | `lib/html.march` | Planned in `templates.md`; implement now |
| `html_auto_escape/1` | `lib/html.march` | Called by `desugar.ml`; needs a runtime impl |
| `IOList` — `from_strings/1`, `empty/0`, `to_string/1` | `lib/io_list.march` | Partial; complete it |
| `Css.style/1` | `lib/css.march` | New |
| `IslandView.island_ssr/4` | `lib/island_view.march` | Exists |
| `CSRF.tag_string/1` | `lib/csrf.march` | Needed for CSRF work too |

---

### Dependency order

The pieces can be built in parallel except where noted:

```
March: fix triple-quoted ~H  ←── unblocks ~H in .march files immediately
                                   (independent of .march.html work)

March: .march.spans sidecar  ←┐
Forge: [preprocessors] hook  ←┤── these three can be designed together
Bastion: bastion lower CLI   ←┘   but built in this order

Bastion: runtime modules     ←── independent; can ship before lowering pass
```

The lowering pass can be prototyped without any March or forge changes by running `bastion lower` manually and pointing `march` directly at the output. This lets the Bastion-side work proceed ahead of the compiler/forge changes.

---

## Relationship to `~H`

`.march.html` and `~H` produce identical output. The choice is ergonomic:

| | `~H"""..."""` | `.march.html` |
|-|--------------|---------------|
| Best for | Inline snippets, island `render/1` | Layouts, pages, shared components |
| Type-checked signature | Inferred from call site | Explicit frontmatter |
| IDE HTML support | Limited (sigil in `.march`) | Full (dedicated file type) |
| Named slots | Not supported | Supported |
| File boundary | No (inline) | Yes (separate file) |

You can freely mix both in an application. A handler calls `Layout.render(...)` whether `Layout` is defined in a `.march.html` file or as a `~H` function in a `.march` file.

---

## Example: Page Template

`src/my_app/templates/pages/home.march.html`:

```
---
fn render(current_user: Option(User), posts: List(Post))
use MyApp.Helpers
---
<.Layout title="Home">
  <:header>
    <.Nav user={current_user} active_section="home" />
  </:header>
  <:body>
    <section class="hero">
      {#if current_user != None}
        {let Some(user) = current_user}
        <h1>Welcome back, {user.name}!</h1>
      {:else}
        <h1>Welcome to MyApp</h1>
      {/if}
    </section>

    <section class="posts">
      <h2>Recent Posts</h2>
      {#if posts != []}
        <ul class="post-list">
          {#for post in posts}
            <li class="post-item">
              <a href={Routes.post_path(post.slug)}>{post.title}</a>
              <span class="meta">
                {Date.format(post.inserted_at, :short)} ·
                {Int.to_string(post.view_count)} views
              </span>
            </li>
          {/for}
        </ul>
      {:else}
        <p class="empty-state">No posts yet.</p>
      {/if}
    </section>
  </:body>
</.Layout>
```

Called from a handler:

```march
fn handle_home(conn) do
  let posts = Blog.recent_posts(conn.assigns.db, 10)
  let page = MyApp.Templates.Pages.Home.render(conn.assigns.current_user, posts)
  Controller.html(conn, 200, page)
end
```

---

## Decisions

### `{let}` supports irrefutable pattern bindings

`{let pat = expr}` supports any irrefutable pattern, not just variable names. This is necessary for practical option unwrapping and consistent with how `let` works everywhere else in March:

```html
{let Some(user) = current_user}
{let {name, role} = get_user_info(conn)}
```

A refutable pattern (one that could fail to match) is a compile-time error in a template `{let}`, the same as it would be in a March `let` binding. Use `{#if}` for conditional unwrapping when the pattern may not match.

### Slot scope: call-site only

Slot content is evaluated in the **call site's scope**. The component's internal variables are not visible inside a `<:slot>` block.

```html
{let greeting = "Hello"}

<.Layout title="Home">
  <:header>
    -- `greeting` is in scope here (call-site variable) ✓
    <h1>{greeting}</h1>
    -- `inner_var` (a variable defined inside Layout's template) is NOT in scope ✗
  </:header>
</.Layout>
```

This keeps slot evaluation predictable: a slot body reads exactly like code at the call site, with no hidden variables injected by the component. Components that need to pass data *into* a slot should do so via explicit parameters — this is a Phase 2 concern (scoped slots / render props) and is out of scope for v1.

### Multiple render functions per file

Deferred. One `render/n` per file. Revisit based on usage patterns after v1.
