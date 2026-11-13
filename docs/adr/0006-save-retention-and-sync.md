# ADR-0006: Save retention and revision synchronization

Status: Accepted

## Context

Unknown content may need to survive a content rollback without becoming active gameplay state. Cloud writes may succeed after the caller stops waiting, while independent devices or a later local mutation continue changing the record. Loose schema acceptance, timestamp ordering and file copying cannot express these boundaries.

## Decision

Keep document envelopes and known field types strict. A Provider may declare an explicit payload retention policy; absence of a policy continues to support admitted scalar, array and native payloads. Profile state owns retained baselines. Collections use declared stable identity, never array position. Explicit deletion and transaction rollback operate on both runtime projection and retained data. Unknown whole sections require exact IDs.

Standard owns one revision synchronization engine independent of Save. Requests freeze namespace, key, operation ID, expected opaque revision, data and local generation. Transport supplies read, remote atomic conditional write, operation idempotency and historical probe. Journal success means durable persistence. Persist intent before dispatch and outcome before reporting committed. Cancellation ends observation; uncertain outcomes retain their original identity for probing.

GFStorageTransfer preserves ordinary Backend comparison, preview, directional copies and explicit merge without claiming CAS or cross-backend atomicity. Conflict reports are frozen values with explicit payload access and payload-free diagnostic summaries.

Save composes the Standard engine with the existing Profile transaction coordinator. Framework-owned metadata stores account binding, durable content generation, acknowledged revision/generation and intent. Public project metadata cannot replace that checkpoint; migrations preserve it. Ordinary saves preserve it, and only confirmed physical writes update the in-memory checkpoint. Late write confirmation respects generation order.

Explicit project projection controls uploaded fields and constructs a complete local download candidate. Downloads atomically persist candidate and checkpoint, rechecking the local generation after the transaction barrier. Retained payloads and unknown sections participate in rollback. A session binds credentials through its Transport and rejects another account's Profile binding. No implicit guest merge exists.

## Consequences

- No external extension dependency, network SDK, HTTP service or second business transaction engine is introduced.
- Profile synchronization uses a confirmed document snapshot; unregistered in-memory changes are not silently discovered.
- A normal upload adds two local transactions. Snapshot, projection and durable intent increase memory and CPU costs. Bounded data validation is not a frame-time guarantee.
- Read-only preview, standalone record sync, ordinary file transfer, manual/custom conflict resolution and local slot presentation retain explicit entry points.
- SlotSyncBridge is removed; project documentation combines the existing slot file plan with Transfer when plain file movement is sufficient.
- Controlled adapters are tests only. Production adapters remain responsible for atomic server revision checks, authentication, idempotency retention and truthful probe results.
