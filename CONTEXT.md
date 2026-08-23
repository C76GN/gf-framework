# GF Framework Context

This file names the concepts used by the GF 11 architecture work. It records product meaning, not an implementation inventory.

## Product tracks

### Runtime Track

The code required while a game is running or exported. It owns framework lifecycle, composition, stable runtime mechanisms, standard runtime capabilities, and optional runtime extensions. It must not depend on editor, distribution, or repository-maintenance code.

### Authoring Track

The code used while creating and maintaining a game project. It owns the GF editor host, package-management user experience, Project Layout, import/build assistance, and other development-time tools. It may depend on the Runtime Track.

### Maintenance Toolchain

Repository-only validation, release, generation, and CI code. It verifies the product tracks but is not shipped as a runtime dependency. A product tool may have a distributable implementation plus a thin repository wrapper; the repository wrapper is not the product.

## Project Layout

### Project Inventory

A frozen observation of project files, directories, relevant Godot metadata, and capture completeness. It identifies what was observed without applying a layout policy.

### Project Dependency Graph

A graph of project resources, scripts, settings, packages, and their evidenced references. Every edge records its source, target, evidence, coverage family, and rewrite capability. Missing or dynamic evidence remains explicit.

### Layout Profile

Project-owned JSON that describes the project's chosen organization rules. It is not a universal GF directory convention.

### Layout Analysis

The findings, coverage, explanations, and reverse indexes produced from one Project Inventory, one Project Dependency Graph, and an optional Layout Profile.

### Operation Plan

An ordered, reviewable graph of proposed project changes with preconditions, evidence, risk, and manual fallbacks. Planning does not imply permission to mutate the project.

## Validation

### Validation Catalog

The single declaration of validation actions, dependencies, inputs, executors, artifacts, time budgets, reuse rules, and intent membership.

### Validation Plan

A frozen decision describing which validation actions execute or reuse evidence, why, and in which lanes they run.

### Action Evidence

The result and produced artifacts of one validation action, bound to its declared inputs, implementation, toolchain, environment, and authority.

### Validation Report

The closed result obtained by joining a Validation Plan with all required Action Evidence. Full and Release reports must prove their complete action closure.

### Authority

The trust level proven by the origin and verification of evidence. Authority is assigned by a trusted Adapter; it is never accepted from a self-declared report field.

## Deferred Runtime interfaces

`GFRuntimeAgentEnvironment`, `GFAsyncKeyedGate`, `GFAsyncGateLease`, `GFAudioBackend`, and `GFHapticBackend` remain part of GF by explicit maintainer decision. This architecture campaign must not remove or redesign them without a new decision.
