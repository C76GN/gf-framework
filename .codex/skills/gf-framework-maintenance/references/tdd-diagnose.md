# GF TDD and Diagnosis Loop

Use this for bug fixes and behavior changes.

## Loop

1. Define one observable behavior that is wrong or missing.
2. Add one focused test through a public or documented GF interface.
3. Confirm the test fails for the expected reason when practical.
4. Implement the smallest framework change that fixes that behavior.
5. Run the focused test, then the relevant maintenance suite.
6. Refactor only after the test is green.

## Test Rules

- Prefer `tests/gf_core/**` for GF behavior and `tests/gf_core/maintenance/**` for enforceable maintenance rules.
- Do not test private helpers unless the helper is already a documented internal contract.
- Keep tests deterministic: seed randomness, avoid sleeps, use frame stepping or GUT helpers for async behavior.
- Clean up nodes, threads, signals, resources, and global state.
- Expected errors and warnings must be asserted explicitly.

## Debug Rules

- Temporary debug output must have a unique prefix and be removed before final checks.
- Runtime validation should use visible errors or result objects; do not rely only on `assert()` for release behavior.
- If a bug cannot be locked down because the public interface is too shallow or fragmented, report the interface problem as an architecture finding.
