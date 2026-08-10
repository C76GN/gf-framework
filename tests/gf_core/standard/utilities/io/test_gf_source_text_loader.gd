## 测试受根路径约束的源码文本加载器。
extends GutTest


const TEST_ROOT: String = "user://gf_source_text_loader_test"
const TEST_FILE: String = "nested/source.txt"
const INVALID_UTF8_FILE: String = "nested/invalid_utf8.txt"


func before_each() -> void:
	_prepare_test_file("hello source")


func after_each() -> void:
	_remove_file_if_exists(TEST_ROOT.path_join(TEST_FILE))
	_remove_file_if_exists(TEST_ROOT.path_join(INVALID_UTF8_FILE))


func test_registered_text_loads_and_caches_by_logical_key() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var registered: bool = loader.register_text("inline/template", "Hello {{name}}", {
		"origin": "memory",
	})

	var first: Dictionary = loader.load_text("inline/template")
	var second: Dictionary = loader.load_text("inline/template")

	assert_true(registered, "内存文本应能注册。")
	assert_true(GFResultDictionary.is_ok(first), "注册文本应能加载。")
	assert_eq(GFVariantData.get_option_string(first, "text"), "Hello {{name}}", "加载结果应包含文本。")
	assert_false(GFVariantData.get_option_bool(first, "from_cache"), "第一次加载不应来自缓存。")
	assert_true(GFVariantData.get_option_bool(second, "from_cache"), "第二次加载应命中缓存。")


func test_file_load_requires_root_and_rejects_escape() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new(TEST_ROOT)

	var loaded: Dictionary = loader.load_text(TEST_FILE)
	var escaped: Dictionary = loader.resolve_key("../outside.txt")

	assert_true(GFResultDictionary.is_ok(loaded), "root 内文件应能加载。")
	assert_eq(GFVariantData.get_option_string(loaded, "text"), "hello source", "文件文本应按 UTF-8 读取。")
	assert_false(GFResultDictionary.is_ok(escaped), "越过 root_path 的路径应被拒绝。")
	assert_eq(GFVariantData.get_option_string(escaped, GFResultDictionary.KEY_REASON), "path_outside_root", "越界原因应稳定。")


func test_file_size_limit_reports_error() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new(TEST_ROOT, {
		"max_bytes": 2,
	})

	var result: Dictionary = loader.load_text(TEST_FILE)

	assert_false(GFResultDictionary.is_ok(result), "超过 max_bytes 的文本应加载失败。")
	assert_eq(GFVariantData.get_option_string(result, GFResultDictionary.KEY_REASON), "file_too_large", "大小限制原因应稳定。")


func test_cached_text_rechecks_current_max_bytes() -> void:
	var file_loader: GFSourceTextLoader = GFSourceTextLoader.new(TEST_ROOT)
	var file_first: Dictionary = file_loader.load_text(TEST_FILE)
	file_loader.max_bytes = 2
	var file_second: Dictionary = file_loader.load_text(TEST_FILE)

	var registered_loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var _registered: bool = registered_loader.register_text("inline/large", "hello")
	var registered_first: Dictionary = registered_loader.load_text("inline/large")
	registered_loader.max_bytes = 2
	var registered_second: Dictionary = registered_loader.load_text("inline/large")

	var custom_loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var _added: bool = custom_loader.add_custom_loader(_load_virtual_source_text)
	var custom_first: Dictionary = custom_loader.load_text("virtual/source")
	custom_loader.max_bytes = 2
	var custom_second: Dictionary = custom_loader.load_text("virtual/source")

	assert_true(GFResultDictionary.is_ok(file_first), "文件文本第一次加载应成功并进入缓存。")
	assert_false(GFResultDictionary.is_ok(file_second), "降低 max_bytes 后不得复用超限文件缓存。")
	assert_eq(
		GFVariantData.get_option_string(file_second, GFResultDictionary.KEY_REASON),
		"text_too_large",
		"文件缓存超限原因应稳定。"
	)
	assert_true(GFResultDictionary.is_ok(registered_first), "注册文本第一次加载应成功并进入缓存。")
	assert_false(GFResultDictionary.is_ok(registered_second), "降低 max_bytes 后不得复用超限注册文本缓存。")
	assert_eq(
		GFVariantData.get_option_string(registered_second, GFResultDictionary.KEY_REASON),
		"text_too_large",
		"缓存超限原因应稳定。"
	)
	assert_true(GFResultDictionary.is_ok(custom_first), "自定义文本第一次加载应成功并进入缓存。")
	assert_false(GFResultDictionary.is_ok(custom_second), "降低 max_bytes 后不得复用超限自定义缓存。")
	assert_eq(
		GFVariantData.get_option_string(custom_second, GFResultDictionary.KEY_REASON),
		"text_too_large",
		"自定义缓存超限原因应稳定。"
	)


