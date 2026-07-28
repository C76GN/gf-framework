# GF Storage Backend Acceptance Template

Copy every file in this directory into an isolated, project-owned path such as
`res://adapters/storage/<provider>/`, remove each `.txt` suffix, and keep the
file names stable until Godot has imported all scripts. Provider SDK code stays
in the project or in a separately distributed Adapter package; it does not
belong under `res://addons/gf`.

The concrete test ships with a bounded memory Provider only so a copied
template is immediately executable. Acceptance of a real Adapter requires
replacing `MemoryStorageProviderFactory` with a factory that constructs the
real Provider and an explicit test-only fault driver. Do not fork or weaken
`ProjectStorageBackendConformance`. Run the unchanged harness against the
installed or exported Adapter and its sandbox account, emulator, test server,
or SDK fault hooks.

The project needs `gf.standard.storage` and its package closure. GUT is required
only for conformance. A maintenance acceptance must copy and rename the
templates into a clean Godot project, run a fresh import, and then run
`storage_backend_contract_test.gd`; source sentinels alone are not acceptance.

## Files and replacement points

- `storage_value_limits.gd` defines the shared bounded plain-value validator.
  Both the Backend and Provider use it; neither side trusts the other.
- `storage_provider.gd` is the narrow real SDK boundary.
- `storage_provider_factory.gd` creates a fresh real Provider for every test and
  supplies sandbox-only configuration without printing it.
- `storage_provider_fault_driver.gd` injects atomic-commit, malformed-result,
  unknown-error, and post-initialize drift faults without exposing production
  fault controls.
- `storage_backend.gd` is the reusable `GFStorageBackend` Adapter.
- `storage_backend_conformance.gd` owns the unchanged acceptance cases.
- `storage_backend_contract_test.gd` binds the harness to one factory. Replace
  only its sample memory factory and sample Provider implementation.

## Protocol, capabilities, and results

`ProjectStorageBackend.PROTOCOL_VERSION` and
`ProjectStorageProvider.PROTOCOL_VERSION` are one exact stable SemVer
contract. Initialization rejects an absent Provider, protocol mismatch,
unknown configuration field, fractional limit, out-of-range limit, invalid
Provider option graph, incomplete capability set, or a Provider that cannot
guarantee atomic replacement.

Capability dictionaries are closed schemas. Every documented key must exist,
no other key is accepted, and every flag must be exactly `bool`. The Adapter
checks protocol and capabilities both before and after Provider initialization
and rejects any drift. `read`, `write`, `delete`, `list`, and `atomic_write` are
required. The base `GFStorageBackend` protocol is synchronous, so the template
requires `cancellation: false` and `sync: false`.

Provider read results contain exactly `ok`, `data`, `metadata`, and
`error_code`. List results contain exactly `ok`, `records`, and `error_code`;
each record contains exactly `storage_key` and `metadata`. Field types are
exact. Provider messages and response bodies are not part of either schema.
A default `GFStorageBackend`, `ProjectStorageBackend`,
`ProjectStorageProvider`, factory, or fault driver is not usable.

## Bounded plain-value contract

Configuration, payloads, metadata, and list records accept only a bounded graph
of `null`, `bool`, `int`, finite `float`, UTF-8 `String`, `Array`, and
`Dictionary` with `String` keys. The shared validator rejects cycles,
`Object`, `Callable`, `RID`, non-finite numbers, excessive depth, excessive
node counts, large containers, and oversized strings without stringifying or
logging the value.

All configured budgets have framework-supplied defaults and absolute maxima.
The Adapter overrides the public `save_data()` entry so value-graph validation
happens before the base backend can recursively duplicate caller data.
`max_payload_bytes` applies before any Provider write and again before a
Provider read result is copied. Cycles, excessive depth, excessive node counts,
and oversized strings therefore fail before deep copy or Provider dispatch.
Provider `read_record` receives the complete read budget before it downloads,
decodes, or allocates data. Provider `list_records` receives item,
encoded-byte, graph, string, depth, and container budgets before enumeration.
The Adapter repeats the validation after each Provider call. A Provider that
first allocates an unbounded response and checks afterward does not satisfy
this contract.

## Logical keys and portable aliases

