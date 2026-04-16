# Bastion: Form Handling

**Status**: Design | **Version**: 0.1 | **Part of**: [Bastion Design Spec](README.md)

---

## Overview

Bastion forms work at three levels of progressively richer capability:

| Tier | Transport | Validation | When to use |
|------|-----------|------------|-------------|
| **Plain** | Full-page POST | Server-side only | Works without JS, accessibility baseline |
| **Enhanced** | `fetch` POST, partial re-render | Server-side + client-side preview | Multi-step flows, inline errors without reload |
| **Island** | Channel push | Client WASM + server confirmation | Highly interactive forms, real-time feedback |

Every tier uses the same validation logic — the same March function that validates a `Gate` on the server can compile to WASM and run on the client. You write validation once.

---

## The Gate Abstraction

Form validation in Bastion is built on `Depot.Gate` — the changeset API. A gate is an immutable value that tracks: the original data, the proposed changes, and any validation errors accumulated along the pipeline.

```march
-- lib/my_app/accounts/user.march
import Depot.Gate as Gate

fn registration_gate(params) do
  Gate.cast(params, ["email", "password"])
    |> Gate.validate_required(["email", "password"])
    |> validate_email()
    |> validate_password()
end

pfn validate_email(gate) do
  Gate.validate_format(gate, "email", ".+@.+\\..+")
    |> Gate.validate_length("email", [LenMax(160)])
end

pfn validate_password(gate) do
  Gate.validate_length(gate, "password", [LenMin(12), LenMax(72)])
end
```

A gate is valid when `Gate.valid?(gate)` is true and carries no errors. A gate with errors is still a value — you hand it back to the template to display errors alongside the form.

### Gate API

```march
-- Construction
Gate.cast(params, permitted_fields)                     -- new gate from params list
Gate.cast_record(record, params, permitted_fields)      -- update existing record

-- Validation
Gate.validate_required(gate, fields)
Gate.validate_format(gate, field, regex_string)
Gate.validate_length(gate, field, [LenMin(n), LenMax(n)])
Gate.validate_number(gate, field, [NumMin(n), NumMax(n)])
Gate.validate_inclusion(gate, field, values)
Gate.validate_confirmation(gate, field)                 -- checks field_confirmation matches
Gate.unique_constraint(gate, field, opts)               -- checked on DB insert, not here

-- Reading
Gate.valid?(gate)                                       -- Bool
Gate.get_change(gate, field)                            -- Option(String)
Gate.get_field(gate, field)                             -- Option(String) — change or original
Gate.errors(gate)                                       -- Map(String, String)
Gate.error_for(gate, field)                             -- Option(String)

-- Mutation
Gate.put_change(gate, field, value)
Gate.delete_change(gate, field)
Gate.add_error(gate, field, message)
```

---

## Tier 1: Plain Server-Side Forms

The default form pattern. No JavaScript required. Works as the accessibility and resilience baseline before WASM loads.

### Handler

```march
mod MyApp.RegistrationController do
  import TypedMiddleware as TM
  import Request
  import Controller

  fn new(conn) do
    let gate = Gate.cast([], [])  -- empty gate for a blank form
    render_form(conn, gate)
  end

  fn create(conn) do
    let params = Request.body_params(conn)
    let gate   = MyApp.Accounts.registration_gate(params)
    if Gate.valid?(gate) do
      case Depot.insert(db(conn), MyApp.Accounts.User.schema(), gate) do
        Ok(user)  ->
          conn
          |> put_flash("info", "Welcome! Please check your email to confirm your account.")
          |> redirect_to("/login")
        Error(gate_with_db_errors) ->
          render_form(conn, gate_with_db_errors)
      end
    else
      render_form(conn, gate)
    end
  end

  pfn render_form(conn, gate) do
    render(conn, "registration/new.march.html", [("gate", gate)])
  end

  pfn db(conn) do TM.get_db(conn) end
end
```

### Template

```html
<!-- registration/new.march.html -->
---
fn new(conn, gate)
---
<h1>Create account</h1>

<.form action="/register" method="post">
  <.input type="email"    name="email"    label="Email"    gate={gate} />
  <.input type="password" name="password" label="Password" gate={gate} />
  <button type="submit">Register</button>
</.form>
```

