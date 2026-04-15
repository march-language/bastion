# drafts/

Quarantined March modules that are **not yet part of the Bastion build graph**.

These files were migrated from the March stdlib's `bastion_*` prototypes on
2026-04-09 (march commit d4a5245), but have not yet been refactored to use the
current stdlib surface or wired into any consumer.  They fail `forge check`
against the current compiler and would block every build if left under `lib/`.

Each file is kept here so the migration work isn't lost — when its feature is
actually needed, pick it up, port it to the current APIs, move it back under
`lib/`, add tests, and wire it into the module graph.

| File | What it was | Why it's parked |
|------|-------------|-----------------|
| `bastion_components.march`  | Shared UI component helpers                     | References stdlib types that have since been renamed |
| `bastion_cookies.march`     | Cookie parsing / encoding helpers               | API drifted from current Conn abstraction |
| `bastion_dev.march`         | Dev-only helpers (liveness, hot-reload stubs)   | Depends on unfinished dev-server infrastructure |
| `bastion_telemetry.march`   | Request telemetry / timing scaffolding          | Pre-dates typed middleware pipeline |
| `bastion_test_sandbox.march`| Test sandbox + Vault-backed fixtures            | Vault API shape has changed (expects `(String, value)` not `(atom, atom)`) |
| `session.march`             | Session store draft                             | Depends on `cookies` and `vault` surfaces that moved |

**This directory is not compiled.**  It's a parking lot, not source code.
