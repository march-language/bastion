/**
 * WASM Bridge for Bastion Islands
 *
 * Phase 2: Server-side rendering bridge.
 *
 * In Phase 2, all rendering and state updates happen server-side.  The client
 * sends messages over the WebSocket, the server runs update() and render(),
 * and sends back rendered HTML which the client morphs into the DOM.
 *
 * The WasmBridge still exists so the runtime can query whether a client-side
 * module is available (it won't be — loadModule always returns null).  This
 * keeps the IslandInstance.dispatch() path simple: no WASM module means
 * "send to server and wait for render response".
 *
 * Phase 4 will replace this with actual WASM loading and client-side
 * render/update/merge calls.
 */
(() => {
  'use strict';

  /**
   * Represents a loaded WASM island module with render, update, and merge
   * functions.  Phase 4 will instantiate these from compiled .wasm binaries.
   */
  class WasmIslandModule {
    /**
     * @param {WebAssembly.Instance} instance
     */
    constructor(instance) {
      this.instance = instance;
      this.exports = instance.exports;
    }

    /**
     * Render the current state to an HTML string.
     * @param {Object} state
     * @returns {string}
     */
    render(state) {
      // Phase 4: call into WASM memory, marshal state, get HTML back
      throw new Error('WasmIslandModule.render not yet implemented (Phase 4)');
    }

    /**
     * Apply a message to the state and return new state.
     * @param {Object} state
     * @param {string|Object} msg
     * @returns {Object}
     */
    update(state, msg) {
      // Phase 4: call into WASM update function
      throw new Error('WasmIslandModule.update not yet implemented (Phase 4)');
    }

    /**
     * Merge local and remote state (CRDT reconciliation).
     * @param {Object} localState
     * @param {Object} remoteState
     * @returns {Object}
     */
    merge(localState, remoteState) {
      // Phase 4: call into WASM merge function
      throw new Error('WasmIslandModule.merge not yet implemented (Phase 4)');
    }
  }

  /**
   * Manages loading and caching of WASM island modules.
   *
   * Phase 2: All methods return null — no client-side WASM.  The runtime
   * detects this and falls back to server-side rendering via WebSocket.
   */
  class WasmBridge {
    constructor() {
      /** @type {Map<string, WasmIslandModule>} */
      this.modules = new Map();
      /** @type {Map<string, Promise<WasmIslandModule|null>>} */
      this._loading = new Map();
      /** @type {boolean} */
      this.serverRendering = true;
    }

    /**
     * Load a WASM module for the given island module name.
     * Returns null in Phase 2 (all rendering is server-side).
     *
     * @param {string} moduleName
     * @returns {Promise<WasmIslandModule|null>}
     */
    async loadModule(moduleName) {
      // Phase 2: no client-side WASM — server renders everything
      return null;
    }

    /**
     * Get a previously loaded module, or null if not loaded.
     * @param {string} moduleName
     * @returns {WasmIslandModule|null}
     */
    getModule(moduleName) {
      // Phase 2: always null
      return null;
    }

    /**
     * Check whether the bridge is in server-rendering mode.
     * @returns {boolean}
     */
    isServerRendering() {
      return this.serverRendering;
    }
  }

  window.__bastionWasm = new WasmBridge();
})();
