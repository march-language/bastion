/**
 * Bastion Islands Client Runtime
 *
 * Discovers <div data-march-island="ModuleName"> elements in the DOM,
 * opens a single multiplexed WebSocket to the server, and manages
 * island lifecycle (state sync, event dispatch, DOM morphing).
 *
 * Dataflow modes (data-march-dataflow attribute):
 *   "server" — server owns state, no event listeners attached.
 *              State arrives via WebSocket only.
 *   "client" — island owns state, handles events locally.
 *              Optional: wire up data-march-channel for last-write-wins sync.
 *
 * Parent-child binding (data-march-parent / data-march-on-event):
 *   Children dispatch events upward via dispatchToParent().
 *   The runtime walks the data-march-parent chain to find the handler.
 *   There is no global island-to-island message bus.
 *
 * Event attributes (new style, preferred):
 *   data-on-click="MsgName"        → dispatches {tag:"MsgName"} on click
 *   data-on-change="MsgName"       → dispatches {tag:"MsgName",value:...} on change
 *   data-on-input="MsgName"        → dispatches {tag:"MsgName",value:...} on input
 *   data-on-submit="MsgName"       → dispatches {tag:"MsgName",data:{...}} on form submit
 *   data-on-keydown="MsgName"      → dispatches {tag:"MsgName",key:...,value:...} on keydown
 *   data-on-keydown-key="Enter"    → optional key filter for data-on-keydown
 *
 * Legacy event attributes (still supported for backward compatibility):
 *   data-msg="MsgName"
 *   data-msg-input="MsgName"
 *   data-msg-change="MsgName"
 *   data-msg-submit="MsgName"
 *   data-msg-keydown="MsgName"
 */

