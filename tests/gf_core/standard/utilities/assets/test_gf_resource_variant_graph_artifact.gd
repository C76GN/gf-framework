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


func test_raw_resource_artifact_generates_portable_name_for_unicode_source() -> void:
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var bytes: PackedByteArray = PackedByteArray([1, 2, 3])
	var _configured: GFRawResourceArtifact = artifact.configure(
		"res://数据/补丁.bin",
		bytes
	)

	var report: Dictionary = artifact.materialize_temp({
		"directory_path": TEMP_ARTIFACT_DIR,
		"scan_filesystem": false,
	})
	var materialized_path: String = GFVariantData.get_option_string(
		report,
		"path"
	)
	var generated_file_name: String = materialized_path.get_file()

	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"省略 file_name 时，Unicode source_path 应生成 portable 默认名。"
	)
	assert_true(
		_string_is_ascii(generated_file_name),
		"框架生成的默认 leaf 必须只包含 ASCII。"
	)
	assert_true(
		generated_file_name.ends_with(".bin"),
		"portable 默认名应保留安全的 ASCII 扩展名。"
	)
	assert_true(FileAccess.file_exists(materialized_path))


func test_raw_resource_artifact_bounds_generated_portable_name_length() -> void:
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var _configured: GFRawResourceArtifact = artifact.configure(
		"res://%s.bin" % "a".repeat(400),
		PackedByteArray([1, 2, 3])
	)

	var report: Dictionary = artifact.materialize_temp({
		"directory_path": TEMP_ARTIFACT_DIR,
		"scan_filesystem": false,
	})
	var generated_file_name: String = (
		GFVariantData.get_option_string(report, "path").get_file()
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(
		generated_file_name.to_utf8_buffer().size() <= 255,
		"框架生成的 portable leaf 不得超过常见文件组件硬上限。"
	)
	assert_true(generated_file_name.ends_with(".bin"))


func test_raw_resource_artifact_rejects_nonportable_temp_file_names() -> void:
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var _configured: GFRawResourceArtifact = artifact.configure(
		"source/raw.bin",
		PackedByteArray([1])
	)
	for file_name: String in [
		".",
		"..",
		"child/file.bin",
		"child\\file.bin",
		"CON.txt",
		"补丁.bin",
		"%s.bin" % "a".repeat(256),
	]:
		var report: Dictionary = artifact.materialize_temp({
			"directory_path": TEMP_ARTIFACT_DIR,
			"file_name": file_name,
			"scan_filesystem": false,
		})
		assert_false(
			GFVariantData.get_option_bool(report, "ok"),
			"非 portable leaf 必须在 path_join 前拒绝：%s" % file_name
		)
		assert_eq(
			GFVariantData.get_option_string(report, "reason"),
			"invalid_file_name"
		)
		assert_true(
			GFVariantData.get_option_string(report, "path").is_empty(),
			"非法 leaf 不得泄露一个已归一化到请求目录外的候选路径。"
		)
	assert_false(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(TEMP_ARTIFACT_DIR)
		),
		"非法 file_name 必须在创建目录或文件前失败。"
	)


func test_raw_resource_artifact_uses_bounded_transactional_materialization() -> void:
	var path: String = TEMP_ARTIFACT_DIR.path_join("bounded/raw.bin")
	var artifact: GFRawResourceArtifact = GFRawResourceArtifact.new()
	var _configured: GFRawResourceArtifact = artifact.configure(
		"source/raw.bin",
		PackedByteArray([1, 2, 3, 4])
	)

	var budget_report: Dictionary = artifact.materialize_to_path(path, {
		"max_file_bytes": 3,
		"scan_filesystem": false,
	})
	var committed_report: Dictionary = artifact.materialize_to_path(path, {
		"max_file_bytes": 4,
		"scan_filesystem": false,
	})
	artifact.data = PackedByteArray([9, 9, 9, 9])
	var overwrite_report: Dictionary = artifact.materialize_to_path(path, {
		"overwrite": false,
		"scan_filesystem": false,
	})
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var bytes: PackedByteArray = PackedByteArray()
	if file != null:
		bytes = file.get_buffer(file.get_length())
		file.close()

	assert_false(
		GFVariantData.get_option_bool(budget_report, "ok"),
		"物化应在写入前执行单文件字节预算。"
	)
	assert_true(
		GFVariantData.get_option_bool(committed_report, "ok"),
		"预算内字节应通过框架级产物事务提交。"
	)
	assert_false(
		GFVariantData.get_option_bool(overwrite_report, "ok"),
		"禁止覆盖时不应改写已有产物。"
	)
	assert_eq(bytes, PackedByteArray([1, 2, 3, 4]))


func test_raw_resource_artifact_preserves_transaction_recovery_handle() -> void:
	var artifact: RecoveryRawResourceArtifact = RecoveryRawResourceArtifact.new()
	var _configured: GFRawResourceArtifact = artifact.configure(
		"source/recovery.bin",
		PackedByteArray([7])
	)

	var report: Dictionary = artifact.materialize_to_path(
		TEMP_ARTIFACT_DIR.path_join("recovery.bin"),
		{ "scan_filesystem": false }
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(report, "reason"),
		"write_failed"
	)
	assert_true(
		GFVariantData.get_option_bool(report, "recovery_required"),
		"事务需要恢复时，artifact 报告不得把恢复状态降级成普通写失败。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(report, "recovery_action"),
		GFArtifactWriteTransaction.RECOVERY_ACTION_ROLLBACK,
		"artifact 必须保留被 write_failed 状态遮蔽的稳定恢复动作。"
	)
	var returned_recovery_transaction: Dictionary = (
		GFVariantData.get_option_dictionary(
			report,
			"recovery_transaction"
		)
	)
	assert_true(
		returned_recovery_transaction == artifact.recovery_transaction,
		"opaque 恢复句柄必须原样透传给调用方。"
	)
	returned_recovery_transaction["nonce"] = 99
	assert_eq(
		GFVariantData.get_option_int(
			artifact.recovery_transaction,
			"nonce"
		),
		17,
		"返回报告必须深复制 opaque 句柄，不能共享可变字典。"
	)


# --- 私有/辅助方法 ---

func _string_is_ascii(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true


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


class RecoveryRawResourceArtifact:
	extends GFRawResourceArtifact

	var recovery_transaction: Dictionary = {
		"transaction_id": "opaque-test-transaction",
		"nonce": 17,
	}

	func _commit_materialization(
		_entries: Array[Dictionary],
		_options: Dictionary
	) -> Dictionary:
		return {
			"ok": false,
			"status": &"recovery_required",
			"recovery_required": true,
			"recovery_action": (
				GFArtifactWriteTransaction.RECOVERY_ACTION_ROLLBACK
			),
			"recovery_transaction": recovery_transaction,
		}
