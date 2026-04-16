# Bastion: Auth / Session / Database Stack

**Status**: Design | **Version**: 0.2 | **Part of**: [Bastion Design Spec](README.md)

---

## Overview

This document is the implementation plan for the auth/session/database stack — the set of features that, taken together, make Bastion usable for real applications. Every piece in this stack exists in some form in the existing specs ([auth.md](auth.md), [security.md](security.md), [depot-integration.md](depot-integration.md), [vault.md](vault.md)). This document organises them into a single build sequence, resolves the dependency order, pins API decisions, and notes what already exists in `lib/`.

The stack has seven layers (plus a prerequisite layer). Each depends on the ones below it:

```
7. Auth generators          forge gen.auth session (+ remember-me, password reset)
       │
6. Auth middleware           load_current_user, require_auth, log_in, log_out
       │
5. CSRF protection           token generation, form injection, validation
      │
      └─ 5b. Rate limiting   sliding window, brute-force protection (uses Vault)
       │
3. Session middleware        cookie-backed (v1); flash messages; Vault/Depot backends later
      │
      └─ 3b. Vault           in-memory store, TTL sweeper
       │
2. Depot integration         pool middleware, context modules, migrations
       │
1. Crypto module             AES-GCM, HMAC, HKDF, Argon2id, SHA-256, CSPRNG
       │
0. Conn prerequisites        cookie helpers, after_send callbacks, form param parsing
```

All layers are Bastion-internal. No March compiler or forge changes are required (generator and migration tooling touches forge but not the compiler).

---

## Layer 0 — Conn Prerequisites

Several layers depend on conn capabilities that don't exist yet. These are small additions to `conn.march` and `HttpServer` that must land before the stack layers can be built.

### 0a. Cookie helpers

`conn.march` currently has no cookie read/write API. Sessions and CSRF both need it.

```march
-- Additions to lib/conn.march

doc "Read a named cookie from the request Cookie header. Returns None if absent."
fn get_req_cookie(conn : Conn, name : String) : Option(String) do
  match get_req_header(conn, "cookie") do
  | None    -> None
  | Some(v) -> find_cookie_value(String.split(v, "; "), name)
  end
end

doc """
Set a response cookie. Appends a Set-Cookie header with the given name, value,
and attributes. Does not replace existing Set-Cookie headers (multiple cookies
require multiple headers per the HTTP spec).
"""
fn put_resp_cookie(conn : Conn, name : String, value : String, attrs : CookieAttrs) : Conn do
  let header = format_set_cookie(name, value, attrs)
  HttpServer.put_resp_header(conn, "set-cookie", header)
end

doc "Delete a response cookie by setting it with max-age=0 and an empty value."
fn delete_resp_cookie(conn : Conn, name : String) : Conn do
  put_resp_cookie(conn, name, "", CookieAttrs { max_age = 0, path = "/" })
end
```

`CookieAttrs` is a simple record:

```march
type CookieAttrs = {
  max_age   : Int,
  path      : String,
  domain    : Option(String),
  secure    : Bool,
  http_only : Bool,
  same_site : SameSite   -- :lax | :strict | :none
}
```

`format_set_cookie` serialises the cookie to the `Set-Cookie` header format: `name=value; Max-Age=N; Path=/; HttpOnly; Secure; SameSite=Lax`.

### 0b. After-send callbacks

The Depot pool middleware needs to return a connection to the pool **after** the response has been sent. This requires a callback slot on conn.

```march
-- Additions to lib/conn.march (or HttpServer if it owns the type)

doc """
Register a callback to run after the response has been fully sent.
Multiple callbacks are stored and run in reverse registration order
(LIFO — last registered runs first). Callbacks receive no arguments
and their return values are ignored.

Primary use case: returning database connections to the pool.
"""
fn register_after_send(conn : Conn, callback : () -> ()) : Conn do
  let callbacks = match HttpServer.get_assign(conn, "_after_send") do
    | None    -> [callback]
    | Some(cbs) -> Cons(callback, cbs)
  end
  HttpServer.assign(conn, "_after_send", callbacks)
end

doc """
Run all registered after-send callbacks. Called by the HTTP server
adapter after the response bytes are on the wire. Not called by
application code directly.
"""
fn run_after_send(conn : Conn) : () do
  match HttpServer.get_assign(conn, "_after_send") do
  | None      -> ()
  | Some(cbs) -> List.each(cbs, fn cb -> cb() end)
  end
end
```

**Implementation note**: `run_after_send` must be called from `bastion_server.march` (or whatever adapter sends the response). If the response send fails (broken connection), callbacks still run — pool connections must be returned regardless. Callbacks must not raise; wrap each in a try/catch and log failures.

### 0c. Form body parsing

CSRF validation reads `_csrf_token` from form submissions. `parse_body` in `typed_middleware.march` stores the raw body string but doesn't parse form fields. Add a form parameter accessor:

```march
doc """
Parse the request body as URL-encoded form data and return the value
for the given key. Returns None if the body isn't form-encoded or the
key is absent.
"""
fn get_form_param(conn : Conn, key : String) : Option(String) do
  match content_type(conn) do
  | Some(ct) when String.starts_with(ct, "application/x-www-form-urlencoded") ->
      parse_form_body(req_body(conn), key)
  | _ -> None
  end
end
```

Form body parsing is intentionally simple — split on `&`, split each pair on `=`, URL-decode both sides. Multipart form parsing is out of scope for this stack (see [uploads.md](uploads.md)).

---

## Layer 1 — Crypto Module

Several layers need cryptographic primitives. These live in `lib/crypto.march`:

