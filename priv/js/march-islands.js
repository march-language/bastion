/**
 * Bastion Islands Client Runtime
 *
 * Discovers <div data-march-island="ModuleName"> elements in the DOM,
 * opens a single multiplexed WebSocket to the server, and manages
 * island lifecycle (state sync, event dispatch, DOM morphing).
 */

(() => {
  'use strict';

  // ── Constants ─────────────────────────────────────────────────

  const WS_PATH = '/_bastion/ws';
  const RECONNECT_BASE_MS = 500;
  const RECONNECT_MAX_MS = 30000;
  const RECONNECT_JITTER = 0.3;  // +/- 30% jitter

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
     * Called when server sends a full state replacement.
     * In Phase 2 (server-rendering), we store the state but do NOT
     * trigger a local rerender -- the server will send a separate
     * 'render' message with the HTML.
     * @param {Object} newState
     */
    onStateUpdate(newState) {
      this.state = newState;
      // Phase 2: don't rerender locally; server sends 'render' messages.
      // Phase 4 (client WASM): uncomment this to rerender client-side.
      // this.rerender();
    }

    /**
     * Called when server sends a merge (CRDT reconciliation).
     * Phase 2: server state always wins (no client-side WASM merge).
     * Phase 4: will use WASM merge function if available.
     * @param {Object} remoteState
     */
    onMerge(remoteState) {
      this.state = remoteState;
      // Phase 2: don't rerender locally; server sends 'render' messages.
    }

    /**
     * Dispatch a user-initiated message.
     *
     * Phase 2 (server-rendering): No optimistic local update. The message
     * is sent to the server which runs update() + render() and sends back
     * rendered HTML.  The client morphs the DOM when the 'render' response
     * arrives.
     *
     * Phase 4 (client WASM): Will restore optimistic local updates when
     * WASM modules are available on the client.
     *
     * @param {string|Object} msgPayload
     */
    dispatch(msgPayload) {
      // Phase 2: send to server, wait for render response.
      // No optimistic local update — all state lives on the server.
      this.manager.send({
        island: this.instanceId,
        type: 'msg',
        payload: msgPayload
      });
    }

    /**
     * Re-render the island. If a client-side WASM render function
     * exists, use it to produce HTML and morph the DOM. Otherwise
     * the server will send rendered HTML via a 'render' message.
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
     */
    discoverIslands() {
      const elements = document.querySelectorAll('[data-march-island]');
      elements.forEach(el => {
        if (el.dataset.marchInstanceId) return;  // already initialized
        const instance = new IslandInstance(el, this);
        this.instances.set(instance.instanceId, instance);

        // Attempt to load WASM module (Phase 2)
        if (window.__bastionWasm) {
          const mod = window.__bastionWasm.getModule(instance.moduleName);
          if (mod) {
            instance.wasmModule = mod;
          }
        }

        // Tell server about this island
        this.send({
          island: instance.instanceId,
          type: 'init',
          module: instance.moduleName,
          payload: instance.state
        });
      });
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
        // onclose will fire after this, triggering reconnection
      };
    }

    /**
     * Handle an incoming WebSocket message from the server.
     * @param {Object} msg
     */
    _handleMessage(msg) {
      // Handle broadcast/system messages
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
        case 'merge':
          instance.onMerge(msg.payload);
          break;
        case 'render':
          // Server-rendered HTML (for islands without client WASM)
          instance.morph(msg.payload);
          break;
        default:
          console.warn(`[bastion] Unknown message type: ${msg.type}`);
      }
    }

    /**
     * Schedule a reconnection with exponential backoff and jitter.
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

    // ── Event Delegation ────────────────────────────────────────

    bindGlobalEvents() {
      // Click events: data-msg attribute
      document.addEventListener('click', (e) => {
        const target = e.target.closest('[data-msg]');
        if (!target) return;

        e.preventDefault();

        let msg = target.dataset.msg;
        // Attempt to parse as JSON for structured messages
        try {
          msg = JSON.parse(msg);
        } catch (_) {
          // Leave as string
        }

        const instance = this._findIslandForElement(target);
        if (instance) {
          instance.dispatch(msg);
        }
      });

      // Input events: data-msg-input attribute
      document.addEventListener('input', (e) => {
        const target = e.target;
        if (!target.dataset.msgInput) return;

        const msg = {
          type: target.dataset.msgInput,
          value: target.value
        };

        const instance = this._findIslandForElement(target);
        if (instance) {
          instance.dispatch(msg);
        }
      });

      // Change events: data-msg-change attribute (for selects, checkboxes)
      document.addEventListener('change', (e) => {
        const target = e.target;
        if (!target.dataset.msgChange) return;

        const value = target.type === 'checkbox' ? target.checked : target.value;
        const msg = {
          type: target.dataset.msgChange,
          value: value
        };

        const instance = this._findIslandForElement(target);
        if (instance) {
          instance.dispatch(msg);
        }
      });

      // Form submit events: data-msg-submit attribute
      document.addEventListener('submit', (e) => {
        const form = e.target.closest('[data-msg-submit]');
        if (!form) return;

        e.preventDefault();
        const formData = new FormData(form);
        const data = Object.fromEntries(formData.entries());
        const msg = {
          type: form.dataset.msgSubmit,
          data: data
        };

        const instance = this._findIslandForElement(form);
        if (instance) {
          instance.dispatch(msg);
        }
      });

      // Keyboard events: data-msg-keydown attribute
      document.addEventListener('keydown', (e) => {
        const target = e.target;
        if (!target.dataset.msgKeydown) return;

        const keyFilter = target.dataset.msgKeydownKey;
        if (keyFilter && e.key !== keyFilter) return;

        const msg = {
          type: target.dataset.msgKeydown,
          key: e.key,
          value: target.value || ''
        };

        const instance = this._findIslandForElement(target);
        if (instance) {
          instance.dispatch(msg);
        }
      });
    }

    /**
     * Find the IslandInstance that owns a given DOM element.
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

      // Debounce mutation handling to batch rapid DOM changes
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

  // Expose for debugging and programmatic access
  window.__bastionIslands = manager;

})();
