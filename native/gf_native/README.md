# GF Native

GF Native is the optional platform addon for packed integer row selection, Terrain-RGB height decoding and tiled WFC entropy solving. Their public GF APIs select the installed capability automatically on the main thread.

## Install in a game

Extract the matching archives beside the game's `project.godot`.

| Installation | Archive |
| --- | --- |
| New Windows x64 project | `gf-framework-windows-x86_64-<version>.zip` |
| Add Windows x64 acceleration to an existing GF installation | `gf-native-windows-x86_64-<version>.zip` |
| Linux x86_64 (glibc), Android arm64-v8a/x86_64 (API 24+), or iOS arm64 (15+) | `gf-framework-<version>.zip` plus `gf-native-multiplatform-<version>.zip` |
| Portable GF for script-only projects | `gf-framework-<version>.zip` |

GFHeightfield3D uses the installed decoder for RGB8 and RGBA8 without enabling Data Batch. The portable package and worker threads run the GDScript decoder. See the [heightfield guide](../../docs/zh/standard/foundation/grid-spatial/heightfield-surface-scatter-3d.md).

The standard WFC API, `GFWaveFunctionCollapse2D.solve_grid()`, accelerates entropy-based selection on grids up to 4096 cells with 1–128 tile types. Worker threads, portable installations, other heuristics and larger caller-approved grids or tile sets use the script solver. Both paths support unrestricted and directional adjacency, fixed cells, periodic boundaries, step limits and the same seeded report. See the [WFC guide](../../docs/zh/standard/foundation/grid-spatial/wave-function-collapse-2d.md).