| Function | Used by | Notes |
|----------|---------|-------|
| `random_bytes(n)` | CSRF token gen, session ID gen, token gen | Cryptographically secure random |
| `secure_compare(a, b)` | CSRF validation, signature verification | Constant-time string equality |
| `sha256(data)` | Remember-me token hashing, reset token hashing | One-way hash for token storage |
| `hash_password(plain)` | Auth generator (user creation) | Argon2id; returns opaque hash string |
| `verify_password(plain, hash)` | Auth generator (login) | Constant-time |
| `encrypt(data, key)` | Cookie session | AES-256-GCM; returns `{ciphertext, iv, tag}` |
| `decrypt(data, key)` | Cookie session | Authenticates then decrypts; returns `Result` |
| `sign(data, key)` | Cookie session | HMAC-SHA256; appended to cookie value |
| `verify_signature(data, sig, key)` | Cookie session | Constant-time MAC comparison |

The underlying implementations delegate to OCaml's `Cryptokit` or `mirage-crypto` (whichever is already a transitive dep of March). Bastion does not implement cryptographic primitives.

**Cookie format**: The session cookie value is `sign(encrypt(json_payload, key), key)` — encrypt first, then sign. Verification reverses: verify signature, then decrypt. This is encrypt-then-MAC, the recommended composition for authenticated encryption. AES-256-GCM already provides authentication, but the outer HMAC catches tampering before any decryption work happens (defense in depth + allows key rotation without trial decryption).

**Key derivation**: The raw `SECRET_KEY_BASE` is not used directly. Derive separate keys for signing and encryption using HKDF:

```march
let signing_key    = Crypto.hkdf(secret_key_base, info: "session_signing", length: 32)
let encryption_key = Crypto.hkdf(secret_key_base, info: "session_encryption", length: 32)
```

This means rotating one key (e.g., for a new encryption algorithm) doesn't invalidate the other.

---

## Layer 2 — Depot Integration

Depot is the March Postgres driver (external library). Bastion wraps it with middleware and a context module convention.

### 2a. Pool middleware

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

### 2b. Context modules

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

### 2c. Migrations

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

### 2d. Test sandbox

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

### 2e. Implementation notes

- `Depot.Pool` is external — Bastion does not implement it, only wraps it.
- The `after_send` callback slot on conn (needed for pool checkin) requires a small addition to `conn.march` if not already present.
- Test sandbox requires that the Depot pool be configured to allow sandbox mode (a test-only pool configuration). See [testing.md](testing.md).

---

## Layer 3 — Session Middleware

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

### Session auto-commit

`commit` must be called before the response is sent. Requiring app code to call it manually is error-prone. Instead, `send_resp` in `conn.march` checks whether a session was loaded and modified, and commits automatically:

```march
-- In conn.march or the HTTP adapter:
pfn maybe_commit_session(conn) do
  match HttpServer.get_assign(conn, "_session_dirty") do
  | Some(true) -> Session.commit(conn, get_session_opts(conn))
  | _          -> conn
  end
end
```

`Session.put`, `Session.delete`, and `Session.clear` set `_session_dirty = true`. `Session.get` does not. This avoids rewriting the cookie on read-only requests.

### Flash messages

Flash messages are one-time session values that survive exactly one request — used for "Login successful", "Item deleted", etc. They live in the session under the `"_flash"` key.

```march
-- lib/flash.march
mod Bastion.Flash do

  fn put(conn : TypedConn(WithSession), key : String, message : String) : TypedConn(WithSession) do
    let flash = get_flash_map(conn)
    let updated = Map.put(flash, key, message)
    Session.put(conn, "_flash", Json.encode(updated))
  end

  fn get(conn : TypedConn(WithSession), key : String) : Option(String) do
    let flash = get_flash_map(conn)
    Map.get(flash, key)
  end

  fn clear(conn : TypedConn(WithSession)) : TypedConn(WithSession) do
    Session.delete(conn, "_flash")
  end

end
```

**Lifecycle**: flash data is read at the start of the request (available to templates) and cleared at the end. The middleware handles this:

```march
fn load_flash(conn : TypedConn(WithSession)) : TypedConn(WithSession) do
  let flash = Session.get(conn, "_flash") |> Option.map(Json.decode) |> Option.unwrap_or(Map.empty())
  let conn = TypedMiddleware.assign(conn, "_flash_current", flash)
  Session.delete(conn, "_flash")
end
```

Templates access the current request's flash via `get_assign(conn, "_flash_current")`. New flash messages written during this request go into the session for the *next* request.

### Session backends (post-v1)

The API above is identical for all backends. Post-v1 additions:

| Backend | When to use | Storage |
|---------|------------|---------|
| Cookie (v1) | Default, small payloads | Encrypted cookie |
| Vault | Large payloads, revocable | Vault table keyed by session ID |
| Depot | Persistent across deploys, auditable | `sessions` table |

---

## Layer 3b — Vault

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

## Layer 5 — CSRF Protection

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

## Layer 5b — Rate Limiting

Rate limiting protects login, registration, and password reset endpoints from brute force. It depends on Vault (Layer 3b) for counter storage. In the implementation order, it slots in after Vault ships (Step 6), but it's documented here because it's a security layer that works alongside CSRF.

### Sliding window algorithm

Uses a sliding window counter stored in Vault. Each key (IP address, user ID, or custom function) maps to a list of timestamps. On each request, expired timestamps are pruned and the remaining count is compared to the limit.

