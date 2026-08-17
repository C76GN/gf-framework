#!/usr/bin/env python3
"""Focused behavioral tests for GF maintenance generators and docs tooling."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import check_docs_quality
import generate_ai_api
import generate_api_coverage_matrix
import generate_api_reference
import generated_output_transaction
import gdscript_api_parser
import gf_api_owners
import gf_maintenance
import sync_reference_project


def api_docs(visibility: str, description: str = "") -> gdscript_api_parser.ApiDocs:
	return gdscript_api_parser.ApiDocs(
		description=[description] if description else [],
		tags={"api": [visibility]} if visibility else {},
	)


class GdscriptDeclarationParsingTests(unittest.TestCase):
	def test_explicit_autoload_owner_docs_bind_to_classless_script(self) -> None:
		parsed = gdscript_api_parser.parse_gdscript_source(
			'''## Global entry point.
## @api public
## @api_owner autoload Gf
## @since 1.0.0
extends Node

## Runs the entry point.
## @api public
func run() -> void:
	pass
''',
			"addons/gf/kernel/core/gf.gd",
			"kernel",
		)
		self.assertEqual(parsed.api_owner_kind, "autoload")
		self.assertEqual(parsed.api_owner_name, "Gf")
		self.assertEqual(parsed.docs.description, ["Global entry point."])
		self.assertEqual(parsed.docs.tags["since"], ["1.0.0"])
		self.assertEqual([member.name for member in parsed.methods], ["run"])
		self.assertIsNone(parsed.to_api_class())

	def test_explicit_owner_rejects_invalid_shape_and_class_name_conflict(self) -> None:
		with self.assertRaisesRegex(ValueError, "<kind> <name>"):
			gdscript_api_parser.parse_gdscript_source(
				"## @api_owner autoload\nextends Node\n",
				"addons/gf/broken.gd",
			)
		with self.assertRaisesRegex(ValueError, "both class_name and @api_owner"):
			gdscript_api_parser.parse_gdscript_source(
				"## @api_owner autoload Gf\nextends Node\nclass_name Broken\n",
				"addons/gf/broken.gd",
			)
		with self.assertRaisesRegex(ValueError, "both class_name and @api_owner"):
			gdscript_api_parser.parse_gdscript_source(
				"## @api_owner autoload Gf\nclass_name Broken\nextends Node\n",
				"addons/gf/broken.gd",
			)
		with self.assertRaisesRegex(ValueError, "<kind> <name>"):
			gdscript_api_parser.parse_gdscript_source(
				"## @api_owner spaceship\nclass_name Broken\nextends Node\n",
				"addons/gf/broken.gd",
			)

	def test_multiline_signals_are_collected_without_string_or_comment_parentheses(self) -> None:
		source = '''
## Public surface.
## @api public
class_name ParserFixture

# A comment containing a fake triple delimiter: """
## Emitted after parsing.
## @api public
signal parsed(
	value: String = ")",
	count: int = 1 # This comment must not close the declaration: )
)

class Inner:
	## Inner signal.
	## @api public
	signal changed(
		message: String = "(",
		ok: bool = true
	)
'''
		parsed = gdscript_api_parser.parse_gdscript_source(
			source,
			"addons/gf/parser_fixture.gd",
		)
		self.assertEqual([item.name for item in parsed.signals], ["parsed"])
		self.assertEqual(
			parsed.signals[0].signature,
			'signal parsed( value: String = ")", count: int = 1 )',
		)
		self.assertEqual(len(parsed.inner_classes), 1)
		self.assertEqual(parsed.inner_classes[0].signals[0].name, "changed")
		self.assertTrue(parsed.inner_classes[0].signals[0].signature.endswith(" )"))

	def test_multiline_string_contents_never_become_api_declarations(self) -> None:
		source = '''
## Public surface.
## @api public
class_name ParserFixture

const EXAMPLE = """
## @api public
signal fake(value: int)
"""

## Real signal.
## @api public
signal real(value: int)
'''
		parsed = gdscript_api_parser.parse_gdscript_source(
			source,
			"addons/gf/parser_fixture.gd",
		)
		self.assertEqual([item.name for item in parsed.signals], ["real"])

	def test_unclosed_callable_declaration_fails_closed(self) -> None:
		with self.assertRaisesRegex(ValueError, "Unclosed signal declaration"):
			gdscript_api_parser.parse_gdscript_source(
				"class_name Broken\nsignal broken(\n\tvalue: int\n",
				"addons/gf/broken.gd",
			)

	def test_multiline_data_declarations_ignore_literal_and_comment_delimiters(self) -> None:
		source = '''
## Public surface.
## @api public
class_name DataDeclarationFixture

## Public defaults.
## @api public
const DEFAULTS: Array[String] = [
	"]",
	"```",
	"# not a comment",
]

## Public exported values.
## @api public
@export var values: PackedInt32Array = PackedInt32Array([
	1, # This comment must not close the declaration: ])
	2,
])

## Public enum.
## @api public
enum Mode {
	FIRST = 0, # This comment must not close the declaration: }
	SECOND = 1,
}

## Declaration after every multiline form.
## @api public
func next_value() -> int:
	return 2

## Public inner fixture.
## @api public
class Inner:
	## Inner defaults.
	## @api public
	const INNER_DEFAULTS: Array[int] = [
		1,
		2,
	]
