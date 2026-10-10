# ADR-0002: Project Layout with one GDScript profile authority

- Status: Accepted
- Date: 2026-10-10

## Context

Project Layout had separate Godot and Python Profile implementations. Python evaluated four additional rule kinds and zone filters, while the Godot tool compiled a narrower policy. This allowed the same accepted Profile to mean different things across editor and maintenance entry points. The product currently provides filesystem inventory, findings, explanations, read-only directory plans, and impact reports with incomplete dependency coverage.

The earlier Python-authority decision assumed an independently distributed analyzer that could run without Godot. The product owner has explicitly declined that requirement. Adding interpreter discovery and a second runtime to the editor would impose distribution and process costs without a required product benefit.

## Decision

GDScript is the only authority for Profile parsing, strict compilation, capture policy, and rule evaluation. One compiled policy and one owned frozen analysis session serve plan, explain, and impact. All nine existing strict rule kinds and all zone fields are implemented in this authority. The optional Authoring package includes its contract, source, and tool fixture; it does not depend on a Python rule engine.

Python maintenance commands are thin transport adapters. They resolve a supported Godot executable and supervise an isolated, trusted tool fixture. The requested project is a read-only filesystem data root. The adapter never starts the target project's editor, autoloads, scripts, plugins, or project configuration. Missing Godot is an explicit unavailable failure; there is no Python evaluator fallback. The adapter transports raw Profile text and its actual source path rather than normalizing or interpreting policy.

Profile and report schema v2 replace the previous contracts without implicit upgrades, compatibility operands, legacy/shadow modes, or a deprecated Validator facade. A project-owned capture declaration binds a portable logical container to one explicit source root and one actual capture root. Generated/disposable exclusions are literal, bounded, recorded in the digest, and rejected when they intersect protected sources. General rules describe only the included scope.

External JSON, process output, and filesystem topology are validated at their seams. Values created and owned inside a valid session are trusted rather than repeatedly decoded, compiled, and revalidated. Public detached reports still require complete closed-contract validation before consumption. The graph remains filesystem-only until a separately scoped dependency feature is proven.

Operation planning remains separate from project mutation. Automatic application is added only per operation type after reference coverage, rewrite capability, precondition revalidation, approval, and recovery are proven.

## Consequences

- Editor use needs Godot alone; repository maintenance uses Python for orchestration and Godot for actual Layout behavior.
- Pure-Python Quick validation checks static artifacts and transport contracts. Actual Profile behavior runs in the existing GUT/integration gates, with migrated coverage and no reduction in the total gate coverage.
- Native tool processes have finite deadlines, private userdata, bounded output, and identity-owned cleanup.
- Dynamic or incomplete reference coverage cannot produce a safe-to-apply verdict.
- No dependency graph expansion, Apply, automatic reorganization, or Python interpreter distribution is part of this migration.
- The Layout Profile remains project-owned policy; GF does not mandate a universal directory layout.
