# ADR-0003: Productize selective validation behind one module

- Status: Accepted
- Date: 2026-08-23

## Context

Validation Shadow, affected analysis, and GUT sharding currently exist as parallel observational implementations with separate commands, reports, schemas, and tests. They do not yet reduce the authoritative validation path, while local Full validation has become expensive.

## Decision

One Validation Module will own planning, lane execution, evidence joining, selection, reuse, partitioning, authority, and fail-closed fallback. Its external interface is limited to planning a request, running a planned lane, and joining evidence into a report.

A single Validation Catalog declares every action's dependencies, inputs, executor, produced artifacts, time budget, reuse policy, partition policy, and membership in local, Full, and Release intents.

Local validation prioritizes fast affected feedback. Remote Full remains the final merge authority; Release remains the strictest authority. GUT partitioning becomes authoritative only after repeated exact comparison with an unfiltered control, and infrastructure uncertainty falls back to unfiltered execution.

Threat handling is layered:

- External and persisted evidence, artifacts, release inputs, credentials, process output, and untrusted paths remain strictly validated.
- Owned typed values inside one invocation are trusted after admission.
- Process timeout, cancellation, and orphan cleanup remain mandatory.
- The implementation does not claim protection from an active same-account attacker mutating local state during an invocation.

## Consequences

- Shadow, affected, and GUT-partition product value is retained, but their parallel top-level schemas and commands are transitional.
- Unknown input closure always executes; failed or ambiguous evidence is never reused.
- Changes to the Validation Catalog, implementation, or workflow disable trusted reuse and require a complete bootstrap run.
- Existing Full/Release action closure and required merge contexts stay unchanged throughout migration.

## Migration sequence

This decision is implemented incrementally. The first slice centralizes action identifiers, statically available command arguments, dependency declarations, existing check groups and suites, and ordered Full lanes without changing execution behavior. A missing static command means only that the runner materializes it later from live inputs; it does not select an executor. Executor selection, inputs, artifacts, partitioning, and reuse remain runner-owned until a real consumer is migrated with focused tests. This temporary representation is not the final Action specification.

The next consumer slice moved the default and per-action timeout floors into the Catalog. The runner still owns caller-requested timeout increases, suite-deadline clipping, and aggregate parallel-lane envelopes; those are distinct policies and are not folded into the action floor.
