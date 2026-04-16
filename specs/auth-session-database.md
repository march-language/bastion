# Bastion: Auth / Session / Database Stack

**Status**: Design | **Version**: 0.1 | **Part of**: [Bastion Design Spec](README.md)

---

## Overview

This document is the implementation plan for the auth/session/database stack — the set of features that, taken together, make Bastion usable for real applications. Every piece in this stack exists in some form in the existing specs ([auth.md](auth.md), [security.md](security.md), [depot-integration.md](depot-integration.md), [vault.md](vault.md)). This document organises them into a single build sequence, resolves the dependency order, pins API decisions, and notes what already exists in `lib/`.

The stack has five layers. Each depends on the ones below it:

```
5. Auth generators        forge gen.auth session / token / oauth
       │
4. Auth middleware        load_current_user, require_auth
       │
3. CSRF protection        token generation, form injection, validation
       │
2. Session middleware     cookie-backed (v1); Vault/Depot backends later
      │ │
      │ └─ 2b. Vault      in-memory store, TTL, rate limiting
      │
1. Depot integration      pool middleware, context modules, migrations
```

All five layers are Bastion-internal. No March compiler or forge changes are required.

---

## Layer 1 — Depot Integration

Depot is the March Postgres driver (external library). Bastion wraps it with middleware and a context module convention.

### 1a. Pool middleware

`typed_middleware.march` already has `with_db/2` and `get_db/1` stubs. The implementation attaches a checked-out Depot connection to `conn.assigns.db` and returns it to the pool at the end of the request.

```march
-- lib/depot_middleware.march
mod Bastion.Middleware.Depot do

  -- Checkout a connection from the pool, attach to conn, run the pipeline,
  -- return the connection to the pool regardless of whether the pipeline halted.
  fn with_pool(conn: TypedConn(Parsed), pool: Depot.Pool) : TypedConn(Parsed) do
    let db = Depot.Pool.checkout(pool)
    let conn = TypedMiddleware.assign_db(conn, db)
    let conn = TypedMiddleware.set_after_send(conn, fn () -> Depot.Pool.checkin(pool, db) end)
    conn
  end

end
```

`assign_db` writes into `conn.assigns` under the key `:db`. `get_db/1` reads it back. The typed conn state does not change — `with_db` is an assign-only operation, not a state transition.

**Error handling:** if `Depot.Pool.checkout` times out (pool exhausted), respond 503 immediately rather than hanging the request indefinitely. Timeout is configurable.

### 1b. Context modules

A context module is a plain March module scoping Depot queries for one domain. No framework magic — just convention:

```march
-- src/my_app/accounts.march
mod MyApp.Accounts do

  fn get_user(db: Depot.Conn, id: Int) : Result(User, :not_found) do
    match Depot.query_one(db, "SELECT * FROM users WHERE id = $1", [id]) do
    | Ok(row)  -> Ok(User.from_row(row))
    | Error(_) -> Error(:not_found)
    end
  end

  fn authenticate(db: Depot.Conn, email: String, password: String) : Result(User, :unauthorized) do
    match Depot.query_one(db, "SELECT * FROM users WHERE email = $1", [email]) do
    | Ok(row) ->
        let user = User.from_row(row)
        if Crypto.verify_password(password, user.password_hash) do Ok(user)
        else Error(:unauthorized)
        end
    | Error(_) -> Error(:unauthorized)
    end
  end

end
```

`forge gen.context Accounts User` scaffolds this pattern. The generator is lower priority than the underlying middleware.

### 1c. Migrations

Migrations are plain March files with `up` and `down` functions:

```march
-- priv/depot/migrations/20260401_create_users.march
mod Migrations.CreateUsers do
  fn up(db: Depot.Conn) do
    Depot.execute(db, """
      CREATE TABLE users (
        id         SERIAL PRIMARY KEY,
        email      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    """)
  end

  fn down(db: Depot.Conn) do
    Depot.execute(db, "DROP TABLE users")
  end
end
```

`forge depot.migrate` runs pending migrations in filename order. `forge depot.rollback` runs `down` on the last applied migration. Migration state is tracked in a `schema_migrations` table (created automatically on first run).

### 1d. Test sandbox

`Bastion.Test.Depot.checkout` wraps each test in a transaction that rolls back at the end, giving per-test isolation without truncating tables:

```march
test "creates a user" do
  use Bastion.Test.Depot
  let db = checkout()
  let result = MyApp.Accounts.create_user(db, %{email: "a@b.com", password: "secret"})
  assert result == Ok(...)
  -- transaction rolls back here automatically
end
```

