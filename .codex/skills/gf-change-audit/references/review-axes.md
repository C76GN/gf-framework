# GF Review Axes

Use these tracks for parallel or sequential audit. Give each sub-agent only the diff, the file list, and the track-specific instructions. Avoid leaking expected findings.

## Standards

Read `AI_MAINTENANCE.md`, `CODING_STYLE.md`, and `API_SURFACE.md`. Check whether the diff violates documented GF rules, including layer direction, generated docs, API comments, GDScript layout, and release constraints. Cite the rule and file path.

## Spec / Intent

Compare the diff with the user's task, issue, PRD, or acceptance criteria. Report missing requirements, scope creep, and behavior that appears implemented incorrectly. If there is no external spec, say so and use only the conversation intent.

## API / Compatibility

Check public API additions, removals, default behavior changes, SemVer implications, `@since` values, `@schema` docs, generated API reference drift, and migration notes.

## Verification

Check whether the right commands were run for the touched files. Report missing or insufficient checks, failed commands, expected failures, and skipped checks with risk.

## Reference Boundary

Check whether external `gf-reference-project` behavior was used correctly: read-only examples by default, explicit sync for writes, no generated `addons/gf` committed as project source, and no reference-project business logic moved into GF runtime.

## Architecture

Use GF language first. Check whether new modules deepen an interface or just pass complexity around. Watch for weak seams, unnecessary adapters, hidden cross-layer dependencies, and extension-to-extension coupling.
