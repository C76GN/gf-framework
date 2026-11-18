# GF Native

GF Native is the prebuilt Windows x64 addon for GF's native capabilities. Its first capability selects integer rows from packed columns. Game code continues to call the Data Batch GDScript API.

## Install in a game

Extract one archive at the root of the Godot project, beside `project.godot`.

| Installation | Archive |
| --- | --- |
| New Windows x64 project | `gf-framework-windows-x86_64-<version>.zip` |
| Add native support to the same version of GF | `gf-native-windows-x86_64-<version>.zip` |
| Portable GF for other targets or script-only projects | `gf-framework-<version>.zip` |

Enable GF Framework in Project Settings. To use integer gather, enable Data Batch in GF Workspace → GF Extensions. The usual five-argument `GFDataBatchPublication.create()` connects automatically on the main thread. An explicit sixth argument of `null` selects GDScript. A project can also supply its own backend or require a compatible backend. See the [Data Batch guide](../../docs/zh/extensions/data-batch/index.md#可选原生-gather).

Godot discovers the descriptor when it imports the project. Keep the native directory together and install it once per project. Its DLL and export dependencies resolve relative to the descriptor, so the directory can be moved intact. Upgrade it alongside GF to the same version. Ship the DLL and both notice files produced by Godot with the exported game. Game developers and players do not need Cargo, Rust or Visual Studio.

## Build and verify

From the repository root on Windows x64, use the MSVC x64 build tools, rustup with Cargo on PATH, and the Godot editor with matching debug and release Windows export templates. The release workflow provisions the pinned editor and compiler. The crate pins its Rust toolchain, Cargo dependencies and C runtime linkage.

```powershell
python tools/build_gf_release_artifacts.py --output-dir build/release
python tools/build_gf_release_artifacts.py --manifest build/release/gf-release-artifacts-<version>.json --validate-only
```

The builder compiles one release DLL and verifies the dependencies recorded by the linker. It installs the complete ZIP in a fresh project, compares real gather results against GDScript, tests adding the supplement to a portable project at a different path, and runs both exported executables with their own copies of the DLL and notices. The manifest records the size and SHA-256 of each published archive. Validation of transported archives reads the same bytes on any host. To run just the native qualification during development, use `python tools/gf_native_acceptance.py --export`.

## Add a capability

1. Place the implementation and Rust unit tests in a capability module beside `src/packed_gather.rs`. Register its module in `src/lib.rs`. Capabilities share the library entry point, Cargo lockfile, loader and distribution package.
2. Give the capability a specific internal Godot class and versioned protocol. Its owning GF extension provides the typed GDScript interface, checks availability and owns the script behavior. The current `GfPackedGatherBackend` singleton receives a batch in one call. The framework retains control of validation, publication and budgets.
3. Register the new capability's scenes or scripts in `tools/gf_native_acceptance.py` so the runner executes them in portable, native and exported games. Add the GDScript adapter to the runner's input fingerprint and the owning extension to `.github/workflows/native-windows.yml` path filters. Simply placing a test file under `tests/native` does not execute it. Include representative sizes and error cases. Qualify each new platform's real binary before adding it to the distribution.
4. When a dependency changes, update the pinned source URLs and license texts in `THIRD_PARTY_NOTICES.txt`. The release builder checks these against Cargo.lock, includes GF's license and attaches the pinned Rust standard library notices.
