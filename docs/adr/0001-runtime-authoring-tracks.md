# ADR-0001: Separate Runtime and Authoring tracks

- Status: Accepted
- Date: 2026-08-23

## Context

The current `gf.kernel` package owns runtime lifecycle together with the editor host and package-management implementation. Most packages also depend on the large `gf.standard.base` package. As a result, package names describe more separation than installed payloads provide.

## Decision

GF 11 will publish two product tracks:

- Runtime owns only code required by a running or exported game.
- Authoring owns editor, distribution, package-management, and development-time tools and may depend on Runtime.

Repository maintenance remains a separate, non-shipped toolchain. The full GF bundle is an explicit composition of Runtime and Authoring artifacts rather than a third source tree.

`gf.standard.base` will be deepened around mechanisms shared by multiple independent Runtime packages. Single-owner implementation returns to its owning package; a full editor toolset is expressed as an explicit distribution preset.

The campaign does not remove or redesign `GFRuntimeAgentEnvironment`, `GFAsyncKeyedGate`, `GFAsyncGateLease`, `GFAudioBackend`, or `GFHapticBackend`.

## Consequences

- Runtime cannot depend on editor, distribution, or maintenance paths.
- Editor and distribution moves require package, smoke, and source-ownership updates.
- No compatibility shim is required for the GF 11 package reorganization.
- Deferred Runtime interfaces remain reviewable future investments rather than deletion targets in this campaign.
