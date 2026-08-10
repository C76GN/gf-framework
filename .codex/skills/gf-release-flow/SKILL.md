---
name: gf-release-flow
description: Prepare and verify GF Framework version releases, Asset Store packages, commits, and SemVer tags. Use when the user asks to determine a version, enter release flow, update release metadata, build release packages, commit, tag, push, or check a GF release.
---

# GF Release Flow

Use this skill only when the user has explicitly moved the task into release, commit, tag, or push work. During ordinary feature work, keep release notes in the current changelog area but do not finalize versions or tags.

## Rules

- Follow `AI_MAINTENANCE.md` release rules exactly.
- Use tag names without `v`, for example `4.2.0`.
- For an ordinary release, finalize the stable version on the already reviewed short-lived internal branch and merge that release commit to `main`; do not create a `release/<version>` branch merely to change version metadata. Use `release/<version>` only for a real stabilization freeze. Use `hotfix/<version>` only for an urgent fix created from the affected immutable stable tag, then merge the verified fix forward through a PR.
- Do not commit, tag, or push unless the user explicitly asks for that action.
- If a release commit was already pushed and fixes are needed, create a new forward commit. Do not rewrite remote history unless the user explicitly requests it and accepts the risk.
- Release packages must come from one `tools/build_gf_release_artifacts.py` invocation and its SHA-256 manifest, not GitHub source archives or independently rebuilt outputs.
- Treat compatibility and validation risk as separate axes. A high-risk compatible fix can remain a patch but still requires full release checks; frequent releases or a large diff do not justify a major bump.
- Treat immutable Git tags and GitHub Releases as the released changelog history. The working-tree `docs/zh/changelog.md` is a current-release document, not a second historical archive; never relabel an older release as the target release or rewrite published tags.

## Flow

1. Determine SemVer from the consumer contract, including APIs, ProjectSettings, package/extension schemas, persisted data, protocols, platform support, defaults, errors, ordering, and lifecycle behavior: patch for compatible fixes without new public capability, minor for backward-compatible public API/features, major only for approved migration-requiring changes.
2. Run `python tools/gf_maintenance.py api-baseline-diff --version <version> --enforce-version --json` before finalizing metadata. Patch releases must fail when compatible public classes, members, or signature expansions were added; minor/patch releases must fail on breaking API changes unless the explicit breaking-release procedure applies.
3. Replace the development identity with the final stable SemVer and verify or update release metadata:
   - `addons/gf/plugin.cfg`
   - `ASSET_LIBRARY.md`
   - `ASSET_STORE.md`
   - `docs/zh/changelog.md`
   - all built-in extension `gf_extension.json` `version` fields
   Keep only the target formal section in `docs/zh/changelog.md`. Remove every older formal section from the working tree; released history remains available from immutable Git tags and GitHub Releases. `release-status` rejects stale, duplicate, unsupported, or unreleased sections.
4. Run the checks in [release-checks.md](references/release-checks.md).
5. Before committing, verify `git diff --check` and `git diff --cached --check` after staging.
6. Commit with the GF message template from `AI_MAINTENANCE.md`.
7. If the user requested a tag, create or move the local annotated SemVer tag only after the final release commit is at `HEAD`.
8. Push branch and tag only when requested. After pushing, verify the remote tag's peeled commit points at the intended commit.
9. Do not create an automatic post-release development commit. The first explicitly requested post-release change selects the next intended line and updates `plugin.cfg` plus bundled extension manifest versions to `X.Y.Z-dev.0` in its own PR.

## Reporting

Report the commit hash, tag name, whether the tag points at `HEAD`, validation commands and outcomes, immutable artifact manifest path, Asset Store package path, and any skipped checks with reasons.
