# GF Feedback Safety And Triage

Project development can expose framework defects and reusable gaps, but most local friction is not automatically a GF issue.

## Classification boundary

- **Project issue**: game rules, local architecture, incorrect API use, custom configuration, or project-only tooling. Keep it in the project.
- **Framework bug**: reproducible GF behavior contradicts its documented or tested contract across projects.
- **Framework feature**: a provider-neutral mechanism with more than one plausible project use and a clear ownership boundary.
- **Documentation gap**: the API is sound but its contract, lifecycle, example, or failure behavior is not discoverable.
- **Adapter contract gap**: GF lacks a provider-neutral seam; provider-specific SDK code still belongs in a separate adapter.
- **Uncertain**: evidence cannot yet distinguish the boundaries. Reproduce and minimize before drafting.

## Submission state machine

`observed -> classified -> reproduced -> redacted -> drafted -> deduplicated -> approved -> submitted`

Submission is never implicit. The project contract must opt in to network submission. The user must review and approve the exact payload hash returned by `feedback-prepare`; any payload or contract change invalidates that approval. GitHub is checked for the evidence fingerprint immediately before creation. MCP intentionally cannot submit. The final `feedback-submit` command requires a human-operated interactive terminal and an exact typed confirmation.

## Data minimization

- Do not attach files automatically.
- Do not upload raw logs, project source, assets, credentials, account IDs, absolute home paths, or proprietary names.
- Prefer a minimal public reproduction over excerpts from the real project.
- Label every evidence item by kind. Source snippets and log excerpts are rejected unless the project contract explicitly opts in to that exact data class.
- Review the exact title and body before approving the hash.