The `<.form>` component injects a CSRF token automatically. The `<.input>` component renders the label, the `<input>` element, and any error message from the gate:

```html
<!-- rendered output for an invalid email field -->
<div class="field">
  <label for="email">Email</label>
  <input type="email" name="email" id="email" value="not-an-email"
         aria-describedby="email-error" aria-invalid="true" />
  <span class="error" id="email-error">must contain @</span>
</div>
```

---

## Tier 2: Enhanced Fetch Forms

Enhanced forms intercept the submit event and POST via `fetch`, then swap only the form HTML with the server response. No full-page reload. Progressive enhancement: if JS doesn't load, the plain form still works.

```html
<!-- registration/new.march.html -->
---
fn new(conn, gate)
---
<.form action="/register" method="post" enhance>
  <.input type="email"    name="email"    label="Email"    gate={gate} />
  <.input type="password" name="password" label="Password" gate={gate} />
  <button type="submit">Register</button>
</.form>
```

The `enhance` attribute on `<.form>` tells the JS runtime to intercept submissions. On the server side, the handler is unchanged — the same `create/1` action runs. The only difference is the response: when the request has `Accept: text/fragment`, the server returns only the form HTML fragment rather than the full page.

```march
-- Controller detects fragment requests
fn create(conn) do
  let params = Request.body_params(conn)
  let gate   = MyApp.Accounts.registration_gate(params)
  if Gate.valid?(gate) do
    -- success is always a redirect (fragment or full)
    conn
    |> put_flash("info", "Account created!")
    |> redirect_to("/login")
  else
    -- failure: re-render form with errors
    render_form(conn, gate)  -- same whether fragment or full page
  end
end
```

Bastion handles the `Accept: text/fragment` detection internally. If the request wants a fragment, only the form component is rendered in the response; the layout wrapper is stripped.

---

## Tier 3: Island Forms

For highly interactive forms — real-time validation, multi-step wizards, optimistic updates — use a WASM island. See [islands-data-flow.md](islands-data-flow.md) §"Forms as First-Class Islands" for the full `ContactForm` example.

### The key: shared validation

The same `validate/1` function compiles to both targets:

```march
mod ContactForm do
  type State = {
    name  : String,
    email : String,
    errors : Map(String, String)
  }

  -- This function is compiled to WASM for client-side validation
  -- AND runs on the server when the channel push arrives.
  -- Write it once; it runs in both places.
  fn validate(state : State) : Map(String, String) do
    Map.empty()
    |> validate_required("name",  state.name)
    |> validate_email("email", state.email)
  end

  pfn validate_required(errors, field, value) do
    if String.length(String.trim(value)) == 0
    then Map.put(errors, field, "is required")
    else errors
  end

  pfn validate_email(errors, field, value) do
    if String.contains(value, "@")
    then errors
    else Map.put(errors, field, "must be a valid email")
  end
end
```

The March compiler emits both a native (server) build and a `wasm32-unknown-unknown` build of the island module. The same `validate` function runs:
- In the WASM build: called on every keystroke, giving instant client-side feedback
- In the native build: called on the channel handler, giving authoritative server-side validation

This eliminates the server/client validation drift that plagues most web frameworks. There is no separate JS validation layer to keep in sync.

### Island form structure

