# Bastion

**Bastion is March's web framework — the Phoenix to March's Elixir.**

It gives you server-rendered HTML by default, typed WASM *islands* for the parts
of the page that need to be interactive, pattern-matched routing, typed
middleware pipelines, and real-time WebSocket channels — all written in
[March](https://github.com/march-language/march), typed end to end.

---

## Design philosophy

Bastion is built around a handful of opinions:

- **Server-first, islands where you need them.** Pages are rendered on the
  server and shipped as HTML. Interactivity is added surgically through
  *islands* — self-contained `init / update / render` components (Elm-style)
  that are written in March, server-rendered for the first paint, and hydrated
  as WASM in the browser. There is no monolithic SPA and no client/server type
  drift: the same typed island runs in both places.

- **The connection is a value.** Every request is a single `Conn` value threaded
  through a pipeline of *plugs* (`Conn -> Conn`). Middleware, routing,
  controllers, and after-send hooks are all just plugs. This is the plug/Conn
  model from Phoenix, made typed.

- **Types all the way through.** Routing matches on method + path via function
  heads, middleware pipelines track the conn's state transitions in the type
  system, forms validate through changeset-style `Gate` pipelines, and island
  messages/state are typed March values. If it compiles, the wiring is sound.

- **Batteries included, no magic.** Auth, sessions, CSRF, CORS, security
  headers, caching, rate limiting, PubSub/channels, uploads, idempotency,
  telemetry, and a Depot (Postgres) integration all ship in `lib/`. They are
  ordinary March modules you compose explicitly — nothing is injected behind
  your back.

- **The framework is a library.** Bastion has no runtime daemon of its own. You
  build a plug, hand it to `BastionServer.start_plug`, and that is your app.
  Generators (`forge bastion.gen.*`) scaffold code you own and can read.

---

## Requirements

- The **March compiler and `forge` build tool**. Bastion depends on the March
  compiler at `/Users/80197052/code/march` (see `CLAUDE.md`); build `forge` from
  that toolchain and put it on your `PATH`.
- **`shasum`** (from `coreutils`) for content-hashing WASM island bundles — see
  [Known limitations](#known-limitations).
- **PostgreSQL**, only if you use the Depot database integration.

## Install

Bastion is a March library (`type = "lib"` in `forge.toml`). To use it in an
application, add it as a dependency in your app's `forge.toml`:

```toml
[deps]
bastion = { path = "/path/to/bastion" }
# or, once published to a git remote:
# bastion = { git = "https://github.com/march-language/bastion.git", branch = "main" }
```

To work on Bastion itself:

```bash
git clone <bastion-repo> bastion
cd bastion
forge check        # fast typecheck of the whole project
forge test         # run the test suite
```

Scaffold a brand-new application with the generator:

```bash
forge bastion.new my_app
cd my_app
forge bastion.server        # dev server with live reload, on http://localhost:4000
```

---

## Basic usage

### A minimal app

Routing matches method + path; handlers are plugs (`Conn -> Conn`). You compose
middleware into a pipeline and hand the resulting plug to the server:

```march
mod Hello do
  fn home(conn : Conn) : Conn do
    Response.html(conn, 200, "<h1>Hello from Bastion</h1>")
  end

  fn health(conn : Conn) : Conn do
    Response.json(conn, 200, "{\"status\":\"ok\"}")
  end

  fn main() : Unit do
    let router =
      Router.new()
      |> Router.get("/",       home)
      |> Router.get("/health", health)

    let plug = fn conn ->
      Middleware.pipeline([
        Middleware.logger,
        Middleware.request_id,
        Router.to_plug(router)
      ], conn)

    BastionServer.start_plug(plug, Bastion.default_opts(4000))
  end
end
```

A fuller, runnable version — scopes, path/query params, JSON bodies, static
files, and a 404 fallback — lives in
[`examples/blog.march`](examples/blog.march).

### Request & response helpers

- **Request:** `Request.query_param`, `Request.path_param`, `Request.json_body`
- **Response:** `Response.html`, `Response.json`, `Response.text`,
  `Response.not_found_`, `Response.bad_request`, plus `redirect` / `assign` /
  `send_resp` from the controller helpers.
- **Routing:** `Router.get/post/...`, `Router.scope("/api/v1", sub_router)`,
  `Router.to_plug`.
- **Middleware:** `Middleware.pipeline([...])` runs plugs in order and halts
  early if a plug marks the conn sent/halted; `Middleware.compose` is the
  two-plug shorthand.

### Islands (typed interactivity)

An island is an `init / update / render` component. It runs on the server for
SSR and, once the WASM browser target lands, hydrates client-side from the same
code:

```march
mod CounterIsland do
  import Islands

  type State = { count : Int }
  type Msg   = Increment | Decrement | Reset | SetValue(Int)

  fn initial() : State do { count: 0 } end

  fn update(state : State, msg : Msg) : State do
    match msg do
    Increment   -> { count: state.count + 1 }
    Decrement   -> { count: state.count - 1 }
    Reset       -> { count: 0 }
    SetValue(n) -> { count: n }
    end
  end

  fn render(state : State) : String do
    "<div class=\"counter\">" ++
    "<button data-on-click=\"Decrement\">-</button>" ++
    "<span>" ++ int_to_string(state.count) ++ "</span>" ++
    "<button data-on-click=\"Increment\">+</button>" ++
    "</div>"
  end

  -- Wrap render output with hydration metadata for a page template:
  fn ssr(state : State) : String do
    Islands.wrap("CounterIsland", Islands.eager(), encode_state(state), render(state))
  end
end
```

`data-on-click="Increment"` tells the JS runtime to route the click back into
`update` as a typed `Msg`. The island can be tested entirely on the server, in
pure March, with no browser — see
[`examples/counter_island.march`](examples/counter_island.march) and
`Bastion.Test.Island`.

---

## Commands

Bastion's tooling is registered as `forge bastion.*` tasks (see `forge.toml`):

| Command | What it does |
|---------|--------------|
| `forge check` | Fast typecheck of the whole project |
| `forge test` | Run the test suite |
| `forge bastion.new <app>` | Scaffold a new Bastion application |
| `forge bastion.server` | Dev server with live reload |
| `forge bastion.console` | Interactive REPL with app context loaded |
| `forge bastion.routes` | Print the route table (`--gen` emits typed path helpers) |
| `forge bastion.gen.handler` | Generate a request handler |
| `forge bastion.gen.island` | Generate a WASM island |
| `forge bastion.gen.channel` | Generate a WebSocket channel handler |
| `forge bastion.gen.auth` | Generate auth boilerplate (users, tokens, controllers) |
| `forge bastion.gen.context` | Generate a context + schema + CRUD + migration |
| `forge bastion.gen.migration` | Generate a Depot migration |
| `forge bastion.depot.migrate` / `.rollback` / `.reset` | Manage database migrations |
| `forge bastion.build.islands` | Compile all WASM islands |
| `forge bastion.assets` | Build and fingerprint static assets |
| `forge bastion.release` | Build a production release (`--dockerfile`, `--embed-assets`) |

> After editing any `.march` file, run `forge check` to typecheck before
> proceeding.

---

## What's included

Implemented and usable today: the HTTP conn/plug pipeline, pattern-matched
routing, typed middleware, island SSR + hydration runtime, `~H` templates,
static file serving, auth / sessions / CSRF / CORS / security headers, `Gate`
form validation, flash messages, cookie sessions, caching (ETag + fragment +
response), rate limiting, PubSub + channels, uploads, idempotency keys,
telemetry + metrics + structured logging, a Depot (Postgres) integration, a dev
dashboard, and the full generator + release toolchain.

The main gaps are the WASM browser target itself (a March compiler roadmap
item), panic-recovery in a couple of dev/error paths, and real OTLP export —
all blocked on lower-level March toolchain primitives.

---

## Known limitations

### `forge bastion.build.islands` — content hashing requires `shasum`

`forge bastion.build.islands` computes 8-char content hashes for compiled WASM
files by shelling out to `shasum -a 256` (available on macOS and most Linux
distributions via `coreutils`).

This is a platform dependency. A future improvement would replace it with a
pure-March SHA-256 implementation so the command works on any target without
requiring system utilities.

Workaround on systems without `shasum`: install `coreutils` (e.g.
`brew install coreutils` on macOS if missing, or `apt install coreutils` on
Debian/Ubuntu), or use `forge bastion.gen.island --compile` for single-island
builds, which skips hashing entirely and serves files with a short cache TTL.