'''
		parsed = gdscript_api_parser.parse_gdscript_source(
			source,
			"addons/gf/data_declaration_fixture.gd",
		)
		self.assertEqual([item.name for item in parsed.constants], ["DEFAULTS"])
		self.assertIn('"```"', parsed.constants[0].signature)
		self.assertTrue(parsed.constants[0].signature.rstrip().endswith("]"))
		self.assertEqual([item.name for item in parsed.properties], ["values"])
		self.assertIn("2,", parsed.properties[0].signature)
		self.assertTrue(parsed.properties[0].signature.rstrip().endswith("])"))
		self.assertEqual([item.name for item in parsed.enums], ["Mode"])
		self.assertIn("SECOND = 1", parsed.enums[0].signature)
		self.assertTrue(parsed.enums[0].signature.rstrip().endswith("}"))
		self.assertEqual([item.name for item in parsed.methods], ["next_value"])
		self.assertEqual(len(parsed.inner_classes), 1)
		self.assertIn("2,", parsed.inner_classes[0].constants[0].signature)
		self.assertTrue(parsed.inner_classes[0].constants[0].signature.rstrip().endswith("]"))
		api_class = parsed.to_api_class()
		self.assertIsNotNone(api_class)
		catalog_xml = generate_api_reference.render_class_xml(api_class)
		reference_markdown = generate_api_reference.render_reference_class_page(api_class)
		self.assertIn(parsed.constants[0].signature, catalog_xml)
		self.assertIn(parsed.properties[0].signature, catalog_xml)
		self.assertIn(parsed.enums[0].signature, reference_markdown)

	def test_unclosed_data_declaration_fails_closed(self) -> None:
		with self.assertRaisesRegex(ValueError, "Unclosed const declaration"):
			gdscript_api_parser.parse_gdscript_source(
				"class_name Broken\nconst VALUES: Array[int] = [\n\t1,\n",
				"addons/gf/broken_data.gd",
			)

	def test_property_signatures_preserve_empty_string_literals(self) -> None:
		source = '''
## Public surface.
## @api public
class_name EmptyStringFixture

## Empty String default.
## @api public
var text: String = ""

## Empty StringName default.
## @api public
var identifier: StringName = &""

## Non-empty String default.
## @api public
var label: String = "BTNode"

## Non-empty StringName default.
## @api public
var preset: StringName = &"overlay"

## NodePath default.
## @api public
var target_path: NodePath = ^"Root/Child"

## String container default.
## @api public
var extensions: PackedStringArray = PackedStringArray(["tres", "res"])

## Literal hash default.
## @api public
var fragment: String = "#value" # The trailing comment is not part of the signature.

## Public inner fixture.
## @api public
class Inner:
	## Empty inner StringName default.
	## @api public
	var identifier: StringName = &""
