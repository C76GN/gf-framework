# ADR-0002: Productize Project Layout with one Python profile authority

- Status: Accepted
- Date: 2026-08-23

## Context

Project Layout currently has separate Godot and Python profile implementations, two inventory paths, filesystem-only dependency coverage, and repeated validation across internal thread hand-offs. The product is intended to grow into dependency-aware impact analysis and actionable project-reorganization plans.

## Decision

Project Layout remains a complete Authoring product. Python is the only authority for Layout Profile semantics and its implementation is distributed with the Authoring tool. This ADR does not claim that GF bundles a Python interpreter; interpreter acquisition, supported versions, update policy, and signing require a separate distribution decision. Until that decision is accepted, failure to discover a supported interpreter is an explicit unavailable state. Godot owns live Project Inventory capture, visualization, interaction, and a narrow Adapter to the Python authority; it does not implement a second profile compiler or evaluator.

One Project Dependency Graph and one Layout Analysis session serve findings, explanations, impact queries, and Operation Plans. External JSON, process output, and filesystem topology are validated at their seams. Values created and owned inside a valid session are trusted rather than repeatedly decoded and revalidated.

Operation planning remains separate from project mutation. Automatic application is added only per operation type after reference coverage, rewrite capability, precondition revalidation, approval, and recovery are proven.

## Consequences

- Python absence is an explicit unavailable state, never a silent Godot fallback.
- Dynamic or incomplete reference coverage cannot produce a safe-to-apply verdict.
- Existing shallow facades, duplicate scanners, query-specific threads, and duplicate profile semantics may be deleted as their behavior moves behind the deeper session interface.
- The Layout Profile remains project-owned policy; GF does not mandate a universal directory layout.
