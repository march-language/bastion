# Bastion Islands Architecture

Design spec for Bastion's interactive island system. Islands are CRDT-hybrid
components where state exists on both client and server simultaneously. There
are no "modes" -- server-only, client-only, signal-only, and collaborative
behaviors all emerge from how you write your island, not from framework
configuration.

## Island Protocol

Every island is a March module that implements up to four functions:

| Function | Signature | Required | Purpose |
|----------|-----------|----------|---------|
| `init`   | `(Props) -> State` | yes | Initialize state from parent-provided props |
| `update` | `(State, Msg) -> State` | yes | Handle a message, produce new state |
| `render` | `(State) -> IOList` | yes | Produce HTML via the `~H` sigil |
| `merge`  | `(State, State) -> State` | no | CRDT reconciliation of local vs remote state |

Islands also define up to three types:

- `type State` -- the island's state shape
- `type Msg` -- the set of messages the island handles
- `type Props` -- the initialization parameters passed by the parent

If `merge` is not defined, the framework provides a default server-wins /
last-write-wins implementation:

```march
fn merge(_local : State, remote : State) : State do
  remote
end
```

This means the simplest island is three functions -- `init`, `update`, `render`
-- the same shape as Elm.

## Templates and Embedding

Islands are embedded in `~H` templates via the `<island>` tag:

```march
~H"""
<h1>Dashboard</h1>
<island module="Counter" init=${{ initial = 0 }} />
<island module="TodoList" init=${{ items = [] }} />
"""
```

The compiler:

- Validates the referenced module exists and has the correct protocol shape
- Automatically bundles WASM for every referenced island
- Generates a hydration placeholder `<div>` with script attributes in the
  output HTML

Parents pass props to islands via attributes on `<island>`. The `init`
attribute maps to the island's `Props` type.

## Composition

- Islands can contain other islands (nested `<island>` tags inside `render`)
- Each island manages its own state independently
- Communication between sibling or parent/child islands goes through the
  server via actor message passing, never through direct client-side coupling

## WebSocket Architecture

### Connection Model

One multiplexed WebSocket per browser page/tab. All island instances on the
page share that single connection. Messages are tagged with an island instance
ID to route them to the correct island actor on the server and WASM instance
on the client.

### Wire Format

JSON to start. Binary format is a future optimization.

Client to server:

```json
{"island": "counter-1", "type": "msg", "payload": "Increment"}
```

Server to client:

```json
{"island": "counter-1", "type": "state", "payload": {"count": 5}}
{"island": "counter-1", "type": "merge", "payload": {"count": 5}}
```

## State Serialization

Serialization is auto-derived from type definitions. The compiler knows the
structure of `type State = { count : Int }` and generates serialize/deserialize
code automatically. There is no manual serialization boilerplate for island
state.

## Client Runtime

A thin JS runtime in the browser handles:

1. Opening the multiplexed WebSocket on page load
2. Loading WASM modules for each island present on the page
3. Routing messages between the WebSocket and WASM instances
4. Calling the WASM `render` function when state changes
5. Morphing the DOM using idiomorph
6. Capturing `data-msg` events from the DOM and dispatching them to the
   island's `update` function

### DOM Patching

DOM patching uses idiomorph (from the htmx team, ~500 LOC), vendored into
Bastion's client JS runtime.

Key properties:

- **ID-set matching algorithm** -- handles list reordering naturally via HTML
  `id` attributes. No `key` prop system needed.
- **Preserves DOM state** -- focus, scroll position, selections, CSS
  transitions all survive patches.
- **Future optimization** -- server-side diff computation (send only changed
  dynamic parts), with idiomorph handling last-mile patching.

### Event Dispatch

DOM elements declare their messages via `data-msg` attributes:

```html
<button data-msg="Increment">+</button>
```

The JS runtime intercepts these events and routes them to the owning island's
`update` function (client-side in WASM) and/or sends them over the WebSocket
to the server actor.

## Server-Side Runtime

Each island instance is a March actor on the server:

- The actor holds the current authoritative state
- Runs `update` for server-side messages
- Sends state to the client via WebSocket on changes
- Receives client state and messages via WebSocket
- Calls `merge` when client and server state diverge

## Behavioral Patterns

These are conventions, not modes. The framework has one unified model; the
behavior emerges from how you write your island.

| Pattern | How it works |
|---------|-------------|
| **Server-authoritative** | `update` only called server-side. Client renders but never mutates locally. `merge` is the default `fn(_, remote) -> remote`. |
| **Client-first** | `update` called client-side in WASM. Server persists. Good for forms, editors, anything latency-sensitive. |
| **Collaborative / synced** | Both sides call `update`. `merge` implements real CRDT logic for conflict resolution. |
| **Signal / broadcast** | No `update`, no `Msg` type. Server pushes state changes, client just renders. Dashboard widgets, live feeds. |

## Compilation

Islands compile to WASM via `march --compile --target wasm32-unknown-unknown`.

The `forge build` step for a Bastion app:

1. Identifies all `<island module="X">` references in templates
2. Compiles each referenced island module to WASM
3. Places WASM artifacts in the app's `islands/` directory
4. Generates the client JS runtime bundle with an island registry mapping
   module names to their WASM files

## Example

### Island Module

```march
mod Counter do
  type Props = { initial : Int }
  type State = { count : Int }
  type Msg = Increment | Decrement | Reset

  fn init(props : Props) : State do
    { count = props.initial }
  end

  fn update(state : State, msg : Msg) : State do
    match msg do
    Increment -> { count = state.count + 1 }
    Decrement -> { count = state.count - 1 }
    Reset     -> { count = 0 }
    end
  end

  fn render(state : State) : IOList do
    ~H"""
    <div id="counter" class="counter">
      <button data-msg="Decrement">-</button>
      <span class="count">${int_to_string(state.count)}</span>
      <button data-msg="Increment">+</button>
    </div>
    """
  end

  -- Optional: override default server-wins merge
  -- fn merge(local : State, remote : State) : State do
  --   { count = Int.max(local.count, remote.count) }
  -- end
end
```

### Usage in a Controller

```march
fn home(conn : Conn) : Conn do
  Controller.render_iolist_ok(conn, fn _c ->
    ~H"""
    <h1>My App</h1>
    <island module="Counter" init=${{ initial = 0 }} />
    <island module="TodoList" init=${{ items = [] }} />
    """
  )
end
```

## Implementation Phases

### Phase 1: Foundation

- Define the island module protocol (type checking for `init`/`update`/`render`/`merge` shape)
- Auto-derive state serialization from type definitions
- `<island>` tag parsing in the `~H` sigil

### Phase 2: Server Runtime

- WebSocket handler in the March runtime or Bastion stdlib
- Island actor lifecycle: spawn, state management, message routing
- Multiplexed WebSocket protocol implementation

### Phase 3: Client Runtime

- Vendor idiomorph into the client JS bundle
- JS runtime: WebSocket connection, WASM loading, event dispatch
- DOM morph on state change

### Phase 4: WASM Compilation

- Compile island modules to WASM via `march --compile --target wasm32-unknown-unknown`
- Auto-bundle referenced islands during `forge build`
- WASM-to-JS bridge: render calls, state serialization across the boundary

### Phase 5: Sync and CRDT

- Merge protocol over WebSocket
- Conflict detection and resolution
- Offline state persistence (IndexedDB or similar)
- Reconnection and state reconciliation