```march
mod ContactForm do
  type State = { name : String, email : String, message : String,
                 errors : Map(String, String), status : Idle | Submitting | Done }
  type Msg   = Field(String, String) | Submit | ServerResponse(Result(Unit, Map(String, String)))

  fn render(state : State) : String do
    ~H"""
    <form data-on-submit="Submit">
      <.field name="name"    value={state.name}    error={Map.get(state.errors, "name")} />
      <.field name="email"   value={state.email}   error={Map.get(state.errors, "email")} />
      <.textarea name="message" value={state.message} />
      <button type="submit" disabled={state.status == Submitting}>
        {if state.status == Submitting then "Sending..." else "Send"}
      </button>
      {if state.status == Done then ~H"<p class=\"success\">Sent!</p>" else ""}
    </form>
    """
  end

  fn update(state : State, msg : Msg) : { state : State, cmd : Option(Cmd) } do
    match msg do
    | Field(k, v) ->
        let s = set_field(state, k, v)
        { state = { s with errors = validate(s) }, cmd = None }
    | Submit ->
        let errs = validate(state)
        if Map.is_empty(errs)
        then { state = { state with status = Submitting },
               cmd   = Some(Channel.push("contact:submit", encode(state))) }
        else { state = { state with errors = errs }, cmd = None }
    | ServerResponse(Ok()) ->
        { state = { state with status = Done }, cmd = None }
    | ServerResponse(Error(errs)) ->
        { state = { state with status = Idle, errors = errs }, cmd = None }
    end
  end
end
```

Island forms validate locally on each keystroke (`Field` message) and again on submit before pushing to the channel. The server validates once more before persisting.

---

## Built-in Form Components

These `~H` components ship with Bastion. They handle the boilerplate that Phoenix requires you to build yourself, while staying out of the way for custom cases.

### `<.form>`

```html
<.form action="/users" method="post">...</.form>
```

- Injects a hidden `_csrf_token` field automatically
- Adds `enhance` attribute support for fetch-based submission
- `method` defaults to `post`

Attributes:
| Attribute | Description |
|-----------|-------------|
| `action`  | Form action URL |
| `method`  | HTTP method (default: `post`) |
| `enhance` | Boolean — intercept and submit via fetch |
| `class`   | Forwarded to `<form>` |

### `<.input>`

```html
<.input type="email" name="email" label="Email address" gate={gate} />
<.input type="text"  name="name"  label="Name"          value={@name} />
```

Renders a `<div class="field">` wrapper containing label, input, and error message.

Attributes:
| Attribute | Description |
|-----------|-------------|
| `type`    | Input type (text, email, password, number, tel, url, …) |
| `name`    | Field name |
| `label`   | Label text |
| `gate`    | `Depot.Gate` — fills value and error from gate changes/errors |
| `value`   | Explicit value (overrides gate) |
| `error`   | Explicit error string (overrides gate) |
| `required`| Adds HTML `required` and asterisk to label |
| `class`   | Forwarded to `<input>` |
| Any other | Forwarded to `<input>` |

### `<.textarea>`

Same as `<.input>` but renders `<textarea>`.

### `<.select>`

```html
<.select name="role" label="Role" options={[("Admin", "admin"), ("Member", "member")]} gate={gate} />
```

Renders `<select>` with `<option>` elements. Options are `List((String, String))` — label + value.

### `<.field>` (unstyled wrapper)

For custom input types or external component libraries, `<.field>` provides only the wrapper and error display without prescribing the input markup:

```html
<.field name="avatar" label="Profile picture" gate={gate}>
  <input type="file" name="avatar" accept="image/*" />
</.field>
```

### `<.error>`

Standalone error display:

```html
<.error gate={gate} field="email" />
```

---

## Flash Messages

Flash messages persist across redirects. They are stored in the session and consumed once.

### Setting a flash

```march
conn
|> put_flash("info",  "Account created successfully.")
|> put_flash("error", "Something went wrong.")
|> redirect_to("/dashboard")
```

### Displaying flash in a layout

```html
<!-- layout/app.march.html -->
---
fn app(conn, inner)
---
<.flash_group conn={conn} />
{inner}
```

The `<.flash_group>` component renders all pending flash messages and clears them from the session. It renders nothing if there are no pending messages.

Default flash key rendering:

| Key | CSS class | ARIA role |
|-----|-----------|-----------|
| `"info"` | `flash-info` | `status` |
| `"error"` | `flash-error` | `alert` |
| `"warning"` | `flash-warning` | `alert` |

Custom keys are rendered with class `flash-{key}`.

### Flash API

```march
-- Controller helpers
put_flash(conn, key, message)   -- store a flash message
get_flash(conn, key)            -- Option(String) — read without consuming
clear_flash(conn)               -- remove all flash messages
```

Flash is consumed (cleared) automatically when `<.flash_group>` renders.

---

## Multi-Step Forms

