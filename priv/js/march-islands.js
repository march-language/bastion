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

    /** True if this is a Server-mode island (read-only, no event listeners). */
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
     * For Server-mode islands: this should never be called (no event listeners).
     *
     * @param {string|Object} msgPayload
     */
    dispatch(msgPayload) {
      if (this.isServer()) return;  // defensive: Server islands have no events

      if (this.wasmModule) {
        const result = this.wasmModule.update(msgPayload);

        if (result) {
          // Handle {state, dispatch} tuple from update (parent-child dispatch)
          const newState = result.state !== undefined ? result.state : result;
          const upstreamDispatch = result.dispatch || null;

          this.state = newState;
          const html = this.wasmModule.render();
          if (html !== null) this.morph(html);

          // Channel sync (last-write-wins, no CRDT)
          if (this.channelTopic) {
            this.manager.channelPush(this.channelTopic, newState);
          }

          // Child-to-parent dispatch: walk up the tree
          if (upstreamDispatch && this.parentId && this.onEvent) {
            this.manager.dispatchToParent(this.parentId, this.onEvent, upstreamDispatch);
          }
        }
      }

      // Send to server (persistence, auth, side-effects)
      this.manager.send({
        island: this.instanceId,
        type: 'msg',
        payload: msgPayload
      });
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
          ignoreActiveValue: true
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
    }

    nextId() {
      return ++this._idCounter;
    }

    // ── Initialization ──────────────────────────────────────────

    init() {
      this.connectWebSocket();
      this.discoverIslands();
      this.bindGlobalEvents();
      this._startObserver();
    }

    /**
     * Scan the DOM for uninitialized island elements and register them.
     *
     * Hydration order: parents before children. DOM order naturally guarantees
     * this for nested islands — querySelectorAll returns nodes in document order,
     * so a parent <div> always appears before its nested children.
     */
    discoverIslands() {
      const elements = document.querySelectorAll('[data-march-island]');
      elements.forEach(el => {
        if (el.dataset.marchInstanceId) return;  // already initialized
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

        // Tell server about this island (Server mode and Client-with-channel)
        this.send({
          island: instance.instanceId,
          type: 'init',
          module: instance.moduleName,
          payload: instance.state
        });

        // Async WASM loading (Phase 4)
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
      });
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
          // Server-rendered HTML (SSR islands or Server-mode)
          instance.morph(msg.payload);
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
          if (instance && !instance.isServer()) {
            instance.dispatch({ tag: onClickEl.dataset.onClick });
          }
          return;
        }

        // Legacy: data-msg
        const msgEl = e.target.closest('[data-msg]');
        if (msgEl) {
          e.preventDefault();
          const instance = this._findIslandForElement(msgEl);
          if (instance && !instance.isServer()) {
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
          if (instance && !instance.isServer()) {
            instance.dispatch({ tag: target.dataset.onInput, value: target.value });
          }
          return;
        }

        // Legacy: data-msg-input
        if (target.dataset.msgInput) {
          const instance = this._findIslandForElement(target);
          if (instance && !instance.isServer()) {
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
          if (instance && !instance.isServer()) {
            const value = target.type === 'checkbox' ? target.checked : target.value;
            instance.dispatch({ tag: target.dataset.onChange, value: value });
          }
          return;
        }

        // Legacy: data-msg-change
        if (target.dataset.msgChange) {
          const instance = this._findIslandForElement(target);
          if (instance && !instance.isServer()) {
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
          if (instance && !instance.isServer()) {
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
          if (instance && !instance.isServer()) {
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
          if (instance && !instance.isServer()) {
            instance.dispatch({ tag: target.dataset.onKeydown, key: e.key, value: target.value || '' });
          }
          return;
        }

        // Legacy: data-msg-keydown
        if (target.dataset.msgKeydown) {
          const keyFilter = target.dataset.msgKeydownKey;
          if (keyFilter && e.key !== keyFilter) return;
          const instance = this._findIslandForElement(target);
          if (instance && !instance.isServer()) {
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

  // ── Boot ────────────────────────────────────────────────────────

  const manager = new IslandManager();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => manager.init());
  } else {
    manager.init();
  }

  // Expose for debugging only. No global send API — use channels or parent-child dispatch.
  window.__bastionIslands = manager;

})();
