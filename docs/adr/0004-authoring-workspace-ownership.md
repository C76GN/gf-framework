# ADR-0004: Authoring workspace ownership and defaults

- Status: Accepted
- Date: 2026-09-28

## Context

GF already has editor commands, contribution manifests, resource fields, artifact transactions, asset catalogs, and configuration pipelines. Authoring improvements need a consistent entry point without introducing competing runtimes or dependencies between independent tools.

## Decision

Keep the existing Runtime dependency direction: `kernel <- standard <- extensions`. Authoring may depend on Runtime. Do not add another runtime layer or a top-level authoring tree. The existing `gf.kernel` descriptor continues to own `kernel/editor`; it is not a separately distributed editor package.

Shared workspace navigation, context, commands, UI helpers, and personal preferences live in `kernel/editor`. New internal directories may group these responsibilities while existing paths and UIDs remain stable. Feature UI stays with its owner: Tween under `extensions/action_queue/editor`, configuration and asset workbenches under their existing `tools` modules, and project bootstrap under a new `tools/project_bootstrap` module depending only on kernel. Scene Placement remains the sole owner of placement behavior.

Tools communicate through explicit host context methods and closed, data-only contributions. Discovery does not instantiate feature scripts. Page and action identities are stable and independent of translated titles. Unavailable extensions may expose descriptions but require explicit extension selection before activation. Context revocation invalidates callbacks and pending operations. Navigation does not create Undo history; mutations use the owning command mechanism.

Presets initialize existing feature resources instead of introducing a universal inheritance framework. Preset copies belong to the project and are never silently changed by framework upgrades. Personal startup, navigation, and favorite preferences use EditorSettings project metadata. Shared project data is explicitly saved in project-owned resources. Neither preference reads nor page navigation may save `project.godot`.

Reuse existing typed fields, native Inspector properties, command sessions, artifact ownership reports and transactions. Artifact transactions retain their main-thread contract. Preview callbacks use request generations; cancellation never implies that native preview work has physically stopped. Resource actions select their receiver without automatically performing destructive or scene-placement operations.

## Consequences

- No ordinary tool-to-tool dependencies and no speculative shared tool base.
- New contribution readers preserve supported prior schema versions with separate field allowlists.
- Default workflows are short and complete; advanced fields edit the same underlying data.
- Dirty resource state, stale result state, and execution state remain distinct.
- Imported resources are not treated as ordinary writable source resources.
- Distribution remains the complete addon described by ADR-0001.
