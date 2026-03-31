# Bastion: Islands Data Flow

**Status**: Design | **Version**: 0.1 | **Part of**: [Bastion Design Spec](README.md)

This is the canonical design for how data flows into, through, and between Bastion WASM islands. It supersedes the global `window.marchIslands.send` messaging model described in the original [wasm-islands.md](wasm-islands.md).

---

## Overview

Islands have two data flow modes:

| Mode | State Owner | Client Role | Channel Required |
|------|-------------|-------------|-----------------|
| `Server` | Server owns state, pushes updates | Read-only projection | Required |
| `Client` | Island owns its own state | Handles events locally | Optional |

A third mode, `Collaborative`, is Phase 2 (CRDT-based multi-client sync). Do not design for it now.

The **mode describes state ownership**, not transport. A `Client` island without a channel wired up has purely local state. A `Client` island with a channel wired up syncs state after each update.

---

## Dataflow Modes

### Server mode

The server owns state. The island is a read-only projection — it renders, but it cannot independently update its own state. All mutations go through the server via a channel. The server pushes new state down.

```march
mod MyApp.ScoreBoard do
  type State = { scores : List({ name : String, score : Int }) }

  -- Server pushes new state; island renders it.
  -- No local Msg type — there's nothing to update locally.

  fn render(state : State) : String do
    ~H"""
    <div class="scoreboard">
      <%= for {name, score} <- state.scores do %>
        <div class="row"><span><%= name %></span><span><%= score %></span></div>
      <% end %>
    </div>
    """
  end
end

impl Island(MyApp.ScoreBoard.State) do
  fn dataflow() do Server end
  fn render(state) do MyApp.ScoreBoard.render(state) end
end
```

When `dataflow()` returns `Server`:
- The compiler rejects `data-on-*` event handlers in the island's render output. Use `Server` mode only for display-only islands.
- The JS runtime does not attach event listeners.
- State updates arrive exclusively via the wired channel.

### Client mode

The island owns its state. Events are handled locally by the WASM `update` function. Optionally, if a channel is wired up, state is synced to the server after each update (last-write-wins).

```march
mod Counter do
  type State = { count : Int }
  type Msg = Increment | Decrement | SetValue(Int)

  fn render(state : State) : String do
    ~H"""
    <div class="counter">
      <button data-on-click="Decrement">-</button>
      <span><%= state.count %></span>
      <button data-on-click="Increment">+</button>
    </div>
    """
  end

  fn update(state : State, msg : Msg) : State do
    match msg do
    | Increment     -> { state with count = state.count + 1 }
    | Decrement     -> { state with count = state.count - 1 }
    | SetValue(n)   -> { state with count = n }
    end
  end
end

impl Island(Counter.State) do
  fn dataflow() do Client end
  fn render(state) do Counter.render(state) end
  fn update(state, msg_json) do
    Counter.update(state, Counter.decode_msg(msg_json))
  end
end
```

### Collaborative mode (Phase 2 — do not implement now)

Multi-client simultaneous editing backed by CRDTs. CRDT metadata travels on a **separate sync channel**, never mixed into the rendered state JSON. Reserved for Phase 2.

---

## Parent–Child Data Binding

Parent islands can slot child islands with props derived from parent state. Children receive data — they do not own it.

**Key rules:**
- Children are always `Server`-dataflow relative to their parent. The parent is the source of truth.
- Children can emit events upward via explicit dispatch. They cannot write state directly.
- A child island is still a full island (WASM module with its own render/update cycle) — but its initial and updated state comes from the parent, not from the server directly.

```march
-- Parent island: owns a list of items, renders child islands into slots
mod ItemList do
  type State = {
    items : List({ id : String, label : String, selected : Bool })
  }

  type Msg = ToggleItem(String) | SelectAll | ClearAll

  fn render(state : State) : String do
    ~H"""
    <div class="item-list">
      <%= for item <- state.items do %>
        <.island name="ItemRow"
                 id={"item-row-#{item.id}"}
                 props={%{id: item.id, label: item.label, selected: item.selected}}
                 on_event="item_event" />
      <% end %>
    </div>
    """
  end

  fn update(state : State, msg : Msg) : State do
    match msg do
    | ToggleItem(id) ->
        let items = List.map(state.items, fn item ->
          if item.id == id do { item with selected = !item.selected }
          else item
          end
        )
        { state with items = items }
    | SelectAll ->
        { state with items = List.map(state.items, fn item -> { item with selected = true }) }
    | ClearAll ->
        { state with items = List.map(state.items, fn item -> { item with selected = false }) }
    end
  end
end

-- Child island: receives props from parent, emits events upward
mod ItemRow do
  type State = { id : String, label : String, selected : Bool }
  type Msg = Toggle

  fn render(state : State) : String do
    ~H"""
    <div class={"item-row #{if state.selected do "selected" else "" end}"}>
      <input type="checkbox"
             checked={state.selected}
             data-on-change="Toggle" />
      <span><%= state.label %></span>
    </div>
    """
  end

  fn update(state : State, msg : Msg) : State do
    match msg do
    | Toggle -> { state with selected = !state.selected }
    end
  end
end

impl Island(ItemRow.State) do
  fn dataflow() do Client end
  fn render(state) do ItemRow.render(state) end
  fn update(state, msg_json) do ItemRow.update(state, ItemRow.decode_msg(msg_json)) end
end
```

