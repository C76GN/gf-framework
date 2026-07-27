# GF Platform Adapter Template

Use this template in a project-owned directory such as
`res://adapters/platform/<provider>/`, or in a separately distributed adapter
package. Do not place provider SDK code under `res://addons/gf`.

## Required boundaries

- Extend `GFPlatformAdapter` for platform capabilities and lifecycle.
- Declare every callable method with `GFPlatformContractDescriptor` and
  `GFPlatformContractMethodDescriptor`.
- Put request/result schemas, byte budgets, capability requirements,
  concurrency, cancellation support, and sensitive fields in the descriptor.
- Treat every provider callback as untrusted input. Correlate it to one active
  request, validate its result schema, and redact it before publishing a GF
  result, lifecycle event, activation intent, diagnostic, or log entry.
- Extend `GFNetworkLobbyBackend` only for lobby operations. Correlate every SDK
  callback with the `request_id` and handle supplied to `_dispatch_operation`.
- When the SDK exposes a Godot `MultiplayerPeer`, pass it to
  `GFMultiplayerPeerNetworkBackend.adopt_peer()` with explicit ownership and
  feature support. Do not add provider types to GF protocols.
- Publish launch, invite, and join callbacks as `GFPlatformActivationIntent`
  with provider-stable intent IDs. The runtime deduplicates and consumes them by
  the composite `adapter_id + intent_id` identity and bounds replay.
- Run `GFPlatformAdapterConformance.inspect()` with exact required contract
  versions before integration tests.
- Fill `compatibility_profile.json` with the actual target environment. Version
  ranges are requirements, not profile metadata: check them explicitly with
  `GFCompatibilityPreflight.require_godot_version()`,
  `require_framework_version()`, and `require_package()`.

## Native mode and fail-closed probing

Choose exactly one native mode in `metadata.native_boundary.mode`:

- `script_only`: remove the native artifacts and prove that no native payload
  belonging to this Adapter is included in exported builds.
- `optional`: an absent native provider leaves the Adapter unregistered and
  publishes no provider capability.
- `required`: an absent, mismatched, or unverifiable provider fails
  initialization with a stable, redacted reason. It must not silently select a
  script fallback or a different native binary.

Packaging and CI verify descriptor and library bytes before execution. A
runtime probe is side-effect free: first match the declared
`platform + architecture + build_configuration` target, then query the expected
resource or registered class. Do not instantiate or initialize a native type
only to detect it. `ClassDB.class_exists()` is an availability fact after engine
loading, not proof of provenance, integrity, compatibility, or permission.
Required evidence that is missing, stale, ambiguous, or only partially readable
must fail closed.

## Native artifact matrix

Record the `.gdextension` descriptor and every selectable native library in
`compatibility_profile.json`. Each native library entry declares one exact
target tuple, immutable source version, license identifier, byte size, SHA-256,
and `editor` or `runtime` export scope. Reject duplicate tuples, undeclared
filename fallbacks, placeholder hashes, missing files, hash mismatches, and a
descriptor whose library mapping disagrees with the profile.

Record the exact Godot compatibility floor and reloadability policy. A
non-reloadable extension requires an editor or process restart; an Adapter must
not claim hot-reload support merely because a script can be reloaded.

## Threading and callback pump

Declare the SDK call thread and callback thread. Native worker callbacks may
copy bounded plain data into a project-owned ingress queue, but must not touch
`Object`, `Node`, `Resource`, a GF request handle, or emit a signal off the main
thread. Drain that ingress through a bounded main-thread callback pump. A
project may use `GFMainThreadDispatchQueue` when its owning package is declared,
or provide an equivalent project-owned pump.

Associate the provider call ID with the GF handle before an SDK call that may
complete synchronously. Apply backpressure to both the provider and callback
queues, validate copied payloads again on the main thread, and ignore late or
duplicate callbacks after the request has reached a terminal state.

## Shutdown and cancellation

Shutdown is idempotent and ordered:

1. Stop accepting new requests and native callbacks.
2. Give each pending GF handle exactly one local cancellation terminal state.
3. Request provider cancellation at most once, then detach provider callbacks.
4. Drop or drain Adapter-owned callback records without invoking released
   owners.
