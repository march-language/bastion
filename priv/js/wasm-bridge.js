/**
 * WASM Bridge for Bastion Islands
 *
 * Phase 1: Stub -- all rendering is done server-side.
 * Phase 2: Load .wasm modules compiled from March island definitions,
 *          call render/update/merge via the WASM interface.
 */
(() => {
  'use strict';

  /**
   * Represents a loaded WASM island module with render, update, and merge
   * functions. Phase 2 will instantiate these from compiled .wasm binaries.
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
      // Phase 2: call into WASM memory, marshal state, get HTML back
      throw new Error('WasmIslandModule.render not yet implemented');
    }

    /**
     * Apply a message to the state and return new state.
     * @param {Object} state
     * @param {string|Object} msg
     * @returns {Object}
     */
    update(state, msg) {
      // Phase 2: call into WASM update function
      throw new Error('WasmIslandModule.update not yet implemented');
    }

    /**
     * Merge local and remote state (CRDT reconciliation).
     * @param {Object} localState
     * @param {Object} remoteState
     * @returns {Object}
     */
    merge(localState, remoteState) {
      // Phase 2: call into WASM merge function
      throw new Error('WasmIslandModule.merge not yet implemented');
    }
  }

  /**
   * Manages loading and caching of WASM island modules.
   */
  class WasmBridge {
    constructor() {
      /** @type {Map<string, WasmIslandModule>} */
      this.modules = new Map();
      /** @type {Map<string, Promise<WasmIslandModule|null>>} */
      this._loading = new Map();
    }

    /**
     * Load a WASM module for the given island module name.
     * Returns null in Phase 1 (no client-side WASM available).
     *
     * @param {string} moduleName
     * @returns {Promise<WasmIslandModule|null>}
     */
    async loadModule(moduleName) {
      // Return cached module if already loaded
      if (this.modules.has(moduleName)) {
        return this.modules.get(moduleName);
      }

      // Deduplicate concurrent loads for the same module
      if (this._loading.has(moduleName)) {
        return this._loading.get(moduleName);
      }

      const promise = this._doLoadModule(moduleName);
      this._loading.set(moduleName, promise);

      try {
        const mod = await promise;
        if (mod) {
          this.modules.set(moduleName, mod);
        }
        return mod;
      } finally {
        this._loading.delete(moduleName);
      }
    }

    /**
     * @param {string} moduleName
     * @returns {Promise<WasmIslandModule|null>}
     * @private
     */
    async _doLoadModule(moduleName) {
      // Phase 2 implementation:
      // try {
      //   const url = `/_bastion/islands/${moduleName}.wasm`;
      //   const resp = await fetch(url);
      //   if (!resp.ok) return null;
      //
      //   const importObject = {
      //     env: {
      //       // Memory management, string passing, etc.
      //       // will be defined based on the March WASM ABI
      //     }
      //   };
      //
      //   const { instance } = await WebAssembly.instantiateStreaming(resp, importObject);
      //   return new WasmIslandModule(instance);
      // } catch (e) {
      //   console.warn(`[bastion] Failed to load WASM for ${moduleName}:`, e);
      //   return null;
      // }

      // Phase 1: no client-side WASM
      return null;
    }

    /**
     * Get a previously loaded module, or null if not loaded.
     * @param {string} moduleName
     * @returns {WasmIslandModule|null}
     */
    getModule(moduleName) {
      return this.modules.get(moduleName) || null;
    }
  }

  window.__bastionWasm = new WasmBridge();
})();