```march
-- lib/rate_limit.march
mod Bastion.RateLimit do

  type RateLimitOpts = {
    key     : (Conn) -> String,    -- function to extract the rate limit key
    limit   : Int,                  -- max requests per window
    window  : Int,                  -- window size in milliseconds
    vault   : Vault.Table           -- vault table to use for counters
  }

  fn check(conn : Conn, opts : RateLimitOpts) : Result(Conn, Conn) do
    let k = opts.key(conn)
    let now = Time.now_ms()
    let window_start = now - opts.window

    -- Atomic read-modify-write: prune expired entries, add current timestamp
    let count = Vault.update(opts.vault, k, fn timestamps ->
      let valid = List.filter(timestamps, fn t -> t > window_start end)
      Cons(now, valid)
    end)
    |> Option.unwrap_or([now])
    |> List.length()

    if count <= opts.limit do
      let conn = conn
        |> Conn.put_resp_header("x-ratelimit-limit", Int.to_string(opts.limit))
        |> Conn.put_resp_header("x-ratelimit-remaining", Int.to_string(opts.limit - count))
      Ok(conn)
    else
      let retry_after = (opts.window / 1000) + 1
      let conn = conn
        |> Conn.put_resp_header("retry-after", Int.to_string(retry_after))
        |> Conn.put_resp_header("x-ratelimit-limit", Int.to_string(opts.limit))
        |> Conn.put_resp_header("x-ratelimit-remaining", "0")
        |> Conn.send_resp(429, "Too many requests")
        |> Conn.halt()
      Error(conn)
    end
  end

end
```

### Default rate limits for auth endpoints

`forge gen.auth session` wires up rate limiting for sensitive endpoints:

| Endpoint | Key | Limit | Window |
|----------|-----|-------|--------|
| `POST /login` | IP address | 5 | 60s |
| `POST /register` | IP address | 3 | 60s |
| `POST /reset-password` | IP address | 3 | 300s |

These are configurable. The generated code looks like:

```march
fn route(conn, :post, ["login"]) do
  match RateLimit.check(conn, %{ key: fn c -> remote_ip(c) end, limit: 5, window: 60_000, vault: rate_limits }) do
  | Ok(conn)    -> AuthController.login(conn)
  | Error(conn) -> conn
  end
end
```

### Vault table setup

Rate limit counters go in a dedicated Vault table created at app startup:

```march
let rate_limits = Vault.new("rate_limits", opts: [ttl_sweep_interval: 30])
```

The TTL sweeper handles cleanup. Individual entries also self-prune on each access (the sliding window filter), so the sweeper is a safety net, not the primary cleanup mechanism.

---

## Layer 6 — Auth Middleware

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

### Remember-me tokens

Cookie sessions expire when the browser closes (session cookie) or after `max_age`. For persistent login ("remember me"), a separate long-lived token is stored in a dedicated cookie and backed by a database table.

```march
-- Generated by forge gen.auth session (in src/my_app/accounts.march)

fn create_remember_token(db : Depot.Conn, user_id : Int) : String do
  let token = Crypto.random_bytes(32) |> Base64.url_encode()
  let hash = Crypto.sha256(token)
  Depot.execute(db, """
    INSERT INTO user_tokens (user_id, token_hash, context, inserted_at)
    VALUES ($1, $2, 'remember_me', now())
  """, [user_id, hash])
  token
end

fn verify_remember_token(db : Depot.Conn, token : String) : Result(Int, :invalid) do
  let hash = Crypto.sha256(token)
  match Depot.query_one(db, """
    SELECT user_id FROM user_tokens
    WHERE token_hash = $1 AND context = 'remember_me'
    AND inserted_at > now() - interval '60 days'
  """, [hash]) do
  | Ok(row) -> Ok(row.user_id)
  | Error(_) -> Error(:invalid)
  end
end
```

The token itself is never stored — only its SHA-256 hash. This means a database leak doesn't compromise active sessions. The raw token lives only in the user's cookie.

**Login flow with remember-me**:

1. User checks "remember me" on login form.
2. `log_in` creates a remember token, stores hash in `user_tokens`, sets cookie `_remember_me` with 60-day max_age.
3. On subsequent visits where the session is empty, `load_current_user` checks the remember-me cookie, verifies the token, and re-establishes the session.
4. `log_out` deletes the token from the database and clears both cookies.

```march
fn log_in(conn, user_id, opts) do
  let conn = conn
    |> Session.clear()
    |> Session.put("current_user_id", Int.to_string(user_id))
  match Map.get(opts, :remember_me) do
  | Some(true) ->
      let db = TypedMiddleware.get_db(unwrap(conn))
      let token = Accounts.create_remember_token(db, user_id)
      Conn.put_resp_cookie(conn, "_remember_me", token, CookieAttrs {
        max_age = 60 * 60 * 24 * 60,  -- 60 days
        http_only = true, secure = true, same_site = :lax, path = "/"
      })
  | _ -> conn
  end
end

fn log_out(conn) do
  -- Delete the remember token from the database
  match Conn.get_req_cookie(unwrap(conn), "_remember_me") do
  | Some(token) ->
      let db = TypedMiddleware.get_db(unwrap(conn))
      Accounts.delete_remember_token(db, token)
  | None -> ()
  end
  conn
  |> Session.clear()
  |> Conn.delete_resp_cookie("_remember_me")
end
```

**The `user_tokens` table** is generated by `forge gen.auth session`:

```sql
CREATE TABLE user_tokens (
  id          SERIAL PRIMARY KEY,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  BYTEA NOT NULL,
  context     TEXT NOT NULL,        -- 'remember_me', 'reset_password', 'confirm_email'
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_user_tokens_hash_context ON user_tokens (token_hash, context);
CREATE INDEX idx_user_tokens_user_id ON user_tokens (user_id);
```

This table is shared by remember-me, password reset, and email confirmation — differentiated by the `context` column.

### Password reset

`forge gen.auth session` also generates a password reset flow. The pattern follows the same token table:

1. **Request reset**: User submits email. If the email exists, generate a token, hash it, store in `user_tokens` with context `reset_password`, email the raw token as a URL parameter. Always respond with the same message regardless of whether the email exists (timing-safe).

