## 测试 GFPathTools 的纯字符串路径规范化、相对路径和排除匹配。
extends GutTest


# --- 测试用例 ---

func test_normalize_root_path_trims_backslashes_and_trailing_slash() -> void:
	var normalized_path: String = GFPathTools.normalize_root_path("res://content\\packs\\base/")

	assert_eq(normalized_path, "res://content/packs/base", "根目录路径应统一斜杠并移除尾随斜杠。")


func test_normalize_root_paths_removes_empty_values_and_duplicates() -> void:
	var normalized_paths: PackedStringArray = GFPathTools.normalize_root_paths(PackedStringArray([
		"res://content\\packs\\base/",
		"res://content/packs/base",
		"",
		"res://content/packs/extra/",
	]), false)

	assert_eq(
		Array(normalized_paths),
		["res://content/packs/base", "res://content/packs/extra"],
		"根目录路径集合应统一斜杠、移除空值并按首次出现顺序去重。"
	)


func test_make_relative_path_returns_path_under_base() -> void:
	var relative_path: String = GFPathTools.make_relative_path(
		"res://content/packs/base/assets/icon.tres",
		"res://content/packs/base/"
	)

	assert_eq(relative_path, "assets/icon.tres", "位于 base_path 下的路径应转换为相对路径。")


func test_is_path_under_root_rejects_parent_escape() -> void:
	var under_root: bool = GFPathTools.is_path_under_root(
		"res://content/packs/base/../escape.tres",
		"res://content/packs/base"
	)

	assert_false(under_root, "包含 .. 的路径简化后越过 root 时应被拒绝。")


func test_is_path_excluded_matches_child_directories() -> void:
	var excluded_paths: PackedStringArray = PackedStringArray(["res://addons", "res://cache"])
	var is_excluded: bool = GFPathTools.is_path_excluded(
		"res://addons/gf/plugin.cfg",
		excluded_paths
	)

	assert_true(is_excluded, "排除目录的子路径也应被视为命中。")
