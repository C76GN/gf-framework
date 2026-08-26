## Tests the internal module ownership boundary of the optional AI Developer Kit.
extends GutTest


const ADDON_ROOT: String = "res://addons/gf/tools/ai_developer"
const PACKAGE_PATH: String = "res://packages/tools/gf.tool.ai_developer.json"


func test_ai_developer_package_declares_optional_tool_boundary() -> void:
	var package: Dictionary = _load_json_dictionary(PACKAGE_PATH)

	assert_eq(GFVariantData.get_option_string(package, "id"), "gf.tool.ai_developer")
	assert_eq(GFVariantData.get_option_string(package, "kind"), "tool")
	assert_eq(GFVariantData.get_option_array(package, "dependencies"), ["gf.kernel"])
	assert_eq(GFVariantData.get_option_array(package, "paths"), ["addons/gf/tools/ai_developer/**"])


func test_ai_developer_schemas_and_templates_are_valid_json() -> void:
	for relative_path: String in [
		"schemas/project_contract.schema.json",
		"schemas/project_snapshot.schema.json",
		"schemas/feedback_candidate.schema.json",
		"schemas/capability_catalog.schema.json",
		"schemas/recipe_catalog.schema.json",
		"templates/gf_project_contract.json",
		"templates/feedback_candidate.json",
		"knowledge/capabilities.json",
		"knowledge/recipes.json",
	]:
		var data: Dictionary = _load_json_dictionary(ADDON_ROOT.path_join(relative_path))
		assert_false(data.is_empty(), "%s must contain a JSON object." % relative_path)


func test_ai_developer_api_index_matches_installed_framework_version() -> void:
	var index: Dictionary = _load_json_dictionary(ADDON_ROOT.path_join("knowledge/api_index.json"))
	var plugin_config: ConfigFile = ConfigFile.new()
	var load_error: Error = plugin_config.load("res://addons/gf/plugin.cfg")

	assert_eq(load_error, OK, "GF plugin.cfg must be readable.")
	assert_eq(
		GFVariantData.get_option_string(index, "framework_version"),
		str(plugin_config.get_value("plugin", "version", "")),
		"AI API knowledge must be version-bound to the installed GF release."
	)
	assert_gt(GFVariantData.get_option_int(index, "class_count"), 500, "AI API index must cover the public GF surface.")
	assert_false(GFVariantData.get_option_dictionary(index, "classes").is_empty())
	assert_eq(GFVariantData.get_option_int(index, "schema_version"), 2)
	assert_eq(GFVariantData.get_option_int(index, "autoload_count"), 1)
	var autoloads: Dictionary = GFVariantData.get_option_dictionary(index, "autoloads")
	var gf_owner: Dictionary = GFVariantData.get_option_dictionary(autoloads, "Gf")
	assert_eq(GFVariantData.get_option_string(gf_owner, "owner_kind"), "autoload")
	assert_eq(GFVariantData.get_option_string(gf_owner, "package_id"), "gf.kernel")
	assert_eq(
		GFVariantData.get_option_string(gf_owner, "path"),
		"addons/gf/kernel/core/gf.gd"
	)
	assert_false(GFVariantData.get_option_dictionary(index, "classes").has("Gf"))


func test_ai_developer_skill_feedback_and_migration_policy_are_shipped() -> void:
	var skill_path: String = ADDON_ROOT.path_join("templates/skills/gf-project-development/SKILL.md")
	var feedback_path: String = ADDON_ROOT.path_join("knowledge/feedback.md")
	var migration_path: String = ADDON_ROOT.path_join("knowledge/migration.md")
	var skill_text: String = FileAccess.get_file_as_string(skill_path)
	var feedback_text: String = FileAccess.get_file_as_string(feedback_path)
	var migration_text: String = FileAccess.get_file_as_string(migration_path)

	assert_true(FileAccess.file_exists(skill_path))
	assert_true(skill_text.begins_with("---\nname: gf-project-development\n"))
	assert_true(feedback_text.contains("MCP intentionally cannot submit"))
	assert_true(feedback_text.contains("interactive terminal"))
	assert_true(migration_text.contains("expected-plan-sha256"))
	assert_true(migration_text.contains("MCP exposes the read-only plan only"))
	assert_true(migration_text.contains("decision_state: pending_review"))
	assert_true(migration_text.contains("Project snapshots are generated evidence"))


func _load_json_dictionary(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "%s must exist." % path)
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(value is Dictionary, "%s must parse as a JSON Dictionary." % path)
	return GFVariantData.as_dictionary(value)
