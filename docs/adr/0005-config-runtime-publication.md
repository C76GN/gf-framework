# ADR-0005: Configuration candidate publication

Status: Accepted

## Context

Editable table Resources and lazy source callbacks cannot also be the write authority for a running configuration set. Incremental registration permits partial replacement, and mutable source aliases can change cross-table meaning between queries.

## Decision

Keep author data in Database/Table Resources. Capture a candidate set, validate its schemas, records, indexes and merged reference graph, then publish one GFConfigSnapshot using a provider generation comparison. Readers may retain an older snapshot. Failed preparation or stale publication does not modify the active set.

Resource and external-source providers remain distinct adapters. Source registration is a catalog operation; explicit preparation loads a requested reference closure. Queries never invoke loaders. Generated objects use an explicit whole-table capture or record enumeration/projector contract. Callbacks are synchronous trusted code; reentrant preparation and catalog mutation reject the outer request.

Incremental candidates reuse isolated unchanged tables, including their indexes and digests. Changed tables are validated and normalized before reference checking. Query results copy mutable collections. Resource leaves remain shared asset references; their internals and arbitrary object behavior are outside snapshot isolation.

Content identity includes an explicit project version and a diagnostic canonical digest with a coverage result. Unencodable values produce an unavailable digest, not a misleading partial hash. Schema descriptions do not authenticate custom validation code or asset contents.

## Consequences

- Remove active per-table registration, clear-then-register replacement, writable table aliases and implicit query-time loading.
- Preserve chapter loading, generated input, incremental edits, explicit unloading and pinned-version reads through the new publication boundary.
- Keep database authoring registration and standalone custom-provider schema validation.
- Preparation, hashing and simultaneous generations cost time and memory; use bounded loading phases and measure project-sized inputs. Do not infer a performance guarantee from functional tests.
- No optional extension dependency or external generator ownership enters Standard.