Enable GF Framework in Project Settings. To use integer gather, enable Data Batch in GF Workspace → GF Extensions. The usual five-argument `GFDataBatchPublication.create()` connects automatically on the main thread. An explicit sixth argument of `null` selects GDScript. A project can also supply its own backend or require a compatible backend. See the [Data Batch guide](../../docs/zh/extensions/data-batch/index.md#可选原生-gather).

Godot discovers the descriptor when it imports the project. Keep the native directory together and install it once per project. Its libraries resolve relative to the descriptor. The multi-platform supplement includes the Windows x64, Linux x64 and Apple Silicon editor libraries and an XCFramework for iOS devices and Apple Silicon simulators. Upgrade it alongside GF to the same version. The shared libraries embed redistribution notices. On Windows, also ship the two notice files exported beside the executable. Game developers and players do not need Cargo, Rust or Visual Studio.

## Build and verify

For the full release, place the qualified `overlay.zip` and its six runtime reports in `build/native-delivery/`. On Windows x64, use the MSVC x64 build tools, rustup with Cargo on PATH, and the Godot editor with matching debug and release Windows export templates. The release workflow provisions the pinned editor and compiler. The crate pins its Rust toolchain, Cargo dependencies and C runtime linkage.

```powershell
python tools/build_gf_release_artifacts.py --output-dir build/release
python tools/build_gf_release_artifacts.py --manifest build/release/gf-release-artifacts-<version>.json --validate-only
```

The release builder takes the Windows DLL from the qualified multi-platform ZIP and verifies its linker dependencies. It installs the complete ZIP in a fresh project, compares gather results, height samples and complete WFC reports against GDScript, tests adding the supplement to a portable project at a different path, and runs both exported executables with their own copies of the DLL and notices. The manifest records the size and SHA-256 of each published archive. Validation of transported archives reads the same bytes on any host. To run just the native qualification during development, use `python tools/gf_native_acceptance.py --export`.

### Build Linux, Android and iOS libraries

Run `rustup target add` inside `native/gf_native` for the triples you want. From the repository root, build Linux and Android with an x86_64 Linux toolchain and Android NDK r28b. Build Apple targets with Xcode on an Apple Silicon Mac.

```sh
python tools/gf_native_platforms.py build --targets x86_64-unknown-linux-gnu aarch64-linux-android x86_64-linux-android --ndk "$ANDROID_NDK_ROOT"
python tools/gf_native_platforms.py build --targets aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim
```

Each host writes its libraries and source-bound receipts under `build/native-platforms/<triple>/`. For local testing, `package --targets` accepts the editor host plus the intended export targets. Include both iOS slices together. For example, on Linux:

```sh
python tools/gf_native_platforms.py package --targets x86_64-unknown-linux-gnu aarch64-linux-android x86_64-linux-android --archive build/native-preview.zip
python tools/gf_native_platform_acceptance.py linux --archive build/native-preview.zip --output build/linux-check
python tools/gf_native_platform_acceptance.py android --device emulator-5554 --archive build/native-preview.zip --output build/android-check
```

Set `GF_GODOT_EXECUTABLE` to the editor with matching release templates. Android uses the editor's Android SDK and JDK settings and a disposable signing key. With an Apple overlay, run `gf_native_platform_acceptance.py ios --device <booted-simulator-UDID>` with the same archive and output options. It builds an unsigned device app and checks the public APIs in a simulator app. Game signing uses the game's own Apple team.

The release workflow joins all seven target libraries into one overlay before exercising the Debug and Release games. To reproduce its handoff, test this exact ZIP on each platform with `--profile debug` and `--profile release`, passing `--receipts build/native-delivery`. Both Android ABIs must report success. Release timings cover 256×256 Terrain-RGB, 16×16 WFC and a 100,000-row gather. The release builder checks all six reports against the ZIP's SHA-256, checks Windows exports with its embedded DLL, and publishes the same bytes. Packaging verifies ELF dependencies, Android 16 KB load-segment alignment and Apple device/simulator identity. The portable framework and its Asset Store distribution remain available independently.

## Benchmark foundation operations

Run the following command on Windows x64 with the pinned Rust toolchain, a Godot editor and its matching Windows release export template.

```powershell
python tools/gf_foundation_benchmark.py --godot "path/to/godot.exe" --baseline-root "path/to/reference-worktree"
```

The reference worktree is optional. It supplies the previous height decoder, four-direction flow, noise grid and Voronoi implementations for a same-export comparison. Use `--height-baseline` to supply only a previous decoder. The runner fingerprints the inputs and binaries, rotates measurement order, warms up twice and records nine samples per operation in `build/foundation-benchmark-results/`. Each measured call returns a complete report that must match the reference.

| Workload | Timed operation |
| --- | --- |
| Terrain-RGB | Public decoder on the main thread with the shipped DLL and on a worker using the portable implementation. Timing starts inside the worker. |
| Height queries and surface scatter | Eight height reads on 64×64 and 512×512 fields and eight placed transforms on the larger field. The runner checks the sampled plane and guards against query cost growing with grid area. |
| Noise grid | Public FastNoiseLite grid sampling including normalized samples, compared with direct engine noise and standalone normalization. |
| Flow | Public four-direction unit-cost field versus a benchmark-only Rust FIFO. The native lane includes capturing the passability mask and constructing the public dictionaries. |
| Voronoi | Complete graph reports on 64, 256 and 512 sites. Instrumented copies time the insertion loop. Given a reference implementation, 504 additional cases compare all fields across input orders, duplicate sites, grids, rings, clustered and nearly collinear sites, and three tolerances. |
| WFC | Equal-weight entropy and MRV, then a floor/stone/water layout with unequal weights, adjacency constraints and three fixed cells. A weighted 128-tile case exercises both words of each domain. Both paths call the public solver and compare the entire report, including partial domains, contradiction locations and step counts. |

The Windows native PR workflow compares geometry with the PR base and retains its JSON report. Use `--voronoi-baseline <gf_voronoi_2d.gd>` to run just the geometry reference alongside the standard workloads. The benchmark flags a 512-site diagram taking over 1.5 times the reference median on the same runner. It checks height query scaling and requires the installed decoder to take at most half the portable time on the same 512×512 RGB8 image.

The 16×16 entropy workload requires the installed solver to take at most half the portable median. The weighted fixed-cell and 128-tile workloads each allow up to 80% of their portable median. Timings include rule normalization and public report construction. The portable timer starts inside the worker.

## Add a capability

1. Place the implementation and Rust unit tests in a capability module beside `src/packed_gather.rs`. Register its module in `src/lib.rs`. Capabilities share the library entry point, Cargo lockfile, loader and distribution package.
2. Give the capability a specific internal Godot class and versioned protocol. Its owning GF extension provides the typed GDScript interface, checks availability and owns the script behavior. The current `GfPackedGatherBackend` singleton receives a batch in one call. The framework retains control of validation, publication and budgets.
3. Register the new capability's scenes or scripts in `tools/gf_native_acceptance.py` so the runner executes them in portable, native and exported games. Add the GDScript adapter to the runner's input fingerprint and the owning extension to `.github/workflows/native-windows.yml` path filters. Simply placing a test file under `tests/native` does not execute it. Include representative sizes and error cases. Qualify each new platform's real binary before adding it to the distribution.
4. When a dependency changes, update the pinned source URLs and license texts in `THIRD_PARTY_NOTICES.txt`. The release builder checks these against Cargo.lock, includes GF's license and attaches the pinned Rust standard library notices.
