extends GutTest

const GF_RESOURCE_LOAD_STATE_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_load_state.gd")
const GF_RESOURCE_IDENTITY_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_identity.gd")
const GF_THREADED_RESOURCE_LOAD_ADAPTER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")


func test_resource_load_state_tracks_progress_resource_and_release() -> void:
	var state: GF_RESOURCE_LOAD_STATE_SCRIPT = GF_RESOURCE_LOAD_STATE_SCRIPT.new()
	var _configured: GF_RESOURCE_LOAD_STATE_SCRIPT = state.configure(&"ui.icon", "res://icon.png", {
		"reference_mode": GF_RESOURCE_LOAD_STATE_SCRIPT.REFERENCE_STRONG,
	})
	var resource: Resource = Resource.new()

	var _requested: GF_RESOURCE_LOAD_STATE_SCRIPT = state.mark_requested({ "group": "ui" })
	var _loading: GF_RESOURCE_LOAD_STATE_SCRIPT = state.mark_loading(0.45)
	var _loaded: GF_RESOURCE_LOAD_STATE_SCRIPT = state.mark_loaded(resource, { "source": "cache" })

	var snapshot: Dictionary = state.to_dictionary()

	assert_eq(state.status, GF_RESOURCE_LOAD_STATE_SCRIPT.STATUS_LOADED, "mark_loaded 应设置 loaded 状态。")
	assert_true(state.has_resource(), "加载状态应能返回资源引用。")
	assert_true(state.is_success(), "loaded 且资源有效时应为成功。")
	assert_eq(GFVariantData.get_option_float(snapshot, "progress"), 1.0, "loaded 状态应把进度设为 1。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "reference_mode"), GF_RESOURCE_LOAD_STATE_SCRIPT.REFERENCE_STRONG, "强引用模式应进入快照。")

	var duplicate_state: GF_RESOURCE_LOAD_STATE_SCRIPT = state.duplicate_state()
	assert_true(duplicate_state.has_resource(), "duplicate_state 应保留当前资源引用。")

	var _released: GF_RESOURCE_LOAD_STATE_SCRIPT = state.mark_released()
	assert_eq(state.status, GF_RESOURCE_LOAD_STATE_SCRIPT.STATUS_RELEASED, "mark_released 应设置 released 状态。")
	assert_false(state.has_resource(), "released 后不应保留资源引用。")
	assert_true(state.is_terminal(), "released 是终态。")


func test_resource_load_state_restores_dictionary_without_resource_reference() -> void:
	var state: GF_RESOURCE_LOAD_STATE_SCRIPT = GF_RESOURCE_LOAD_STATE_SCRIPT.from_dictionary({
		"resource_key": &"hero",
		"resource_path": "res://hero.tres",
		"status": GF_RESOURCE_LOAD_STATE_SCRIPT.STATUS_FAILED,
		"progress": 0.5,
		"error": "missing",
		"metadata": { "pack": "base" },
	})

	assert_eq(state.resource_key, &"hero", "from_dictionary 应恢复资源键。")
	assert_eq(state.status, GF_RESOURCE_LOAD_STATE_SCRIPT.STATUS_FAILED, "from_dictionary 应恢复状态。")
	assert_eq(state.error, "missing", "from_dictionary 应恢复错误。")
	assert_false(state.has_resource(), "字典恢复不应伪造资源引用。")

	var _stale: GF_RESOURCE_LOAD_STATE_SCRIPT = state.mark_stale("manifest_changed")
	assert_eq(state.status, GF_RESOURCE_LOAD_STATE_SCRIPT.STATUS_STALE, "mark_stale 应设置 stale。")
	assert_eq(GFVariantData.get_option_string(state.metadata, "stale_reason"), "manifest_changed", "stale 原因应进入 metadata。")


func test_resource_identity_canonicalizes_path_uid_and_cache_key() -> void:
	var raw_path: String = "res://addons/gf/standard/utilities/assets/../assets/gf_resource_load_state.gd"
	var expected_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_load_state.gd"
	var identity: GF_RESOURCE_IDENTITY_SCRIPT = GF_RESOURCE_IDENTITY_SCRIPT.from_path(raw_path, &"state", "GDScript")

	assert_eq(identity.raw_path, raw_path, "身份应保留调用方原始路径。")
	assert_eq(identity.canonical_path, expected_path, "身份应规范化 slash 和 dot segment。")
	assert_eq(identity.scheme, GF_RESOURCE_IDENTITY_SCRIPT.SCHEME_RES, "规范化后应识别 res scheme。")
	assert_eq(identity.extension, "gd", "应从规范化路径推导扩展名。")
	assert_true(identity.exists, "测试资源应存在。")
	assert_true(identity.uid_path.begins_with("uid://"), "已有 uid 的资源应输出 uid_path。")
	assert_eq(identity.cache_key, identity.uid_path, "存在 UID 时 cache_key 应优先使用 uid_path。")

	var restored_identity: GF_RESOURCE_IDENTITY_SCRIPT = GF_RESOURCE_IDENTITY_SCRIPT.from_dictionary(identity.to_dictionary())
	assert_eq(restored_identity.cache_key, identity.cache_key, "字典恢复应保留 cache_key。")


func test_resource_identity_resolves_uid_path_to_canonical_path() -> void:
	var expected_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_load_state.gd"
	var uid: int = ResourceLoader.get_resource_uid(expected_path)
	assert_ne(uid, ResourceUID.INVALID_ID, "测试资源应有 Godot UID。")
	var uid_path: String = ResourceUID.id_to_text(uid)
	var identity: GF_RESOURCE_IDENTITY_SCRIPT = GF_RESOURCE_IDENTITY_SCRIPT.from_path(uid_path, &"state")

	assert_eq(identity.raw_path, uid_path, "原始路径应保留 uid://。")
	assert_eq(identity.canonical_path, expected_path, "uid:// 应回解为当前工程资源路径。")
	assert_eq(identity.uid_path, uid_path, "uid_path 应保留稳定 UID。")
	assert_eq(identity.cache_key, uid_path, "uid:// 身份应使用 UID 作为 cache_key。")


func test_resource_load_state_exports_resource_identity_snapshot() -> void:
	var state: GF_RESOURCE_LOAD_STATE_SCRIPT = GF_RESOURCE_LOAD_STATE_SCRIPT.new()
	var raw_path: String = "res://addons/gf/standard/utilities/assets/../assets/gf_resource_load_state.gd"
	var _configured: GF_RESOURCE_LOAD_STATE_SCRIPT = state.configure(&"state", raw_path, {
		"metadata": { "source": "test" },
	})
	var identity: GF_RESOURCE_IDENTITY_SCRIPT = state.get_resource_identity()
	var snapshot: Dictionary = state.to_dictionary()
	var identity_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, "resource_identity")

	assert_eq(identity.raw_path, raw_path, "状态身份应保留原始路径。")
	assert_eq(GFVariantData.get_option_string(identity_snapshot, "cache_key"), identity.cache_key, "状态快照应包含资源身份 cache_key。")
	assert_eq(GFVariantData.get_option_string(identity_snapshot, "canonical_path"), identity.canonical_path, "状态快照应包含规范化资源路径。")


