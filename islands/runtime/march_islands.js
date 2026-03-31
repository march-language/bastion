/**
 * march-islands.js — Client-side WASM island runtime for Bastion.
 *
 * Implements the islands data-flow architecture:
 *   - Server / Client dataflow modes (data-march-dataflow)
 *   - Parent-child island tree with prop passing and upward event dispatch
 *   - Channel sync for Client-mode islands (data-march-channel)
 *   - Form island lifecycle: validate → push → handle server response
 *   - Five hydration strategies: eager | lazy | idle | interaction | on-visible
 *
 * Embed in your page:
 *   <script type="module" src="/_march/islands/march-islands.js"
 *           data-march-base="/_march/islands"></script>
 *
 * Or via the Bastion standard library:
 *   Islands.bootstrap_script("/_march/islands")
 *
 * ── Hydration attributes ────────────────────────────────────────────────────
 *
 *   data-march-island="Name"         Island module name (matches .wasm file)
 *   data-march-hydrate="strategy"    eager | lazy | idle | interaction | on-visible
 *   data-march-state='{"k":"v"}'     JSON initial state (single-quoted attr)
 *   data-march-dataflow="client"     client (default) | server
 *   data-march-channel="topic"       Phoenix-style channel topic for state sync
 *   data-march-parent="inst-id"      parent island's instance ID (child islands)
 *   data-march-on-event="handler"    event handler name on parent (child islands)
 *   data-march-form="true"           form island — validate → channel push lifecycle
 *   data-march-island-css="..."      scoped CSS injected into <head> on hydration
 *   data-march-props='{"k":"v"}'     props pushed from parent's latest render
 *
 * ── Upward event dispatch ───────────────────────────────────────────────────
 *
 *   Add data-dispatch="parent" (or target="parent") to any interactive element
 *   inside a child island to dispatch the event to the parent island instead
 *   of the local actor. The parent's WASM handle_child_event export receives
 *   (state, child_name, event_tag, payload_json).
 *
 * ── WASM exports ───────────────────────────────────────────────────────────
 *
 *   march_island_render(state_ptr)                               → str ptr
 *   march_island_update(state_ptr, msg_ptr)                      → str ptr
 *   march_island_init()                                          → str ptr | 0
 *   march_island_handle_child_event(state, child, event, payload)→ str ptr
 *   march_island_validate(state_ptr)                             → str ptr (JSON)
 *   march_alloc_export(size: i64)                                → i32
 *   march_string_lit_export(ptr, len)                            → i32
 *   march_dealloc(ptr)                                           → void
 *   _start()                                                     → void
 *
 * ── March string layout (wasm32) ───────────────────────────────────────────
 *
 *   offset  0: rc       (i64, 8 bytes)  — reference count
 *   offset  8: tag      (i32, 4 bytes)  — type tag
 *   offset 12: pad      (i32, 4 bytes)
 *   offset 16: length   (i64, 8 bytes)  — byte length of UTF-8 data
 *   offset 24: data_ptr (i64, 8 bytes)  — pointer to UTF-8 bytes
 */

'use strict';

// ── Constants ─────────────────────────────────────────────────────────────────

const ISLAND_ATTR   = 'data-march-island';
const STATE_ATTR    = 'data-march-state';
const HYDRATE_ATTR  = 'data-march-hydrate';
const DATAFLOW_ATTR = 'data-march-dataflow';
const CHANNEL_ATTR  = 'data-march-channel';
const PARENT_ATTR   = 'data-march-parent';
const ON_EVENT_ATTR = 'data-march-on-event';
const FORM_ATTR     = 'data-march-form';
const PROPS_ATTR    = 'data-march-props';
const CSS_ATTR      = 'data-march-island-css';

// ── DevTools instrumentation ──────────────────────────────────────────────────

/** Emit a DevTools event if __MARCH_DEBUG is enabled. */
function devtoolsEmit(type, data) {
  if (!window.__MARCH_DEBUG) return;
  window.postMessage({
    source: 'march-devtools-page',
    payload: Object.assign({ type, timestamp: Date.now() }, data),
  }, '*');
}

/** Safely parse a JSON state string; return the parsed object or the raw string. */
function safeParseJson(s) {
  try { return JSON.parse(s); } catch { return s; }
}