### How `<.island>` slots work

`<.island name=... id=... props=... on_event=...>` in a `~H` template:

1. **SSR**: The server renders the child island inline, using `props` as the initial state. The child gets a `data-march-parent` attribute pointing to the parent's island ID.
2. **Hydration order**: Parent hydrates first, resolves its state, then pushes initial props to children via `data-march-state` on the child wrapper. Lazy/OnInteraction children still receive initial props eagerly as data attributes — they just delay WASM loading.
3. **Runtime updates**: When the parent re-renders (state change), it diffs child prop changes and pushes new state to live children via the runtime's internal message bus (not `window.marchIslands.send` — this is runtime-internal only).

---

## Event Dispatch

**No global island-to-island message bus.** The `window.marchIslands.send(name, msg)` API is removed.

Event dispatch is **explicit and unidirectional** — always up the tree.

### Child-to-parent dispatch

A child island dispatches an event to its parent by emitting a named event with a payload. The runtime walks up the `data-march-parent` chain to find the handler.

```march
-- In a child island's update function, return a dispatch alongside the new state:
fn update(state : State, msg : Msg) : { state : State, dispatch : Option(Event) } do
  match msg do
  | Toggle ->
      let new_state = { state with selected = !state.selected }
      { state = new_state, dispatch = Some(Event("item_toggled", { id = state.id, selected = new_state.selected })) }
  end
end
```

The parent declares an event handler via `on_event=` in the template. The runtime calls the parent's `handle_child_event` when a dispatch arrives:

```march
impl Island(ItemList.State) do
  fn dataflow() do Client end
  fn render(state) do ItemList.render(state) end
  fn update(state, msg_json) do { state = ItemList.update(state, ItemList.decode_msg(msg_json)), dispatch = None } end
  fn handle_child_event(state : ItemList.State, event : String, payload_json : String) : ItemList.State do
    match event do
    | "item_toggled" ->
        let payload = Json.decode_payload(payload_json)
        ItemList.update(state, ItemList.ToggleItem(payload.id))
    | _ -> state
    end
  end
end
```

### Top-level island to server

Top-level islands (no parent) communicate with the server through a channel. There is no island-to-island path at the top level. Sibling islands that need to share state should both be children of a common parent, or communicate through the server.

```march
-- In a top-level Client island's update, send to server via channel:
fn update(state : State, msg : Msg) : { state : State, cmd : Option(Cmd) } do
  match msg do
  | SubmitForm(data) ->
      { state = { state with loading = true },
        cmd   = Some(Channel.push("form:submit", Json.encode(data))) }
  | ServerAck(result) ->
      { state = handle_result(state, result), cmd = None }
  end
end
```

### No synthetic event bubbling

There is no DOM-style capture/bubble phase for island events. Dispatch is explicit: a child sends to its declared parent. The runtime walks the `data-march-parent` chain linearly. If no handler is found at any ancestor, the event is dropped (not propagated to the server silently).

---

## Forms as First-Class Islands

Form islands have a built-in submit lifecycle. This is a common enough pattern to deserve a dedicated interface.