2. **Verify token**: User clicks the link. Look up the token hash, verify it's less than 1 hour old and context is `reset_password`. If valid, render the password change form.

3. **Change password**: User submits new password. Verify the token again, update `password_hash`, delete all tokens for this user with context `reset_password` (single-use), and clear all sessions (force re-login everywhere).

```march
-- Generated in src/my_app/accounts.march

fn create_reset_token(db : Depot.Conn, user_id : Int) : String do
  -- Delete any existing reset tokens for this user first
  Depot.execute(db, "DELETE FROM user_tokens WHERE user_id = $1 AND context = 'reset_password'", [user_id])
  let token = Crypto.random_bytes(32) |> Base64.url_encode()
  let hash = Crypto.sha256(token)
  Depot.execute(db, """
    INSERT INTO user_tokens (user_id, token_hash, context, inserted_at)
    VALUES ($1, $2, 'reset_password', now())
  """, [user_id, hash])
  token
end

fn verify_reset_token(db : Depot.Conn, token : String) : Result(Int, :invalid) do
  let hash = Crypto.sha256(token)
  match Depot.query_one(db, """
    SELECT user_id FROM user_tokens
    WHERE token_hash = $1 AND context = 'reset_password'
    AND inserted_at > now() - interval '1 hour'
  """, [hash]) do
  | Ok(row) -> Ok(row.user_id)
  | Error(_) -> Error(:invalid)
  end
end

fn reset_password(db : Depot.Conn, user_id : Int, new_password : String) : Result((), :error) do
  let hash = Crypto.hash_password(new_password)
  Depot.execute(db, "UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2", [hash, user_id])
  -- Invalidate all remember-me and reset tokens
  Depot.execute(db, "DELETE FROM user_tokens WHERE user_id = $1", [user_id])
  Ok(())
end
```

Generated handler routes:

```march
fn route(conn, :get,  ["reset-password"])         do AuthController.reset_password_form(conn) end
fn route(conn, :post, ["reset-password"])          do AuthController.request_reset(conn) end
fn route(conn, :get,  ["reset-password", token])   do AuthController.verify_reset_token(conn, token) end
fn route(conn, :put,  ["reset-password", token])   do AuthController.change_password(conn, token) end
```

**Security notes**:
- Tokens are single-use: deleted after password change.
- Tokens expire after 1 hour.
- Only the hash is stored; the raw token is in the email link only.
- `request_reset` uses constant-time response regardless of email existence.
- All existing sessions/tokens are invalidated on password change.

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

## Layer 7 — Auth Generators

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
-- Auth routes (generated)
fn route(conn, :get,  ["login"])                  do AuthController.login_form(conn) end
fn route(conn, :post, ["login"])                  do AuthController.login(conn) end
fn route(conn, :delete, ["logout"])               do AuthController.logout(conn) end
fn route(conn, :get,  ["register"])               do AuthController.register_form(conn) end
fn route(conn, :post, ["register"])               do AuthController.register(conn) end
fn route(conn, :get,  ["reset-password"])          do AuthController.reset_password_form(conn) end
fn route(conn, :post, ["reset-password"])           do AuthController.request_reset(conn) end
fn route(conn, :get,  ["reset-password", token])    do AuthController.verify_reset_token(conn, token) end
fn route(conn, :put,  ["reset-password", token])    do AuthController.change_password(conn, token) end
```

The generated `accounts.march` uses `Crypto.hash_password` and `Crypto.verify_password` — Bastion provides these wrappers over a password hashing library (Argon2id, with bcrypt as a fallback if Argon2 is unavailable). Password hashing config (memory cost, iterations) is in `config/config.march`.

### Generated migration

`forge gen.auth session` produces two migrations:

```march
-- priv/depot/migrations/<timestamp>_create_users.march
mod Migrations.CreateUsers do
  fn up(db) do
    Depot.execute(db, """
      CREATE TABLE users (
        id            SERIAL PRIMARY KEY,
        email         TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        confirmed_at  TIMESTAMPTZ,
        inserted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    """)
    Depot.execute(db, "CREATE UNIQUE INDEX idx_users_email ON users (email)")
  end

  fn down(db) do Depot.execute(db, "DROP TABLE users") end
end

-- priv/depot/migrations/<timestamp>_create_user_tokens.march
mod Migrations.CreateUserTokens do
  fn up(db) do
    Depot.execute(db, """
      CREATE TABLE user_tokens (
        id          SERIAL PRIMARY KEY,
        user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash  BYTEA NOT NULL,
        context     TEXT NOT NULL,
        inserted_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    """)
    Depot.execute(db, "CREATE INDEX idx_user_tokens_hash_context ON user_tokens (token_hash, context)")
    Depot.execute(db, "CREATE INDEX idx_user_tokens_user_id ON user_tokens (user_id)")
  end

  fn down(db) do Depot.execute(db, "DROP TABLE user_tokens") end
end
```

### What the generator does NOT do

- Does not generate email sending. The password reset flow creates the token and the URL, but printing/emailing it is left to the app. A `TODO: send this URL to the user` comment is generated.
- Does not generate email confirmation. The `confirmed_at` column is present but unused until `forge gen.auth confirm_email` ships (post-v1).
- Does not generate OAuth or token-based auth. Those are separate generators with different dependencies.

---

## Implementation Order

Build strictly in this sequence — each step is usable without the next:

```
Step 0.  Conn prerequisites (cookie helpers, after_send, get_form_param)
         → unblocks everything; small, isolated changes to conn.march

Step 1.  Crypto module (random_bytes, secure_compare, encrypt/decrypt, sign/verify,
         hash_password, verify_password, sha256)
         → unblocks sessions, CSRF, and auth tokens