Implemented as a `setup`/`setup_all` hook that begins a transaction on checkout and rolls it back on test completion.

### 1e. Implementation notes

- `Depot.Pool` is external — Bastion does not implement it, only wraps it.
- The `after_send` callback slot on conn (needed for pool checkin) requires a small addition to `conn.march` if not already present.
- Test sandbox requires that the Depot pool be configured to allow sandbox mode (a test-only pool configuration). See [testing.md](testing.md).

---

## Layer 2a — Session Middleware

Sessions ship in a single backend for v1: **signed + encrypted cookies**. No server-side storage. Vault and Depot session backends are planned but post-v1.

### Why cookie sessions first

- No infrastructure dependency (no Vault actor, no DB table)
- Simple to implement correctly
- Suitable for the majority of session use cases (user ID, flash messages, CSRF token)
- Depot-backed sessions can be added transparently later — the session API is identical regardless of backend

Cookie sessions store all session data as a JSON payload, encrypted with AES-256-GCM, signed with HMAC-SHA256. Both operations use the app's `secret_key_base` from config. The cookie is `HttpOnly`, `Secure` in production, `SameSite=Lax`.

### Session API

The typed middleware already has the right stubs. The implementation fills them in:

```march
-- lib/session.march
mod Bastion.Session do

  -- Load session from the signed+encrypted cookie. If the cookie is absent,
  -- tampered with, or expired, starts a fresh empty session.
  fn load(conn: TypedConn(Parsed), opts: SessionOpts) : TypedConn(WithSession) do
    let raw = Conn.get_req_cookie(conn, opts.cookie_name)
    let data = match raw do
      | None       -> Map.empty()
      | Some(blob) -> decrypt_and_verify(blob, opts.secret) |> Result.unwrap_or(Map.empty())
    end
    TypedMiddleware.put_session_store(conn, data)
  end

  -- Write session data back to the response cookie.
  -- Called automatically by send_resp if session was modified.
  fn commit(conn: TypedConn(s), opts: SessionOpts) : TypedConn(s) do
    let data = TypedMiddleware.get_session_store(conn)
    let blob = encrypt_and_sign(data, opts.secret)
    Conn.put_resp_cookie(conn, opts.cookie_name, blob, cookie_attrs(opts))
  end

  fn get(conn: TypedConn(WithSession), key: String) : Option(Any) do
    Map.get(TypedMiddleware.get_session_store(conn), key)
  end

  fn put(conn: TypedConn(WithSession), key: String, value: Any) : TypedConn(WithSession) do
    let store = Map.put(TypedMiddleware.get_session_store(conn), key, value)
    TypedMiddleware.put_session_store(conn, store)
  end

  fn delete(conn: TypedConn(WithSession), key: String) : TypedConn(WithSession) do
    let store = Map.delete(TypedMiddleware.get_session_store(conn), key)
    TypedMiddleware.put_session_store(conn, store)
  end

  fn clear(conn: TypedConn(WithSession)) : TypedConn(WithSession) do
    TypedMiddleware.put_session_store(conn, Map.empty())
  end

end
```

`commit` must be called before the response is sent. The cleanest approach: `send_resp` in `conn.march` checks whether the session was loaded and modified, and commits automatically if so. This mirrors how Phoenix handles session persistence.

### Configuration

```march
-- config/config.march
let session_opts = Bastion.Session.opts(
  cookie_name: "_my_app_session",
  secret: Config.fetch!("SECRET_KEY_BASE"),
  max_age: 60 * 60 * 24 * 30,  -- 30 days
  same_site: :lax,
  secure: Config.env() == :prod
)
```

`SECRET_KEY_BASE` must be at least 64 bytes. `forge gen.auth` generates it and adds it to `config/prod.march` with a clear warning about not committing it.

### Session backends (post-v1)

The API above is identical for all backends. Post-v1 additions:

| Backend | When to use | Storage |
|---------|------------|---------|
| Cookie (v1) | Default, small payloads | Encrypted cookie |
| Vault | Large payloads, revocable | Vault table keyed by session ID |
| Depot | Persistent across deploys, auditable | `sessions` table |

---

## Layer 2b — Vault

Vault is an in-memory, per-node key-value store implemented as a supervised actor. It is the storage backend for rate limiting and optionally for sessions/fragment caching.

### Actor design