let _devtoolsIdCounter = 0;

// ── CSS injection ─────────────────────────────────────────────────────────────

const _injectedCss = new Set();

/**
 * Inject scoped CSS from data-march-island-css into <head>, once per module.
 * The attribute value is HTML-unescaped before insertion.
 */
function injectIslandCss(name, element) {
  if (_injectedCss.has(name)) return;
  const raw = element.getAttribute(CSS_ATTR);
  if (!raw) return;
  const css = raw
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g,   '<')
    .replace(/&gt;/g,   '>')
    .replace(/&amp;/g,  '&');
  const style = document.createElement('style');
  style.setAttribute('data-march-island-css', name);
  style.textContent = css;
  document.head.appendChild(style);
  _injectedCss.add(name);
}

// ── Channel client ────────────────────────────────────────────────────────────

/**
 * ChannelClient — multiplexed WebSocket channel over a single connection.
 *
 * Protocol (JSON frames):
 *   Client → Server:
 *     { type: "join",  topic }
 *     { type: "push",  topic, event, payload }
 *   Server → Client:
 *     { type: "push",  topic, event, payload }
 */
class ChannelClient {
  #socket;
  #handlers    = new Map();  // topic → (msg) => void
  #pendingJoins = [];
  #connected   = false;

  constructor(url) {
    this.#socket = new WebSocket(url);
    this.#socket.onopen = () => {
      this.#connected = true;
      this.#pendingJoins.forEach(topic => this.#doJoin(topic));
      this.#pendingJoins = [];
    };
    this.#socket.onmessage = event => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.topic) {
          const handler = this.#handlers.get(msg.topic);
          if (handler) handler(msg);
        }
      } catch (err) {
        console.error('[march-islands] channel parse error', err);
      }
    };
    this.#socket.onerror = () => {
      console.error('[march-islands] channel socket error');
    };
    this.#socket.onclose = () => {
      this.#connected = false;
      console.warn('[march-islands] channel socket closed');
    };
  }

  /** Join a topic and register a message handler. */
  join(topic, onMessage) {
    this.#handlers.set(topic, onMessage);
    if (this.#connected) {
      this.#doJoin(topic);
    } else {
      this.#pendingJoins.push(topic);
    }
  }

  /** Push a message to a topic. */
  push(topic, event, payload) {
    this.#send({ type: 'push', topic, event, payload });
  }

  #doJoin(topic) {
    this.#send({ type: 'join', topic });
  }

  #send(msg) {
    if (this.#socket.readyState === WebSocket.OPEN) {
      this.#socket.send(JSON.stringify(msg));
    } else {
      // Buffer in pending if socket is still connecting
      console.warn('[march-islands] channel not ready, dropping', msg.type, msg.topic);
    }
  }
}

let _channelClient = null;

/** Return the shared ChannelClient for this page, creating it on first call. */
function getChannelClient() {
  if (_channelClient) return _channelClient;
  const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const url   = `${proto}//${location.host}/_march/socket`;
  _channelClient = new ChannelClient(url);
  return _channelClient;
}

// ── IslandActor ───────────────────────────────────────────────────────────────

/**
 * IslandActor owns one island's state and drives its render/update cycle.
 *
 * Messages are processed cooperatively via queueMicrotask — only one message
 * is in flight at a time, matching March's single-threaded actor semantics.
 */
class IslandActor {
  #name;
  #wasm;
  #state;
  #element;
  #baseUrl;
  #mailbox     = [];
  #ticking     = false;
  #paused      = false;
  #pausedQueue = [];

  // Dataflow
  #isServer;
  #channelTopic;
  #channel = null;  // ChannelClient, once connected

  // Parent-child tree
  #parentActor  = null;
  #childActors  = [];

  constructor(name, wasm, initialState, element, baseUrl) {
    this.#name         = name;
    this.#wasm         = wasm;
    this.#state        = initialState;
    this.#element      = element;
    this.#baseUrl      = baseUrl;
    this.#isServer     = (element.getAttribute(DATAFLOW_ATTR) ?? 'client') === 'server';
    this.#channelTopic = element.getAttribute(CHANNEL_ATTR) ?? null;
  }