Step 2.  Depot pool middleware (with_pool, after_send pool checkin)
         → apps can hit the database

Step 3.  Cookie session middleware (load, commit, get, put, delete, clear)
         + session auto-commit in send_resp
         → apps have sessions; CSRF and auth become possible

Step 4.  Flash messages (put, get, load_flash, clear)
         → depends on sessions; small module, immediate usability payoff

Step 5.  CSRF middleware (protect, token, tag_string, skip)
         → forms are safe; existing ~H desugaring now has a runtime

Step 6.  Auth middleware (load_current_user, require_auth/authenticated,
         log_in, log_out)
         → apps can authenticate users

Step 7.  Vault (put, get, delete, put_new, TTL sweeper — core API only)
         → rate limiting becomes possible; optional session backend available

Step 8.  Rate limiting (check, sliding window, response headers)
         → auth endpoints are brute-force protected

Step 9.  Depot migrations + forge depot.migrate / forge depot.rollback
         → database schema management

Step 10. forge gen.auth session generator (users table, user_tokens table,
         Accounts context, AuthController, login/register/reset templates,
         remember-me, password reset)
         → full auth flow scaffolded in one command

Step 11. Test sandbox (Bastion.Test.Depot.checkout) + Bastion.Test.Auth
         → per-test transaction rollback, auth test helpers

Step 12. Remaining Vault API (bags, ordered sets, bulk ops) — post-v1
Step 13. Vault/Depot session backends                       — post-v1
Step 14. forge gen.auth token / oauth / magic_link          — post-v1
```

Steps 0–6 are the minimum for a real server-rendered app with login. Steps 7–11 complete the production-ready stack. Steps 12–14 are post-v1.

---

## What Already Exists

| Piece | File | Status |
|-------|------|--------|
| `TypedConn` states (Raw, Parsed, WithSession, Authenticated) | `typed_middleware.march` | Implemented |
| `load_session/2` | `typed_middleware.march` | Implemented — basic sig.payload parsing, no real crypto |
| `get_session_value/2`, `put_session_value/3` | `typed_middleware.march` | Implemented — key=value;key=value format, no encryption |
| `require_auth/1` → `Result(TypedConn(Authenticated), Conn)` | `typed_middleware.march` | Implemented — redirects to /login on failure |
| `authenticated/2` sugar | `typed_middleware.march` | Implemented |
| `load_current_user/2` with injected loader | `typed_middleware.march` | Implemented — reads from assigns, calls loader |
| `get_current_user/1`, `set_current_user_id/1` | `typed_middleware.march` | Implemented |
| `with_db/2`, `get_db/1` | `typed_middleware.march` | Implemented — simple assign-based, no pool management |
| `web_pipeline/2`, `full_pipeline/3` shortcuts | `typed_middleware.march` | Implemented |
| `is_json_request/1`, `is_form_request/1`, `is_multipart_request/1` | `typed_middleware.march` | Implemented |
| `CSRF.tag_string(conn)` call sites | `desugar.ml` (March compiler) | Called by ~H desugarer; runtime not implemented |
| Cookie helpers (`get_req_cookie`, `put_resp_cookie`) | `conn.march` | **Not present** — must be added (Layer 0a) |
| `after_send` callback | `conn.march` / `bastion_server.march` | **Not present** — must be added (Layer 0b) |
| Form param parsing | `conn.march` | **Not present** — must be added (Layer 0c) |

**Key observation**: `typed_middleware.march` has working implementations of session loading, auth gates, and DB assignment, but they use simplified formats (no encryption, no HMAC verification, string-concatenation session storage). The real implementations in `session.march`, `auth_middleware.march`, etc. will replace these with proper cryptographic operations. The typed signatures and pipeline flow are correct — only the internals change.

The upgrade path:
1. Add Layer 0 prerequisites to `conn.march`
2. Implement `session.march` with real crypto
3. Update `typed_middleware.march` to delegate to `session.march` instead of using inline key=value parsing
4. Add the remaining new modules
5. Existing call sites (`web_pipeline`, `full_pipeline`, `authenticated`) continue to work — same API, better internals

---

## New Files

| File | Layer | Purpose |
|------|-------|---------|
| `lib/crypto.march` | Cross-cutting | Random bytes, HMAC, AES-GCM, SHA-256, Argon2id password hashing |
| `lib/depot_middleware.march` | 2 | `with_pool`, `after_send` pool checkin |
| `lib/session.march` | 3 | Cookie session: load, commit, auto-commit, get/put/delete/clear |
| `lib/flash.march` | 4 | Flash messages: put, get, load_flash, clear |
| `lib/vault.march` | 7 | In-memory KV actor with TTL |
| `lib/csrf.march` | 5 | Token generation, form injection, validation |
| `lib/auth_middleware.march` | 6 | `load_current_user`, `require_auth`, `authenticated`, `log_in`, `log_out` |
| `lib/rate_limit.march` | 8 | Sliding window rate limiting backed by Vault |

Plus generator scaffolding and migration tooling, which touch forge rather than Bastion lib.

---

## Error Handling

Each layer has specific failure modes. The principle: **fail safe** — if a security mechanism can't determine whether a request is valid, reject it.

### Layer 0 — Conn

| Failure | Behaviour |
|---------|-----------|
| Cookie parse error (malformed Cookie header) | Return empty map — no cookies found |
| `after_send` callback raises | Log the error, continue running remaining callbacks |
| Form body parse error | `get_form_param` returns `None` |

### Layer 2 — Depot

| Failure | Behaviour |
|---------|-----------|
| Pool exhausted (checkout timeout) | Respond 503 Service Unavailable immediately; do not queue |
| Query error (bad SQL, constraint violation) | Propagate as `Error(...)` to application code |
| Connection dropped mid-request | Depot marks the connection as dead; pool replaces it; current request gets an error |

The pool checkout timeout is configurable (default: 5000ms). If the pool is consistently exhausted, it's a capacity problem, not something the framework should silently retry.

### Layer 3 — Sessions

| Failure | Behaviour |
|---------|-----------|
| Cookie absent | Start fresh empty session |
| Cookie signature invalid (tampered) | Start fresh empty session; do not log the bad cookie value (may contain attacker data) |
| Cookie decryption fails | Start fresh empty session |
| Cookie too large (>4096 bytes) | Log warning; truncate or reject. Cookie sessions should stay small — use Vault/Depot backend for large session data. |
| `SECRET_KEY_BASE` missing at startup | Crash immediately with a clear error message. Do not fall back to a default key. |

### Layer 3b — Vault

| Failure | Behaviour |
|---------|-----------|
| Table not started | Raise at lookup time with a clear message: "Vault table :name has not been started" |
| Sweeper crash | Supervisor restarts it; expired entries accumulate until the next sweep |
| Memory pressure | Vault does not enforce a size limit in v1. Monitor via `Vault.info/1`. |

### Layer 5 — CSRF

| Failure | Behaviour |
|---------|-----------|
| Token missing from request | 403 Forbidden, body: "Missing CSRF token" |
| Token mismatch | 403 Forbidden, body: "Invalid CSRF token" |
| Session not loaded (programming error) | Raise: "CSRF.protect requires a loaded session — call load_session before protect" |

### Layer 6 — Auth

| Failure | Behaviour |
|---------|-----------|
| User ID in session but user deleted from DB | `load_current_user` assigns `None`; does not halt |
| Loader function raises | Treat as `Error(...)` → assign `None`; log the error |
| `require_auth` called before `load_current_user` | Still works — checks `current_user` assign, which is `None` if never set |

---

## Configuration

All configuration flows through a single config module in the application. Bastion does not read environment variables directly — the app's config module does that and passes values to Bastion.

### Required configuration

```march
-- config/config.march
mod MyApp.Config do

  fn secret_key_base() : String do
    -- Must be at least 64 bytes. In production, read from env.
    -- In development, a stable default is fine.
    match Bastion.env() do
    | :prod -> System.get_env!("SECRET_KEY_BASE")
    | _     -> "dev-secret-key-base-at-least-64-bytes-long-for-hmac-and-aes-operations!!"
    end
  end

  fn session_opts() : Bastion.Session.SessionOpts do
    Bastion.Session.opts(
      cookie_name: "_my_app_session",
      secret: secret_key_base(),
      max_age: 60 * 60 * 24 * 30,  -- 30 days
      same_site: :lax,
      secure: Bastion.env() == :prod
    )
  end

  fn db_config() : Depot.Config do
    %{
      hostname: System.get_env("DB_HOST") |> Option.unwrap_or("localhost"),
      port: 5432,
      database: "my_app_" ++ Atom.to_string(Bastion.env()),
      username: System.get_env("DB_USER") |> Option.unwrap_or("postgres"),
      password: System.get_env("DB_PASSWORD") |> Option.unwrap_or(""),
      pool_size: 10
    }
  end

  fn password_hash_opts() : Crypto.PasswordOpts do
    %{
      algorithm: :argon2id,
      memory_cost: 65536,    -- 64 MB
      time_cost: 3,
      parallelism: 4
    }
  end