```march
-- lib/vault.march
mod Bastion.Vault do

  actor Table do
    state { data: Map(String, VaultEntry), opts: TableOpts }

    on Put(key, value, ttl) do
      let entry = VaultEntry { value = value, expires_at = ttl_to_expiry(ttl) }
      { state with data = Map.put(state.data, key, entry) }
    end

    on Get(key, reply_to) do
      let result = match Map.get(state.data, key) do
        | None -> None
        | Some(entry) ->
            if is_expired(entry) do None
            else Some(entry.value)
            end
      end
      send(reply_to, result)
      state
    end

    on Delete(key) do
      { state with data = Map.delete(state.data, key) }
    end

    on Sweep do
      let now = Time.now()
      let pruned = Map.filter(state.data, fn _k v -> !is_expired_at(v, now) end)
      { state with data = pruned }
    end
  end

end
```

The TTL sweeper sends itself a `Sweep` message every 30 seconds (configurable). Sweep filters all expired entries in one pass — no per-entry timer.

**Data structure**: plain `Map(String, VaultEntry)` for v1. The HAMT question from `open-questions.md` §6 is deferred — a standard functional map is sufficient until benchmarks show otherwise. The actor serialises all writes anyway; read concurrency is addressed by the actor mailbox, not the data structure.

### Starting a Vault table

```march
-- In the app supervisor:
let sessions_vault = Vault.new("sessions", opts: [ttl_sweep_interval: 30])
let rate_limit_vault = Vault.new("rate_limits", opts: [table_type: :bag])
```

Tables are registered by name and looked up by name. A table that hasn't been started raises at lookup time, not silently.

### Implementation scope for v1

For v1, implement only what CSRF and rate limiting need: `put/3`, `get/2`, `delete/2`, `put_new/3` (atomic insert-if-absent). The full API from [vault.md](vault.md) (bags, ordered sets, bulk ops) follows in a subsequent pass.

---

## Layer 3 — CSRF Protection

The `~H` desugarer in `desugar.ml` already injects `CSRF.tag_string(conn)` into `<form>` tags with mutating methods. The runtime half — generating, storing, and validating tokens — doesn't exist yet.

### Token lifecycle

1. `load_session` runs — session is available.
2. On first access to `CSRF.token(conn)`, generate a 32-byte random token, store in session under `"_csrf_token"`. On subsequent accesses within the same request, return the existing token.
3. `~H` form desugaring calls `CSRF.tag_string(conn)` which returns `<input type="hidden" name="_csrf_token" value="<token>">`.
4. On `POST`/`PUT`/`PATCH`/`DELETE` requests, the CSRF middleware reads the token from:
   - `_csrf_token` form field, or
   - `x-csrf-token` request header (for AJAX)
   — and compares to the session token using a constant-time comparison.
5. If missing or mismatched: halt with 403. If JSON content-type: skip validation (CORS provides the same-origin guarantee for JSON).

```march
-- lib/csrf.march
mod Bastion.CSRF do

  fn protect(conn: TypedConn(WithSession)) : TypedConn(WithSession) do
    if is_safe_method(conn) || is_json_request(conn) do
      conn
    else
      let session_token = Session.get(conn, "_csrf_token") |> Option.unwrap_or("")
      let request_token =
        get_form_param(conn, "_csrf_token")
        |> Option.or_else(fn () -> get_req_header(conn, "x-csrf-token") end)
        |> Option.unwrap_or("")
      if Crypto.secure_compare(session_token, request_token) do
        conn
      else
        conn |> send_resp(403, "Invalid CSRF token") |> halt()
      end
    end
  end

  fn token(conn: TypedConn(WithSession)) : String do
    match Session.get(conn, "_csrf_token") do
    | Some(t) -> t
    | None ->
        let t = Crypto.random_bytes(32) |> Base64.url_encode()
        Session.put(conn, "_csrf_token", t)
        t
    end
  end

  -- Called by the ~H desugarer at template render time.
  fn tag_string(conn: TypedConn(WithSession)) : String do
    "<input type=\"hidden\" name=\"_csrf_token\" value=\"${token(conn)}\">"
  end

end
```

`is_safe_method` is `GET`, `HEAD`, `OPTIONS`. `Crypto.secure_compare` is constant-time string equality (prevents timing attacks).

### Skipping CSRF per route

For API routes that intentionally skip CSRF (e.g., webhook receivers with their own signature verification):

```march
fn route(conn, :post, ["webhooks", "stripe"]) do
  conn
  |> CSRF.skip()
  |> StripeWebhookHandler.handle()
end
```

`CSRF.skip()` marks the conn so the `protect` middleware no-ops for this request.

---

## Layer 4 — Auth Middleware

Two middleware functions. Both require `WithSession` state — session must be loaded first.

