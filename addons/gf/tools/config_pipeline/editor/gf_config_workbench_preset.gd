@tool

# 配置工作台版本化预设与 create-only 样例；不修改已有 Profile 的缺省值。
extends RefCounted


# --- 常量 ---

const _PATHS_SCRIPT = preload("res://addons/gf/kernel/core/gf_project_artifact_paths.gd")
const _PRESET_PATH: String = "res://addons/gf/tools/config_pipeline/presets/basic_v1.json"
const _READER_TEMPLATE: String = "res://addons/gf/tools/config_pipeline/templates/read_config.gd.txt"


# --- 框架内部方法 ---

## 创建独立 Profile，冻结预设值；只为生成路径和类名选择尚未占用的建议。
## [br]
## @api framework_internal
## [br]
## @param source_path: 用户选择的来源。
## [br]
## @param database_name: 建议数据库标识。
## [br]
## @param output_root: 生成目录。
## [br]
## @return: 新 Profile，不写文件。
static func make_profile(source_path: String, database_name: String = "main", output_root: String = "res://generated") -> GFConfigPipelineProfile:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var identifier: String = database_name.validate_node_name().to_snake_case()
	if identifier.is_empty() or not identifier.is_valid_identifier():
		identifier = "main"
	var suffix: int = 1
	var output_path: String = output_root.path_join("config/%s.tres" % identifier)
	var access_path: String = _PATHS_SCRIPT.CONFIG_ACCESS_OUTPUT_PATH if identifier == "main" and output_root == _PATHS_SCRIPT.GENERATED_ROOT else output_root.path_join("%s_config_access.gd" % identifier)
	var access_name: String = "GFConfigAccess" if access_path == _PATHS_SCRIPT.CONFIG_ACCESS_OUTPUT_PATH else identifier.to_pascal_case() + "ConfigAccess"
	while FileAccess.file_exists(output_path) or FileAccess.file_exists(access_path) or _class_exists(access_name):
		suffix += 1
		var candidate: String = "%s_%d" % [identifier, suffix]
		output_path = output_root.path_join("config/%s.tres" % candidate)
		access_path = output_root.path_join("%s_config_access.gd" % candidate)
		access_name = candidate.to_pascal_case() + "ConfigAccess"
	profile.profile_id = StringName(identifier)
	profile.database_id = StringName(identifier)
	profile.output_path = output_path
	profile.access_output_path = access_path
	profile.access_class_name = access_name
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = source_path
	var preset: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(FileAccess.get_file_as_string(_PRESET_PATH)))
	source.schema_options = GFVariantData.get_option_dictionary(preset, "schema_options").duplicate(true)
	profile.access_options = GFVariantData.get_option_dictionary(preset, "access_options").duplicate(true)
	profile.sources.append(source)
	profile.metadata["gf_config_preset"] = preset.duplicate(true)
	return profile


## 比较版本化预设的管理字段；不推断用户自定义值的来源，也不修改草稿。
## [br]
## @api framework_internal
## [br]
## @param profile: 待比较的草稿。
## [br]
## @return: 每项变化的路径、当前值和预设值。
static func describe_changes(profile: GFConfigPipelineProfile) -> PackedStringArray:
	var preset: Dictionary = _read_preset()
	var changes: PackedStringArray = []
	var schema_options: Dictionary = GFVariantData.get_option_dictionary(preset, "schema_options")
	for source: GFConfigPipelineTableSource in profile.sources:
		if source == null:
			continue
		for key: String in schema_options:
			if source.schema_options.get(key) != schema_options[key]:
				var _appended: bool = changes.append("%s.schema_options.%s: %s → %s" % [source.get_table_key(), key, str(source.schema_options.get(key)), str(schema_options[key])])
		if source.schema != null:
			var _appended: bool = changes.append("%s: 显式 Schema 优先，预设不会修改其字段或 ID 规则。" % source.get_table_key())
	var access_options: Dictionary = GFVariantData.get_option_dictionary(preset, "access_options")
	for key: String in access_options:
		if profile.access_options.get(key) != access_options[key]:
			var _appended: bool = changes.append("access_options.%s: %s → %s" % [key, str(profile.access_options.get(key)), str(access_options[key])])
	return changes


