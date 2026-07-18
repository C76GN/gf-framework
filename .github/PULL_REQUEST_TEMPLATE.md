## Summary

<!-- State the problem and the resulting behavior. Keep the PR to one outcome. -->

## Contract and Risk

- Change type: <!-- feat / fix / refactor / perf / docs / test / build / ci / chore -->
- Consumer-visible behavior:
- API or extension contract:
- Persisted data, package, protocol, or ProjectSettings impact:
- Failure, cancellation, rollback, concurrency, and ownership impact:
- Compatibility and migration:

## Verification

<!-- List exact focused commands and outcomes. Do not claim checks that were not run. -->

- [ ] Focused tests cover the changed behavior and failure path.
- [ ] `python tools/gf_maintenance.py check --suite quick --failed-only`
- [ ] GDScript warning and LSP gates are clean when `.gd` files changed.
- [ ] Generated API or knowledge output is fresh when its source changed.
- [ ] Ready PR CI completed through `GF merge gate`.

## Documentation and Release

- [ ] Relevant guide and `[未发布]` changelog entries are updated, or the change is not user-visible.
- [ ] Development version impact is correct, or the change does not alter the intended SemVer line.
- [ ] This PR does not create a tag or publish a release.
