---
name: gf-release-flow
description: Prepare and verify GF Framework version releases, Asset Store packages, commits, and SemVer tags. Use when the user asks to determine a version, enter release flow, update release metadata, build release packages, commit, tag, push, or check a GF release.
---

# GF Release Flow

Use this skill only when the user has explicitly moved the task into release, commit, tag, or push work. During ordinary feature work, keep release notes in the current changelog area but do not finalize versions or tags.

## Rules

- Follow `AI_MAINTENANCE.md` release rules exactly.
- Use tag names without `v`, for example `4.2.0`.
- Do not commit, tag, or push unless the user explicitly asks for that action.
- If a release commit was already pushed and fixes are needed, create a new forward commit. Do not rewrite remote history unless the user explicitly requests it and accepts the risk.
- Godot Asset Store packages must come from `tools/build_asset_store_package.py`, not GitHub source archives.

## Flow

1. Determine SemVer from the actual diff: patch for compatible fixes, minor for backward-compatible public API/features, major only for approved breaking changes.
2. Verify or update release metadata:
   - `addons/gf/plugin.cfg`
   - `ASSET_LIBRARY.md`
   - `ASSET_STORE.md`
   - `docs/zh/changelog.md`
   - all built-in extension `gf_extension.json` `version` fields
3. Run the checks in [release-checks.md](references/release-checks.md).
4. Before committing, verify `git diff --check` and `git diff --cached --check` after staging.
5. Commit with the GF message template from `AI_MAINTENANCE.md`.
6. If the user requested a tag, create or move the local annotated SemVer tag only after the final release commit is at `HEAD`.
7. Push branch and tag only when requested. After pushing, verify the remote tag's peeled commit points at the intended commit.

## Reporting

Report the commit hash, tag name, whether the tag points at `HEAD`, validation commands and outcomes, Asset Store package path, and any skipped checks with reasons.