end
```

### Configuration validation at startup

The application supervisor validates configuration before starting the server:

```march
fn start() do
  -- Validate critical config
  let secret = MyApp.Config.secret_key_base()
  if String.byte_length(secret) < 64 do
    panic("SECRET_KEY_BASE must be at least 64 bytes, got ${String.byte_length(secret)}")
  end

  -- Start services
  children = [
    {Vault.Sweeper, interval: 30_000},
    {Depot.Pool, MyApp.Config.db_config()},
    {Bastion.Endpoint, MyApp.Endpoint, port: 4000}
  ]
  Bastion.Supervisor.start_link(children, strategy: :one_for_one)
end
```

`forge gen.auth session` generates a `SECRET_KEY_BASE` value and writes it to `config/dev.march`. It also adds a `.env.example` with a placeholder for production.

---

## Testing Strategy

Each layer can be tested in isolation. The test helpers build on `Bastion.Test` (already implemented in `test.march`).

### Testing sessions

```march
test "session round-trip: put then get" do
  let conn = Bastion.Test.conn(:get, "/")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  let tc = Session.put(tc, "user_id", "42")
  assert Session.get(tc, "user_id") == Some("42")
end

test "load_session with no cookie starts empty session" do
  let conn = Bastion.Test.conn(:get, "/")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  assert Session.get(tc, "anything") == None
end

test "tampered cookie starts fresh session" do
  let conn = Bastion.Test.conn(:get, "/")
    |> put_req_header("cookie", "_my_app_session=tampered-garbage")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  assert Session.get(tc, "anything") == None
end
```

### Testing CSRF

```march
test "CSRF blocks POST without token" do
  let conn = Bastion.Test.conn(:post, "/submit")
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  let tc = CSRF.protect(tc)
  assert Conn.status(unwrap(tc)) == 403
end

test "CSRF allows POST with valid token" do
  -- First, generate a token in the session
  let conn = Bastion.Test.conn(:get, "/form")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  let token = CSRF.token(tc)
  -- Now simulate a POST with that token
  let conn = Bastion.Test.conn(:post, "/submit")
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> put_req_body("_csrf_token=" ++ token)
  -- Must use the same session
  let tc = wrap(conn) |> parse_body() |> load_session_with(test_secret(), session_from(tc))
  let tc = CSRF.protect(tc)
  assert not Conn.halted(unwrap(tc))
