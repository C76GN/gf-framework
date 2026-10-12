# GF Review Axes

Use these tracks for parallel or sequential audit. Give each sub-agent only the diff, the file list, and the track-specific instructions. Avoid leaking expected findings.

## Standards

Read `AI_MAINTENANCE.md`, `CODING_STYLE.md`, and `API_SURFACE.md`. Check whether the diff violates documented GF rules, including layer direction, generated docs, API comments, GDScript layout, and release constraints. Cite the rule and file path.

## Spec / Intent

Compare the diff with the user's task, issue, PRD, or acceptance criteria. Report missing requirements, scope creep, and behavior that appears implemented incorrectly. If there is no external spec, say so and use only the conversation intent.

## API / Compatibility

Check public API additions, removals, default behavior changes, SemVer implications, `@since` values, `@schema` docs, generated API reference drift, and migration notes.

## Product Readiness

Apply [产品化交付](../../../../AI_MAINTENANCE.md#产品化交付) to changed interfaces, configuration, UI, comments, tests, examples, documentation, generated outputs and handoff text. Judge whether a developer without the conversation can understand the capability, defaults, failure behavior and limitations. Flag temporary option labels, discussion-only phase names, labels inherited from abandoned proposals and unresolved conversational references; provide the semantic correction rather than just deleting a label. Preserve self-contained design comparisons and rationale. Do not flag legitimate standards, test data or necessary issue / PR / ADR references, rewrite frozen evidence, or expand the requested feature scope. Keyword scans are discovery aids, not proof of readiness.

## Verification

Check whether the right commands were run for the touched files. Report missing or insufficient checks, failed commands, expected failures, and skipped checks with risk.

## Example Boundary

Check that the repository-owned sample remains independently runnable, the examples suite exercises it through normal process and lifecycle gates, and project business rules stay outside GF runtime. The external Reference workflow is retired.

## Architecture

Use GF language first. Check whether new modules deepen an interface or just pass complexity around. Watch for weak seams, unnecessary adapters, hidden cross-layer dependencies, and extension-to-extension coupling.
