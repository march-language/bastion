# Production-Readiness Review — 2026-06-11

Scope: whole framework vs specs/features.md claims. Produced by a read-only
review agent; verify line numbers before fixing.

**Verdict: suitable for dev/staging; NOT production-ready until Phases 1–2 land.**
Architecture (Conn, Router, middleware pipeline, islands, channels) is sound;
the gaps are operational: error recovery, config, TLS, observability.

## Top blockers (ranked)

1. **`safe_call_plug` is a no-op** — `lib/bastion_server.march:92-94`. No panic
   recovery; one bad handler can take down the worker. Blocked on a
   `HttpServer.try_call`-style catch primitive in the March stdlib.
2. **OTLP export stubbed** — `lib/otel.march:83-88` silently drops spans
   ("HttpClient not yet available").
3. **No async HTTP client** in March stdlib — blocks webhooks, OTLP, retries,
   background jobs.
4. **Panic-recovery primitive missing** — also blocks error_overlay's
   `rescue_errors/1` and the crash REPL (both currently no-ops).
5. **Pool checkout failure silently ignored** — `lib/depot_middleware.march:60-75`;
   DB outage surfaces as handler panics instead of clean 503s.
6. **No Config module** — no env-var binding, typed config, or secrets story;
   blocks 12-factor deployment.
7. **TLS not exposed** through `Bastion.Opts`/server wiring.
8. **No request-scoped DB transactions** — no auto BEGIN/COMMIT/ROLLBACK around
   handlers; partial writes leak on crashes.
9. **Telemetry coverage sparse** — only channel-message + endpoint-exception
   events; no request start/stop, middleware, or query timing.
10. **Test coverage thin** — 8 test files vs 68 lib modules; no end-to-end
    CRUD+auth+DB+channel integration tests.

## features.md corrections needed

- OpenTelemetry exporter: marked implemented → actually a stub (no POST, no Task.async).
- Error overlay + crash REPL: marked implemented → `rescue_errors/1` no-op,
  `debug_socket/2` 404s, `March.Repl` doesn't exist.
- Structured logging: "JSON in prod via MARCH_ENV" → nothing reads MARCH_ENV.
- Metrics + dashboard: dashboard is a static HTML stub.
- Nothing under-claimed: islands SSR and Channel/PubSub are as good as or
  better than documented.

## API inconsistencies (1.0 hygiene)

- `new` vs `start` vs `default_opts` naming; no `Opts.new()`.
- Error semantics mixed: `Result` arg orders differ (Auth vs Pool), `Option`
  used where errors carry information (pool exhaustion → `None`).
- Conn-returning vs unit-returning mutators mixed (Session.put vs Vault.set).
- Only 2 after-send hooks, hardcoded in bastion_server; needs a Hooks registry.
- Vault `set`/`put` aliases, `drop` vs `delete`.
- No HTTP status constants/helpers.
- Namespacing mixed: `Bastion.Logger` vs `BastionServer` vs bare `Router`.

## Suggested order of work

- **Phase 1 — safety**: panic recovery + 500 path; Config module; TLS in Opts;
  auto transaction wrapping in depot middleware.
- **Phase 2 — observability**: real OTLP POST (needs stdlib HttpClient);
  request/middleware/query telemetry; Hooks registry.
- **Phase 3 — reliability**: integration tests (CRUD+auth+DB+channels, failure
  modes); exception logging/telemetry in safe_call_plug; graceful shutdown via
  Health.start_drain on SIGTERM.
- **Phase 4 — API polish**: standardize Result/Conn conventions, HTTP constants,
  namespace moves.
- **Phase 5 — docs**: deployment guide (TLS/config/shutdown), error-handling
  contract, failure runbooks.
