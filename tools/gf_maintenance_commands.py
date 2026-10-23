"""Data-only descriptions of the uniform, read-only maintenance commands.

Descriptions own spelling, help, and the JSON invocation. They grant no execution
authority: the runner still binds trusted callables, while the Validation Catalog
independently owns check admission, suites, dependencies, and executor kinds.
Commands with options or different exit semantics retain explicit adapters.
"""

from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType


@dataclass(frozen=True)
class CommandDescriptor:
	action_id: str
	help: str

	@property
	def name(self) -> str:
		return self.action_id.replace("_", "-")

	def arguments(self, *, json_output: bool = False) -> tuple[str, ...]:
		return (self.name, "--json") if json_output else (self.name,)


COMMANDS = (
	CommandDescriptor("path_hygiene", "Check tracked and untracked repository paths for cross-platform hazards."),
	CommandDescriptor("diagnostic_policy", "Check framework diagnostic templates and reviewed forwarding boundaries."),
	CommandDescriptor("gdscript_readability", "Enforce readable GDScript layout across owned sources and templates."),
	CommandDescriptor("codeql_suppression_policy", "Reject CodeQL suppressions and configuration escape hatches."),
	CommandDescriptor("api_since_touched", "Check changed public/protected API documentation blocks for @since tags."),
	CommandDescriptor("dependency_boundary", "Check GF layer, extension manifest, and bundled extension dependency boundaries."),
	CommandDescriptor("changelog_policy", "Check that the current changelog matches the framework development or stable version state."),
	CommandDescriptor("public_docs_boundary", "Check public docs for internal planning leaks and optional-extension boundary claims."),
	CommandDescriptor("public_api_boundary", "Check public API source and generated references for planning-route names."),
	CommandDescriptor("project_profile_artifacts", "Check native Layout artifacts without launching Godot."),
	CommandDescriptor("package_boundary", "Check internal GF module descriptors for schema, path ownership, and dependency graph violations."),
	CommandDescriptor("package_closure_audit", "Report internal GF module dependency closures, standard fan-in, and oversized extension dependency risk."),
	CommandDescriptor("package_source_boundary", "Check GF module-owned source files for undeclared module path and class references."),
	CommandDescriptor("core_only_smoke", "Check that the root plugin entry does not require standard modules at parse time."),
	CommandDescriptor("package_focused_gut_mapping", "Validate the module-to-focused-GUT coverage mapping used by maintenance gates."),
	CommandDescriptor("maintenance_self_test", "Check maintenance execution and workflow contracts."),
	CommandDescriptor("project_settings_drift", "Check project.godot for unintended local changes."),
)
BY_ACTION = MappingProxyType({command.action_id: command for command in COMMANDS})
BY_NAME = MappingProxyType({command.name: command for command in COMMANDS})
if len(BY_ACTION) != len(COMMANDS) or len(BY_NAME) != len(COMMANDS):
	raise ValueError("Maintenance command identities must be unique.")
