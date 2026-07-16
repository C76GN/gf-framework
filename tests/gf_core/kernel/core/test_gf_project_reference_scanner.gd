## 测试 GFProjectReferenceScanner 的项目引用扫描契约。
extends GutTest


class BinaryReferenceResource:
	extends Resource

	@export var dependency: Resource


# --- 测试用例 ---

func test_scans_one_file_against_multiple_targets() -> void:
	var directory: String = "user://gf_project_reference_scanner_multi"
	var path: String = directory.path_join("references.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		'const First = preload("res://addons/author/first/runtime/tool.gd")',
		'const Second = preload("res://addons/author/second/runtime/tool.gd")',
	]))

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "author.first",
			"root_path": "res://addons/author/first",
			"class_names": [],
		},
		{
			"id": "author.second",
			"root_path": "res://addons/author/second",
			"class_names": [],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_target": 10,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var targets: Dictionary = _option_dictionary(report, "targets")
	assert_false(_option_bool(report, "ok"), "存在 strong 引用时扫描报告应失败。")
	assert_eq(_option_int(report, "input_target_count"), 2, "扫描报告应保留目标数量。")
	assert_eq(_option_int(report, "target_count"), 2, "两个目标被引用时都应进入 target 报告。")
	assert_eq(_option_int(report, "reference_count"), 2, "单个文件内的两个目标引用都应被记录。")
	assert_eq(_option_int(report, "scanned_file_count"), 1, "同一文件应只读取一次再匹配所有目标。")
	assert_true(targets.has(&"author.first"), "报告应包含第一个目标。")
	assert_true(targets.has(&"author.second"), "报告应包含第二个目标。")


func test_budget_exceeded_returns_partial_fail_closed_report() -> void:
	var directory: String = "user://gf_project_reference_scanner_budget"
	var path: String = directory.path_join("large_reference.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, 'const First = preload("res://addons/author/first/runtime/tool.gd")')

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "author.first",
			"root_path": "res://addons/author/first",
			"class_names": [],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_file_bytes": 16,
		"max_total_bytes": 1024,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	var skipped_files: Array = _option_array(report, "skipped_files")
	assert_false(_option_bool(report, "ok"), "预算耗尽时不能把不完整扫描报告为 ok。")
	assert_true(_option_bool(report, "partial_scan"), "预算耗尽应明确标记 partial_scan。")
	assert_true(_option_bool(report, "budget_exceeded"), "单文件超限应进入 budget_exceeded。")
	assert_eq(_option_int(report, "reference_count"), 0, "未读取的文件不应产生伪引用。")
	assert_eq(_option_int(report, "scanned_file_count"), 0, "超过单文件预算时不应读取正文。")
	assert_eq(skipped_files.size(), 1, "被预算跳过的文件应进入 skipped_files。")
	assert_push_warning("[GFProjectReferenceScanner] 引用扫描达到 max_file_bytes=16 字节预算，后续结果按 partial_scan 处理：%s。" % path)


func test_weak_text_references_do_not_block_report() -> void:
	var directory: String = "user://gf_project_reference_scanner_weak"
	var path: String = directory.path_join("weak_text.gd")
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		'# preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")',
		'var path_text: String = "res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd"',
		'var class_text: String = "GFSaveGraphUtility"',
	]))

	var report: Dictionary = GFProjectReferenceScanner.scan_references([
		{
			"id": "gf.extension.save",
			"root_path": "res://addons/gf/extensions/save",
			"class_names": ["GFSaveGraphUtility"],
		},
	], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"include_weak_references": true,
		"max_references_per_target": 10,
		"max_weak_references_per_target": 10,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_true(_option_bool(report, "ok"), "只有弱文本命中时扫描报告应保持 ok。")
	assert_eq(_option_int(report, "reference_count"), 0, "弱文本命中不应计入阻断引用。")
	assert_eq(_option_int(report, "weak_reference_count"), 2, "普通字符串路径和 class_name 应进入弱引用报告。")


func test_binary_res_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_res"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("target.res")
	var consumer_path: String = consumer_directory.path_join("consumer.res")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_directory)
	)
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(consumer_directory)
	)
	var target: Resource = Resource.new()
	assert_eq(ResourceSaver.save(target, target_path), OK, "测试应能保存目标二进制资源。")
	var consumer: BinaryReferenceResource = BinaryReferenceResource.new()
	consumer.dependency = ResourceLoader.load(target_path)
	assert_not_null(consumer.dependency, "测试应能加载目标二进制资源。")
	assert_eq(ResourceSaver.save(consumer, consumer_path), OK, "测试应能保存引用目标的 .res。")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "binary.res.target",
		"root_path": target_directory,
		"class_names": [],
	}], {
		"scan_roots": [consumer_directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var references: Array = _option_array(report, "references")

	consumer.dependency = null
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "二进制 .res 依赖必须阻断目标移除。")
	assert_eq(references.size(), 1, "二进制 .res 依赖应生成一条引用记录。")
	if references.size() == 1:
		assert_eq(_option_string(references[0], "strength"), "verified", "二进制依赖应由 Godot 依赖图验证。")
		assert_eq(_option_string(references[0], "source"), "godot_dependency", "二进制依赖应记录依赖图来源。")


func test_binary_scn_dependency_is_reported_as_verified_reference() -> void:
	var directory: String = "user://gf_project_reference_scanner_binary_scn"
	var target_directory: String = directory.path_join("target")
	var consumer_directory: String = directory.path_join("consumer")
	var target_path: String = target_directory.path_join("texture.res")
	var consumer_path: String = consumer_directory.path_join("consumer.scn")
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_directory)
	)
	var _make_consumer_dir_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(consumer_directory)
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	assert_eq(ResourceSaver.save(texture, target_path), OK, "测试应能保存场景依赖纹理。")
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = ResourceLoader.load(target_path)
	assert_not_null(sprite.texture, "测试应能加载场景依赖纹理。")
	var packed_scene: PackedScene = PackedScene.new()
	assert_eq(packed_scene.pack(sprite), OK, "测试应能打包二进制场景。")
	assert_eq(ResourceSaver.save(packed_scene, consumer_path), OK, "测试应能保存 .scn。")

	var report: Dictionary = GFProjectReferenceScanner.scan_references([{
		"id": "binary.scn.target",
		"root_path": target_directory,
		"class_names": [],
	}], {
		"scan_roots": [consumer_directory],
		"ignored_roots": [],
		"use_resource_dependencies": true,
	})
	var references: Array = _option_array(report, "references")

	sprite.free()
	_remove_path_if_exists(consumer_path)
	_remove_path_if_exists(target_path)
	_remove_path_if_exists(consumer_directory)
	_remove_path_if_exists(target_directory)
	_remove_path_if_exists(directory)

	assert_false(_option_bool(report, "ok"), "二进制 .scn 依赖必须阻断目标移除。")
	assert_eq(references.size(), 1, "二进制 .scn 依赖应生成一条引用记录。")
	if references.size() == 1:
		assert_eq(_option_string(references[0], "strength"), "verified", "二进制场景依赖应由 Godot 依赖图验证。")
		assert_eq(_option_string(references[0], "source"), "godot_dependency", "二进制场景依赖应记录依赖图来源。")


# --- 私有/辅助方法 ---

func _write_text_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时文本文件。")
	if file == null:
		return
	var _store_string_result: Variant = file.store_string(text)
	file.close()


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)


func _option_bool(options: Dictionary, key: String, default_value: bool = false) -> bool:
	if options.has(key) and options[key] is bool:
		var bool_value: bool = options[key]
		return bool_value
	return default_value


func _option_int(options: Dictionary, key: String, default_value: int = 0) -> int:
	if options.has(key) and options[key] is int:
		var int_value: int = options[key]
		return int_value
	return default_value


func _option_array(options: Dictionary, key: String) -> Array:
	if options.has(key) and options[key] is Array:
		var array_value: Array = options[key]
		return array_value
	return []


func _option_dictionary(options: Dictionary, key: String) -> Dictionary:
	if options.has(key) and options[key] is Dictionary:
		var dictionary_value: Dictionary = options[key]
		return dictionary_value
	return {}


func _option_string(options: Dictionary, key: String, default_value: String = "") -> String:
	if options.has(key) and (options[key] is String or options[key] is StringName):
		return String(options[key])
	return default_value
