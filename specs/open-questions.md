# Bastion: Open Questions and Future Work

**Status**: Draft | **Version**: 0.1 | **Part of**: [Bastion Design Spec](README.md)

---

## Open Design Questions

1. ~~**Sigil implementation**~~ — **Resolved (diagnosis was wrong).** The March lexer's `read_triple_string` rule returns the same `STRING` token as regular single-quoted strings — both `"..."` and `"""..."""` produce `STRING`. The existing parser production `SIGIL_PREFIX STRING` therefore already handles triple-quoted sigils. No parser change needed. `~H"""..."""` works today.

2. ~~**WASM compilation target**~~ — **Resolved.** The `wasm32-unknown-unknown` target is fully implemented in `lib/tir/llvm_emit.ml` (target triple, pointer size, island export functions, bump allocator runtime). The compiler accepts `--target wasm32-unknown-unknown` and produces valid browser WASM. Forge's `cmd_build.ml` already uses it for `@island` modules. Remaining work is JS-side: deferred hydration strategies and `march_island_msg_from_name` wiring in `priv/js/`. See todos.md.

3. **Island serialization**: How are props serialized from server to client for hydration? JSON is the natural choice (consistent with the JS interop boundary), but should there be a binary fast-path for large datasets?

4. **Hot code reloading**: Can islands be hot-swapped in development without losing state? How does the dev server coordinate WASM recompilation?

5. **WASM actor runtime**: How are March actors (green threads, mailboxes, `Pid(a)`) implemented in the WASM target? Does each island get its own WASM instance, or do they share one with cooperative scheduling?

6. **Vault implementation**: What's the underlying data structure? Hash array mapped trie (HAMT) for lock-free reads? How does the TTL sweeper interact with ongoing reads? What are the memory overhead characteristics per entry?

7. **Vault and multi-node**: Should Vault support optional replication/sync across nodes (e.g., for session data), or remain strictly per-node with external tools for distribution?

8. **Embedded asset size limits**: For `--embed-assets`, how large can embedded static assets be before they degrade binary startup time? Is there a threshold where external files are preferable?

9. **OpenTelemetry overhead**: What's the performance impact of tracing in production? Should spans be sampled by default? What's the right default sample rate?

---

## Explicitly Out of Scope for v1

The following features are intentionally excluded from Bastion v1:

- **Background jobs / task queues** — will be a separate library
- **Mailer / email sending** — use an external library
- **Internationalization (i18n)** — deferred to post-v1
- **API versioning** — application-level concern, not framework-level
- **GraphQL** — use a dedicated GraphQL library on top of Bastion
- **OpenAPI / Swagger generation** — deferred
- **Admin dashboard** — deferred (see Bastion.LiveDashboard in future work)

---

## Future Work (Post v1)

- **Typed bidirectional JS bindings**: Auto-generated TypeScript types from March island types, direct function exports, shared memory for high-performance interop (see [js-interop.md](js-interop.md))
- **Bastion.Presence**: Track which users are online (like Phoenix.Presence) using CRDTs
- **Bastion.LiveDashboard**: Built-in admin panel showing request metrics, WebSocket connections, actor counts, WASM bundle sizes, Vault table stats
- **Background job system**: Persistent job queues backed by Depot, with retries, scheduling, and dead-letter handling
- **Distributed PubSub**: Cross-node Channel message broadcasting
- **Distributed Vault**: Optional cross-node replication for Vault tables that need consistency across nodes
- **Static site generation**: Pre-render pages at build time for content-heavy sites
- **Edge deployment**: Compile Bastion apps to WASM for edge runtime deployment (Cloudflare Workers, etc.)
- **Form handling**: A typed form library that validates on client (WASM) and server with the same validation rules
- **i18n**: Internationalization support with compile-time string extraction
- **Built-in CSS pipeline**: Optional integrated CSS preprocessing if ecosystem demand warrants it
- **CSP auto-generation**: Automatically derive CSP policy from the app's actual resource usage