'''
		parsed = gdscript_api_parser.parse_gdscript_source(
			source,
			"addons/gf/empty_string_fixture.gd",
		)
		self.assertEqual(
			[item.signature for item in parsed.properties],
			[
				'var text: String = ""',
				'var identifier: StringName = &""',
				'var label: String = "BTNode"',
				'var preset: StringName = &"overlay"',
				'var target_path: NodePath = ^"Root/Child"',
				'var extensions: PackedStringArray = PackedStringArray(["tres", "res"])',
				'var fragment: String = "#value"',
			],
		)
		self.assertEqual(len(parsed.inner_classes), 1)
		self.assertEqual(
			parsed.inner_classes[0].properties[0].signature,
			'var identifier: StringName = &""',
		)


class GeneratedTreeBoundaryTests(unittest.TestCase):
	def test_nonportable_or_escaping_keys_are_rejected_before_root_creation(self) -> None:
		invalid_keys = (
			"C:drive-relative.txt",
			"/rooted.txt",
			"\\rooted.txt",
			"folder\\child.txt",
			"folder//child.txt",
			"CON.txt",
			"trailing./child.txt",
			"control\x01.txt",
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			for index, key in enumerate(invalid_keys):
				root = parent / f"output-{index}"
				with self.subTest(key=key):
					with self.assertRaises(ValueError):
						generated_output_transaction.replace_generated_trees(
							[(root, {key: "payload"})]
						)
					self.assertFalse(root.exists())

	def test_casefold_and_unicode_normalization_collisions_are_rejected(self) -> None:
		collisions = (
			{"Folder/API.md": "a", "folder/api.MD": "b"},
			{"café.md": "a", "cafe\u0301.md": "b"},
			{"Folder/first.md": "a", "folder/second.md": "b"},
			{"café/first.md": "a", "cafe\u0301/second.md": "b"},
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			for index, files in enumerate(collisions):
				root = parent / f"collision-{index}"
				with self.subTest(files=files):
					with self.assertRaisesRegex(ValueError, "portable path collision"):
						generated_output_transaction.replace_generated_trees([(root, files)])
					self.assertFalse(root.exists())

	def test_shared_tree_comparator_reports_missing_stale_and_extra(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "stale.txt").write_text("old", encoding="utf-8")
			(root / "extra.txt").write_text("extra", encoding="utf-8")
			mismatches = generated_output_transaction.compare_generated_tree(
				root,
				{"stale.txt": "new", "missing.txt": "new"},
			)
			self.assertEqual(
				mismatches,
				["missing: missing.txt", "stale: stale.txt", "extra: extra.txt"],
			)

	def test_transaction_preserves_binary_payload_bytes(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "binary-output"
			payload = b"\x00GF\xff\r\n"
			generated_output_transaction.replace_generated_trees(
				[(root, {"empty": None, "nested/payload.bin": payload})]
			)
			self.assertEqual((root / "nested/payload.bin").read_bytes(), payload)
			self.assertTrue((root / "empty").is_dir())

	def test_file_cannot_be_a_portable_ancestor_of_another_entry(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "ancestor-conflict"
			with self.assertRaisesRegex(ValueError, "ancestor directory"):
				generated_output_transaction.replace_generated_trees(
					[(root, {"Folder": b"file", "Folder/child.txt": b"child"})]
				)
			self.assertFalse(root.exists())


class ReferenceProjectSyncTests(unittest.TestCase):
	def capture_manifest(
		self,
		source: Path,
		limits: sync_reference_project.SyncLimits = sync_reference_project.DEFAULT_LIMITS,
	) -> sync_reference_project.ReferencePayloadManifest:
		return sync_reference_project.capture_payload_manifest(source, limits)

	def test_copy_sync_replaces_the_target_as_one_binary_exact_tree(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			target = fixture_root / "project/addons/gf"
			source.mkdir()
			target.mkdir(parents=True)
			(source / "payload.bin").write_bytes(b"\x00new\xff")
			(source / "empty").mkdir()
			(target / "stale.txt").write_text("stale", encoding="utf-8")
			manifest = self.capture_manifest(source)

			plan = sync_reference_project.sync_addon(
				manifest,
				source,
				target,
				"copy",
				apply=False,
			)
			self.assertEqual(plan.planned_actions, ["replace_copy_tree"])
			self.assertEqual(plan.applied_actions, [])
			self.assertTrue((target / "stale.txt").is_file())

			stats = sync_reference_project.sync_addon(
				manifest,
				source,
				target,
				"copy",
				apply=True,
			)

			self.assertEqual((target / "payload.bin").read_bytes(), b"\x00new\xff")
			self.assertTrue((target / "empty").is_dir())
			self.assertFalse((target / "stale.txt").exists())
			self.assertEqual(stats.manifest.file_count, 1)
			self.assertEqual(stats.manifest.total_bytes, 5)
			self.assertEqual(stats.applied_actions, ["replace_copy_tree"])

			check = sync_reference_project.check_addon(manifest, source, target)
			self.assertEqual(check.mismatch_count, 0)
			self.assertEqual(check.target_mode, "copy")
			(target / "extra-empty").mkdir()
			check = sync_reference_project.check_addon(manifest, source, target)
			self.assertIn("extra entry: extra-empty", check.mismatches)

	def test_copy_sync_preserves_an_unreplaceable_existing_target(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			target = fixture_root / "project/addons/gf"
			source.mkdir()
			target.parent.mkdir(parents=True)
			(source / "payload.txt").write_text("new", encoding="utf-8")
			target.write_text("user-owned", encoding="utf-8")
			manifest = self.capture_manifest(source)

			for apply in (False, True):
				with self.subTest(apply=apply):
					with self.assertRaisesRegex(
						sync_reference_project.ReferenceSyncError,
						"reference_sync.copy_target_conflict",
					):
						sync_reference_project.sync_addon(
							manifest,
							source,
							target,
							"copy",
							apply=apply,
						)

			self.assertEqual(target.read_text(encoding="utf-8"), "user-owned")

	def test_link_sync_never_deletes_an_existing_target(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			target = fixture_root / "project/addons/gf"
			source.mkdir()
			target.mkdir(parents=True)
			(target / "user.txt").write_text("preserve", encoding="utf-8")
			manifest = self.capture_manifest(source)

			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.link_target_conflict",
			):
				sync_reference_project.sync_addon(
					manifest,
					source,
					target,
					"link",
					apply=True,
				)

			self.assertEqual((target / "user.txt").read_text(encoding="utf-8"), "preserve")

	def test_overlap_boundaries_reject_repository_and_source_target_aliases(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			repository = fixture_root / "repository"
			source = repository / "addons/gf"
			project = repository / "reference"
			target = project / "addons/gf"
			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.project_overlaps_repository",
			):
				sync_reference_project.assert_sync_boundaries(
					source,
					project,
					target,
					repository_root=repository,
				)

			external_repository = fixture_root / "other-repository"
			for overlapping_target in (source, source / "nested", source.parent):
				with self.subTest(overlapping_target=overlapping_target):
					with self.assertRaisesRegex(
						sync_reference_project.ReferenceSyncError,
						"reference_sync.source_target_overlap",
					):
						sync_reference_project.assert_sync_boundaries(
							source,
							fixture_root / "external-project",
							overlapping_target,
							repository_root=external_repository,
						)

	def test_source_identity_requires_the_fixed_addon_root_and_plugin_marker(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = Path(temporary_directory) / "repository"
			source = repository / "addons/gf"
			source.mkdir(parents=True)

			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.source_identity",
			):
				sync_reference_project.assert_source_root(source, repository_root=repository)

			(source / "plugin.cfg").write_text("[plugin]\n", encoding="utf-8")
			sync_reference_project.assert_source_root(source, repository_root=repository)

	def test_filesystem_aliases_count_as_overlapping_paths(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			alias = fixture_root / "alias"
			source.mkdir()
			gf_maintenance.create_directory_link_fixture(source, alias)
			try:
				self.assertTrue(sync_reference_project.paths_overlap(source, alias))
			finally:
				if alias.is_symlink():
					alias.unlink()
				elif generated_output_transaction.path_is_link_or_junction(alias):
					alias.rmdir()

	def test_project_addons_link_is_rejected_before_target_access(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			project = fixture_root / "project"
			outside = fixture_root / "outside"
			linked_addons = project / "addons"
			project.mkdir()
			outside.mkdir()
			(outside / "canary.txt").write_text("outside", encoding="utf-8")
			gf_maintenance.create_directory_link_fixture(outside, linked_addons)
			try:
				with self.assertRaisesRegex(
					sync_reference_project.ReferenceSyncError,
					"reference_sync.target_boundary",
				):
					sync_reference_project.assert_generated_target(
						project,
						linked_addons / "gf",
					)
				self.assertEqual(
					(outside / "canary.txt").read_text(encoding="utf-8"),
					"outside",
				)
			finally:
				if linked_addons.is_symlink():
					linked_addons.unlink()
				elif generated_output_transaction.path_is_link_or_junction(linked_addons):
					linked_addons.rmdir()

	def test_skip_policy_is_relative_to_payload_not_machine_ancestors(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			source = Path(temporary_directory) / "node_modules/repository/addons/gf"
			source.mkdir(parents=True)
			(source / "visible.txt").write_text("visible", encoding="utf-8")

			manifest = self.capture_manifest(source)

			self.assertEqual(
				[entry.relative_path for entry in manifest.entries],
				["visible.txt"],
			)

	def test_payload_budgets_fail_with_stable_rule_ids(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			source = Path(temporary_directory) / "source"
			source.mkdir()
			(source / "large.bin").write_bytes(b"1234")
			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.file_bytes_limit",
			):
				self.capture_manifest(
					source,
					sync_reference_project.SyncLimits(
						max_file_bytes=3,
						max_total_bytes=8,
					),
				)

			(source / "second.txt").write_text("x", encoding="utf-8")
			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.entry_limit",
			):
				self.capture_manifest(
					source,
					sync_reference_project.SyncLimits(max_entries=1),
				)

			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.total_bytes_limit",
			):
				self.capture_manifest(
					source,
					sync_reference_project.SyncLimits(
						max_file_bytes=8,
						max_total_bytes=4,
					),
				)

			with self.assertRaisesRegex(
				sync_reference_project.ReferenceSyncError,
				"reference_sync.deadline",
			):
				sync_reference_project.capture_payload_manifest(source, deadline=0.0)

	def test_mismatch_samples_are_bounded_without_losing_total_count(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			target = fixture_root / "target"
			source.mkdir()
			target.mkdir()
			(source / "expected.txt").write_text("expected", encoding="utf-8")
			for index in range(8):
				(target / f"extra-{index}").mkdir()
			manifest = self.capture_manifest(source)
			limits = sync_reference_project.SyncLimits(max_mismatches=3)

			check = sync_reference_project.check_addon(manifest, source, target, limits)

			self.assertEqual(check.mismatch_count, 9)
			self.assertEqual(len(check.mismatches), 3)
			self.assertTrue(check.to_dict()["mismatches_truncated"])

	def test_internal_directory_links_are_rejected_without_traversal(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			outside = fixture_root / "outside"
			linked = source / "linked"
			source.mkdir()
			outside.mkdir()
			(outside / "secret.txt").write_text("outside", encoding="utf-8")
			gf_maintenance.create_directory_link_fixture(outside, linked)
			try:
				with self.assertRaisesRegex(
					sync_reference_project.ReferenceSyncError,
					"reference_sync.source_link",
				):
					self.capture_manifest(source)
			finally:
				if linked.is_symlink():
					linked.unlink()
				elif generated_output_transaction.path_is_link_or_junction(linked):
					linked.rmdir()

	def test_machine_output_is_path_redacted_and_cli_defaults_to_check(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			source = fixture_root / "source"
			target = fixture_root / "target"
			source.mkdir()
			(source / "payload.txt").write_text("payload", encoding="utf-8")
			manifest = self.capture_manifest(source)
			plan = sync_reference_project.sync_addon(
				manifest,
				source,
				target,
				"copy",
				apply=False,
			)
			encoded = json.dumps(plan.to_dict(), ensure_ascii=False)

			self.assertNotIn(str(fixture_root), encoded)
			self.assertEqual(
				sync_reference_project.selected_operation(
					sync_reference_project.parse_arguments([])
				),
				"check",
			)
			self.assertEqual(
				sync_reference_project.selected_operation(
					sync_reference_project.parse_arguments(["--apply"])
				),
				"apply",
			)


class PublicAiApiTests(unittest.TestCase):
	def test_cli_reports_owner_drift_without_a_traceback(self) -> None:
		stderr = io.StringIO()
		with mock.patch.object(
			generate_ai_api,
			"collect_api",
			side_effect=ValueError("owner drift"),
		), contextlib.redirect_stderr(stderr):
			status = generate_ai_api.main(["--check"])
		self.assertEqual(status, 2)
		self.assertIn("AI API generation input is invalid: owner drift", stderr.getvalue())

	def test_public_profile_excludes_internal_classes_and_members_without_mutating_input(self) -> None:
		public_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="run",
			signature="func run() -> void:",
			line=10,
			docs=api_docs("public"),
		)
		internal_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="debug_only",
			signature="func debug_only() -> void:",
			line=20,
			docs=api_docs("framework_internal"),
		)
		protected_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="inspect",
			signature="func inspect() -> void:",
			line=15,
			docs=api_docs("protected"),
		)
		layer_internal_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="bridge_only",
			signature="func bridge_only() -> void:",
			line=16,
			docs=api_docs("layer_internal"),
		)
		private_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="implementation_detail",
			signature="func implementation_detail() -> void:",
			line=17,
			docs=api_docs(""),
		)
		public_script = gdscript_api_parser.ApiScript(
			path="addons/gf/public.gd",
			module="kernel",
			class_name="GFPublic",
			docs=api_docs("public"),
			methods=[
				public_method,
				protected_method,
				internal_method,
				layer_internal_method,
				private_method,
			],
		)
		internal_script = gdscript_api_parser.ApiScript(
			path="addons/gf/internal.gd",
			module="kernel",
			class_name="GFInternal",
			docs=api_docs("framework_internal"),
			methods=[internal_method],
		)
		classless_public = gdscript_api_parser.ApiScript(
			path="addons/gf/gf.gd",
			module="kernel",
			api_owner_kind="autoload",
			api_owner_name="Gf",
			docs=api_docs("public"),
			methods=[public_method, internal_method],
		)

		class_owners = gf_api_owners.select_api_owners(
			[public_script, internal_script],
			(),
		)
		autoload_contract = gf_api_owners.ApiAutoloadContract(
			name="Gf",
			source_path="addons/gf/gf.gd",
			resource_path="res://addons/gf/gf.gd",
			package_id="gf.kernel",
			registration_script_path="registration.gd",
			runtime_resolver_script_path="resolver.gd",
		)
		classless_public.extends = "Node"
		autoload_owners = gf_api_owners.select_api_owners(
			[classless_public],
			(autoload_contract,),
		)
		filtered = [*class_owners, *autoload_owners]

		self.assertEqual([(owner.kind, owner.name) for owner in filtered], [
			("class", "GFPublic"),
			("autoload", "Gf"),
		])
		self.assertEqual(
			[[method.name for method in owner.script.methods] for owner in filtered],
			[["run", "inspect"], ["run"]],
		)
		self.assertEqual(len(public_script.methods), 5)
		self.assertEqual(len(classless_public.methods), 2)
		with self.assertRaisesRegex(ValueError, "no controlled owner contract"):
			gf_api_owners.select_api_owners([
				gdscript_api_parser.ApiScript(
					path="addons/gf/unknown.gd",
					module="kernel",
					methods=[public_method],
				)
			], ())

	def test_semantic_digest_ignores_source_lines_but_location_digest_tracks_them(self) -> None:
		def make_owner(line: int, signature: str = "func run() -> void:") -> gf_api_owners.ApiOwner:
			script = gdscript_api_parser.ApiScript(
				path="addons/gf/public.gd",
				module="kernel",
				class_name="GFPublic",
				line=line,
				docs=api_docs("public", "Public class."),
				methods=[gdscript_api_parser.ApiMember(
					kind="method",
					name="run",
					signature=signature,
					line=line + 4,
					docs=api_docs("public"),
				)],
			)
			return gf_api_owners.ApiOwner("class", "GFPublic", script, "gf.kernel")

		first = json.loads(generate_ai_api.render_outputs([make_owner(3)], ROOT / "addons/gf")["api.json"])
		second = json.loads(generate_ai_api.render_outputs([make_owner(30)], ROOT / "addons/gf")["api.json"])
		changed = json.loads(generate_ai_api.render_outputs([
			make_owner(30, "func run(value: int) -> void:")
		], ROOT / "addons/gf")["api.json"])
		self.assertEqual(first["schema_version"], 3)
		self.assertEqual(first["owner_count"], 1)
		self.assertEqual(first["files"][0]["owner_kind"], "class")
		self.assertEqual(first["files"][0]["owner_name"], "GFPublic")
		self.assertEqual(first["files"][0]["package_id"], "gf.kernel")
		with self.assertRaisesRegex(ValueError, "class owner identity"):
			generate_ai_api.render_outputs([
				gf_api_owners.ApiOwner("class", "Alias", make_owner(3).script, "gf.kernel")
			], ROOT / "addons/gf")
		mismatched_autoload_script = make_owner(3).script
		mismatched_autoload_script.class_name = ""
		mismatched_autoload_script.api_owner_kind = "autoload"
		mismatched_autoload_script.api_owner_name = "Other"
		with self.assertRaisesRegex(ValueError, "autoload owner identity"):
			generate_ai_api.render_outputs([
				gf_api_owners.ApiOwner(
					"autoload",
					"Gf",
					mismatched_autoload_script,
					"gf.kernel",
				)
			], ROOT / "addons/gf")
		self.assertEqual(first["source_digest"], second["source_digest"])
		self.assertNotEqual(first["location_digest"], second["location_digest"])
		self.assertNotEqual(second["source_digest"], changed["source_digest"])


class MarkdownStructureTests(unittest.TestCase):
	def test_visible_headings_ignore_comments_and_exact_fence_rules(self) -> None:
		text = '''# Visible
