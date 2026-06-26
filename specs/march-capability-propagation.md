# March Capability Propagation — Compiler Fix Needed

**Status**: workaround in place; compiler fix required to eliminate 11 spurious warnings  
**Affects**: `forge check` output — no runtime impact  
**Compiler issue location**: `march/refine/` (capability checker pass)

---

## The Problem

The March capability checker has contradictory behaviour when a module imports
another module that requires a capability:

**Scenario**: `bastion_cache.march` imports `Vault`, which internally requires
`Cap(IO.Mut)`.

| Declaration | `forge check` result |
|-------------|----------------------|
| `needs IO.Mut` present | WARNING: "module declares `needs IO.Mut` but no function requires `Cap(IO.Mut)`" |
| `needs IO.Mut` absent  | ERROR: "imports Vault which requires `Cap(IO.Mut)`, but `IO.Mut` not declared" |

Both outcomes are wrong. The checker oscillates: removing the declaration turns
a warning into an error; adding it back turns the error into a warning.

### Affected files (11 declarations)

| File | Capability | Via import |
|------|-----------|------------|
| `lib/http/bastion_server.march` | `IO.Console` | `Bastion` → `IO.Console` ops |
| `lib/observability/telemetry_aggregator.march` | `IO.Mut` | `Vault` |
| `lib/channels/bastion_pubsub.march` | `IO.Mut` | `Vault` |
| `lib/cache/bastion_cache.march` | `IO.Mut` | `Vault` |
| `lib/security/csrf.march` | `IO.Random` | `Crypto` |
| `lib/view/error_overlay.march` | `IO.Console` | `Bastion.Dev` |
| `lib/view/error_overlay.march` | `IO.Clock` | `Bastion.Dev` |
| `lib/testing/test_channel.march` | `IO.Mut` | `Vault` |
| `lib/cache/cache.march` | `IO.Mut` | `Vault` |
| `lib/security/session.march` | `IO.Random` | `Crypto` |
| `lib/islands/island_socket.march` | `IO.Mut` | `Vault` |

---

## Root Cause

The capability checker enforces two rules that conflict for transitive
requirements:

1. **Propagation rule**: A module that imports `M` must declare every capability
   that `M` requires, so the capability is visible to callers up the stack.
2. **Usage rule**: A declared capability must be *directly* used (i.e., a
   function in the module must require `Cap(X)`); otherwise the declaration is
   flagged as dead.

These rules are both correct in isolation. They conflict when a capability is
needed *only* to satisfy the propagation rule — the module never uses the
capability directly but must declare it to avoid an error from rule 1, causing
a warning from rule 2.

---

## Recommended Fix (compiler change)

### Option A — suppress "unused" for propagated capabilities (minimal diff)

In the "unused capability" warning pass, check whether the declared capability
is transitively required by any import. If so, suppress the warning.

```
-- pseudo-code in the capability checker
for each declared_cap in module.needs do
  if not directly_used(declared_cap, module) then
    if not transitively_required_by_imports(declared_cap, module) then
      emit WARNING "unused capability declaration"
    end
    -- otherwise: silent; declaration is load-bearing for propagation
  end
end
```

`transitively_required_by_imports` walks the import graph and returns true if
any reachable import has `declared_cap` in its required-capabilities set.

**Trade-off**: Keeps explicit declarations required (good for auditability)
while eliminating the false-positive warning. No API change.

### Option B — auto-propagate capabilities from imports (ergonomic)

Remove the requirement to redeclare capabilities that come entirely from
imports. The checker computes the *effective* capability set as:

```
effective_caps(M) = declared_caps(M) ∪ ⋃{ required_caps(I) | I ∈ imports(M) }
```

Callers of `M` would see `effective_caps(M)` without `M` needing to name each
imported capability explicitly.

**Trade-off**: More ergonomic (no boilerplate `needs` lines for pass-through
modules), but makes the capability boundary of a module implicit. Could
surprise users auditing what a module can do.

### Option C — capability inference (most ergonomic, largest change)

Drop explicit `needs` declarations entirely; infer the full capability set from
the module body and its imports during the check pass. Emit the inferred set in
`forge check --verbose` output for auditability.

**Trade-off**: Least boilerplate, but `needs` declarations lose their role as
a machine-checked contract. Probably appropriate only as an opt-in default for
library code, not security-sensitive handlers.

---

## Recommended action

**Implement Option A** in the capability checker (`march/refine/` or wherever
the "unused capability" diagnostic is emitted). It is the smallest change, it
keeps `needs` declarations as explicit contracts, and it fixes the false
positives without touching the error half of the oscillation.

The fix is entirely in the diagnostic logic and requires no grammar, parser, or
codegen changes. The implementation roughly is:

1. After the existing "unused capability" check, before emitting the warning,
   call a helper `import_requires_cap(mod, cap)` that queries the type-checked
   module table for the capability sets of each direct import.
2. If that helper returns true, skip the warning for this declaration.
3. Add a test case: a module that declares `needs IO.Mut`, imports Vault, and
   has no direct `IO.Mut` calls should produce zero diagnostics.

Once this lands in the compiler and is deployed to the toolchain used by this
repo, all 11 `needs` lines listed above can be removed from Bastion.
