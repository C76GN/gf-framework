# ADR-0001: Separate Runtime and Authoring tracks

- Status: Accepted
- Date: 2026-08-23
- Amended: 2026-08-26

## Context

The original decision separated Runtime from Authoring because `gf.kernel` combined exported-game lifecycle code with editor-host responsibilities, while broad dependencies on `gf.standard.base` made internal module names describe more separation than the source ownership actually provided.

GF 11 subsequently retired the user-facing Package Manager and modular distribution. Runtime and Authoring therefore remain useful repository ownership and dependency boundaries, but they are not independently installable products.

## Decision

GF keeps two source and maintenance tracks inside one complete addon:

- Runtime owns only code required by a running or exported game.
- Authoring owns editor-host and development-time tools and may depend on Runtime.

GF releases Runtime and Authoring together in the complete `gf-framework-<version>.zip`, with the full `addons/gf` directory at its install boundary. GF does not publish runtime-only, authoring-only, kernel-only, per-module, or preset archives, and it does not provide a Package Manager. Internal module descriptors exist only for source ownership, dependency validation, tests, and maintenance tooling; they are not installation units.

Repository maintenance remains a separate, non-shipped toolchain. `gf.standard.base` is limited to mechanisms shared by multiple independent Runtime areas, while single-owner implementation returns to its owning source area. Optional bundled extensions remain present in the complete addon and are selected locally through `GF Extensions`; local enablement does not create another distribution track.

The campaign does not remove or redesign `GFRuntimeAgentEnvironment`, `GFAsyncKeyedGate`, `GFAsyncGateLease`, `GFAudioBackend`, or `GFHapticBackend`.

## Consequences

- Runtime cannot depend on editor, distribution, or maintenance paths.
- Editor and source-ownership moves require internal descriptor, smoke, and boundary-test updates.
- Install and upgrade guidance always replaces the complete `addons/gf` directory; source-track boundaries never imply selective downloads.
- No compatibility shim is required for internal GF 11 source reorganization.
- Deferred Runtime interfaces remain reviewable future investments rather than deletion targets in this campaign.

## Decision history

The 2026-08-23 version described Runtime and Authoring as separately composed product artifacts and assigned package management and distribution presets to Authoring. The 2026-08-26 amendment supersedes those distribution conclusions after GF 11 retired modular installation, while preserving the original dependency direction and source-ownership rationale.