end

test "CSRF skips JSON requests" do
  let conn = Bastion.Test.conn(:post, "/api/items")
    |> put_req_header("content-type", "application/json")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  let tc = CSRF.protect(tc)
  assert not Conn.halted(unwrap(tc))
end
```

### Testing auth

```march
test "require_auth returns Ok when user is loaded" do
  let conn = Bastion.Test.conn(:get, "/dashboard")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  let tc = load_current_user(tc, fn _conn id -> Ok(%{ id: id, email: "test@test.com" }) end)
  -- Simulate a logged-in session
  let tc = Session.put(tc, "current_user_id", "1")
  let tc = load_current_user(tc, fn _conn _id -> Ok(%{ id: 1 }) end)
  match require_auth(tc) do
  | Ok(_)    -> assert true
  | Error(_) -> assert false
  end
end

test "require_auth returns Error and redirects when no user" do
  let conn = Bastion.Test.conn(:get, "/dashboard")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
  match require_auth(tc) do
  | Ok(_)      -> assert false
  | Error(conn) ->
      assert Conn.status(conn) == 302
      assert Conn.get_resp_header(conn, "location") == Some("/login")
  end
end

test "authenticated helper runs handler on auth success" do
  let conn = Bastion.Test.conn(:get, "/dashboard")
  let tc = wrap(conn) |> parse_body() |> load_session(test_secret())
    |> put_session_value("current_user_id", "1")
    |> load_current_user(fn _conn _id -> Ok(%{ id: 1 }) end)
  let result = authenticated(tc, fn authed_tc ->
    Conn.send_resp(unwrap(authed_tc), 200, "dashboard")
  end)
  assert Conn.status(result) == 200
end
```

### Testing with the Depot sandbox

Tests that hit the database use the transaction sandbox (Layer 1d). The sandbox wraps each test in a transaction that rolls back, giving per-test isolation without truncation:

```march
test "login with valid credentials" do
  use Bastion.Test.Depot
  let db = checkout()
  -- Seed test data
  let hash = Crypto.hash_password("secret123")
  Depot.execute(db, "INSERT INTO users (email, password_hash) VALUES ($1, $2)", ["test@test.com", hash])

  let conn = Bastion.Test.conn(:post, "/login")
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> put_req_body("email=test@test.com&password=secret123&_csrf_token=" ++ valid_csrf_token())
  let result = MyApp.Router.route(conn)
  assert Conn.status(result) == 302
  -- Session should have user_id
end
```

### Test helper: `Bastion.Test.Auth`

A convenience module for tests that need authenticated requests without going through the login flow:

```march
-- lib/test.march (addition)
mod Bastion.Test.Auth do

  fn log_in_user(conn : Conn, user_id : Int, secret : String) : Conn do
    let tc = wrap(conn) |> parse_body() |> load_session(secret)
    let tc = Session.put(tc, "current_user_id", Int.to_string(user_id))
    Session.commit(tc, test_session_opts()) |> unwrap()
  end

end
```

---

## End-to-End Example

A complete request through all layers, showing how the pieces compose.

### Application setup

```march
-- src/my_app.march
mod MyApp do

  fn start() do
    let secret = MyApp.Config.secret_key_base()
    if String.byte_length(secret) < 64 do panic("SECRET_KEY_BASE too short") end

    Vault.new("rate_limits", opts: [ttl_sweep_interval: 30])

    let children = [
      {Vault.Sweeper, interval: 30_000},
      {Depot.Pool, MyApp.Config.db_config()},
      {Bastion.Endpoint, MyApp.Endpoint, port: 4000}
    ]
    Bastion.Supervisor.start_link(children, strategy: :one_for_one)
  end

end
```

### Endpoint pipeline

```march
-- src/my_app/endpoint.march
mod MyApp.Endpoint do

  fn call(conn : Conn) : Conn do
    let secret = MyApp.Config.secret_key_base()
    let pool   = MyApp.Repo.pool()

    -- Layer 0+1: attach DB, parse, load session
    let tc = TypedMiddleware.wrap(conn)
             |> TypedMiddleware.parse_body()
             |> TypedMiddleware.load_session(secret)

    -- Layer 4: soft-load current user (from session + remember-me)
    let tc = TypedMiddleware.load_current_user(tc, fn conn id ->
      MyApp.Accounts.get_user(TypedMiddleware.get_db(conn), id)
    end)

    -- Layer 3: CSRF protection
    let tc = Bastion.CSRF.protect(tc)

    -- Flash
    let tc = Bastion.Flash.load_flash(tc)

    -- Unwrap and route
    let conn = TypedMiddleware.unwrap(tc)
    let conn = TypedMiddleware.with_db(conn, pool)
    MyApp.Router.route(conn)
  end

end
```

### Router with authenticated and public routes

```march
-- src/my_app/router.march
mod MyApp.Router do

  -- Public routes
  fn route(conn, :get, ["login"])     do MyApp.AuthController.login_form(conn) end
  fn route(conn, :post, ["login"])    do
    match Bastion.RateLimit.check(conn, login_rate_opts()) do
    | Ok(conn)    -> MyApp.AuthController.login(conn)
    | Error(conn) -> conn
    end
  end
  fn route(conn, :delete, ["logout"]) do MyApp.AuthController.logout(conn) end
  fn route(conn, :get, ["register"])  do MyApp.AuthController.register_form(conn) end
  fn route(conn, :post, ["register"]) do MyApp.AuthController.register(conn) end

  -- Authenticated routes
  fn route(conn, :get, ["dashboard"]) do
    let tc = TypedMiddleware.wrap(conn) |> TypedMiddleware.parse_body()
             |> TypedMiddleware.load_session(MyApp.Config.secret_key_base())
             |> TypedMiddleware.load_current_user(user_loader())
    TypedMiddleware.authenticated(tc, fn authed_tc ->
      let user = TypedMiddleware.get_current_user(authed_tc)
      MyApp.DashboardController.index(TypedMiddleware.unwrap(authed_tc), user)
    end)
  end

  -- Catch-all
  fn route(conn, _, _) do Conn.send_resp(conn, 404, "Not Found") end

