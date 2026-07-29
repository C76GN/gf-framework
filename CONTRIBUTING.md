# Contributing to GF Framework

GF uses a trunk-based workflow with short-lived branches. The `main` branch is
the next releasable state of the framework, while immutable SemVer tags and
GitHub Releases identify published versions.

## Branch Model

- Start every change from the latest `main`.
- Do not push development commits directly to `main`.
- Keep branches short-lived and focused on one reviewable outcome.
- Open a Draft PR as soon as the branch has a coherent direction.
- Rebase on `main` before merge. Do not merge `main` into the topic branch.
- Delete the topic branch after merge.
- Do not maintain a long-lived `develop` or integration branch.

Internal branches must use one of these prefixes:

```text
feat/       New consumer-facing capability
fix/        Compatible bug fix
refactor/   Internal restructuring without an intended behavior change
perf/       Measured performance improvement
docs/       Documentation-only change
test/       Test-only change
build/      Build or packaging change
ci/         CI or repository-governance change
chore/      Narrow maintenance change
hotfix/     Urgent fix based on a published tag
release/    Temporary release stabilization, only when a freeze is required
codex/      Codex-owned short-lived work
```

Use lowercase names with digits, dots, underscores, or hyphens after the
prefix, for example `fix/package-rollback` or `codex/workflow-governance`.

## Pull Request States

Draft and Ready PRs have different contracts:

- **Draft**: design and implementation may still change. CI runs the repository
  policy and the pure-Python quick maintenance suite behind the independent
  `GF draft gate`, without bootstrapping Godot or the documentation build
  environment. This gate provides early feedback but never makes a Draft PR
  mergeable.
- **Ready for review**: scope, migration impact, tests, and documentation are
  complete. CI runs every shard whose union is equivalent to the full suite;
  framework work is partitioned into `framework-gut`, `framework-lsp`, and
  `framework-static` so independent checks can finish concurrently. A focused
  Windows job also verifies native process-tree cleanup. These results are
  aggregated into a frozen-base `GF full validation (<BASE_SHA>)` marker before
  the merge gate.
- **Mergeable**: both required checks, `GF repository policy` and the stable
  `GF merge gate`, pass as GitHub Actions app-bound checks; the merge gate runs
  even after cancelled or skipped dependencies so those states fail closed; all review
  conversations are resolved, and the branch is current with `main`.

Use squash merge for a normal single-outcome PR. Rebase merge is reserved for a
deliberately structured commit series whose individual commits are independently
valid. Merge commits are not part of the repository history.

Editing only PR metadata such as the title or description does not cancel Full
validation already running for the same commit. It reruns repository policy and
the exact `GF merge gate`; that gate may reuse only the newest successful Full
validation epoch for the same repository, PR, head commit, and base commit from
the last seven days. A newer Full run takes precedence immediately, even while
its aggregate marker is still pending. Missing, stale, failed, malformed, or
unverifiable evidence fails closed. A base branch change is not metadata-only:
it reruns the Draft or Ready gate applicable to the PR's current state.

Manual diagnostics run only through the separate `CI manual diagnostics`
workflow and always use `GF manual ...` check names. A non-`main` manual run
checks repository policy only; a `main` manual run also performs Full and
Windows diagnostics. Manual runs never emit the protected `GF merge gate` and
cannot be used as merge evidence; use a Ready PR for that purpose.

## Change Contract

Every PR must make these points reviewable:

1. The problem or capability being addressed.
2. The consumer-visible behavior before and after the change.
3. The affected API, persisted data, package, extension, editor, and lifecycle
   contracts, including explicit confirmation when an axis is unaffected.
4. Failure, cancellation, rollback, concurrency, and resource-ownership
   behavior where applicable.
5. Focused verification and any check that could not be run.

Do not preserve a weak design only because existing code already depends on it.
When compatibility is intentionally broken, document the migration and select
the corresponding SemVer impact instead of adding a permanent compatibility
branch.

## Required Repository Updates

- Runtime or editor behavior changes require focused tests.
- Public API changes require complete API Surface annotations and regenerated
  API reference output.
- Any change to an existing free-text public `@schema` contract is a breaking
  API change, including appending, rewriting, reordering, or removing text. The
  API baseline gate fails closed because it cannot prove those edits compatible
  and requires the corresponding major development line. Only adding a schema
  where the stable baseline had none is classified as compatible.
