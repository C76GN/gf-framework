# Contributing to GF Framework

GF uses short-lived branches and pull requests. The workflow switches after
the official `12.0.0` GitHub Release. See the
[maintainer rollout and release procedure](docs/maintainers/branch-workflow.md).

## Branch Model

- Until the `12.0.0` candidate is merged, start development from the latest
  `main` and target it in your PR.
- After publication, start regular feature, fix, and maintenance work from
  `develop` and target it in your PR. If the published stable major is `N`,
  the development target is always `(N+1).0.0-dev.K` where `K` is the
  prerelease counter.
- After the cutover, `main` carries stable releases. Open an internal `release/<version>` PR
  for major releases and a `hotfix/<version>` PR for compatible patches.
- Keep branches short-lived and focused on one reviewable outcome.
- Open a Draft PR as soon as the branch has a coherent direction.
- Rebase ordinary topic branches on their current target before merging.
- Delete the topic branch after merge.

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
hotfix/     Compatible patch from the current published tag
release/    Major release candidate
codex/      Codex-owned short-lived work
```

Use lowercase names with digits, dots, underscores, or hyphens after the
prefix, for example `fix/save-rollback` or `codex/workflow-governance`.

## Pull Request States

Draft and Ready PRs have different contracts:

- **Draft**: design and implementation may still change. CI runs the repository
  policy and the pure-Python quick maintenance suite behind the independent
  `GF draft gate`, without bootstrapping Godot or the documentation build
  environment. This gate provides early feedback but never makes a Draft PR
  mergeable.
- **Ready for review**: scope, migration impact, tests, and documentation are
  complete. CI runs every shard whose union is equivalent to the full suite;
  framework work is partitioned into `framework-gut`, `framework-lsp`,
  `framework-static`, and `framework-integration` so independent checks can
  finish concurrently. A focused Windows job also verifies native process-tree
  cleanup. These results are
  aggregated into a frozen-base `GF full validation (<BASE_SHA>)` marker before
  the merge gate.
- **Mergeable**: both required checks, `GF repository policy` and the stable
  `GF merge gate`, pass as GitHub Actions app-bound checks; the merge gate runs
  even after cancelled or skipped dependencies so those states fail closed; all review
  conversations are resolved, and the branch is current with its PR base.

Use squash merge for release and ordinary topic PRs. Rebase merge suits a
structured series whose individual commits are independently valid.
`main` requires linear history.

Editing only PR metadata such as the title or description does not cancel Full
validation already running for the same commit. It reruns repository policy and
the exact `GF merge gate`; that gate may reuse only the newest successful Full
validation epoch from the last seven days for the same repository, PR, head
commit, base commit, and target branch. A newer Full run takes precedence even while
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

Unreleased code uses a governed `X.Y.Z-dev.N` SemVer prerelease identity.
After switching, `develop` opens `13.0.0-dev.0` from the published `12.0.0`
commit. A stable patch keeps the development target. The next major release
advances the development target to the following major.

- `addons/gf/plugin.cfg` and bundled extension manifest `version` fields must
  match exactly.
- A development identity permits exactly one canonical `## [未发布]`
  changelog section and no formal release sections. A stable identity permits
  exactly one dated section for that version and no unreleased or historical
  sections; immutable tags and GitHub Releases preserve published history.
- The Changelog title and sole candidate heading form the exact top-level
  sequence. Authoring instructions belong in the
  [Changelog authoring guide](docs/maintainers/changelog-authoring.md), not in
  the public release notes. Every candidate must
  start with a readable version overview and contain at least one readable,
  non-empty top-level H3 category in the documented order. Raw HTML, mixed
  comment/visible lines, non-ASCII heading separators, and decorative-only
  bodies fail closed.
- The Changelog gate maps a governed development identity to its stable core
  for API baseline SemVer enforcement and also verifies every bundled extension
  manifest against the full framework identity.
- New public API uses `@since unreleased` until the final release version is
  selected.
- The `dev` counter changes only for an intentionally published prerelease
  snapshot; it is not a commit counter.
- A stable version string is not a release by itself. Only an immutable SemVer
  tag and its successful Release workflow publish a version.

Document migrations for changes that break the stable contract. Keep compatible
new public capabilities in the next major development line alongside those
changes.

## Verification

Run the narrowest focused tests while implementing, then use the maintenance
runner for repository gates:

```powershell
python tools\gf_maintenance.py workspace-status --json
python tools\gf_maintenance.py changelog-policy --json
python tools\gf_maintenance.py check --suite quick --failed-only
python tools\gf_maintenance.py check --suite full --json
```

Ready PRs and pushes to `main` or `develop` must pass the CI shards whose union is equivalent
to `check --suite full`, plus the focused `windows-process-supervision` job that
runs maintenance self-tests on `windows-latest`. A local full run defaults to
three concurrent workers, each in an isolated workspace; `--jobs 2` through
`--jobs 6` tune bounded parallelism, while `check --suite full --jobs 1` is the
serial diagnostic path.
Save the report with `--json-output build/full.json`. If unchanged-source checks
fail, `check-retry --from-report build/full.json` reruns only the failed or
unexecuted actions and their fresh dependencies. It preserves the original
report and does not turn historical PASS records into a new Full or CI result.
See [validation performance](docs/maintainers/validation-performance.md) for
source/environment constraints, profiling and timeout handling.
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

A release must pass the Release workflow against the archives listed in its
manifest. These include the portable framework, the Windows x64 framework with
native acceleration, the Windows x64 native supplement for an existing portable
installation, and the standalone AI Developer Kit. Validation and publication
use the same manifest and archive bytes.

## Hotfixes and Releases

- Create a compatible hotfix from the current published tag and propose the
  next patch through a PR to `main`. When both lines need the fix, open
  one PR per line and validate each against its own compatibility contract.
  Patch publication leaves the ongoing development cycle in progress.
- Promote the next major through an internal release candidate based on
  `develop`. Include the current `main` tip on that release branch and review
  stability fixes before squash-merging. Wait for Full CI on the merged
  `main` commit before tagging.
- After a major publication, open the following cycle on `develop` through
  `chore/start-<version>`. Pin its API baseline to the published tag and
  commit in `.github/repository-policy.json`.
- Correct a published problem with a forward commit and a new release.
