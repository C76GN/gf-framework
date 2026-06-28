## 测试受根路径约束的源码文本加载器。
extends GutTest


const TEST_ROOT: String = "user://gf_source_text_loader_test"
const TEST_FILE: String = "nested/source.txt"


func before_each() -> void:
	_prepare_test_file("hello source")


func after_each() -> void:
	_remove_file_if_exists(TEST_ROOT.path_join(TEST_FILE))


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


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