```march
mod ContactForm do
  type State = {
    name    : String,
    email   : String,
    message : String,
    errors  : Map(String, String),
    status  : Idle | Submitting | Success | Error(String)
  }

  type Msg =
    | UpdateField(String, String)
    | Submit
    | ServerResponse(Result(Ok, ValidationErrors))

  fn render(state : State) : String do
    ~H"""
    <form data-on-submit="Submit">
      <.field name="name"  value={state.name}    error={Map.get(state.errors, "name")} />
      <.field name="email" value={state.email}   error={Map.get(state.errors, "email")} />
      <.textarea name="message" value={state.message} />
      <button type="submit" disabled={state.status == Submitting}>
        <%= if state.status == Submitting do "Sending..." else "Send" end %>
      </button>
      <%= if state.status == Success do %>
        <p class="success">Message sent!</p>
      <% end %>
    </form>
    """
  end

  fn validate(state : State) : Map(String, String) do
    let errors = Map.empty()
    let errors = if String.length(state.name) == 0 do Map.put(errors, "name", "Required") else errors end
    let errors = if !String.contains(state.email, "@") do Map.put(errors, "email", "Invalid email") else errors end
    errors
  end

  fn update(state : State, msg : Msg) : { state : State, cmd : Option(Cmd) } do
    match msg do
    | UpdateField(field, value) ->
        let new_state = set_field(state, field, value)
        { state = new_state, cmd = None }
    | Submit ->
        let errors = validate(state)
        if Map.is_empty(errors) do
          { state = { state with status = Submitting, errors = Map.empty() },
            cmd   = Some(Channel.push("contact:submit", encode_form(state))) }
        else
          { state = { state with errors = errors }, cmd = None }
        end
    | ServerResponse(Ok()) ->
        { state = { state with status = Success }, cmd = None }
    | ServerResponse(Error(errs)) ->
        { state = { state with status = Idle, errors = errs }, cmd = None }
    end
  end
end
```

**Lifecycle:**
1. User fills form fields → `UpdateField` msgs update local state.
2. User submits → `validate` runs client-side. If errors, display and stop.
3. If valid → set `Submitting`, push to server channel.
4. Server responds → `ServerResponse` msg drives state to `Success` or shows server validation errors.
5. On success, optionally redirect via a `Cmd.navigate` or display inline success state.

---

## Channel Sync for Client Mode

Wiring up a channel to a `Client` island is opt-in. If no channel is wired, the island has purely local state.

```march
-- Without channel: purely local state
Islands.wrap("Counter", Islands.Eager, state_json, Counter.render(initial))

-- With channel: state syncs after each update (last-write-wins)
Islands.wrap_with_channel(
  "Counter",
  Islands.Eager,
  state_json,
  Counter.render(initial),
  channel_topic: "counter:#{user_id}"
)
```

When a channel is wired:
- After each local `update`, the runtime pushes the new state JSON to the channel topic.
- The channel can push new state down at any time (e.g., another session updated the counter).
- Last-write-wins. No merge, no CRDT. This is sufficient for the `Client` mode use cases (user preferences, UI state, simple counters).

**The dataflow mode describes ownership, not transport.** A `Client` island with a channel is still a `Client` island — it owns its state, and the channel is a sync sidecar.

---

## Hydration Order

1. The page HTML is delivered with all island wrappers in place. Children already have their initial `data-march-state` set from the server render.
2. The JS runtime scans for `data-march-island` nodes in DOM order.
3. Parents hydrate before children (DOM order guarantees this for nested islands).
4. A parent that re-renders immediately after hydration (e.g., fetching fresh data) pushes new props to already-hydrated children via the runtime's internal channel.
5. Lazy/OnInteraction children: WASM loading is deferred, but initial props in `data-march-state` are available immediately for progressive enhancement.

---

## Compiler Enforcement

- If an island declares `fn dataflow() do Server end`, the compiler emits a warning (or error with `--strict`) if its `render` function produces any `data-on-*` attributes. Server islands are display-only.
- The `<.island>` template helper is only valid inside a `~H` block inside an island's `render` function.
- `on_event=` on `<.island>` requires the parent to implement `handle_child_event`. Missing implementation is a compile-time error.

---

## What Was Removed

| Old design | Replacement |
|-----------|-------------|
| `window.marchIslands.send(name, msg)` global bus | Parent-child dispatch via `on_event=` and `handle_child_event` |
| Siblings communicate directly | Siblings share a parent island, or communicate through the server |
| Ad-hoc island-to-island messaging | Explicit dispatch, always upward |
| CRDTs in Client mode | LWW via channel. CRDTs reserved for Collaborative mode (Phase 2) |

---

## Open Questions

1. **`handle_child_event` arity**: Should it receive `(state, event_name, payload)` as shown, or a typed `ChildEvent` union that the parent pattern-matches on? Typed union is more March-idiomatic but requires more codegen.

2. **Multi-hop dispatch**: If a child's dispatch isn't handled by its immediate parent, should it propagate to the grandparent? Current design: no, it's dropped. This is intentional to keep dispatch explicit, but worth confirming.

3. **`Islands.wrap_with_channel` API**: Should this be a separate function or a keyword arg on `Islands.wrap`? Lean toward keyword arg.

4. **Hydration race**: If a parent re-renders before a child has finished WASM loading, how does the runtime buffer prop updates? Needs a queue design.

5. **Dev tools**: How does [islands-devtools.md](islands-devtools.md) show the parent-child tree and dispatch events? This is now more useful than the old flat island list.