For multi-step wizards, store intermediate state in the session between steps. Each step is a plain controller action.

```march
mod MyApp.OnboardingController do

  fn step1(conn) do
    render(conn, "onboarding/step1.march.html", [("gate", Gate.cast([], []))])
  end

  fn step1_submit(conn) do
    let params = Request.body_params(conn)
    let gate   = validate_step1(params)
    if Gate.valid?(gate) do
      conn
      |> TM.put_session_value("onboarding_step1", encode_step1(params))
      |> redirect_to("/onboarding/step2")
    else
      render(conn, "onboarding/step1.march.html", [("gate", gate)])
    end
  end

  fn step2(conn) do
    let prev = TM.get_session_value(conn, "onboarding_step1")
    render(conn, "onboarding/step2.march.html", [("gate", Gate.cast([], [])), ("prev", prev)])
  end

  -- ... etc
end
```

---

## Comparison with Other Frameworks

### Phoenix (Elixir)

The closest analogue. Phoenix uses `Ecto.Changeset` for validation, `Phoenix.HTML.Form` for rendering, and `CoreComponents` for input helpers. Bastion's design maps directly:

| Phoenix | Bastion |
|---------|---------|
| `Ecto.Changeset` | `Depot.Gate` |
| `Phoenix.HTML.Form` | `Bastion.Form` (render layer) |
| `to_form/1` | Not needed — `Gate` is passed directly to components |
| `<.input>` in CoreComponents | `<.input>` built into Bastion |
| `<.flash>` in CoreComponents | `<.flash_group>` built into Bastion |
| `put_flash/3` | `put_flash/3` (same) |

**Where Bastion improves on Phoenix**: Phoenix requires you to write separate JS validation (or accept that client-side validation is a separate system that can drift from server-side). In Bastion, `validate/1` is a March function that compiles to both WASM and native — there is no separate layer.

### SvelteKit / Remix

Both use a `form action` + `use:enhance` progressive enhancement model that is very similar to Bastion's Tier 1/Tier 2 design. The key difference: in those frameworks, server-side validation is JavaScript (Zod, etc.) and client-side validation is also JavaScript, but they are typically separate schemas or re-implementations. In Bastion, the March function is literally the same artifact for both.

### React Hook Form / Zod

Bastion does not compete with these for pure client-side SPA use cases. For island forms that need complex real-time interaction, the `ContactForm` pattern in Tier 3 is the equivalent — but with a native server component rather than an API endpoint.

---

## Implementation Plan

Dependencies: `~H` templates (triple-quoted sigil fix + `bastion lower` CLI), `lib/csrf.march`.

1. **`Bastion.Form` render helpers** — `form_tag`, `input_tag`, `error_tag`. Low-level HTML builders used by the `~H` components.
2. **`<.form>`, `<.input>`, `<.select>`, `<.textarea>`, `<.field>`, `<.error>` components** — `~H` components registered in the Bastion component namespace.
3. **`<.flash_group>` component** — reads and clears flash from session assigns.
4. **`put_flash/3`, `get_flash/2`, `clear_flash/1`** — session-backed flash API in `lib/session.march`.
5. **Enhanced form JS** — intercept `<form enhance>` submit, POST via fetch, swap fragment response.
6. **Shared validation story** — document the island form pattern and the `wasm32-unknown-unknown` compilation path. No new code needed; this is already how the compiler works.

Order: items 1–4 can be built before WASM. Item 5 requires the JS runtime. Item 6 is documentation.

---

## Open Questions

- **`enhance` fragment response format**: Should the server return the `<form>` HTML directly, or a JSON envelope with the HTML? Direct HTML is simpler; JSON allows returning out-of-band updates (e.g., update a counter elsewhere on the page without a full reload). Defer to implementation.
- **File uploads in enhanced forms**: `fetch` handles `multipart/form-data` natively, but streaming large files without degrading to full-page POST requires coordination with the uploads middleware. See [uploads.md](uploads.md).
- **Island form CSRF**: Island forms that push over a channel do not go through the CSRF middleware. Channel authentication (a token in the channel join) acts as the CSRF equivalent. Document this clearly.