- User-visible changes require the relevant guide and the `[未发布]` changelog
  section to be updated.
- Package, extension, persisted-data, protocol, or ProjectSettings changes must
  state compatibility and migration behavior explicitly.
- Generated files must be produced by their owning generator and checked for
  freshness; do not edit generated output by hand.
- Temporary reports, local logs, caches, and `ai_analysis/` content do not belong
  in a PR.

## Development Version

The source tree between stable releases uses a governed `X.Y.Z-dev.N` SemVer
prerelease identity, such as `9.0.0-dev.0`. This prevents unreleased `main` code
from presenting itself as the last published release.

- `addons/gf/plugin.cfg` and bundled extension manifest `version` fields must
  match exactly.
- A development identity permits exactly one canonical `## [未发布]`
  changelog section and no formal release sections. A stable identity permits
  exactly one dated section for that version and no unreleased or historical
  sections; immutable tags and GitHub Releases preserve published history.
- The Changelog title, structure-standard heading, maintenance-policy heading,
  and sole candidate heading form one exact top-level sequence. Its numbered
  structure must match the executable category constants. Every candidate must
  start with a readable version overview and contain at least one readable,
  non-empty top-level H3 category in the documented order. Raw HTML, mixed
  comment/visible lines, non-ASCII heading separators, and decorative-only
  bodies fail closed.
- The Changelog gate maps a governed development identity to its stable core
  for API baseline SemVer enforcement and also verifies every bundled extension
  manifest against the full framework identity.
- Package manifest versions remain `unreleased` until the release transaction.
- New public API uses `@since unreleased` until the final release version is
  selected.
- The `dev` counter changes only for an intentionally published prerelease
  snapshot; it is not a commit counter.
- A stable version string is not a release by itself. Only an immutable SemVer
  tag and its successful Release workflow publish a version.

When a change alters the required SemVer line, update the development identity
in the same PR. Compatible public additions require at least a minor version;
approved migration-requiring changes require a major version.

## Verification

Run the narrowest focused tests while implementing, then use the maintenance
runner for repository gates:

```powershell
python tools\gf_maintenance.py workspace-status --json
python tools\gf_maintenance.py changelog-policy --json
python tools\gf_maintenance.py check --suite quick --failed-only
python tools\gf_maintenance.py check --suite full --json
```

Ready PRs and pushes to `main` must pass the CI shards whose union is equivalent
to `check --suite full`, plus the focused `windows-process-supervision` job that
runs maintenance self-tests on `windows-latest`. A local full run defaults to
three concurrent workers, each in an isolated workspace; `--jobs 2` through
`--jobs 6` tune bounded parallelism, while `check --suite full --jobs 1` is the
serial diagnostic path.
Workers are prepared and cleaned in bounded batches, and a real Godot preflight
proves that every platform data/config/cache path and `user://` stays private.
On Windows, the runner also proves that its clone, staging, and private temporary
roots fit the conservative local path budget. If automatic short-root selection
is unavailable, `GF_MAINTENANCE_VALIDATION_TEMP_ROOT` may name an existing short
local parent directory. The runner validates that parent, creates a random
identity-pinned child below it, and rejects source-owned, linked, UNC, and device
paths, mapped network drives, and substituted drive aliases. Untracked regular
files are read through stable handles in deadline-aware chunks, capped at 64 MiB
per file and 256 MiB in total. Every worker is held in an owned process group or
Windows Job Object that is emptied before its report is accepted.
The full suite always treats LSP
errors, warnings, diagnostic timeouts, connection failures, and transport
failures as hard failures.

Within one suite invocation, package smoke checks reuse one sealed package
artifact set. The runner verifies its hashes and source-workspace fingerprint,
then gives every consumer a private copy and requires its report to match the
same manifest digest and artifact count. Tree scans, hashing, copying, and final
revalidation obey the suite's absolute deadline. It does not reuse package
artifacts across revisions, and consumers must not mutate the shared bytes. A
release is a separate operation and must pass the Release workflow against one
immutable release artifact set.

## Hotfixes and Releases

- Create a hotfix branch from the affected immutable tag, not from an arbitrary
  historical working tree.
- Merge the verified hotfix back through a PR and publish a patch tag from the
  resulting release commit.
- Use a temporary `release/` branch only when a real stabilization freeze is
  needed. Delete it after the release.
- Do not rewrite published tags or release assets. Correct a published problem
  with a forward commit and a new SemVer version.
