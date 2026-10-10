# Reactive performance benchmark

This maintainer-only benchmark compares the current eager `GFComputedProperty` with private pull-cache prototypes. It adds no public API and does not import a second reactive system. The fixture has no `class_name`, is outside GUT's `test_` discovery, and copies exactly seven kernel dependencies into a private Godot project.

```powershell
python tools/gf_reactive_benchmark.py --godot "<trusted Godot executable>"
```

The default JSON report is `build/reactive-benchmark.json`; logs are under `ai_analysis/godot_logs/reactive_benchmark`. `--correctness-only` runs lifecycle and value-isolation checks without performance samples. `--keep-sandbox` retains the private project and environment for inspection; otherwise the harness removes only its own verified sandbox after supervised processes are quiescent. Godot receives private user-data, configuration, cache and temporary directories. The overall deadline defaults to 180 seconds and may be set to a finite 1–600 seconds; each process also has a maximum 60-second deadline. Existing output is replaced only when it identifies itself as this harness's schema-v1 report.

The three workloads use 24 views and 1200 simulated 60Hz frames per sample:

- `sparse_expensive`: writes at 20Hz, reads at 1Hz, 256 arithmetic steps per computation.
- `cheap_every_frame`: a single arithmetic step, with writes and reads every frame.
- `branch_view`: reads every frame; the active source changes at 1Hz, the inactive source at 20Hz, and explicit branch selection every two seconds.

Each process warms up for 120 frames, then records nine samples. Three process repetitions rotate mode order. The result records source SHA256, Godot version, checksums, compute/invalidation/rebind counts and subscription counts. Identical workload checksums and zero remaining subscriptions are correctness requirements. Timing is observational evidence, not a CI performance pass/fail threshold.

`frame_p95_usec` and `read_p95_usec` measure Godot's monotonic elapsed time during active code. They are neither simulated time nor per-frame CPU accounting. Windows additionally records the direct Godot process's kernel-plus-user CPU time with `GetProcessTimes`; this includes startup and shutdown. On platforms without this accounting, CPU is explicitly unavailable rather than approximated from elapsed time. Concurrent machine load, timer resolution, engine startup, OS scheduling and arithmetic chosen for the fixture limit comparisons; repeat on the target hardware before making a product claim.

The static prototype listens to explicit sources but computes only on read. The branch prototype explicitly reconnects to a chosen source; it does not discover arbitrary tracked reads, maintain a dynamic graph, detect graph cycles or support implicit dependencies. Both return collection copies, release source subscriptions on disposal, and reject cache publication if their compute callback changes the source epoch. The fixture also checks owner exit, source deduplication and branch subscription replacement.

Pull views have no eager `value_changed` notification contract and are not drop-in replacements for `GFComputedProperty`. They move computation into reads: lower total work or frame p95 can coexist with worse read latency. The branch prototype's selector subscription adds ownership and rebind costs even when selection never changes. A useful design requires an explicit pull consumer, a read-time budget and lifecycle/reentry semantics; a favorable synthetic result alone does not establish the need for a public API.