<!--
## Commented
-->
~~~~gdscript
## Fenced
~~~
## Still Fenced
~~~~
## Visible Section
'''
		headings = check_docs_quality.visible_markdown_headings(text)
		self.assertEqual(headings, [(1, 1, "Visible"), (10, 2, "Visible Section")])

	def test_explicit_heading_ids_match_mkdocs_attr_list_anchors(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "page.md"
			path.write_text(
				"# 页面\n\n## 中文标题 { #stable-task-anchor }\n",
				encoding="utf-8",
			)
			self.assertEqual(
				check_docs_quality.collect_markdown_heading_anchors(path),
				{"页面", "stable-task-anchor"},
			)

	def test_file_shape_supports_tilde_and_long_fences(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "docs"
			root.mkdir()
			path = root / "page.md"
			path.write_text(
				"# Page\n\n~~~~text\n# Not an H1\n~~~\n# Still not an H1\n~~~~\n",
				encoding="utf-8",
			)
			self.assertEqual(
				check_docs_quality.check_file(path, root, 50, 50, 500),
				[],
			)

	def test_hidden_or_fenced_headings_cannot_satisfy_entry_templates(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "docs"
			kernel = root / "kernel"
			standard = root / "standard"
			kernel.mkdir(parents=True)
			standard.mkdir(parents=True)
			(kernel / "child.md").write_text("# Child\n", encoding="utf-8")
			(kernel / "index.md").write_text(
				"# Kernel\n<!--\n## 阅读入口\n-->\n~~~markdown\n## 使用边界\n~~~\n"
				"## API Reference\n[API](../reference/api/kernel.md)\n",
				encoding="utf-8",
			)
			(standard / "index.md").write_text(
				"# Standard\n## API Reference\n[API](../reference/api/standard.md)\n",
				encoding="utf-8",
			)

			errors = check_docs_quality.check_section_entry_templates(root)
			self.assertEqual(len(errors), 1)
			self.assertIn("## 阅读入口", errors[0])
			self.assertIn("## 使用边界", errors[0])

			(kernel / "index.md").write_text(
				"# Kernel\n## 阅读入口\n- [Child](child.md)\n## 使用边界\nBoundary.\n"
				"## API Reference\n[API](../reference/api/kernel.md)\n",
				encoding="utf-8",
			)
			self.assertEqual(check_docs_quality.check_section_entry_templates(root), [])


class PublicDocsContractTests(unittest.TestCase):
	def _safe_readme(self) -> str:
		return '''# GF