func test_threaded_resource_loader_calls_are_centralized_in_adapter() -> void:
	var adapter_source: String = _read_text_file("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")
	assert_true(adapter_source.contains("ResourceLoader.load_threaded_request"), "adapter 应集中发起 threaded request。")
	assert_true(adapter_source.contains("ResourceLoader.load_threaded_get_status"), "adapter 应集中读取 threaded status。")
	assert_true(adapter_source.contains("ResourceLoader.load_threaded_get(path)"), "adapter 应集中取出 threaded resource。")

	var source_paths: Array[String] = [
		"res://addons/gf/standard/utilities/assets/gf_asset_utility.gd",
		"res://addons/gf/standard/utilities/jobs/gf_background_work_utility.gd",
		"res://addons/gf/standard/utilities/scene/gf_scene_utility.gd",
	]
	for source_path: String in source_paths:
		var source: String = _read_text_file(source_path)
		assert_false(source.contains("ResourceLoader.load_threaded_"), "%s 不应直接调用 threaded ResourceLoader。" % source_path)


func test_threaded_resource_load_adapter_reports_invalid_empty_path() -> void:
	var error: Error = GF_THREADED_RESOURCE_LOAD_ADAPTER_SCRIPT.request("")

	assert_eq(error, ERR_INVALID_PARAMETER, "空路径应由 adapter 拒绝。")


# --- 私有/辅助方法 ---

func _read_text_file(path: String) -> String:
	var read_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var file: FileAccess = FileAccess.open(read_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取文本文件：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