5. Join Adapter-owned workers with a documented bounded timeout.
6. Release the provider only after callbacks can no longer arrive.

A join timeout or callback source that cannot be quiesced is a shutdown failure,
not a successful unload. Cancellation never waits indefinitely for a provider
acknowledgement, and a late acknowledgement cannot create a second terminal
result.

## Permissions and sensitive data

List native permissions and external resources explicitly. Permission denial,
unavailable elevation, or a forbidden interactive prompt produces a stable
typed failure; headless, export, and background paths must never open an
implicit permission dialog. Do not bypass operating-system policy or expand
access after initialization.

Keep credentials, account tokens, payment data, device or network identifiers,
and raw provider errors out of compatibility metadata, activation intents, and
logs. Declare request fields that require redaction as `sensitive_fields`, copy
only the minimum result data needed by the contract, and test diagnostics with
representative secret-shaped values.

## Reproducible supply chain

Pin native source and transitive dependencies to immutable versions, record
checksums and licenses, and keep credentials outside build inputs. Acceptance
must be repeatable offline from reviewed, locked inputs; mutable branches,
implicit package-manager resolution, build-time downloads, and locally
discovered binaries are rejection conditions. Record the resulting artifact
hashes and sizes in the compatibility profile instead of trusting filenames.

## Editor and export boundary

Declare every artifact as editor-only or runtime. Editor tooling and debug-only
libraries must not leak into a release export; required runtime descriptors and
libraries must be selected by each export preset. Run the load, request,
cancellation, and shutdown matrix against the exported artifact on every
declared target tuple. An Adapter that works only inside the editor has not
passed runtime acceptance.

## Failure matrix

Test every row independently from the real project UI and gameplay:

| Condition | Required outcome |
| --- | --- |
| Required SDK/plugin absent | Initialization fails with a stable, redacted reason and publishes no capability. |
| Optional SDK/plugin absent | Adapter remains unregistered and publishes no partial capability. |
| Probe has side effects | Rejected; detection must not instantiate or initialize the provider. |
| Target tuple undeclared or ambiguous | Rejected before a native class or library is selected. |
| Descriptor/library missing, stale, or hash-mismatched | Rejected by packaging or preflight; no filename fallback. |
| Unsupported Godot floor or reload policy | Rejected with an explicit restart or compatibility action. |
| SDK initialized twice | One initialization completion; no duplicate callbacks. |
| Unknown contract or method | Rejected before an SDK call. |
| Invalid request/result schema | Typed failure; no malformed value escapes. |
| Concurrent same-method limit | Excess request rejected without disturbing active work. |
| User cancellation | Local terminal result first; provider cancellation requested once. |
| Timeout | Local `timed_out` result; late provider callback ignored. |
| Duplicate provider callback | First terminal result wins. |
| Worker-thread callback | Bounded plain data is pumped to the main thread before GF or Godot objects are touched. |
| Callback after shutdown begins | Callback is detached or dropped; no released owner is invoked. |
| Shutdown with pending calls | Every handle reaches one cancellation terminal state and owned workers join within budget. |
| Permission denied or prompt unavailable | Stable typed failure; no implicit elevation or headless prompt. |
| Secret-shaped request or provider error | Public result, diagnostics, and logs remain redacted. |
| Mutable or network-only build input | Acceptance fails until an immutable offline-reproducible input is supplied. |
| Editor-only artifact in runtime export | Export acceptance fails. |
| Required runtime artifact missing from export | Export acceptance fails before provider initialization. |
| Duplicate activation event | One queued intent per Adapter; duplicate is observable as dropped. |
| Borrowed MultiplayerPeer release | External peer remains open. |
| Owned MultiplayerPeer release | Backend closes the peer exactly once. |

## Project-owned policy

The project still owns matchmaking policy, lobby visibility, authority,
fallback selection, account linking, entitlement, UI, rewards, product
catalogs, credentials, telemetry consent, and content acquisition. An adapter
translates capabilities; it does not decide product behavior.