## 显式更新预设管理值及版本记录，保留所有非管理字段；调用方负责标记并保存草稿。
## [br]
## @api framework_internal
## [br]
## @param profile: 待修改的独立草稿。
static func apply_managed_values(profile: GFConfigPipelineProfile) -> void:
	var preset: Dictionary = _read_preset()
	for source: GFConfigPipelineTableSource in profile.sources:
		if source != null:
			source.schema_options.merge(GFVariantData.get_option_dictionary(preset, "schema_options"), true)
	profile.access_options.merge(GFVariantData.get_option_dictionary(preset, "access_options"), true)
	profile.metadata["gf_config_preset"] = preset.duplicate(true)


## 返回与当前产物匹配的读取示例，不依赖生成访问器类已被编辑器导入。
## [br]
## @api framework_internal
## [br]
## @param profile: 导出任务。
## [br]
## @return: 可作为 Label 脚本使用的源码。
static func make_read_example(profile: GFConfigPipelineProfile) -> String:
	if profile == null or profile.sources.is_empty() or profile.sources[0] == null:
		return "# Add a valid table source to the Profile, then generate the reading example."
	var table_name: String = String(profile.sources[0].get_table_key()) if not profile.sources.is_empty() else "items"
	return FileAccess.get_file_as_string(_READER_TEMPLATE).replace("{DatabasePath}", JSON.stringify(profile.output_path)).replace("{TableName}", JSON.stringify(table_name))


## 在显式选择的项目根创建样例；所有目标均为用户文件，冲突时全批零写入。
## [br]
## @api framework_internal
## [br]
## @param root_path: res:// 或 user:// 项目片段根。
## [br]
## @return: 事务报告及 profile_path、scene_path。
## [br]
## @schema return: Dictionary，包含 ok、issues、recovery_required 和样例路径。
static func create_sample(root_path: String) -> Dictionary:
	var source_path: String = root_path.path_join("data/config/items.csv")
	var profile_path: String = root_path.path_join("config/build/main.tres")
	var script_path: String = root_path.path_join("config/examples/read_config.gd")
	var scene_path: String = root_path.path_join("config/examples/read_config.tscn")
	var profile: GFConfigPipelineProfile = make_profile(source_path, "main", root_path.path_join("generated"))
	var temporary_path: String = "user://gf_config_profile_%d.tres" % Time.get_ticks_usec()
	var save_error: Error = ResourceSaver.save(profile, temporary_path)
	if save_error != OK:
		return { "ok": false, "error": error_string(save_error) }
	var profile_text: String = FileAccess.get_file_as_string(temporary_path)
	var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	var scene_text: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=%s id=\"1\"]\n\n[node name=\"ReadConfig\" type=\"Label\"]\ntext = \"Export the configuration, then run this scene.\"\nscript = ExtResource(\"1\")\n" % JSON.stringify(script_path)
	var entries: Array[Dictionary] = [
		GFArtifactWriteTransaction.make_text_entry(source_path + ".import", "[remap]\n\nimporter=\"keep\"\n", { "overwrite": false }),
		GFArtifactWriteTransaction.make_text_entry(source_path, "id:int!,name:string,power:float\n1,Potion,2.5\n2,Ether,3.0\n", { "overwrite": false }),
		GFArtifactWriteTransaction.make_text_entry(profile_path, profile_text, { "overwrite": false }),
		GFArtifactWriteTransaction.make_text_entry(script_path, make_read_example(profile), { "overwrite": false }),
		GFArtifactWriteTransaction.make_text_entry(scene_path, scene_text, { "overwrite": false }),
	]
	var result: Dictionary = GFArtifactWriteTransaction.commit(entries, {
		"allowed_roots": [root_path],
		"overwrite_existing": false,
		"metadata": { "artifact_owner": "user", "preset_id": "gf.config.basic", "preset_version": 1 },
	})
	result["profile_path"] = profile_path
	result["scene_path"] = scene_path
	return result


# --- 私有/辅助方法 ---

static func _read_preset() -> Dictionary:
	return GFVariantData.as_dictionary(JSON.parse_string(FileAccess.get_file_as_string(_PRESET_PATH)))


static func _class_exists(type_name: String) -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if GFVariantData.get_option_string(entry, "class") == type_name:
			return true
	return ClassDB.class_exists(type_name)
