# GF Project Contract Migration

Contract migrations change declared project intent and are never inferred from a generated snapshot. The current kit accepts only its current contract schema for normal context and validation.

## Protocol

1. Request `gf_contract_migration_plan`, or run:

   ```powershell
   python <gf-ai-cli> contract-migration-plan --project-root .
   ```

2. Review `plan_sha256`, source and target hashes, every change, the complete candidate, warnings, owner defaults, selected Recipes, acceptance conditions, package policy, and remaining unknowns.
3. Apply only the reviewed plan hash from a human-operated interactive terminal:

   ```powershell
   python <gf-ai-cli> contract-migrate --project-root . --expected-plan-sha256 <plan-sha256>
   ```

4. Validate the migrated contract and regenerate the project snapshot.

The CLI prints the complete candidate and requires the exact phrase `MIGRATE <plan-sha256>`. MCP exposes the read-only plan only. The plan hash binds the tool version, migration id, contract path, canonical source, and canonical target. Application uses compare-and-swap under an exclusive lock and fails if any bound input changes, a linked/reparsed path is encountered, or the reviewed target cannot be reproduced. Unsupported versions, invalid legacy fields, unknown capabilities, missing provider package declarations, invalid owners, and Recipe mismatches block the write. The tool never maintains two live contract formats and never inserts inferred business acceptance conditions.

The v1-to-v2 migration converts each legacy required capability into one owner-bound requirement with `decision_state: pending_review`, `owner: project`, and empty Recipe, acceptance, and notes fields. Snapshot drift remains blocked until a human chooses a valid owner and advertised Recipe, writes project-owned acceptance conditions, and changes the state to `confirmed`.

The v2-to-v3 step initializes the closed `architecture.path_roles` array. The v3-to-v4 step initializes only `architecture.source_domains: []`; v1 and v2 sources chain through both steps. A legacy v1/v2 source that predeclares `path_roles`, or any v1/v2/v3 source that predeclares `source_domains`, is invalid and must not be preserved with `.get()` defaults. The migration plan warns that unmatched scripts now default fail-safe to `runtime` and that legacy test-directory or `test_` filename heuristics are no longer authoritative. Before relying on snapshot evidence, explicitly declare the real test, tool, and editor roots, including nested runtime resets where needed.

Project snapshots are generated evidence. Snapshot v7 replaces the old source-domain heuristic with authoritative contract roots and adds the closed API package-policy analysis. Do not migrate an old snapshot or copy fields forward. Delete or overwrite it by running the current `snapshot` command after the contract and installed GF version are valid.