```gdscript
extends Node

func _ready() -> void:
	if not await Gf.register_model(PlayerModel.new()):
		return
	if not await Gf.register_utility(GFStorageUtility.new()):
		return
	if not await Gf.register_system(BattleSystem.new()):
		return
	if not await Gf.init():
		return
	var player_model := Gf.get_model(PlayerModel) as PlayerModel
	var battle_system := Gf.get_system(BattleSystem) as BattleSystem
	if player_model == null or battle_system == null:
		return
```

```gdscript
class_name GameInstaller
extends GFInstaller

func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var model_ok := await architecture.register_model_instance(PlayerModel.new())
	if scope.is_cancel_requested():
		return
	if not model_ok:
		architecture.fail_initialization("model")
		return
	var utility_ok := await architecture.register_utility_instance(GFStorageUtility.new())
	if scope.is_cancel_requested():
		return
	if not utility_ok:
		architecture.fail_initialization("utility")
		return
	var system_ok := await architecture.register_system_instance(BattleSystem.new())
	if scope.is_cancel_requested():
		return
	if not system_ok:
		architecture.fail_initialization("system")
```
'''

	def test_readme_quickstarts_require_observed_async_results_and_language_parity(self) -> None:
		readme = self._safe_readme()
		self.assertEqual(
			check_docs_quality.check_readme_quickstart_contracts(readme, readme),
			[],
		)

		unsafe = readme.replace("if not await Gf.init():", "await Gf.init()")
		errors = check_docs_quality.check_readme_quickstart_contracts(unsafe, readme)
		self.assertTrue(any("identical" in error for error in errors))
		self.assertTrue(any("if not await Gf.init()" in error for error in errors))

	def test_public_entry_contracts_follow_machine_defaults_and_task_boundaries(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)

			def write(relative_path: str, text: str) -> None:
				path = root / relative_path
				path.parent.mkdir(parents=True, exist_ok=True)
				path.write_text(text, encoding="utf-8")

			readme = self._safe_readme()
			readme += "\n[Uninstall](docs/zh/overview/quickstart/uninstall.md)\n"
			write("README.md", readme)
			write("README.zh.md", readme)
			write(
				"ASSET_STORE.md",
				"A project installer does not replace checking the awaited result.\n",
			)
			write(
				"ASSET_LIBRARY.md",
				"- Description:\n\n```text\nGF Framework is concise.\n```\n",
			)
			write(
				"docs/zh/extensions/installation.md",
				(
					"扩展选择 preset 使用 `gf.save`；package 安装 preset `gf.preset.save` "
					"安装 `gf.extension.save`。见 "
					"[Package Manager](../editor/workspace.md#package-manager)。\n"
				),
			)
			write(
				"docs/zh/overview/quickstart/uninstall.md",
				(
					"先禁用插件，再删除文件。只移除由 GF 插件登记的 `Gf` AutoLoad，"
					"不会删除同名但不指向 GF 的 AutoLoad。保留 `.gf/packages.lock.json`；"
					"package 卸载不是完整插件卸载。失败时恢复同一版本。\n"
				),
			)
			write(
				"docs/zh/overview/quickstart/install-autoload.md",
				"[Packages](../../editor/workspace.md#package-manager) [Uninstall](uninstall.md)\n",
			)
			write(
				"docs/zh/faq.md",
				"# FAQ\n\n## 按主题查找\n\n[Uninstall](overview/quickstart/uninstall.md)\n",
			)
			write("docs/maintainers/index.md", "GF 内置可选扩展默认关闭。\n")
			write(
				"addons/gf/extensions/save/gf_extension.json",
				json.dumps({"id": "gf.save", "enabled_by_default": False}),
			)

			self.assertEqual(check_docs_quality.check_public_entry_contracts(root), [])

			write("docs/maintainers/index.md", "GF 内置扩展默认随 GF 启用。\n")
			errors = check_docs_quality.check_public_entry_contracts(root)
			self.assertTrue(any("derive the all-disabled" in error for error in errors))
			self.assertTrue(any("contradicts" in error for error in errors))


class CoverageEvidenceTests(unittest.TestCase):
	def test_identifier_hits_do_not_accept_substrings(self) -> None:
		files = [
			generate_api_coverage_matrix.make_text_record("fixture.gd", "GFRunnerExtra rerun"),
		]
		self.assertEqual(generate_api_coverage_matrix.find_class_hits(files, ["GFRunner"]), [])
		self.assertEqual(
			generate_api_coverage_matrix.find_member_hits(files, ["GFRunnerExtra"], ["run"]),
			[],
		)

	def test_input_budget_and_utf8_errors_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "large.md").write_text("12345", encoding="utf-8")
			budget = generate_api_coverage_matrix.CoverageReadBudget(
				max_files=10,
				max_total_bytes=10,
				max_file_bytes=4,
			)
			with self.assertRaises(generate_api_coverage_matrix.CoverageInputError):
				generate_api_coverage_matrix.collect_text_files(root, {".md"}, budget=budget)

			(root / "large.md").unlink()
			(root / "invalid.md").write_bytes(b"\xff")
			with self.assertRaises(generate_api_coverage_matrix.CoverageInputError):
				generate_api_coverage_matrix.collect_text_files(
					root,
					{".md"},
					budget=generate_api_coverage_matrix.CoverageReadBudget(),
				)

	def test_directory_enumeration_is_bounded_even_for_irrelevant_files(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "first.bin").write_bytes(b"x")
			(root / "second.bin").write_bytes(b"x")
			budget = generate_api_coverage_matrix.CoverageReadBudget(max_entries=1)
			with self.assertRaises(generate_api_coverage_matrix.CoverageInputError):
				generate_api_coverage_matrix.collect_text_files(
					root,
					{".md"},
					budget=budget,
				)

	def test_external_example_paths_are_redacted_and_roots_are_deduplicated(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "example.gd").write_text("GFExample", encoding="utf-8")
			records = generate_api_coverage_matrix.collect_text_files(
				root,
				{".gd"},
				budget=generate_api_coverage_matrix.CoverageReadBudget(),
				display_prefix="examples/0",
			)
			self.assertEqual(records[0]["path"], "examples/0/example.gd")
			self.assertNotIn(temporary_directory, records[0]["path"])
			self.assertEqual(generate_api_coverage_matrix.dedupe_roots([root, root / "."]), [root.resolve()])

	def test_nonstandard_output_root_requires_explicit_opt_in(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "coverage"
			errors = generate_api_coverage_matrix.validate_generated_output_root(root, False)
			self.assertTrue(errors)
			self.assertEqual(generate_api_coverage_matrix.validate_generated_output_root(root, True), [])

	def test_coverage_writer_preserves_existing_tree_when_manifest_validation_fails(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory) / "coverage"
			root.mkdir()
			canary = root / "canary.txt"
			canary.write_text("old", encoding="utf-8")
			with self.assertRaises(ValueError):
				generate_api_coverage_matrix.write_outputs(
					root,
					{"../escape.txt": "new"},
				)
			self.assertEqual(canary.read_text(encoding="utf-8"), "old")
			self.assertEqual(sorted(path.name for path in root.iterdir()), ["canary.txt"])


class MarkdownGenerationTests(unittest.TestCase):
	def test_partial_source_collection_only_requires_contained_autoload_contracts(self) -> None:
		extension_owners = gf_api_owners.collect_api_owners(
			ROOT / "addons/gf/extensions",
			ROOT,
		)
		self.assertTrue(extension_owners)
		self.assertFalse(any(owner.kind == "autoload" for owner in extension_owners))
		partial_payload = json.loads(generate_ai_api.render_outputs(
			extension_owners,
			ROOT / "addons/gf/extensions",
		)["api.json"])
		self.assertEqual(partial_payload["schema_version"], 3)
		self.assertEqual(partial_payload["autoload_count"], 0)

		full_owners = gf_api_owners.collect_api_owners(ROOT / "addons/gf", ROOT)
		self.assertEqual(
			[owner.name for owner in full_owners if owner.kind == "autoload"],
			["Gf"],
		)
		self.assertEqual(
			gf_api_owners._autoload_contracts_within_source_root(
				ROOT / "addons/gf/kernel",
				ROOT,
				(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
			),
			(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
		)
		outside_contract = gf_api_owners.ApiAutoloadContract(
			name="Outside",
			source_path="addons/outside.gd",
			resource_path="res://addons/outside.gd",
			package_id="gf.outside",
			registration_script_path="addons/outside_registration.gd",
			runtime_resolver_script_path="addons/outside_runtime.gd",
		)
		self.assertEqual(
			gf_api_owners._autoload_contracts_within_source_root(
				ROOT / "addons/gf",
				ROOT,
				(outside_contract,),
			),
			(outside_contract,),
		)

	def test_classless_api_owner_selection_is_explicit_and_fails_closed(self) -> None:
		public_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="run",
			signature="func run() -> void:",
			line=1,
			docs=api_docs("public"),
		)
		unknown = gdscript_api_parser.ApiScript(
			path="addons/gf/unknown_singleton.gd",
			module="kernel",
			extends="Node",
			methods=[public_method],
		)
		with self.assertRaisesRegex(ValueError, "no controlled owner contract"):
			gf_api_owners.select_api_owners([unknown], ())

		known = gdscript_api_parser.parse_gdscript_file(
			ROOT / gf_api_owners.GF_AUTOLOAD_CONTRACT.source_path,
			ROOT / "addons/gf",
			ROOT,
		)
		owners = gf_api_owners.select_api_owners(
			[known],
			(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
		)
		self.assertEqual([(owner.kind, owner.name) for owner in owners], [("autoload", "Gf")])
		self.assertEqual([member.name for member in owners[0].script.methods][:2], [
			"has_architecture",
			"create_architecture",
		])
		self.assertEqual(len(owners[0].script.methods), 65)
		self.assertEqual(len(owners[0].script.constants), 3)
		self.assertEqual(len(owners[0].script.properties), 1)
		with self.assertRaisesRegex(ValueError, "contract is stale"):
			gf_api_owners.select_api_owners([], (gf_api_owners.GF_AUTOLOAD_CONTRACT,))

	def test_controlled_autoload_registration_and_package_identity_fail_closed(self) -> None:
		known = gdscript_api_parser.parse_gdscript_file(
			ROOT / gf_api_owners.GF_AUTOLOAD_CONTRACT.source_path,
			ROOT / "addons/gf",
			ROOT,
		)
		owners = gf_api_owners.select_api_owners(
			[known],
			(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
		)
		gf_api_owners.validate_controlled_autoloads(
			owners,
			ROOT,
			(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
		)
		self.assertTrue(gf_api_owners._uses_controlled_autoload_registration_call(
			"plugin.add_autoload_singleton(\n\tAUTOLOAD_NAME,\n\tAUTOLOAD_PATH\n)\n"
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			"# plugin.add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)\n"
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			'var text := "add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)"\n'
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			"func add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH):\n\tpass\n"
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			"signal add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)\n"
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			"other.plugin.add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)\n"
		))
		self.assertFalse(gf_api_owners._uses_controlled_autoload_registration_call(
			"plugin.add_autoload_singleton(OTHER_NAME, AUTOLOAD_PATH)\n"
		))

		package_records = [
			{"id": "gf.kernel", "kind": "kernel"},
			{"id": "gf.duplicate", "kind": "extension"},
		]
		with mock.patch.object(
			gf_api_owners.build_gf_package,
			"collect_package_files",
			return_value=[ROOT / gf_api_owners.GF_AUTOLOAD_CONTRACT.source_path],
		):
			with self.assertRaisesRegex(ValueError, "exactly one package"):
				gf_api_owners.resolve_api_owner_packages(owners, package_records, ROOT)

	def test_class_and_autoload_owner_names_cannot_collide(self) -> None:
		autoload_script = gdscript_api_parser.parse_gdscript_file(
			ROOT / gf_api_owners.GF_AUTOLOAD_CONTRACT.source_path,
			ROOT / "addons/gf",
			ROOT,
		)
		class_script = gdscript_api_parser.ApiScript(
			path="addons/gf/kernel/core/gf_class.gd",
			module="kernel",
			class_name="Gf",
			docs=api_docs("public"),
		)
		with self.assertRaisesRegex(ValueError, "collision across owner kinds"):
			gf_api_owners.select_api_owners(
				[autoload_script, class_script],
				(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
			)

	def test_autoload_owner_has_distinct_catalog_and_reference_identity(self) -> None:
		script = gdscript_api_parser.parse_gdscript_file(
			ROOT / gf_api_owners.GF_AUTOLOAD_CONTRACT.source_path,
			ROOT / "addons/gf",
			ROOT,
		)
		selected_owner = gf_api_owners.select_api_owners(
			[script],
			(gf_api_owners.GF_AUTOLOAD_CONTRACT,),
		)[0]
		owner = gf_api_owners.ApiOwner(
			selected_owner.kind,
			selected_owner.name,
			selected_owner.script,
			"gf.kernel",
		)
		catalog = generate_api_reference.render_catalog_files(
			[],
			ROOT / "addons/gf",
			[owner],
		)
		self.assertIn('schemaVersion="3"', catalog["index.xml"])
		self.assertIn('autoloadCount="1"', catalog["index.xml"])
		self.assertIn('<autoload name="Gf"', catalog["index.xml"])
		self.assertIn('packageId="gf.kernel"', catalog["autoloads/Gf.xml"])
		self.assertNotIn("classes/Gf.xml", catalog)

		reference = generate_api_reference.render_reference_files(
			[],
			catalog["index.xml"],
			[owner],
		)
		self.assertIn("autoloads/Gf.md", reference)
		self.assertIn("Owner 类型：`autoload`", reference["autoloads/Gf.md"])
		self.assertIn(
			'<a id="member-gf-methods-has_architecture"></a>',
			reference["autoloads/Gf.md"],
		)
		with contextlib.redirect_stdout(io.StringIO()):
			self.assertEqual(
				generate_api_reference.check_reference_coverage(
					[],
					reference,
					report_success=False,
					api_autoloads=[owner],
				),
				0,
			)

	def test_reference_without_autoloads_has_no_dangling_owner_index(self) -> None:
		owner = gdscript_api_parser.ApiClass(
			name="PartialOwner",
			path="addons/gf/extensions/partial_owner.gd",
			module="extensions",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
		)
		catalog = generate_api_reference.render_catalog_files(
			[owner],
			ROOT / "addons/gf/extensions",
		)
		reference = generate_api_reference.render_reference_files(
			[owner],
			catalog["index.xml"],
		)
		self.assertNotIn("autoloads/index.md", reference)
		self.assertNotIn("autoloads/index.md", reference["index.md"])
		with contextlib.redirect_stdout(io.StringIO()):
			self.assertEqual(
				generate_api_reference.check_reference_coverage(
					[owner],
					reference,
					report_success=False,
				),
				0,
			)

	def test_parameter_table_cells_escape_markdown_structure(self) -> None:
		lines: list[str] = []
		generate_api_reference.append_params(
			lines,
			gdscript_api_parser.ApiDocs(tags={"param": ["value: pipe | tick ` and\nnewline"]}),
		)
		self.assertIn("| `value` | pipe \\| tick \\` and newline |", lines)

	def test_member_code_fence_outgrows_backticks_in_signature(self) -> None:
		member = gdscript_api_parser.ApiMember(
			kind="const",
			name="MARKDOWN",
			signature='const MARKDOWN: String = "```"',
			line=1,
			docs=api_docs("public"),
		)
		lines: list[str] = []
		generate_api_reference.append_member_group_markdown(
			lines,
			"constants",
			[member],
		)
		self.assertIn("````gdscript", lines)
		self.assertEqual(lines.count("````"), 1)
		owner = gdscript_api_parser.ApiClass(
			name="MarkdownOwner",
			path="addons/gf/markdown_owner.gd",
			module="kernel",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
			constants=[member],
		)
		summary_lines: list[str] = []
		generate_api_reference.append_member_summary_markdown(summary_lines, owner, 2)
		self.assertTrue(
			any('```` const MARKDOWN: String = "```" ````' in line for line in summary_lines)
		)

	def test_coverage_requires_the_exact_owner_member_anchor(self) -> None:
		shared_signature = "func run() -> void:"
		top_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="run",
			signature=shared_signature,
			line=1,
			docs=api_docs("public"),
		)
		inner_method = gdscript_api_parser.ApiMember(
			kind="method",
			name="run",
			signature=shared_signature,
			line=2,
			docs=api_docs("public"),
		)
		inner = gdscript_api_parser.ApiClass(
			name="Inner",
			owner="Owner",
			path="addons/gf/owner.gd",
			module="kernel",
			extends="RefCounted",
			line=2,
			docs=api_docs("public"),
			methods=[inner_method],
		)
		owner = gdscript_api_parser.ApiClass(
			name="Owner",
			path="addons/gf/owner.gd",
			module="kernel",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
			methods=[top_method],
			inner_classes=[inner],
		)
		catalog = generate_api_reference.render_catalog_files([owner], ROOT / "addons/gf")
		reference = generate_api_reference.render_reference_files([owner], catalog["index.xml"])
		top_anchor = (
			'<a id="'
			+ generate_api_reference.member_anchor_id(owner, "methods", top_method)
			+ '"></a>\n'
		)
		reference["classes/Owner.md"] = reference["classes/Owner.md"].replace(
			top_anchor,
			"",
			1,
		)
		with contextlib.redirect_stdout(io.StringIO()):
			coverage_status = generate_api_reference.check_reference_coverage(
				[owner],
				reference,
				report_success=False,
			)
		self.assertEqual(coverage_status, 1)

	def test_duplicate_and_anchor_colliding_owners_fail_before_render(self) -> None:
		first = gdscript_api_parser.ApiClass(
			name="Owner",
			path="addons/gf/first.gd",
			module="kernel",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
		)
		duplicate = gdscript_api_parser.ApiClass(
			name="Owner",
			path="addons/gf/second.gd",
			module="kernel",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
		)
		with self.assertRaisesRegex(ValueError, "duplicate API owner"):
			generate_api_reference.render_catalog_files(
				[first, duplicate],
				ROOT / "addons/gf",
			)

		upper_inner = gdscript_api_parser.ApiClass(
			name="Inner",
			owner="Container",
			path="addons/gf/container.gd",
			module="kernel",
			extends="RefCounted",
			line=2,
			docs=api_docs("public"),
		)
		lower_inner = gdscript_api_parser.ApiClass(
			name="inner",
			owner="Container",
			path="addons/gf/container.gd",
			module="kernel",
			extends="RefCounted",
			line=3,
			docs=api_docs("public"),
		)
		container = gdscript_api_parser.ApiClass(
			name="Container",
			path="addons/gf/container.gd",
			module="kernel",
			extends="RefCounted",
			line=1,
			docs=api_docs("public"),
			inner_classes=[upper_inner, lower_inner],
		)
		with self.assertRaisesRegex(ValueError, "portable identity collision"):
			generate_api_reference.render_catalog_files(
				[container],
				ROOT / "addons/gf",
			)

	def test_generated_reference_link_graph_rejects_missing_targets_and_anchors(self) -> None:
		errors = generate_api_reference.validate_generated_reference_links({
			"index.md": (
				"# Index\n\n"
				"[Missing page](missing.md)\n\n"
				"[Missing anchor](page.md#missing)\n"
			),
			"page.md": "# Page\n",
		})
		self.assertEqual(len(errors), 2)
		self.assertTrue(any("target is missing" in error for error in errors))
		self.assertTrue(any("anchor is missing" in error for error in errors))


if __name__ == "__main__":
	unittest.main()