### `load_current_user`

Soft check. Reads the user ID from the session, loads the user from the database, assigns to `conn.assigns.current_user`. If no session user ID, assigns `None`. Does not halt.

```march
-- lib/auth_middleware.march
mod Bastion.Auth do

  fn load_current_user(conn: TypedConn(WithSession), loader: (Depot.Conn, Int) -> Result(User, Any))
      : TypedConn(WithSession) do
    let user = match Session.get(conn, "current_user_id") do
      | None     -> None
      | Some(id) ->
          let db = TypedMiddleware.get_db(conn)
          match loader(db, id) do
          | Ok(user) -> Some(user)
          | Error(_) -> None  -- stale session; user was deleted
          end
    end
    TypedMiddleware.set_current_user(conn, user)
  end

  fn require_auth(conn: TypedConn(WithSession)) : TypedConn(Authenticated) do
    match TypedMiddleware.get_current_user(conn) do
    | Some(_) -> TypedMiddleware.mark_authenticated(conn)
    | None    ->
        conn
        |> put_session("return_to", Conn.request_path(conn))
        |> redirect("/login")
        |> halt()
        -- type system allows this because halt() marks the conn as done;
        -- the unreachable Authenticated branch is never reached but the
        -- type checker needs a coercion here. Use a typed hole or an
        -- explicit cast. Mark as a known compiler ergonomics issue.
    end
  end

  fn log_in(conn: TypedConn(WithSession), user_id: Int) : TypedConn(WithSession) do
    conn
    |> Session.clear()         -- session fixation protection: always rotate on login
    |> Session.put("current_user_id", user_id)
  end

  fn log_out(conn: TypedConn(WithSession)) : TypedConn(WithSession) do
    conn |> Session.clear()
  end

end
```

The `loader` function is injected by the application — Bastion does not know the shape of `User`. `forge gen.auth session` wires this up automatically.

### `require_auth` is a gate, not a pipeline step

The typed pipeline models *linear* state transitions. Auth is a *branch* — either proceed authenticated or short-circuit. Forcing a branch into a linear state machine requires lying to the type checker, which the original stub did.

**The correct design splits the two concerns:**

- **`load_current_user`** belongs in the pipeline. It is a soft check: reads the user ID from the session, loads the user from the database, assigns it to `conn`. Never halts. State stays `WithSession`.
- **`require_auth`** is a gate called inside the route handler. It returns `Result(TypedConn(Authenticated), Conn)`. Callers use `with` to handle both branches.

```march
-- In the pipeline (soft, never halts):
fn load_current_user(tc: TypedConn(WithSession), loader: (Conn, Int) -> Result(User, Any))
    : TypedConn(WithSession)

-- Gate called inside handlers (returns Result, never unsafe-casts):
fn require_auth(tc: TypedConn(WithSession)) : Result(TypedConn(Authenticated), Conn)

-- Sugar for the common case:
fn authenticated(tc: TypedConn(WithSession), handler: (TypedConn(Authenticated)) -> Conn) : Conn
```

Call sites use `with` or the `authenticated` helper:

```march
fn handle_dashboard(conn: Conn) : Conn do
  let tc = wrap(conn) |> parse_body() |> load_session(secret) |> load_current_user(db)
  authenticated(tc, fn tc ->
    Dashboard.render(tc, get_current_user(tc)) |> unwrap()
  end)
end
```

The continuation is only ever called with a genuinely `Authenticated` conn. No unsafe casts anywhere. The `Error` branch of `require_auth` carries a plain `Conn` (not a `TypedConn`) because it is a finished halted response that needs no further type tracking.

---

## Layer 5 — Auth Generators

`forge gen.auth session` generates the minimal cookie-session auth flow. The other strategies (token, OAuth, magic_link) follow the same pattern but are post-v1.

### What `forge gen.auth session` produces

```
src/my_app/
  accounts.march              -- User queries: get, create, authenticate
  auth_controller.march       -- Login/logout/register handlers
  templates/
    auth/
      login.march.html
      register.march.html
priv/depot/migrations/
  <timestamp>_create_users.march
```

And patches the router to add:

```march
fn route(conn, :get,  ["login"])    do AuthController.login_form(conn) end
fn route(conn, :post, ["login"])    do AuthController.login(conn) end
fn route(conn, :delete, ["logout"]) do AuthController.logout(conn) end
fn route(conn, :get,  ["register"]) do AuthController.register_form(conn) end
fn route(conn, :post, ["register"]) do AuthController.register(conn) end
```