(() => {
  'use strict';

  // ── Constants ─────────────────────────────────────────────────

  const WS_PATH = '/_bastion/ws';
  const RECONNECT_BASE_MS = 500;
  const RECONNECT_MAX_MS = 30000;
  const RECONNECT_JITTER = 0.3;

  // ── Island Instance ─────────────────────────────────────────────

  class IslandInstance {
    /**
     * @param {HTMLElement} el - The DOM element with data-march-island
     * @param {IslandManager} manager - The owning manager
     */
    constructor(el, manager) {
      this.el = el;
      this.manager = manager;
      this.moduleName = el.dataset.marchIsland;
      this.instanceId = `${this.moduleName}-${manager.nextId()}`;
      this.state = this._parseInitialState(el);
      this.wasmModule = null;

      // "server" | "client" — default to "client" for backward compat
      this.dataflow = (el.dataset.marchDataflow || 'client').toLowerCase();

      // Optional channel topic for Client-mode sync (last-write-wins)
      this.channelTopic = el.dataset.marchChannel || null;

      // Parent-child relationship
      this.parentId = el.dataset.marchParent || null;
      this.onEvent  = el.dataset.marchOnEvent || null;

      el.dataset.marchInstanceId = this.instanceId;
    }

    /**
     * Safely parse initial state from the element's data attribute.
     * Falls back to empty object on parse failure.
     */
    _parseInitialState(el) {
      const raw = el.dataset.marchState;
      if (!raw) return {};
      try {
        return JSON.parse(raw);
      } catch (e) {
        console.warn(`[bastion] Failed to parse initial state for ${this.moduleName}:`, e);
        return {};
      }
    }

    /**
     * True if this is a Server-mode island (server owns state; no local
     * WASM module is loaded). Server-owned islands can still dispatch
     * DOM events — see dispatch() — the events are sent to the server
     * for authoritative update+render instead of being applied locally.
     */
    isServer() {
      return this.dataflow === 'server';
    }

    /**
     * Called when the server pushes a full state replacement.
     * Server-mode: always apply. Client-mode: apply and re-render.
     * @param {Object} newState
     */
    onStateUpdate(newState) {
      this.state = newState;
      if (this.wasmModule) {
        this.rerender();
      }
    }

    /**
     * Called when the server sends a "props" update (parent pushed new props).
     * Equivalent to a state update from the parent's perspective.
     * @param {Object} newProps
     */
    onPropsUpdate(newProps) {
      this.state = newProps;
      if (this.wasmModule) {
        this.rerender();
      }
    }

    /**
     * Called when server sends a merge response (CRDT reconciliation).
     * @param {Object} remoteState
     */
    onMerge(remoteState) {
      this.state = remoteState;
      if (this.wasmModule) {
        this.wasmModule.merge && this.wasmModule.merge(remoteState);
        this.rerender();
      }
    }

    /**
     * Dispatch a user-initiated message from a DOM event.
     *
     * For Client-mode islands:
     *   1. If WASM is loaded, apply update optimistically and re-render.
     *   2. Check if update returned a dispatch tuple {state, dispatch}.
     *      If so, walk up the parent chain and call handle_child_event.
     *   3. If a channel is wired, push state to the channel topic.
     *   4. Also send to the WebSocket server for persistence.
     *
     * For Server-mode islands: there is no local wasmModule, so step 1-3
     * above are skipped naturally (the `if (this.wasmModule)` guard below
     * is false). Only step 4 runs: the message is sent to the server, which
     * runs the authoritative update+render and pushes a "render" message
     * back — handled by _handleMessage's morph() call, independent of
     * wasmModule. This is the "Server-authoritative" pattern from
     * specs/islands.md: update only runs server-side, but the client still
     * originates the event.
     *
     * @param {string|Object} msgPayload
     */
    dispatch(msgPayload) {
      if (this.wasmModule) {
        // Use updateWithCmd if available (islands that return (State, Cmd) tuples).
        // Falls back to plain update() for islands that just return State.
        const { updated, cmd } = this.wasmModule.updateWithCmd
          ? this.wasmModule.updateWithCmd(msgPayload)
          : { updated: this.wasmModule.update(msgPayload), cmd: null };

        if (updated) {
          const html = this.wasmModule.render();
          if (html !== null) this.morph(html);

          // Channel sync (last-write-wins, no CRDT)
          if (this.channelTopic) {
            this.manager.channelPush(this.channelTopic, this.state);
          }
        }

        // Execute any Cmd produced by the island's update function
        if (cmd) {
          executeCmd(this, cmd);
        }
      }

      // Send to server (persistence, auth, side-effects)
      this.manager.send({
        island: this.instanceId,
        type: 'msg',
        payload: msgPayload
      });

      // Notify any Bastion.onDispatch() listeners registered for this island type
      const listeners = this.manager._dispatchListeners &&
        this.manager._dispatchListeners.get(this.moduleName);
      if (listeners && listeners.length > 0) {
        const snapshot = this.state;
        listeners.forEach(cb => {
          try { cb(this.instanceId, msgPayload, snapshot); } catch (e) {
            console.warn('[bastion] onDispatch listener threw:', e);
          }
        });
      }
    }

    /**
     * Re-render using the WASM module if available.
     */
    rerender() {
      if (this.wasmModule && typeof this.wasmModule.render === 'function') {
        try {
          const html = this.wasmModule.render(this.state);
          this.morph(html);
        } catch (e) {
          console.warn(`[bastion] WASM render failed for ${this.moduleName}:`, e);
        }
      }
    }

    /**
     * Morph the island element's inner DOM to match newHTML.
     * Uses Idiomorph when available, falls back to innerHTML.
     * @param {string} newHTML
     */
    morph(newHTML) {
      if (typeof Idiomorph !== 'undefined' && Idiomorph.morph) {
        Idiomorph.morph(this.el, newHTML, {
          morphStyle: 'innerHTML',
          ignoreActiveValue: true,
          callbacks: {
            // A user-toggled <details> keeps its open state across server pushes.
            // The server may still *add* open; only removals are ignored.
            beforeAttributeUpdated: (attr, node, mutationType) =>
              !(attr === 'open' && mutationType === 'remove' && node.tagName === 'DETAILS')
          }
        });
      } else {
        this.el.innerHTML = newHTML;
      }
    }

    /**
     * Clean up this island instance.
     */
    destroy() {
      this.manager.send({
        island: this.instanceId,
        type: 'destroy'
      });
      delete this.el.dataset.marchInstanceId;
    }
  }

  // ── Island Manager ──────────────────────────────────────────────

  class IslandManager {
    constructor() {
      /** @type {Map<string, IslandInstance>} */
      this.instances = new Map();
      this._idCounter = 0;
      /** @type {WebSocket|null} */
      this.ws = null;
      this.wsReady = false;
      /** @type {Array<Object>} */
      this.pendingMessages = [];
      this._reconnectAttempts = 0;
      this._reconnectTimer = null;
      this._observer = null;
      /** @type {IntersectionObserver|null} - watches data-march-hydrate="on-visible" islands */
      this._visibilityObserver = null;
    }

    nextId() {
      return ++this._idCounter;
    }

    // ── Initialization ──────────────────────────────────────────

    init() {
      this.connectWebSocket();
      this._startVisibilityObserver();
      this.discoverIslands();
      this.bindGlobalEvents();
      this._startObserver();
    }

    /**
     * Scan the DOM for uninitialized island elements and schedule hydration
     * according to the element's data-march-hydrate attribute.
     *
     * Hydration strategies (data-march-hydrate):
     *   (absent)        — hydrate immediately (eager, default)
     *   "lazy"          — hydrate after the page load event (or immediately
     *                     if page is already loaded)
     *   "idle"          — hydrate during the browser's idle period via
     *                     requestIdleCallback (falls back to setTimeout)
     *   "interaction"   — hydrate on first click, focus, or keypress on the
     *                     element or its descendants
     *   "on-visible"    — hydrate when the element scrolls into the viewport
     *                     (IntersectionObserver with 10% threshold)
     *
     * Hydration order: parents before children. DOM order naturally guarantees
     * this for nested islands — querySelectorAll returns nodes in document order,
     * so a parent <div> always appears before its nested children.
     */
    discoverIslands() {
      const elements = document.querySelectorAll('[data-march-island]');
      elements.forEach(el => {
        if (el.dataset.marchInstanceId) return;  // already initialized
        if (el.dataset.marchHydratePending) return;  // already scheduled

        const strategy = (el.dataset.marchHydrate || '').toLowerCase();

        if (!strategy || strategy === 'eager') {
          this._hydrateOne(el);
        } else {
          this._scheduleHydration(el, strategy);
        }
      });
    }

    /**
     * Perform the actual hydration of a single island element.
     * Registers the instance, injects CSS, loads WASM, and notifies the server.
     * @param {HTMLElement} el
     */
    _hydrateOne(el) {
      // Guard: may have been hydrated by a parallel deferred trigger
      if (el.dataset.marchInstanceId) return;

      // Clear the pending marker set by _scheduleHydration
      delete el.dataset.marchHydratePending;

      const instance = new IslandInstance(el, this);
      this.instances.set(instance.instanceId, instance);

      // Inject scoped CSS on first hydration
      this._injectScopedCss(instance);

      // Load WASM module synchronously from registry if already available
      if (window.__bastionWasm) {
        const mod = window.__bastionWasm.getModule(instance.moduleName);
        if (mod) {
          instance.wasmModule = mod;
        }
      }

      // Tell server about this island (Server mode and Client-with-channel).
      // Include the channel topic when present so IslandSocket can subscribe
      // this instance to PubSub and deliver server-push state updates.
      const initMsg = {
        island: instance.instanceId,
        type: 'init',
        module: instance.moduleName,
        payload: instance.state
      };
      if (instance.channelTopic) {
        initMsg.channel = instance.channelTopic;
      }
      this.send(initMsg);

      // Async WASM loading
      if (window.__bastionWasm) {
        window.__bastionWasm.loadModule(instance.moduleName).then(wasmMod => {
          if (wasmMod) {
            instance.wasmModule = wasmMod;
            if (instance.state && Object.keys(instance.state).length > 0) {
              const html = wasmMod.render(instance.state);
              if (html !== null) instance.morph(html);
            }
          }
        });
      }
    }

    /**
     * Schedule hydration of an element using the specified strategy.
     * Marks the element as pending so discoverIslands doesn't re-schedule it.
     * @param {HTMLElement} el
     * @param {string} strategy - "lazy" | "idle" | "interaction" | "on-visible"
     */
    _scheduleHydration(el, strategy) {
      el.dataset.marchHydratePending = '1';

      switch (strategy) {
        case 'lazy': {
          // After the page load event (or immediately if already loaded)
          if (document.readyState === 'complete') {
            // Already past load — hydrate on next tick to avoid blocking paint
            setTimeout(() => this._hydrateOne(el), 0);
          } else {
            const onLoad = () => {
              window.removeEventListener('load', onLoad);
              this._hydrateOne(el);
            };
            window.addEventListener('load', onLoad);
          }
          break;
        }

        case 'idle': {
          // Hydrate during the browser's next idle period
          if (typeof requestIdleCallback === 'function') {
            requestIdleCallback(() => this._hydrateOne(el), { timeout: 2000 });
          } else {
            // Safari fallback
            setTimeout(() => this._hydrateOne(el), 200);
          }
          break;
        }

        case 'interaction': {
          // Hydrate on the first user interaction with the element or its children
          const events = ['click', 'focus', 'keypress', 'touchstart', 'pointerdown'];
          const handler = () => {
            events.forEach(evt => el.removeEventListener(evt, handler, true));
            this._hydrateOne(el);
          };
          events.forEach(evt => el.addEventListener(evt, handler, { once: true, capture: true, passive: true }));
          break;
        }

        case 'on-visible': {
          // Hydrate when the element enters the viewport (10% visible threshold)
          if (this._visibilityObserver) {
            this._visibilityObserver.observe(el);
          } else {
            // IntersectionObserver not available — hydrate immediately
            this._hydrateOne(el);
          }
          break;
        }

        default: {
          // Unknown strategy — fall back to eager
          console.warn(`[bastion] Unknown hydration strategy "${strategy}", falling back to eager`);
          this._hydrateOne(el);
        }
      }
    }

    /**
     * Create a shared IntersectionObserver for on-visible island hydration.
     * Hydrates when at least 10% of the island element is visible.
     */
    _startVisibilityObserver() {
      if (this._visibilityObserver) return;
      if (typeof IntersectionObserver === 'undefined') return;

      this._visibilityObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this._visibilityObserver.unobserve(entry.target);
            this._hydrateOne(entry.target);
          }
        });
      }, { threshold: 0.1 });
    }

    /**
     * Inject an island's scoped CSS into the document <head> on first hydration.
     * Creates a single <style> tag per island module (deduped by id).
     * @param {IslandInstance} instance
     */
    _injectScopedCss(instance) {
      const css = instance.el.dataset.marchIslandCss;
      if (!css) return;

      const styleId = `bastion-css-${instance.moduleName}`;
      if (document.getElementById(styleId)) return;

      const style = document.createElement('style');
      style.id = styleId;
      style.setAttribute('data-bastion-island', instance.moduleName);
      style.textContent = css;
      document.head.appendChild(style);
    }

    /**
     * Clean up islands whose elements have been removed from the DOM.
     */
    pruneIslands() {
      for (const [id, instance] of this.instances) {
        if (!document.body.contains(instance.el)) {
          instance.destroy();
          this.instances.delete(id);
        }
      }
    }

    // ── WebSocket ───────────────────────────────────────────────

    connectWebSocket() {
      if (this._reconnectTimer) {
        clearTimeout(this._reconnectTimer);
        this._reconnectTimer = null;
      }

      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const url = `${proto}//${location.host}${WS_PATH}`;

      try {
        this.ws = new WebSocket(url);
      } catch (e) {
        console.warn('[bastion] WebSocket creation failed:', e);
        this._scheduleReconnect();
        return;
      }

      this.ws.onopen = () => {
        this.wsReady = true;
        this._reconnectAttempts = 0;

        // Flush pending messages
        const pending = this.pendingMessages;
        this.pendingMessages = [];
        pending.forEach(msg => {
          try {
            this.ws.send(JSON.stringify(msg));
          } catch (e) {
            this.pendingMessages.push(msg);
          }
        });

        // Re-register all existing islands with the new connection
        for (const [, instance] of this.instances) {
          this.ws.send(JSON.stringify({
            island: instance.instanceId,
            type: 'init',
            module: instance.moduleName,
            payload: instance.state
          }));
        }
      };

      this.ws.onmessage = (event) => {
        let msg;
        try {
          msg = JSON.parse(event.data);
        } catch (e) {
          console.warn('[bastion] Failed to parse WebSocket message:', e);
          return;
        }
        this._handleMessage(msg);
      };

      this.ws.onclose = (event) => {
        this.wsReady = false;
        if (!event.wasClean) {
          this._scheduleReconnect();
        }
      };

      this.ws.onerror = () => {
        // onclose fires after this, triggering reconnection
      };
    }

    /**
     * Handle an incoming WebSocket message from the server.
     * @param {Object} msg
     */
    _handleMessage(msg) {
      if (msg.type === 'ping') {
        this.send({ type: 'pong' });
        return;
      }

      const instance = this.instances.get(msg.island);
      if (!instance) return;

      switch (msg.type) {
        case 'state':
          instance.onStateUpdate(msg.payload);
          break;
        case 'props':
          // Parent pushed updated props to this child island
          instance.onPropsUpdate(msg.payload);
          break;
        case 'merge':
          instance.onMerge(msg.payload);
          break;
        case 'render':
          // Server-rendered HTML — morph the DOM.
          instance.morph(msg.payload);
          // handoff:true means this is a client-mode island: the server did
          // the first render (SSR over WS) but the WASM module should take
          // over subsequent events.  Start loading it now in the background.
          if (msg.handoff && window.__bastionWasm) {
            window.__bastionWasm.loadModule(instance.moduleName).then(wasmMod => {
              if (wasmMod) {
                instance.wasmModule = wasmMod;
                console.log(`[bastion] WASM handoff: ${instance.moduleName} now handling events locally`);
              }
            });
          }
          break;
        default:
          console.warn(`[bastion] Unknown message type: ${msg.type}`);
      }
    }

    /**
     * Schedule reconnection with exponential backoff and jitter.
     */
    _scheduleReconnect() {
      if (this._reconnectTimer) return;

      const base = Math.min(
        RECONNECT_BASE_MS * Math.pow(2, this._reconnectAttempts),
        RECONNECT_MAX_MS
      );
      const jitter = base * RECONNECT_JITTER * (Math.random() * 2 - 1);
      const delay = Math.max(0, base + jitter);

      this._reconnectAttempts++;
      this._reconnectTimer = setTimeout(() => {
        this._reconnectTimer = null;
        this.connectWebSocket();
      }, delay);
    }

    /**
     * Send a message over the WebSocket. Queues if not connected.
     * @param {Object} msg
     */
    send(msg) {
      if (this.wsReady && this.ws && this.ws.readyState === WebSocket.OPEN) {
        try {
          this.ws.send(JSON.stringify(msg));
        } catch (e) {
          this.pendingMessages.push(msg);
        }
      } else {
        this.pendingMessages.push(msg);
      }
    }

    /**
     * Push state to a channel topic for last-write-wins sync.
     * Called after a Client-mode island updates its local state.
     * @param {string} topic
     * @param {Object} state
     */
    channelPush(topic, state) {
      this.send({
        type: 'channel_push',
        topic: topic,
        payload: state
      });
    }

    // ── Parent-child dispatch ───────────────────────────────────

    /**
     * Walk the data-march-parent chain from the given parent ID upward
     * and call handle_child_event on the first ancestor that matches.
     *
     * If the parent's WASM module has handle_child_event, call it locally
     * and re-render the parent. Also send a child_event message to the server
     * so the server-side state stays in sync.
     *
     * If no ancestor handles the event, the event is dropped (no silent
     * propagation to the server, per spec).
     *
     * @param {string} parentId   - Instance ID of the immediate parent
     * @param {string} onEvent    - Event handler name registered on the parent
     * @param {Object} dispatchObj - {event: string, payload: Object}
     */
    dispatchToParent(parentId, onEvent, dispatchObj) {
      const parentInstance = this.instances.get(parentId);
      if (!parentInstance) return;

      // Local WASM handle_child_event (Phase 4+)
      if (parentInstance.wasmModule && typeof parentInstance.wasmModule.handle_child_event === 'function') {
        const eventName = typeof dispatchObj === 'object' ? dispatchObj.event : dispatchObj;
        const payload = typeof dispatchObj === 'object' ? (dispatchObj.payload || {}) : {};
        const newState = parentInstance.wasmModule.handle_child_event(eventName, payload);
        if (newState !== undefined) {
          parentInstance.state = newState;
          parentInstance.rerender();
        }
      }

      // Send to server so server-side parent state stays in sync
      const eventName = typeof dispatchObj === 'object' ? dispatchObj.event : String(dispatchObj);
      const payload   = typeof dispatchObj === 'object' ? (dispatchObj.payload || {}) : {};
      this.send({
        island: parentId,
        type: 'child_event',
        event: eventName,
        payload: payload
      });
    }

    // ── Event Delegation ────────────────────────────────────────

    /**
     * Bind global event listeners that route DOM events to island dispatches.
     *
     * Supports both new data-on-* attributes and legacy data-msg* attributes.
     * Server-mode islands are skipped — they have no event handlers.
     */
    bindGlobalEvents() {
      // ── Click ─────────────────────────────────────────────────
      document.addEventListener('click', (e) => {
        // New style: data-on-click
        const onClickEl = e.target.closest('[data-on-click]');
        if (onClickEl) {
          e.preventDefault();
          const instance = this._findIslandForElement(onClickEl);
          if (instance) {
            instance.dispatch({ tag: onClickEl.dataset.onClick });
          }
          return;
        }

        // Legacy: data-msg
        const msgEl = e.target.closest('[data-msg]');
        if (msgEl) {
          e.preventDefault();
          const instance = this._findIslandForElement(msgEl);
          if (instance) {
            let msg = msgEl.dataset.msg;
            try { msg = JSON.parse(msg); } catch (_) { msg = { tag: msg }; }
            instance.dispatch(msg);
          }
        }
      });

      // ── Input ──────────────────────────────────────────────────
      document.addEventListener('input', (e) => {
        const target = e.target;

        // New style: data-on-input
        if (target.dataset.onInput) {
          const instance = this._findIslandForElement(target);
          if (instance) {
            instance.dispatch({ tag: target.dataset.onInput, value: target.value });
          }
          return;
        }

        // Legacy: data-msg-input
        if (target.dataset.msgInput) {
          const instance = this._findIslandForElement(target);
          if (instance) {
            instance.dispatch({ type: target.dataset.msgInput, value: target.value });
          }
        }
      });

      // ── Change ─────────────────────────────────────────────────
      document.addEventListener('change', (e) => {
        const target = e.target;

        // New style: data-on-change
        if (target.dataset.onChange) {
          const instance = this._findIslandForElement(target);
          if (instance) {
            const value = target.type === 'checkbox' ? target.checked : target.value;
            instance.dispatch({ tag: target.dataset.onChange, value: value });
          }
          return;
        }

        // Legacy: data-msg-change
        if (target.dataset.msgChange) {
          const instance = this._findIslandForElement(target);
          if (instance) {
            const value = target.type === 'checkbox' ? target.checked : target.value;
            instance.dispatch({ type: target.dataset.msgChange, value: value });
          }
        }
      });

      // ── Submit ─────────────────────────────────────────────────
      document.addEventListener('submit', (e) => {
        // New style: data-on-submit (on the <form> element)
        const onSubmitForm = e.target.closest('[data-on-submit]');
        if (onSubmitForm) {
          e.preventDefault();
          const formData = new FormData(onSubmitForm);
          const data = Object.fromEntries(formData.entries());
          const instance = this._findIslandForElement(onSubmitForm);
          if (instance) {
            instance.dispatch({ tag: onSubmitForm.dataset.onSubmit, data: data });
          }
          return;
        }

        // Legacy: data-msg-submit
        const msgForm = e.target.closest('[data-msg-submit]');
        if (msgForm) {
          e.preventDefault();
          const formData = new FormData(msgForm);
          const data = Object.fromEntries(formData.entries());
          const instance = this._findIslandForElement(msgForm);
          if (instance) {
            instance.dispatch({ type: msgForm.dataset.msgSubmit, data: data });
          }
        }
      });

      // ── Keydown ────────────────────────────────────────────────
      document.addEventListener('keydown', (e) => {
        const target = e.target;

        // New style: data-on-keydown
        if (target.dataset.onKeydown) {
          const keyFilter = target.dataset.onKeydownKey;
          if (keyFilter && e.key !== keyFilter) return;
          const instance = this._findIslandForElement(target);
          if (instance) {
            instance.dispatch({ tag: target.dataset.onKeydown, key: e.key, value: target.value || '' });
          }
          return;
        }

        // Legacy: data-msg-keydown
        if (target.dataset.msgKeydown) {
          const keyFilter = target.dataset.msgKeydownKey;
          if (keyFilter && e.key !== keyFilter) return;
          const instance = this._findIslandForElement(target);
          if (instance) {
            instance.dispatch({ type: target.dataset.msgKeydown, key: e.key, value: target.value || '' });
          }
        }
      });
    }

    /**
     * Find the IslandInstance that owns a given DOM element.
     * Walks up the DOM to find the nearest enclosing island wrapper.
     * @param {HTMLElement} el
     * @returns {IslandInstance|null}
     */
    _findIslandForElement(el) {
      const islandEl = el.closest('[data-march-island]');
      if (!islandEl || !islandEl.dataset.marchInstanceId) return null;
      return this.instances.get(islandEl.dataset.marchInstanceId) || null;
    }

    // ── MutationObserver ────────────────────────────────────────

    _startObserver() {
      if (this._observer) return;

      let pending = false;
      this._observer = new MutationObserver(() => {
        if (pending) return;
        pending = true;
        requestAnimationFrame(() => {
          pending = false;
          this.discoverIslands();
          this.pruneIslands();
        });
      });

      this._observer.observe(document.body, {
        childList: true,
        subtree: true
      });
    }
  }

  // ── Cmd Executor ────────────────────────────────────────────────
  //
  // Interprets the JSON Cmd envelope produced by island update functions
  // (via march_island_update_cmd / march_island_last_cmd WASM exports).
  //
  // Cmd JSON schema — see lib/cmd.march for the canonical type definition.

  /**
   * Execute a single Cmd on behalf of the given IslandInstance.
   * Non-recursive; Batch is handled by iterating the list.
   *
   * @param {IslandInstance} instance
   * @param {Object} cmd        - Parsed cmd JSON, must have a "tag" field
   */
  function executeCmd(instance, cmd) {
    if (!cmd || !cmd.tag) return;

    switch (cmd.tag) {
      // ── No-op ────────────────────────────────────────────────────────
      case 'None':
        break;

      // ── Batch ────────────────────────────────────────────────────────
      case 'Batch':
        if (Array.isArray(cmd.cmds)) {
          cmd.cmds.forEach(c => executeCmd(instance, c));
        }
        break;

      // ── HTTP ─────────────────────────────────────────────────────────
      case 'HttpGet':
        if (cmd.url) {
          fetch(cmd.url, { credentials: 'same-origin' })
            .then(r => r.text())
            .then(body => {
              if (cmd.ref && instance.wasmModule &&
                  typeof instance.wasmModule.exports.march_island_deliver_cmd === 'function') {
                const m = instance.manager;
                const result = { ref: cmd.ref, ok: true, body };
                instance.dispatch(result);
              }
            })
            .catch(err => {
              if (cmd.ref) {
                instance.dispatch({ ref: cmd.ref, ok: false, body: err.message });
              }
            });
        }
        break;

      case 'HttpPost':
        if (cmd.url) {
          fetch(cmd.url, {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json' },
            body: cmd.body || '',
          })
            .then(r => r.text())
            .then(body => {
              if (cmd.ref) instance.dispatch({ ref: cmd.ref, ok: true, body });
            })
            .catch(err => {
              if (cmd.ref) instance.dispatch({ ref: cmd.ref, ok: false, body: err.message });
            });
        }
        break;

      // ── Timers ───────────────────────────────────────────────────────
      case 'After':
        if (typeof cmd.ms === 'number' && cmd.msg != null) {
          setTimeout(() => instance.dispatch(cmd.msg), cmd.ms);
        }
        break;

      case 'Every':
        if (typeof cmd.ms === 'number' && cmd.msg != null) {
          setInterval(() => instance.dispatch(cmd.msg), cmd.ms);
        }
        break;

      // ── DOM ──────────────────────────────────────────────────────────
      case 'Focus':
        if (cmd.id) {
          const el = document.getElementById(cmd.id);
          if (el && typeof el.focus === 'function') el.focus();
        }
        break;

      case 'Blur':
        if (cmd.id) {
          const el = document.getElementById(cmd.id);
          if (el && typeof el.blur === 'function') el.blur();
        }
        break;

      // ── Navigation ───────────────────────────────────────────────────
      case 'PushUrl':
        if (cmd.path && typeof history.pushState === 'function') {
          history.pushState({}, '', cmd.path);
        }
        break;

      case 'ReplaceUrl':
        if (cmd.path && typeof history.replaceState === 'function') {
          history.replaceState({}, '', cmd.path);
        }
        break;

      // ── localStorage ────────────────────────────────────────────────
      case 'StoreLocal':
        if (cmd.key != null && cmd.value != null) {
          try { localStorage.setItem(cmd.key, cmd.value); } catch (_) {}
        }
        break;

      case 'LoadLocal':
        if (cmd.key != null) {
          let value = null;
          try { value = localStorage.getItem(cmd.key); } catch (_) {}
          if (cmd.ref) {
            instance.dispatch({ ref: cmd.ref, value: value !== null ? value : undefined });
          }
        }
        break;

      case 'RemoveLocal':
        if (cmd.key != null) {
          try { localStorage.removeItem(cmd.key); } catch (_) {}
        }
        break;

      // ── Channel ──────────────────────────────────────────────────────
      case 'ChannelPush':
        if (cmd.event != null && cmd.payload != null && instance.channelTopic) {
          instance.manager.send({
            type: 'channel_push',
            topic: instance.channelTopic,
            event: cmd.event,
            payload: cmd.payload,
          });
        }
        break;

      default:
        console.warn(`[bastion/cmd] unknown Cmd tag: ${cmd.tag}`);
    }
  }

  // ── Boot ────────────────────────────────────────────────────────

  const manager = new IslandManager();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => manager.init());
  } else {
    manager.init();
  }

  // ── Public API ───────────────────────────────────────────────────
  //
  // window.Bastion.getIsland(moduleName) → IslandHandle
  //
  // Allows host-page JS (outside Bastion) to send messages into specific
  // island instances and read their current state snapshots.
  //
  // This is different from the removed window.marchIslands.send global bus —
  // each call targets a named island type, not a broadcast to all islands.
  //
  // Example:
  //   const searchBar = Bastion.getIsland("MyApp.Islands.SearchBar");
  //   searchBar.send({ tag: "SetQuery", value: "new search term" });
  //   const state = searchBar.getState();
  //   console.log(state.results.length);
  //
  //   // All instances of this island type (e.g. multiple on the page):
  //   Bastion.getIsland("MyApp.Islands.Counter").all().forEach(h => {
  //     h.send({ tag: "Reset" });
  //   });

  /**
   * A handle for sending messages to a named island type.
   * Wraps all currently-hydrated instances with that module name.
   */
  class IslandHandle {
    /**
     * @param {string} moduleName
     * @param {IslandManager} mgr
     */
    constructor(moduleName, mgr) {
      this._moduleName = moduleName;
      this._mgr = mgr;
    }

    /** Collect all live instances of this island type. */
    _instances() {
      const result = [];
      for (const [, inst] of this._mgr.instances) {
        if (inst.moduleName === this._moduleName) result.push(inst);
      }
      return result;
    }

    /**
     * Send a JSON-compatible message to all instances of this island type.
     *
     * msg can be:
     *   a plain string         → zero-payload variant, e.g. "Increment"
     *   { tag: "Name" }        → zero-payload variant (tag form)
     *   { tag: "Name", ...kv } → payloaded variant
     *
     * Each instance calls its dispatch() — WASM update + server sync.
     *
     * @param {string|Object} msg
     */
    send(msg) {
      const instances = this._instances();
      if (instances.length === 0) {
        console.warn(`[bastion] Bastion.getIsland("${this._moduleName}").send() — no hydrated instances found`);
        return;
      }
      instances.forEach(inst => inst.dispatch(msg));
    }

    /**
     * Return the current state snapshot of the first (or only) instance.
     * Returns null if no instances are hydrated yet.
     *
     * @returns {Object|null}
     */
    getState() {
      const instances = this._instances();
      return instances.length > 0 ? instances[0].state : null;
    }

    /**
     * Return per-instance handles when multiple instances of the same
     * island type exist on the page.
     *
     * @returns {Array<{instanceId: string, send: Function, getState: Function}>}
     */
    all() {
      return this._instances().map(inst => ({
        instanceId: inst.instanceId,
        el: inst.el,
        send: (msg) => inst.dispatch(msg),
        getState: () => inst.state,
      }));
    }

    /** Number of currently-hydrated instances of this island type. */
    get count() {
      return this._instances().length;
    }
  }

  window.Bastion = {
    /**
     * Get a handle to all instances of a named island type.
     *
     * @param {string} moduleName - PascalCase island module name,
     *   e.g. "MyApp.Islands.SearchBar" or just "SearchBar"
     * @returns {IslandHandle}
     */
    getIsland(moduleName) {
      return new IslandHandle(moduleName, manager);
    },

    /**
     * Register a callback that fires whenever an island of the named type
     * dispatches a message. Useful for observing island activity from host JS.
     *
     * Returns an unsubscribe function.
     *
     * @param {string} moduleName
     * @param {Function} cb - fn(instanceId, msg, state)
     * @returns {Function} unsubscribe
     */
    onDispatch(moduleName, cb) {
      // Store in a manager-level listener map
      if (!manager._dispatchListeners) manager._dispatchListeners = new Map();
      const key = moduleName;
      const listeners = manager._dispatchListeners.get(key) || [];
      listeners.push(cb);
      manager._dispatchListeners.set(key, listeners);
      // Return unsubscribe
      return () => {
        const current = manager._dispatchListeners.get(key) || [];
        manager._dispatchListeners.set(key, current.filter(l => l !== cb));
      };
    },

    /** Version string for runtime detection. */
    version: '0.1.0',
  };

  // Internal debug handle — use window.Bastion for production use.
  window.__bastionIslands = manager;

})();
