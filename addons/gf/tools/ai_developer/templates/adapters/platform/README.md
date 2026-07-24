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

## Failure matrix

Test every row independently from the real project UI and gameplay:

| Condition | Required outcome |
| --- | --- |
| SDK/plugin absent | Initialization fails with a stable, redacted reason. |
| SDK initialized twice | One initialization completion; no duplicate callbacks. |
| Unknown contract or method | Rejected before an SDK call. |
| Invalid request/result schema | Typed failure; no malformed value escapes. |
| Concurrent same-method limit | Excess request rejected without disturbing active work. |
| User cancellation | Local terminal result first; provider cancellation requested once. |
| Timeout | Local `timed_out` result; late provider callback ignored. |
| Duplicate provider callback | First terminal result wins. |
| Shutdown with pending calls | Every handle reaches one cancellation terminal state. |
| Duplicate activation event | One queued intent per Adapter; duplicate is observable as dropped. |
| Borrowed MultiplayerPeer release | External peer remains open. |
| Owned MultiplayerPeer release | Backend closes the peer exactly once. |

## Project-owned policy

The project still owns matchmaking policy, lobby visibility, authority,
fallback selection, account linking, entitlement, UI, rewards, product
catalogs, credentials, telemetry consent, and content acquisition. An adapter
translates capabilities; it does not decide product behavior.
