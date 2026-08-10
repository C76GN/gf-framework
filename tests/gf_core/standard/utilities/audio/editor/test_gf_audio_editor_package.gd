extends GutTest


# --- 常量 ---

const _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd"
)
const _STANDARD_CONTRIBUTIONS_PATH: String = (
	"res://addons/gf/standard/editor/gf_editor_contributions.json"
)
const _AUDIO_INSPECTOR_PATH: String = (
	"res://addons/gf/standard/utilities/audio/editor/gf_audio_bank_inspector_plugin.gd"
)


# --- 测试方法 ---

func test_audio_editor_package_loads_inspector_script() -> void:
	var script: GDScript = _load_script(_AUDIO_INSPECTOR_PATH)
	if script == null:
		return

	assert_eq(script.get_instance_base_type(), "EditorInspectorPlugin")


func test_audio_editor_contribution_has_one_owned_reachable_inspector() -> void:
	var records: Dictionary = _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_records(
		_STANDARD_CONTRIBUTIONS_PATH
	)
	var matches: Array[Dictionary] = []
	for record: Dictionary in _to_record_array(
		GFVariantData.get_option_value(records, "inspector_plugin_records", [])
	):
		if GFVariantData.get_option_string(record, "owner_package_id") == "gf.standard.audio.editor":
			matches.append(record)

	assert_eq(matches.size(), 1, "Audio editor package 必须恰好拥有一个 AudioBank Inspector 贡献。")
	if matches.size() != 1:
		return
	assert_eq(GFVariantData.get_option_string(matches[0], "path"), _AUDIO_INSPECTOR_PATH)
	assert_eq(
		GFVariantData.get_option_string(matches[0], "source_id"),
		"gf.standard.audio.editor:audio.inspector.audio_bank"
	)


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null


func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	for record_value: Variant in value:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			records.append(record)
	return records