`file_name` is a logical storage key, not an operating-system path, Provider
URL, or bucket name. The template accepts portable slash-separated components
and rejects absolute paths, empty components, `.`, `..`, backslashes, drive
prefixes, wildcards, control characters, trailing dots or spaces, and reserved
device aliases. Reserved checks are case-insensitive, use the stem before the
first dot, and normalize the `COM¹`/`COM²`/`COM³` and
`LPT¹`/`LPT²`/`LPT³` aliases. A configured `key_prefix` keeps Provider keys
inside one Adapter-owned namespace.

If the Provider ultimately writes files, object-store keys, registry entries,
or native platform slots, validate again before translating the logical key.
Resolve file destinations inside one owned root and reject link/reparse
traversal or namespace escape. Never concatenate an untrusted key into a raw
path or URL.

## Options, revisions, and atomic writes

Top-level initialization accepts only the documented Provider, prefix, and
budget fields. Provider-specific configuration belongs inside
`provider_options`, is bounded before it crosses the Provider boundary, and
must never be rendered into diagnostics.

A write may carry only `write_options.expected_revision`,
`write_options.create_if_absent`, and `write_options.request_id`.
`expected_revision` is a bounded opaque non-empty String token; projects must
not parse it as an integer. `create_if_absent: true` is explicit and mutually
exclusive with `expected_revision`. A stale token or an existing
create-if-absent target fails without changing data or metadata.

`write_record_atomic()` must leave either the complete old record or the
complete new record visible. A temporary upload, transaction,
compare-and-swap, or write-then-rename strategy is acceptable only when its
Provider semantics really give that guarantee. Never advertise `atomic_write`
for a sequence that can expose partial bytes or delete the previous record
before commit succeeds. Provider-generated bounded revision tokens are
returned in metadata; project code owns retry, conflict, quota, offline, and
merge policy.

## Error translation and sensitive data

Provider errors are mapped to an explicit allowlist of Godot `Error` values.
Unknown, malformed, or Provider-specific integers normalize to the
operation-specific stable fallback. A result with `ok: false` and
`error_code: OK` is contradictory and is rejected as malformed
`ERR_INVALID_DATA`; it never crosses the Adapter as a successful error code.
Backend errors contain fixed Adapter text only. Logs and assertions must report
operation IDs, stable error codes, and bounded counts; never full configuration, payloads, metadata,
result dictionaries, credentials, account identifiers, access tokens, bucket
names, host paths, Provider messages, or response bodies.

The conformance suite injects a redaction canary through a malformed Provider
result and proves it cannot cross the closed result schema. Add
Provider-specific canaries for authentication loss, quota, offline state,
timeout, rate limits, partial upload, concurrent writers, permission denial,
corruption, callback threading, and export targets without printing their
values.

## Cancellation and asynchronous Providers

`GFStorageBackend` is a synchronous protocol and has no per-operation
cancellation parameter. Do not hide a live cancellation token in metadata or
claim cancellability in capabilities. For an asynchronous SDK, add a separate
project-owned asynchronous facade that:

1. validates logical keys and immutable options before dispatch;
2. associates one Provider call ID before a synchronous callback can arrive;
3. checks cancellation before dispatch and gives the caller one terminal
   result;
4. requests Provider cancellation at most once and ignores late or duplicate
   callbacks;
5. copies bounded plain data through bounded main-thread ingress before
   touching Godot or GF objects; and
6. shuts down with a documented bounded wait.

Keep that facade outside `GFStorageBackend`; this synchronous Adapter must not
block indefinitely while pretending an asynchronous operation is cancellable.

## Acceptance matrix

The unchanged harness covers:

- absent, default, mismatched, non-atomic, and capability-drifting Providers;
- exact capability and result schemas before and after initialization;
- invalid configuration and bounded Provider option graphs;
- exists/read/write/delete/list behavior and deterministic listing;
- Provider-visible read/list hard budgets and pre-write rejection;
- portable keys, reserved stems, superscript aliases, and closed options;
- cycles, forbidden Variant types, non-finite values, and all graph limits;
- opaque revisions, explicit create-if-absent, and stale-token conflicts;
- injected commit failure preserving the complete previous record;
- explicit Provider error normalization and redaction canaries;
- defensive copies; and
- idempotent shutdown with no usable operations afterward.

The real Provider factory and fault driver are part of the acceptance asset.
If the Provider cannot produce one required fault safely, improve its sandbox
or test boundary; do not delete the case.