end
```

### Auth controller (generated)

```march
-- src/my_app/auth_controller.march (generated by forge gen.auth session)
mod MyApp.AuthController do

  fn login(conn : Conn) : Conn do
    let email    = Conn.get_form_param(conn, "email") |> Option.unwrap_or("")
    let password = Conn.get_form_param(conn, "password") |> Option.unwrap_or("")
    let remember = Conn.get_form_param(conn, "remember_me") == Some("true")
    let db       = TypedMiddleware.get_db(conn)

    match MyApp.Accounts.authenticate(db, email, password) do
    | Ok(user) ->
        let tc = TypedMiddleware.wrap(conn) |> TypedMiddleware.parse_body()
                 |> TypedMiddleware.load_session(MyApp.Config.secret_key_base())
        let tc = Bastion.Auth.log_in(tc, user.id, %{ remember_me: remember })
        let return_to = Session.get(tc, "return_to") |> Option.unwrap_or("/dashboard")
        let tc = Session.delete(tc, "return_to")
        TypedMiddleware.unwrap(tc)
        |> Bastion.Flash.put("info", "Welcome back!")
        |> Conn.put_resp_header("location", return_to)
        |> Conn.send_resp(302, "")
    | Error(:unauthorized) ->
        conn
        |> Bastion.Flash.put("error", "Invalid email or password")
        |> Conn.put_resp_header("location", "/login")
        |> Conn.send_resp(302, "")
    end
  end

  fn logout(conn : Conn) : Conn do
    let tc = TypedMiddleware.wrap(conn) |> TypedMiddleware.parse_body()
             |> TypedMiddleware.load_session(MyApp.Config.secret_key_base())
    let tc = Bastion.Auth.log_out(tc)
    TypedMiddleware.unwrap(tc)
    |> Bastion.Flash.put("info", "Logged out successfully")
    |> Conn.put_resp_header("location", "/")
    |> Conn.send_resp(302, "")
  end

end
```

---

## Security Checklist

A verification checklist for implementors. Each item maps to a specific layer.

### Cryptography (Layer 1)
- [ ] `SECRET_KEY_BASE` is at least 64 bytes
- [ ] App panics at startup if `SECRET_KEY_BASE` is missing or too short
- [ ] AES-256-GCM is used for cookie encryption (not AES-CBC)
- [ ] HMAC-SHA256 signature is verified **before** decryption (encrypt-then-MAC)
- [ ] `secure_compare` is constant-time (prevents timing attacks on CSRF and signatures)
- [ ] Password hashing uses Argon2id with recommended parameters (≥64MB memory, ≥3 iterations)
- [ ] `Crypto.random_bytes` uses a CSPRNG, not `Math.random`

### Sessions (Layer 3)
- [ ] Session cookie has `HttpOnly`, `Secure` (in prod), `SameSite=Lax`
- [ ] Tampered cookies result in empty sessions, not errors or partial data
- [ ] Session is rotated on login (`Session.clear()` before writing new user ID)
- [ ] Session cookie value is not logged or included in error reports
- [ ] `max_age` is enforced server-side (not just by the browser)

### CSRF (Layer 5)
- [ ] All non-safe methods (POST/PUT/PATCH/DELETE) with form content types are checked
- [ ] Token comparison uses `secure_compare`, not `==`
- [ ] JSON requests are exempt (CORS provides same-origin guarantee)
- [ ] `CSRF.skip()` is explicit per-route, not a global toggle
- [ ] `~H` form desugaring automatically injects the token (no opt-in needed)

### Auth (Layer 6)
- [ ] Remember-me tokens are hashed before storage (raw token never in DB)
- [ ] Password reset tokens expire after 1 hour
- [ ] Password reset tokens are single-use (deleted after use)
- [ ] Password change invalidates all existing tokens and sessions
- [ ] `request_reset` response time is constant regardless of whether email exists
- [ ] Login rate limiting is active (5/min by default)
- [ ] Failed login does not reveal whether email exists ("Invalid email or password", not "User not found")

### Database (Layer 2)
- [ ] Pool connections are always returned, even on request failure (`after_send`)
- [ ] Pool exhaustion returns 503, not a hang
- [ ] Test sandbox rolls back — no data leaks between tests
- [ ] Parameterized queries are used everywhere (no string interpolation into SQL)

---

## Changes to Existing Files

In addition to new files, these existing files require modifications:

| File | Change | Layer |
|------|--------|-------|
| `lib/conn.march` | Add `get_req_cookie`, `put_resp_cookie`, `delete_resp_cookie`, `register_after_send`, `run_after_send`, `get_form_param` | 0 |
| `lib/bastion_server.march` | Call `Conn.run_after_send(conn)` after sending the response | 0 |
| `lib/typed_middleware.march` | Replace session stubs with calls to `Session.load`; add `_session_dirty` tracking; update `load_current_user` to check remember-me cookie | 3, 6 |
| `lib/test.march` | Add `Bastion.Test.Auth` and `Bastion.Test.Depot` modules | Testing |
| `forge.toml` | Add `depot` dependency; add `gen.auth`, `depot.migrate`, `depot.rollback` commands | 2, 7 |