func test_file_and_custom_byte_sources_reject_invalid_utf8() -> void:
	var invalid_bytes: PackedByteArray = PackedByteArray([0x66, 0x80, 0x6f])
	_prepare_test_bytes(INVALID_UTF8_FILE, invalid_bytes)
	var file_loader: GFSourceTextLoader = GFSourceTextLoader.new(TEST_ROOT)
	var file_result: Dictionary = file_loader.load_text(INVALID_UTF8_FILE)

	var custom_loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var _added: bool = custom_loader.add_custom_loader(_load_invalid_virtual_source_bytes)
	var custom_result: Dictionary = custom_loader.load_text("virtual/invalid-bytes")

	assert_false(GFResultDictionary.is_ok(file_result), "文件字节不是严格 UTF-8 时应拒绝。")
	assert_eq(
		GFVariantData.get_option_string(file_result, GFResultDictionary.KEY_REASON),
		"invalid_utf8",
		"文件 UTF-8 失败原因应稳定。"
	)
	assert_false(GFResultDictionary.is_ok(custom_result), "自定义 loader 的非法 UTF-8 字节也应拒绝。")
	assert_eq(
		GFVariantData.get_option_string(custom_result, GFResultDictionary.KEY_REASON),
		"invalid_utf8",
		"自定义字节 UTF-8 失败原因应稳定。"
	)


func test_custom_loader_loads_virtual_text_and_caches_by_key() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var added: bool = loader.add_custom_loader(_load_virtual_source_text, {
		"origin": "virtual",
	})

	var first: Dictionary = loader.load_text("virtual/source")
	var second: Dictionary = loader.load_text("virtual/source")
	var entry_metadata: Dictionary = GFVariantData.get_option_dictionary(first, "entry_metadata")

	assert_true(added, "有效 Callable 应能注册为自定义 loader。")
	assert_true(GFResultDictionary.is_ok(first), "自定义 loader 应能加载虚拟文本。")
	assert_eq(GFVariantData.get_option_string(first, "text"), "hello virtual", "加载结果应使用自定义 loader 返回的文本。")
	assert_true(GFVariantData.get_option_bool(first, "custom_loader"), "结果应标记来自自定义 loader。")
	assert_false(GFVariantData.get_option_bool(first, "from_cache"), "第一次自定义加载不应来自缓存。")
	assert_true(GFVariantData.get_option_bool(second, "from_cache"), "第二次相同 key 应命中自定义加载缓存。")
	assert_eq(GFVariantData.get_option_string(entry_metadata, "origin"), "virtual", "loader 元数据应进入结果。")


func test_custom_loader_can_return_utf8_bytes() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var _added: bool = loader.add_custom_loader(_load_virtual_source_bytes)

	var result: Dictionary = loader.load_text("virtual/bytes")

	assert_true(GFResultDictionary.is_ok(result), "自定义 loader 应支持 UTF-8 字节结果。")
	assert_eq(GFVariantData.get_option_string(result, "text"), "bytes 文本", "多字节结果应按严格 UTF-8 转为文本。")


func test_custom_loader_can_decline_and_fall_back_to_file() -> void:
	var loader: GFSourceTextLoader = GFSourceTextLoader.new(TEST_ROOT)
	var _added: bool = loader.add_custom_loader(_decline_source_text)

	var result: Dictionary = loader.load_text(TEST_FILE)

	assert_true(GFResultDictionary.is_ok(result), "自定义 loader 未处理时应继续回退到文件加载。")
	assert_eq(GFVariantData.get_option_string(result, "text"), "hello source", "回退后应读取 root 内文件。")
	assert_false(GFVariantData.get_option_bool(result, "custom_loader"), "文件回退结果不应标记为自定义 loader。")


# --- 私有/辅助方法 ---

func _prepare_test_file(text: String) -> void:
	var directory: String = ProjectSettings.globalize_path(TEST_ROOT.path_join("nested"))
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(TEST_ROOT.path_join(TEST_FILE), FileAccess.WRITE)
	assert_not_null(file, "测试文件应能创建。")
	if file == null:
		return
	var _store_result: Variant = file.store_string(text)
	file.close()


func _prepare_test_bytes(relative_path: String, bytes: PackedByteArray) -> void:
	var directory: String = ProjectSettings.globalize_path(TEST_ROOT.path_join(relative_path.get_base_dir()))
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(TEST_ROOT.path_join(relative_path), FileAccess.WRITE)
	assert_not_null(file, "测试字节文件应能创建。")
	if file == null:
		return
	var _store_buffer_result: Variant = file.store_buffer(bytes)
	file.close()


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _load_virtual_source_text(source_key: String, context: Dictionary) -> Dictionary:
	if source_key != "virtual/source":
		return { "handled": false }
	return {
		"handled": true,
		"text": "hello virtual",
		"resolved_path": "virtual://source",
		"metadata": GFVariantData.get_option_dictionary(context, "loader_metadata"),
	}


func _load_virtual_source_bytes(source_key: String, _context: Dictionary) -> Dictionary:
	if source_key != "virtual/bytes":
		return { "handled": false }
	return {
		"handled": true,
		"bytes": "bytes 文本".to_utf8_buffer(),
		"resolved_path": "virtual://bytes",
	}


func _load_invalid_virtual_source_bytes(source_key: String, _context: Dictionary) -> Dictionary:
	if source_key != "virtual/invalid-bytes":
		return { "handled": false }
	return {
		"handled": true,
		"bytes": PackedByteArray([0x66, 0x80, 0x6f]),
		"resolved_path": "virtual://invalid-bytes",
	}


func _decline_source_text(_source_key: String, _context: Dictionary) -> Dictionary:
	return { "handled": false }