  get name()        { return this.#name; }
  get instanceId()  { return this.#element._marchIslandId; }
  get isServer()    { return this.#isServer; }
  get parentActor() { return this.#parentActor; }
  get childActors() { return [...this.#childActors]; }

  /** Connect a ChannelClient for state sync. */
  connectChannel(channel) {
    if (this.#channel || this.#isServer) return;
    this.#channel = channel;
    channel.join(this.#channelTopic, msg => {
      switch (msg.event) {
        case 'state_push':
          this.send({ tag: '__channel_state__', state: msg.payload.state });
          break;
        case 'form_ok':
          this.send({ tag: '__channel_state__', state: msg.payload.state });
          break;
        case 'form_error':
          this.send({ tag: '__form_errors__', errors: msg.payload.errors ?? [] });
          break;
      }
    });
  }

  /** Wire this actor as a child of parentActor. */
  setParent(parentActor) {
    this.#parentActor = parentActor;
    parentActor.#childActors.push(this);
  }

  /** Called by child actors to dispatch an event upward to this parent. */
  handleChildEvent(childName, eventTag, payload) {
    if (!this.#wasm.handleChildEvent) {
      console.warn(`[march-islands] ${this.#name}: no march_island_handle_child_event export`);
      return;
    }
    this.send({ tag: '__child_event__', childName, eventTag, payload });
  }

  /** Called by parent to push new props down to this child. */
  onPropsUpdate(propsJson) {
    this.send({ tag: '__props__', props: propsJson });
  }

  /**
   * Validate state and push a form submission through the channel.
   * Called by the event layer when a form island intercepts submit.
   */
  async submitForm(formData) {
    // Client-side WASM validation (optional export)
    if (this.#wasm.validate) {
      let validation;
      try {
        validation = JSON.parse(this.#wasm.validate(this.#state));
      } catch {
        validation = { ok: true };
      }
      if (!validation.ok) {
        this.send({ tag: '__form_errors__', errors: validation.errors ?? [] });
        return;
      }
    }

    if (this.#channel && this.#channelTopic) {
      this.#channel.push(this.#channelTopic, 'form_submit', {
        state: this.#state,
        form:  formData,
      });
      // Response (form_ok / form_error) arrives via channel join handler → send()
    } else {
      // No channel — process locally
      this.send({ tag: 'Submit', data: formData });
    }
  }

  /**
   * Enqueue a message for processing.
   * Messages are processed in order; rendering happens after each update.
   */
  send(msg) {
    if (this.#paused) {
      this.#pausedQueue.push(msg);
      devtoolsEmit('island:message-queued', {
        id:        this.#element._marchIslandId,
        name:      this.#name,
        msg,
        queueSize: this.#pausedQueue.length,
      });
      return;
    }
    this.#mailbox.push(msg);
    if (!this.#ticking) {
      this.#ticking = true;
      queueMicrotask(() => this.#drain());
    }
  }

  /** Pause the actor — messages queue but don't process. DevTools time-travel. */
  pause() { this.#paused = true; }

  /** Resume the actor — drain any queued messages. */
  resume() {
    this.#paused = false;
    if (this.#pausedQueue.length > 0) {
      this.#mailbox.push(...this.#pausedQueue);
      this.#pausedQueue = [];
      if (!this.#ticking) {
        this.#ticking = true;
        queueMicrotask(() => this.#drain());
      }
    }
  }

  /** Render at a specific state without mutating live state. DevTools time-travel. */
  renderAt(stateJson) {
    try {
      this.#element.innerHTML = this.#wasm.render(stateJson);
    } catch (err) {
      console.error(`[march-islands] ${this.#name}: renderAt error`, err);
    }
  }

  /** Re-render at current live state and rebind handlers. */
  renderLive() { this.#render(); }

  #drain() {
    while (this.#mailbox.length > 0) {
      const msg = this.#mailbox.shift();
      try {
        // DevTools state restore — bypass update, set state directly
        if (msg.tag === '__restore__' && msg.state !== undefined) {
          this.#state = typeof msg.state === 'string'
            ? msg.state
            : JSON.stringify(msg.state);
          this.#render();
          devtoolsEmit('island:state-change', {
            id:    this.#element._marchIslandId,
            name:  this.#name,
            state: safeParseJson(this.#state),
            msg:   { tag: '__restore__' },
          });
          continue;
        }

        // Incoming channel state (LWW) — replace state directly
        if (msg.tag === '__channel_state__') {
          this.#state = typeof msg.state === 'string'
            ? msg.state
            : JSON.stringify(msg.state);
          this.#render();
          continue;
        }

        // Props update from parent
        if (msg.tag === '__props__') {
          const prevState = this.#state;
          this.#state = this.#wasm.update(
            this.#state,
            JSON.stringify({ tag: '__props__', props: msg.props }),
          );
          devtoolsEmit('island:state-change', {
            id:        this.#element._marchIslandId,
            name:      this.#name,
            state:     safeParseJson(this.#state),
            prevState: safeParseJson(prevState),
            msg,
          });
          this.#render();
          continue;
        }

        // Child event dispatched upward — call WASM handle_child_event
        if (msg.tag === '__child_event__') {
          const prevState = this.#state;
          const payload = typeof msg.payload === 'string'
            ? msg.payload
            : JSON.stringify(msg.payload ?? {});
          this.#state = this.#wasm.handleChildEvent(
            this.#state,
            msg.childName,
            msg.eventTag,
            payload,
          );
          devtoolsEmit('island:state-change', {
            id:        this.#element._marchIslandId,
            name:      this.#name,
            state:     safeParseJson(this.#state),
            prevState: safeParseJson(prevState),
            msg,
          });
          this.#render();
          // Push updated state to channel (parent may be synced)
          this.#pushChannel();
          continue;
        }

        // Regular update
        const prevState = this.#state;
        this.#state = this.#wasm.update(this.#state, JSON.stringify(msg));
        devtoolsEmit('island:state-change', {
          id:        this.#element._marchIslandId,
          name:      this.#name,
          state:     safeParseJson(this.#state),
          prevState: safeParseJson(prevState),
          msg,
        });
        this.#render();
        this.#pushChannel();

      } catch (err) {
        console.error(`[march-islands] ${this.#name}: update error`, err);
        devtoolsEmit('island:error', {
          id:    this.#element._marchIslandId,
          name:  this.#name,
          error: String(err),
        });
      }
    }
    this.#ticking = false;
  }

  /** Push current state to the wired channel (LWW sync). */
  #pushChannel() {
    if (this.#channel && this.#channelTopic) {
      this.#channel.push(this.#channelTopic, 'state_update', { state: this.#state });
    }
  }

  #render() {
    try {
      const html = this.#wasm.render(this.#state);
      this.#element.innerHTML = html;

      // Inject scoped CSS into <head> (once per module name)
      injectIslandCss(this.#name, this.#element);

      if (this.#isServer) {
        warnServerEventHandlers(this.#element, this.#name);
        return;
      }

      attachEventHandlers(this.#element, this);

      // Push props to already-hydrated children and hydrate new ones
      hydrateChildIslands(this.#element, this.#baseUrl, this);

    } catch (err) {
      console.error(`[march-islands] ${this.#name}: render error`, err);
      devtoolsEmit('island:error', {
        id:    this.#element._marchIslandId,
        name:  this.#name,
        error: `render: ${err}`,
      });
    }
  }
}

// ── Event binding ─────────────────────────────────────────────────────────────

/**
 * Determine if an element wants to dispatch an event to its parent island.
 * Recognised signals: data-dispatch="parent" or target="parent".
 */
function targetsParent(el) {
  return el.getAttribute('data-dispatch') === 'parent' ||
         el.getAttribute('target')        === 'parent';
}

/**
 * Resolve the dispatch target for an event: the actor itself or its parent.
 * Returns null if no parent is available when a parent dispatch is requested.
 */
function resolveDispatchTarget(el, actor) {
  if (targetsParent(el)) {
    if (!actor.parentActor) {
      console.warn(`[march-islands] ${actor.name}: data-dispatch="parent" but no parent island`);
      return null;
    }
    return { actor: actor.parentActor, isParent: true };
  }
  return { actor, isParent: false };
}

/**
 * Bind data-on-* event handlers within an island's root element.
 * Supports upward dispatch (data-dispatch="parent") and form island lifecycle.
 * Each re-render replaces innerHTML, so handlers are re-bound after every update.
 */
function attachEventHandlers(root, actor) {
  const isFormIsland = root.getAttribute(FORM_ATTR) === 'true';

  // data-on-click
  root.querySelectorAll('[data-on-click]').forEach(el => {
    const tag    = el.getAttribute('data-on-click');
    const target = resolveDispatchTarget(el, actor);
    if (!target) return;
    el.addEventListener('click', e => {
      e.preventDefault();
      if (target.isParent) {
        target.actor.handleChildEvent(actor.name, tag, {});
      } else {
        target.actor.send({ tag });
      }
    });
  });

  // data-on-input
  root.querySelectorAll('[data-on-input]').forEach(el => {
    const tag    = el.getAttribute('data-on-input');
    const target = resolveDispatchTarget(el, actor);
    if (!target) return;
    el.addEventListener('input', e => {
      const payload = { value: e.target.value };
      if (target.isParent) {
        target.actor.handleChildEvent(actor.name, tag, payload);
      } else {
        target.actor.send({ tag, ...payload });
      }
    });
  });

  // data-on-change
  root.querySelectorAll('[data-on-change]').forEach(el => {
    const tag    = el.getAttribute('data-on-change');
    const target = resolveDispatchTarget(el, actor);
    if (!target) return;
    el.addEventListener('change', e => {
      const payload = { value: e.target.value, checked: e.target.checked };
      if (target.isParent) {
        target.actor.handleChildEvent(actor.name, tag, payload);
      } else {
        target.actor.send({ tag, ...payload });
      }
    });
  });

  // data-on-submit (form)
  root.querySelectorAll('[data-on-submit]').forEach(el => {
    const tag    = el.getAttribute('data-on-submit');
    const target = resolveDispatchTarget(el, actor);
    if (!target) return;
    el.addEventListener('submit', async e => {
      e.preventDefault();
      const formData = el.tagName === 'FORM'
        ? Object.fromEntries(new FormData(el))
        : {};
      if (target.isParent) {
        target.actor.handleChildEvent(actor.name, tag, formData);
      } else if (isFormIsland) {
        await actor.submitForm(formData);
      } else {
        target.actor.send({ tag, data: formData });
      }
    });
  });
}

/**
 * Warn if a Server-mode island's rendered HTML contains data-on-* attributes.
 * The JS runtime does NOT attach event listeners to Server-mode islands.
 */
function warnServerEventHandlers(root, name) {
  const found = root.querySelector(
    '[data-on-click],[data-on-input],[data-on-change],[data-on-submit]',
  );
  if (found) {
    console.warn(
      `[march-islands] ${name}: Server-mode island rendered data-on-* attributes ` +
      `but no event handlers will be attached. ` +
      `Use Client mode or remove the event attributes.`,
    );
  }
}

// ── WASM string bridge ────────────────────────────────────────────────────────

const _decoder = new TextDecoder();
const _encoder = new TextEncoder();

let _wasmStringHelpers = null;

/**
 * Read a March string from WASM linear memory.
 *
 * Uses exported march_island_string_length / march_island_string_data helpers
 * when available. Falls back to reading the struct layout directly (wasm32).
 */
function readMarchString(memory, ptr) {
  if (_wasmStringHelpers) {
    const len     = _wasmStringHelpers.length(ptr);
    const dataPtr = _wasmStringHelpers.data(ptr);
    return _decoder.decode(new Uint8Array(memory.buffer, dataPtr, len));
  }
  // Fallback: wasm32 layout (see header)
  const view    = new DataView(memory.buffer);
  const len     = Number(view.getBigInt64(ptr + 16, true));
  const dataPtr = view.getInt32(ptr + 24, true);
  return _decoder.decode(new Uint8Array(memory.buffer, dataPtr, len));
}

/**
 * Write a JS string into WASM linear memory as a March string struct.
 */
function writeMarchString(exports, str) {
  const { memory, march_alloc_export, march_string_lit_export } = exports;
  const encoded = _encoder.encode(str);
  const dataPtr = march_alloc_export(BigInt(encoded.length + 1));
  const mem = new Uint8Array(memory.buffer);
  mem.set(encoded, dataPtr);
  mem[dataPtr + encoded.length] = 0;
  return march_string_lit_export(dataPtr, BigInt(encoded.length));
}

// ── WASM module wrapper ───────────────────────────────────────────────────────

/**
 * Wrap raw WASM exports into the {init, render, update, handleChildEvent, validate}
 * interface expected by IslandActor. Bridges JS strings ↔ March WASM strings.
 */
function wrapWasmExports(exports, name) {
  const {
    memory,
    march_island_render,
    march_island_update,
    march_island_init,
    march_island_handle_child_event,
    march_island_validate,
    march_island_string_length,
    march_island_string_data,
  } = exports;

  if (march_island_string_length && march_island_string_data) {
    _wasmStringHelpers = {
      length: march_island_string_length,
      data:   march_island_string_data,
    };
  }

  const wrapped = {
    /** Call march_island_init; return JSON string or '{}'. */
    init() {
      const ptr = march_island_init();
      if (ptr === 0) return '{}';
      return readMarchString(memory, ptr);
    },

    /** Write stateJson into WASM, call render, read HTML string back. */
    render(stateJson) {
      const sp = writeMarchString(exports, stateJson);
      const rp = march_island_render(sp);
      return readMarchString(memory, rp);
    },

    /** Write stateJson + msgJson into WASM, call update, read new state back. */
    update(stateJson, msgJson) {
      const sp = writeMarchString(exports, stateJson);
      const mp = writeMarchString(exports, msgJson);
      const np = march_island_update(sp, mp);
      return readMarchString(memory, np);
    },

    /**
     * Call march_island_handle_child_event.
     * Returns new state JSON, or null if the export is absent.
     */
    handleChildEvent: march_island_handle_child_event
      ? (stateJson, childName, eventTag, payloadJson) => {
          const sp = writeMarchString(exports, stateJson);
          const cp = writeMarchString(exports, childName);
          const ep = writeMarchString(exports, eventTag);
          const pp = writeMarchString(exports, payloadJson);
          const np = march_island_handle_child_event(sp, cp, ep, pp);
          return readMarchString(memory, np);
        }
      : null,

    /**
     * Call march_island_validate.
     * Returns validation JSON string (e.g. '{"ok":true}'), or null if absent.
     */
    validate: march_island_validate
      ? stateJson => {
          const sp = writeMarchString(exports, stateJson);
          const rp = march_island_validate(sp);
          return readMarchString(memory, rp);
        }
      : null,
  };

  return wrapped;
}

// ── WASM loading ──────────────────────────────────────────────────────────────

/**
 * Load and instantiate a WASM island module.
 *
 * @param {string} baseUrl  URL prefix, e.g. "/_march/islands"
 * @param {string} name     Island name, e.g. "Counter"
 * @returns {Promise<object|null>}  wrapped WASM or null
 */
async function loadWasmModule(baseUrl, name) {
  // Allow test harnesses to inject mock WASM modules.
  if (window.__marchTestLoader) {
    return window.__marchTestLoader(baseUrl, name);
  }

  const wasmUrl = `${baseUrl}/${name}.wasm`;
  try {
    const resp = await fetch(wasmUrl);
    if (!resp.ok) {
      console.info(
        `[march-islands] ${name}: WASM not found at ${wasmUrl} (${resp.status}).` +
        ` Island will remain static (SSR content preserved).`,
      );
      return null;
    }

    const { instance } = await WebAssembly.instantiate(await resp.arrayBuffer());

    if (instance.exports._start) {
      instance.exports._start();
    }

    return wrapWasmExports(instance.exports, name);
  } catch (err) {
    console.error(`[march-islands] ${name}: failed to load WASM`, err);
    return null;
  }
}

// ── State parsing ─────────────────────────────────────────────────────────────

/** Parse the island's initial state from its data-march-state attribute. */
function parseState(element) {
  const raw = element.getAttribute(STATE_ATTR);
  if (!raw) return '{}';
  // Unescape &#39; → ' (single-quoted attribute escaping)
  const unescaped = raw.replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  try {
    JSON.parse(unescaped); // validate
    return unescaped;
  } catch (e) {
    console.error('[march-islands] Invalid island state JSON:', raw, e);
    return '{}';
  }
}

// ── Hydration ─────────────────────────────────────────────────────────────────

/**
 * Hydrate one island element: load WASM, parse state, spawn actor.
 * If WASM is unavailable, the SSR content is left in place unchanged.
 *
 * @param {Element}      element      — the data-march-island root div
 * @param {string}       baseUrl      — asset base URL
 * @param {IslandActor|null} parentActor — parent actor to wire, if known
 */
async function hydrateIsland(element, baseUrl, parentActor = null) {
  const name = element.getAttribute(ISLAND_ATTR);
  if (!name || element._marchActor) return;

  const hydration  = element.getAttribute(HYDRATE_ATTR) ?? 'eager';
  const dataflow   = element.getAttribute(DATAFLOW_ATTR) ?? 'client';
  const id         = 'island-' + (++_devtoolsIdCounter);
  element._marchIslandId = id;

  const initialStateJson = parseState(element);

  devtoolsEmit('island:mount', {
    id,
    name,
    hydration,
    dataflow,
    state:      safeParseJson(initialStateJson),
    wasmModule: `${name}.wasm`,
  });

  const t0   = performance.now();
  const wasm = await loadWasmModule(baseUrl, name);
  if (!wasm) return; // WASM not available; preserve SSR content

  const actor = new IslandActor(name, wasm, initialStateJson, element, baseUrl);
  element._marchActor = actor;

  // Wire parent-child relationship
  if (parentActor) {
    actor.setParent(parentActor);
  }

  // Connect channel if topic is declared (Client mode only)
  const channelTopic = element.getAttribute(CHANNEL_ATTR);
  if (channelTopic && dataflow !== 'server') {
    actor.connectChannel(getChannelClient());
  }

  const duration = Math.round(performance.now() - t0);
  devtoolsEmit('island:hydrate', { id, name, duration });

  // Initial render kick-off
  actor.send({ tag: '__init__' });

  console.debug(`[march-islands] ${name} hydrated (${dataflow}, ${hydration})`);
}

/**
 * After a parent renders, scan its new DOM for child island elements.
 * - Already-hydrated children receive prop updates via onPropsUpdate.
 * - Un-hydrated children are hydrated with the parent actor wired in.
 */
async function hydrateChildIslands(root, baseUrl, parentActor) {
  const children = root.querySelectorAll(`[${ISLAND_ATTR}]`);
  for (const el of children) {
    if (el._marchActor) {
      // Already hydrated — push new props if present in the re-rendered HTML
      const propsJson = el.getAttribute(PROPS_ATTR);
      if (propsJson) {
        el._marchActor.onPropsUpdate(propsJson);
      }
    } else {
      await hydrateIsland(el, baseUrl, parentActor);
    }
  }
}

// ── Hydration strategies ──────────────────────────────────────────────────────

/**
 * Apply the hydration strategy declared on an island element.
 *
 * Strategies:
 *   eager        — hydrate immediately
 *   lazy         — hydrate after DOMContentLoaded
 *   idle         — hydrate during requestIdleCallback (or setTimeout fallback)
 *   interaction  — hydrate on first user interaction (click, focus, pointer)
 *   on-visible   — hydrate when scrolled into view (IntersectionObserver)
 */
function applyStrategy(element, baseUrl) {
  const strategy = element.getAttribute(HYDRATE_ATTR) ?? 'eager';

  switch (strategy) {
    case 'eager':
      hydrateIsland(element, baseUrl);
      break;

    case 'lazy': {
      // Defer until DOMContentLoaded (already fired → hydrate immediately)
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () =>
          hydrateIsland(element, baseUrl), { once: true });
      } else {
        hydrateIsland(element, baseUrl);
      }
      break;
    }

    case 'idle':
      if ('requestIdleCallback' in window) {
        requestIdleCallback(() => hydrateIsland(element, baseUrl));
      } else {
        setTimeout(() => hydrateIsland(element, baseUrl), 200);
      }
      break;

    case 'interaction': {
      const triggers = ['click', 'focusin', 'touchstart', 'pointerdown'];
      function onFirstInteraction() {
        triggers.forEach(ev => element.removeEventListener(ev, onFirstInteraction));
        hydrateIsland(element, baseUrl);
      }
      triggers.forEach(ev => element.addEventListener(ev, onFirstInteraction));
      break;
    }

    case 'on-visible': {
      const obs = new IntersectionObserver(entries => {
        if (entries.some(e => e.isIntersecting)) {
          obs.unobserve(element);
          hydrateIsland(element, baseUrl);
        }
      });
      obs.observe(element);
      break;
    }

    default:
      console.warn(`[march-islands] Unknown hydration strategy "${strategy}"; using eager`);
      hydrateIsland(element, baseUrl);
  }
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

/**
 * Resolve the base URL for WASM files from the script element's
 * data-march-base attribute, falling back to /_march/islands.
 */
function resolveBaseUrl() {
  const script = document.currentScript
    ?? document.querySelector('script[data-march-base]');
  return script?.getAttribute('data-march-base') ?? '/_march/islands';
}

/**
 * Bootstrap: discover and hydrate all islands on the page.
 *
 * Hydration order:
 *   1. Parent islands (no data-march-parent) — apply their declared strategy.
 *   2. Orphan child islands declared directly in the static HTML (uncommon).
 *      These are hydrated eagerly so parents can wire them after load.
 *
 * Child islands created by parent renders are handled inside IslandActor#render
 * via hydrateChildIslands, which runs after every parent render.
 */
function bootstrap() {
  const baseUrl = resolveBaseUrl();
  const all     = document.querySelectorAll(`[${ISLAND_ATTR}]`);

  if (all.length === 0) return;
  console.debug(`[march-islands] Bootstrapping ${all.length} island(s) (base: ${baseUrl})`);

  // Separate root islands from pre-declared child islands
  const roots    = [];
  const children = [];

  all.forEach(el => {
    if (el.getAttribute(PARENT_ATTR)) {
      children.push(el);
    } else {
      roots.push(el);
    }
  });

  // Hydrate root islands first (respects declared strategy)
  roots.forEach(el => applyStrategy(el, baseUrl));

  // Hydrate statically-declared child islands eagerly (parents expected to
  // be in the same page; parent actor wiring happens via setParent inside
  // hydrateIsland when the parent element is already hydrated)
  children.forEach(el => hydrateIsland(el, baseUrl));
}

// ── DevTools scan ─────────────────────────────────────────────────────────────

function devtoolsScan() {
  const elements = document.querySelectorAll(`[${ISLAND_ATTR}]`);
  const islands  = [];
  elements.forEach(el => {
    const name = el.getAttribute(ISLAND_ATTR);
    const id   = el._marchIslandId ?? ('island-' + (++_devtoolsIdCounter));
    el._marchIslandId = id;
    const actor = el._marchActor;
    islands.push({
      id,
      name,
      hydration:  el.getAttribute(HYDRATE_ATTR) ?? 'eager',
      dataflow:   el.getAttribute(DATAFLOW_ATTR) ?? 'client',
      status:     actor ? 'hydrated' : 'pending',
      state:      safeParseJson(parseState(el)),
      parentId:   el.getAttribute(PARENT_ATTR) ?? null,
      children:   actor ? actor.childActors.map(c => c.instanceId) : [],
      wasmModule: `${name}.wasm`,
      mountedAt:  Date.now(),
    });
  });
  window.postMessage({
    source:  'march-devtools-page',
    payload: { type: 'scan-result', islands, timestamp: Date.now() },
  }, '*');
}

// Listen for scan requests from the DevTools extension
window.addEventListener('message', event => {
  if (event.source !== window) return;
  if (event.data?.source === 'march-devtools-extension' && event.data.type === 'scan') {
    devtoolsScan();
  }
});

if (window.__MARCH_DEBUG) {
  window.__marchDevtools = window.__marchDevtools ?? {};
  window.__marchDevtools.scan = devtoolsScan;
}

// ── Debug-only reference (no public send API) ─────────────────────────────────

// Expose manager reference for debugging only.
// The global window.marchIslands.send bus has been removed.
// Inter-island communication is exclusively via parent-child tree traversal.
if (window.__MARCH_DEBUG) {
  window.__bastionIslands = {
    actors: () => Array.from(document.querySelectorAll(`[${ISLAND_ATTR}]`))
      .filter(el => el._marchActor)
      .map(el => el._marchActor),
  };
}

// ── Entry point ───────────────────────────────────────────────────────────────

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootstrap);
} else {
  bootstrap();
}
