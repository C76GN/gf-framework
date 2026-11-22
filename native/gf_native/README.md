# GF Native

GF Native is the optional Windows x64 addon for packed integer row selection, Terrain-RGB height decoding and tiled WFC entropy solving. Their public GF APIs select the installed capability automatically on the main thread.

## Install in a game

Extract one archive at the root of the Godot project, beside `project.godot`.

| Installation | Archive |
| --- | --- |
| New Windows x64 project | `gf-framework-windows-x86_64-<version>.zip` |
| Add native support to the same version of GF | `gf-native-windows-x86_64-<version>.zip` |
| Portable GF for other targets or script-only projects | `gf-framework-<version>.zip` |

GFHeightfield3D uses the installed decoder for RGB8 and RGBA8 without enabling Data Batch. The portable package and worker threads run the GDScript decoder. See the [heightfield guide](../../docs/zh/standard/foundation/grid-spatial/heightfield-surface-scatter-3d.md).

The standard WFC API, `GFWaveFunctionCollapse2D.solve_grid()`, accelerates entropy-based selection on grids up to 4096 cells with 1–128 tile types. Worker threads, portable installations, other heuristics and larger caller-approved grids or tile sets use the script solver. Both paths support unrestricted and directional adjacency, fixed cells, periodic boundaries, step limits and the same seeded report. See the [WFC guide](../../docs/zh/standard/foundation/grid-spatial/wave-function-collapse-2d.md).

Enable GF Framework in Project Settings. To use integer gather, enable Data Batch in GF Workspace → GF Extensions. The usual five-argument `GFDataBatchPublication.create()` connects automatically on the main thread. An explicit sixth argument of `null` selects GDScript. A project can also supply its own backend or require a compatible backend. See the [Data Batch guide](../../docs/zh/extensions/data-batch/index.md#可选原生-gather).

Godot discovers the descriptor when it imports the project. Keep the native directory together and install it once per project. Its DLL and export dependencies resolve relative to the descriptor, so the directory can be moved intact. Upgrade it alongside GF to the same version. Ship the DLL and both notice files produced by Godot with the exported game. Game developers and players do not need Cargo, Rust or Visual Studio.

## Build and verify

From the repository root on Windows x64, use the MSVC x64 build tools, rustup with Cargo on PATH, and the Godot editor with matching debug and release Windows export templates. The release workflow provisions the pinned editor and compiler. The crate pins its Rust toolchain, Cargo dependencies and C runtime linkage.

```powershell
python tools/build_gf_release_artifacts.py --output-dir build/release
python tools/build_gf_release_artifacts.py --manifest build/release/gf-release-artifacts-<version>.json --validate-only
```

The builder compiles one release DLL and verifies the dependencies recorded by the linker. It installs the complete ZIP in a fresh project, compares gather results, height samples and complete WFC reports against GDScript, tests adding the supplement to a portable project at a different path, and runs both exported executables with their own copies of the DLL and notices. The manifest records the size and SHA-256 of each published archive. Validation of transported archives reads the same bytes on any host. To run just the native qualification during development, use `python tools/gf_native_acceptance.py --export`.

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
