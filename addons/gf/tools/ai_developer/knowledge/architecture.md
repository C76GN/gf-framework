# GF Project Architecture Boundaries

GF exists to provide stable mechanisms. A game project owns product rules, content semantics, provider choices, and deployment policy.

## Decision order

1. Start from the project's declared responsibility and non-functional constraints.
2. Reuse a GF capability only when its contract owns the mechanism.
3. Put provider-specific calls behind a project-owned or separately distributed adapter.
4. Keep business policy in project modules even when GF supplies the data structure or lifecycle host.
5. Add a new boundary only when it gives ownership, replaceability, testability, or failure isolation.

## GF architecture roles

- `GFModel`: authoritative project state and snapshots. It should not own rendering or platform SDK calls.
- `GFSystem`: project behavior that coordinates models and services. It should not become a global utility bag.
- `GFUtility`: reusable service with explicit lifecycle, side effects, and ownership. Pure algorithms do not need to be utilities.
- `GFController`: scene-facing bridge between nodes/UI and architecture. It should remain thin and disposable with the scene.
- `GFInstaller`: composition root. It selects implementations and adapters; it does not contain gameplay flow.
- GF extensions and standard packages: optional mechanisms selected by package and capability, never business feature folders.

## Adapter rule

An adapter translates a provider API into a provider-neutral project or GF protocol. Steam, WeChat, Epic, console, cloud storage, analytics, ads, payment, and proprietary backends stay outside `addons/gf` unless GF publishes a separate provider package.

The adapter owns initialization, availability checks, callback-to-async conversion, error normalization, identity translation, and provider cleanup. The project owns UI, rewards, matchmaking policy, product catalog, social rules, and fallback decisions.

## Hard boundaries

- Never edit vendored `addons/gf` to implement a game feature.
- Never infer determinism, authority, persistence compatibility, trust, or performance requirements from current code alone.
- Never treat a sample project layout as a framework requirement.
- Never call a provider SDK from domain models or portable systems.
- Never keep an async operation without an owner, terminal state, cancellation path, and failure observation.
- Never let generated artifacts become the only record of human intent.
