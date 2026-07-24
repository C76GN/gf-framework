## 测试资源变体 provider、资源图扫描和原始资源 artifact。
extends GutTest


# --- 常量 ---

const TEMP_ARTIFACT_DIR: String = "user://gf_test_raw_artifacts"


# --- 测试生命周期 ---

func after_each() -> void:
	_remove_user_path_if_exists(TEMP_ARTIFACT_DIR)


# --- 测试用例 ---

func test_resource_variant_provider_resolves_requested_variant_with_default_fallback() -> void:
	var resolver: GFResourceResolverUtility = GFResourceResolverUtility.new()
	resolver.init()
	var provider: GFResourceVariantProvider = GFResourceVariantProvider.new()
	var default_registered: bool = provider.register_variant(&"ui.panel", &"default", "res://ui/default_panel.tres", "Resource")
	var mobile_registered: bool = provider.register_variant(&"ui.panel", &"mobile", "res://ui/mobile_panel.tres", "Resource")
	var registered: bool = resolver.register_provider(provider, &"variant", 10)

	var mobile_report: Dictionary = resolver.resolve(&"ui.panel", "Resource", {
		"check_exists": false,
		"variant_keys": PackedStringArray(["mobile", "default"]),
	})
	var fallback_report: Dictionary = resolver.resolve(&"ui.panel", "Resource", {
		"check_exists": false,
		"variant_keys": PackedStringArray(["desktop", "default"]),
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(mobile_report, "metadata")

	assert_true(default_registered, "默认变体应注册成功。")
	assert_true(mobile_registered, "移动端变体应注册成功。")
	assert_true(registered, "变体 provider 应符合 resolver provider 协议。")
	assert_eq(GFVariantData.get_option_string(mobile_report, "path"), "res://ui/mobile_panel.tres")
	assert_eq(GFVariantData.get_option_string_name(metadata, "variant_key"), &"mobile")
	assert_eq(GFVariantData.get_option_string(fallback_report, "path"), "res://ui/default_panel.tres")
	resolver.dispose()


func test_resource_graph_scanner_reports_paths_and_cycles_without_editor_ui() -> void:
	var root: GraphResource = GraphResource.new()
	var child: GraphResource = GraphResource.new()
	root.child = child
	root.items = [child]
	root.map = {
		"child": child,
	}
	child.child = root

	var report: Dictionary = GFResourceGraphScanner.scan(root)
	var paths: PackedStringArray = GFResourceGraphScanner.collect_paths(root)

	assert_true(GFVariantData.get_option_int(report, "node_count") >= 3, "扫描报告应包含根、子资源和容器节点。")
	assert_true(GFVariantData.get_option_int(report, "cycle_count") >= 1, "资源环应被记录而不是递归爆栈。")
	assert_true(paths.has("child"), "路径列表应包含资源属性路径。")
	assert_true(paths.has("items"), "路径列表应包含数组属性路径。")
	assert_true(paths.has("map"), "路径列表应包含字典属性路径。")
	child.child = null
	root.child = null
	root.items.clear()
	root.map.clear()


func test_raw_resource_artifact_materializes_to_user_path_explicitly() -> void:
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var bytes: PackedByteArray = PackedByteArray([1, 2, 3, 4])
	var _configured: GFRawResourceArtifact = artifact.configure("source/raw.bin", bytes, "application/octet-stream")

	var report: Dictionary = artifact.materialize_temp({
		"directory_path": TEMP_ARTIFACT_DIR,
		"file_name": "raw.bin",
	})
	var materialized_path: String = GFVariantData.get_option_string(report, "path")
	var file: FileAccess = FileAccess.open(materialized_path, FileAccess.READ)
	var read_bytes: PackedByteArray = PackedByteArray()
	if file != null:
		read_bytes = file.get_buffer(int(file.get_length()))
		file.close()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "artifact 应可显式物化到 user://。")
	assert_eq(read_bytes, bytes, "物化后的文件内容应与 artifact 字节一致。")


func test_raw_resource_artifact_rejects_res_path_by_default() -> void:
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var _configured: GFRawResourceArtifact = artifact.configure("source/raw.bin", PackedByteArray([1]))

	var report: Dictionary = artifact.materialize_to_path("res://tests/gf_core/tmp_raw_artifact.bin")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "默认不应写入 res://。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "path_not_allowed")


# --- 私有/辅助方法 ---

func _remove_user_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_absolute_path(absolute_path)


func _remove_absolute_path(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_file_result: Error = DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	var _list_result: Error = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			_remove_absolute_path(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	var _remove_dir_result: Error = DirAccess.remove_absolute(path)


# --- 内部类 ---

class GraphResource:
	extends Resource

	@export var child: Resource = null
	@export var items: Array[Resource] = []
	@export var map: Dictionary = {}
