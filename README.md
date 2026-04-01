# Bastion

## Known limitations

### `forge bastion.build.islands` — content hashing requires `shasum`

`forge bastion.build.islands` computes 8-char content hashes for compiled WASM
files by shelling out to `shasum -a 256` (available on macOS and most Linux
distributions via `coreutils`).

This is a platform dependency. A future improvement would replace it with a
pure-March SHA-256 implementation so the command works on any target without
requiring system utilities.

Workaround on systems without `shasum`: install `coreutils` (e.g.
`brew install coreutils` on macOS if missing, or `apt install coreutils` on
Debian/Ubuntu), or use `forge bastion.gen.island --compile` for single-island
builds, which skips hashing entirely and serves files with a short cache TTL.
