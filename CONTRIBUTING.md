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
  policy and the pure-Python quick maintenance suite for early feedback without
  bootstrapping Godot or the documentation build environment.
- **Ready for review**: scope, migration impact, tests, and documentation are
  complete. CI runs every shard whose union is equivalent to the full suite.
- **Mergeable**: the stable `GF merge gate` check passes, all review
  conversations are resolved, and the branch is current with `main`.

Use squash merge for a normal single-outcome PR. Rebase merge is reserved for a
deliberately structured commit series whose individual commits are independently
valid. Merge commits are not part of the repository history.

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
python tools\gf_maintenance.py check --suite quick --failed-only
```

Ready PRs and pushes to `main` must pass the CI shards whose union is equivalent
to `check --suite full`. GDScript changes must also remain clean under the
warning and LSP diagnostics gates. A release is a separate operation and must
pass the Release workflow against one immutable artifact set.

## Hotfixes and Releases

- Create a hotfix branch from the affected immutable tag, not from an arbitrary
  historical working tree.
- Merge the verified hotfix back through a PR and publish a patch tag from the
  resulting release commit.
- Use a temporary `release/` branch only when a real stabilization freeze is
  needed. Delete it after the release.
- Do not rewrite published tags or release assets. Correct a published problem
  with a forward commit and a new SemVer version.