The generated `accounts.march` uses `Crypto.hash_password` and `Crypto.verify_password` — Bastion provides these wrappers over a password hashing library (Argon2id, with bcrypt as a fallback if Argon2 is unavailable). Password hashing config (memory cost, iterations) is in `config/config.march`.

---

## Cross-Cutting: Crypto Module

Several layers need cryptographic primitives. These live in `lib/crypto.march`:

| Function | Used by | Notes |
|----------|---------|-------|
| `random_bytes(n)` | CSRF token gen, session ID gen | Cryptographically secure random |
| `secure_compare(a, b)` | CSRF validation | Constant-time string equality |
| `hash_password(plain)` | Auth generator (user creation) | Argon2id; returns opaque hash string |
| `verify_password(plain, hash)` | Auth generator (login) | Constant-time |
| `encrypt(data, key)` | Cookie session | AES-256-GCM; returns `{ciphertext, iv, tag}` |
| `decrypt(data, key)` | Cookie session | Authenticates then decrypts; returns `Result` |
| `sign(data, key)` | Cookie session | HMAC-SHA256; appended to cookie value |
| `verify_signature(data, sig, key)` | Cookie session | Constant-time MAC comparison |

The underlying implementations delegate to OCaml's `Cryptokit` or `mirage-crypto` (whichever is already a transitive dep of March). Bastion does not implement cryptographic primitives.

---

## Implementation Order

Build strictly in this sequence — each step is usable without the next:

```
Step 1.  Crypto module (random_bytes, secure_compare, encrypt/decrypt, sign/verify)
         → unblocks sessions and CSRF

Step 2.  Depot pool middleware (with_pool, after_send hook on conn)
         → apps can hit the database

Step 3.  Cookie session middleware (load, commit, get, put, delete, clear)
         → apps have sessions; CSRF and auth become possible

Step 4.  CSRF middleware (protect, token, tag_string, skip)
         → forms are safe; existing ~H desugaring now has a runtime

Step 5.  Auth middleware (load_current_user, require_auth, log_in, log_out)
         → apps can authenticate users

Step 6.  Vault (put, get, delete, put_new, TTL sweeper)
         → rate limiting becomes possible; optional session backend available

Step 7.  forge gen.auth session generator
         → full auth flow scaffolded in one command

Step 8.  Depot migrations + forge depot.migrate
         → database schema management

Step 9.  Test sandbox (Bastion.Test.Depot.checkout)
         → per-test transaction rollback

Step 10. Remaining Vault API (bags, ordered sets, bulk ops) — post-v1
Step 11. Vault/Depot session backends                       — post-v1
Step 12. forge gen.auth token / oauth / magic_link          — post-v1
```

Steps 1–5 are the minimum for a real server-rendered app. Steps 6–9 complete the production-ready stack. Steps 10–12 are post-v1.

---

## What Already Exists

| Piece | File | Status |
|-------|------|--------|
| `TypedConn` states (Raw, Parsed, WithSession, Authenticated) | `typed_middleware.march` | Implemented |
| `load_session/2` stub | `typed_middleware.march` | Stub — no implementation |
| `require_auth/1` stub | `typed_middleware.march` | Stub — no implementation |
| `with_db/2`, `get_db/1` stubs | `typed_middleware.march` | Stub — no implementation |
| `set_current_user/2`, `get_current_user_id/1` stubs | `typed_middleware.march` | Stub — no implementation |
| `CSRF.tag_string(conn)` call sites | `desugar.ml` (March compiler) | Called by ~H desugarer; runtime not implemented |
| `Conn.put_resp_cookie` / `get_req_cookie` | `conn.march` | May need addition — check |

The typed middleware module was designed with this stack in mind. Implementing the stack is primarily about filling in the stubs and adding the supporting modules (`session.march`, `csrf.march`, `auth_middleware.march`, `crypto.march`, `vault.march`, `depot_middleware.march`).

---

## New Files

| File | Layer | Purpose |
|------|-------|---------|
| `lib/crypto.march` | Cross-cutting | Random bytes, HMAC, AES-GCM, password hashing |
| `lib/depot_middleware.march` | 1 | `with_pool`, `after_send` pool checkin |
| `lib/session.march` | 2a | Cookie session: load, commit, get/put/delete/clear |
| `lib/vault.march` | 2b | In-memory KV actor with TTL |
| `lib/csrf.march` | 3 | Token generation, form injection, validation |
| `lib/auth_middleware.march` | 4 | `load_current_user`, `require_auth`, `log_in`, `log_out` |

Plus generator scaffolding and migration tooling, which touch forge rather than Bastion lib.
