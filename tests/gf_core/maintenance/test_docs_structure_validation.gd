## 验证 Read the Docs / MkDocs 文档结构保持稳定。
extends GutTest


# --- 常量 ---

const DOCS_ROOT: String = "res://docs/zh"
const WIKI_ROOT: String = "res://docs/wiki"
const MKDOCS_CONFIG_PATH: String = "res://mkdocs.yml"
const README_EN_PATH: String = "res://README.md"
const README_ZH_PATH: String = "res://README.zh.md"
const ADDON_README_PATH: String = "res://addons/gf/README.md"
const DOCS_DIRECTORY_FIXTURE_ROOT: String = "user://gf_docs_structure_directory_fixture"
const READTHEDOCS_URL: String = "https://gf-framework.readthedocs.io/"
const MAX_MKDOCS_NAV_ITEMS: int = 100
const MAX_MKDOCS_NAV_DEPTH: int = 4
const MAX_API_MODULE_REFERENCE_LINES: int = 1000
const WIKI_ENTRY_FILES: Array[String] = ["Home.md", "_Sidebar.md", "_Footer.md"]
const DOCS_TOP_LEVEL_FILES: Array[String] = ["index.md", "faq.md", "changelog.md"]
const DOCS_TOP_LEVEL_DIRECTORIES: Array[String] = [
	"overview",
	"kernel",
	"standard",
	"extensions",
	"editor",
	"reference",
]
const REQUIRED_MKDOCS_NOT_IN_NAV_PATTERNS: Array[String] = [
	"reference/api/classes/*.md",
	"reference/api/autoloads/*.md",
	"overview/**/*.md",
	"kernel/**/*.md",
	"standard/**/*.md",
	"extensions/**/*.md",
	"editor/*.md",
]


# --- 测试用例 ---

func test_chinese_doc_pages_are_reachable_from_mkdocs_nav() -> void:
	var docs_paths: Array[String] = _collect_markdown_files(DOCS_ROOT)
	var mkdocs_source: String = _read_text(MKDOCS_CONFIG_PATH)
	var nav_paths: Array[String] = _collect_markdown_paths_from_text(mkdocs_source)
	var reachable_paths: Array[String] = _collect_reachable_doc_pages(nav_paths)

	var issues: Array[String] = []
	for path: String in docs_paths:
		var relative_path: String = path.trim_prefix(DOCS_ROOT + "/")
		if _is_generated_api_reference_detail_page(relative_path):
			continue
		if not reachable_paths.has(relative_path):
			issues.append("%s is not reachable from mkdocs.yml nav" % relative_path)

	assert_eq(issues, [], "`docs/zh` 中的正式页面应能从 mkdocs.yml 导航入口通过文档链接访问：\n%s" % _join_lines(issues))


func test_mkdocs_nav_paths_exist() -> void:
	var mkdocs_source: String = _read_text(MKDOCS_CONFIG_PATH)
	var nav_paths: Array[String] = _collect_markdown_paths_from_text(mkdocs_source)

	var issues: Array[String] = []
	for relative_path: String in nav_paths:
		var docs_path: String = DOCS_ROOT.path_join(relative_path)
		if not FileAccess.file_exists(docs_path):
			issues.append("%s points to missing file" % relative_path)

	assert_eq(issues, [], "`mkdocs.yml` 导航中引用的页面必须存在：\n%s" % _join_lines(issues))


func test_mkdocs_nav_labels_are_not_garbled() -> void:
	var mkdocs_source: String = _read_text(MKDOCS_CONFIG_PATH)
	var nav_lines: Array[String] = _collect_mkdocs_nav_lines(mkdocs_source)

	var issues: Array[String] = []
	for line: String in nav_lines:
		var label: String = _extract_mkdocs_nav_label(line)
		if label.is_empty():
			continue
		if label.contains("?"):
			issues.append("mkdocs.yml nav label appears garbled: %s" % label)

	assert_eq(issues, [], "Read the Docs 导航标题必须保持 UTF-8 文本，不能退化成问号占位：\n%s" % _join_lines(issues))


func test_mkdocs_nav_stays_at_entry_level() -> void:
	var mkdocs_source: String = _read_text(MKDOCS_CONFIG_PATH)
	var nav_metrics: Dictionary = _collect_mkdocs_nav_metrics(mkdocs_source)
	var item_count: int = GFVariantData.to_int(nav_metrics.get("item_count", 0), 0)
	var max_depth: int = GFVariantData.to_int(nav_metrics.get("max_depth", 0), 0)

	var issues: Array[String] = []
	if item_count > MAX_MKDOCS_NAV_ITEMS:
		issues.append("mkdocs.yml nav has %d items; expected <= %d" % [item_count, MAX_MKDOCS_NAV_ITEMS])
	if max_depth > MAX_MKDOCS_NAV_DEPTH:
		issues.append("mkdocs.yml nav depth is %d; expected <= %d" % [max_depth, MAX_MKDOCS_NAV_DEPTH])
	for pattern: String in REQUIRED_MKDOCS_NOT_IN_NAV_PATTERNS:
		if not mkdocs_source.contains(pattern):
			issues.append("mkdocs.yml not_in_nav is missing `%s`" % pattern)

	assert_eq(issues, [], "Read the Docs 左侧导航只应保留主入口、专题总览和参考索引：\n%s" % _join_lines(issues))


func test_generated_api_reference_uses_split_owner_pages() -> void:
	var api_root: String = DOCS_ROOT.path_join("reference/api")
	var api_paths: Array[String] = _collect_markdown_files(api_root)

	var issues: Array[String] = []
	if not FileAccess.file_exists(api_root.path_join("classes/index.md")):
		issues.append("reference/api/classes/index.md is missing")
	else:
		var class_index_text: String = _read_text(api_root.path_join("classes/index.md"))
		if not class_index_text.contains("\n## 模块概览\n"):
			issues.append("reference/api/classes/index.md must expose a module summary")
		if not class_index_text.contains("\n## 模块索引\n"):
			issues.append("reference/api/classes/index.md must group classes by module")
		if not class_index_text.contains("\n### Standard\n"):
			issues.append("reference/api/classes/index.md must include module sections")
		if not class_index_text.contains("| 类 | 类别 | 继承 | 成员 | 源文件 |"):
			issues.append("reference/api/classes/index.md must expose category and member count columns")
		if not class_index_text.contains("运行时服务 (`runtime_service`)"):
			issues.append("reference/api/classes/index.md must keep readable category labels")

	var autoload_index_page: String = api_root.path_join("autoloads/index.md")
	if not FileAccess.file_exists(autoload_index_page):
		issues.append("reference/api/autoloads/index.md is missing")
	else:
		var autoload_index_text: String = _read_text(autoload_index_page)
		if not autoload_index_text.contains("| AutoLoad | 模块 | 包 | 继承 | 成员 | 源文件 |"):
			issues.append("reference/api/autoloads/index.md must expose owner identity and package columns")
		if not autoload_index_text.contains("[`Gf`](Gf.md)"):
			issues.append("reference/api/autoloads/index.md must link the controlled Gf owner page")

	var behavior_tree_page: String = api_root.path_join("classes/GFBehaviorTree.md")
	if FileAccess.file_exists(behavior_tree_page):
		var behavior_tree_text: String = _read_text(behavior_tree_page)
		if not behavior_tree_text.contains("\n## 内部类概览\n"):
			issues.append("GFBehaviorTree.md must expose an inner class summary")
		if not behavior_tree_text.contains("\n## 内部类详情\n"):
			issues.append("GFBehaviorTree.md must separate inner class details from summary")
	else:
		issues.append("GFBehaviorTree.md is missing")

	for path: String in api_paths:
		var relative_path: String = path.trim_prefix(DOCS_ROOT + "/")
		if relative_path == "reference/api/index.md" or _is_generated_api_reference_detail_page(relative_path):
			continue

		var text: String = _read_text(path)
		var line_count: int = text.split("\n").size()
		if line_count > MAX_API_MODULE_REFERENCE_LINES:
			issues.append("%s has %d lines; module API pages should stay as indexes" % [relative_path, line_count])
		if text.contains("\n### `") or text.contains("\n#### `"):
			issues.append("%s appears to contain member detail headings; details belong under an API owner detail directory" % relative_path)

	assert_eq(issues, [], "API Reference 应保持模块索引 + owner 详情页结构：\n%s" % _join_lines(issues))


func test_docs_use_semantic_directories_matching_navigation() -> void:
	var dir: DirAccess = DirAccess.open(DOCS_ROOT)
	assert_not_null(dir, "应能打开 docs/zh。")
	if dir == null:
		return

	var issues: Array[String] = []
	var _list_dir_begin_result_61: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		if dir.current_is_dir():
			if _is_numbered_slug(entry):
				issues.append("%s should be renamed to semantic layer directory" % entry)
			elif not DOCS_TOP_LEVEL_DIRECTORIES.has(entry):
				issues.append("%s is not an allowed docs/zh top-level directory" % entry)
		elif entry.ends_with(".md") and not DOCS_TOP_LEVEL_FILES.has(entry):
			issues.append("%s should live under a semantic docs directory" % entry)
		entry = dir.get_next()
	dir.list_dir_end()

	assert_eq(issues, [], "docs/zh 顶层必须保持语义目录，并与 Read the Docs 导航分组一致：\n%s" % _join_lines(issues))


func test_doc_directories_have_index_pages() -> void:
	var dirs: Array[String] = _collect_directories(DOCS_ROOT)

	var issues: Array[String] = []
	for dir_path: String in dirs:
		var index_path: String = dir_path.path_join("index.md")
		if not FileAccess.file_exists(index_path):
			issues.append("%s has no index.md" % dir_path.trim_prefix(DOCS_ROOT + "/"))

	assert_eq(issues, [], "每个文档目录都应提供 index.md 作为该组导读：\n%s" % _join_lines(issues))


func test_doc_directory_collection_ignores_empty_directories() -> void:
	_remove_directory_tree(DOCS_DIRECTORY_FIXTURE_ROOT)
	var empty_dir: String = DOCS_DIRECTORY_FIXTURE_ROOT.path_join("empty")
	var content_parent: String = DOCS_DIRECTORY_FIXTURE_ROOT.path_join("content")
	var content_dir: String = content_parent.path_join("nested")
	var empty_create_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(empty_dir)
	)
	assert_eq(empty_create_result, OK, "测试应能创建空文档目录。")
	_write_text(content_dir.path_join("page.md"), "# Fixture\n")

	var dirs: Array[String] = _collect_directories(DOCS_DIRECTORY_FIXTURE_ROOT)
	assert_false(dirs.has(empty_dir), "没有 Markdown 内容的空目录不应成为文档结构输入。")
	assert_has(dirs, content_parent, "包含 Markdown 后代的父目录应保留。")
	assert_has(dirs, content_dir, "直接包含 Markdown 的目录应保留。")
	_remove_directory_tree(DOCS_DIRECTORY_FIXTURE_ROOT)


func test_doc_index_pages_link_direct_child_pages() -> void:
	var dirs: Array[String] = _collect_directories(DOCS_ROOT)
	dirs.append(DOCS_ROOT)
	dirs.sort()

	var issues: Array[String] = []
	for dir_path: String in dirs:
		var index_path: String = dir_path.path_join("index.md")
		if not FileAccess.file_exists(index_path):
			continue

		var index_relative_path: String = index_path.trim_prefix(DOCS_ROOT + "/")
		var linked_paths: Array[String] = _collect_markdown_link_targets(index_relative_path, _read_text(index_path))
		for child_relative_path: String in _collect_direct_child_doc_entries(dir_path):
			if _is_generated_api_reference_detail_page(child_relative_path):
				continue
			if not linked_paths.has(child_relative_path):
				issues.append("%s does not link direct child %s" % [index_relative_path, child_relative_path])

	assert_eq(issues, [], "压缩导航后，每个目录 index.md 必须直接链接自己的子页或子目录入口：\n%s" % _join_lines(issues))


func test_legacy_wiki_entry_files_point_to_readthedocs() -> void:
	var issues: Array[String] = []
	for file_name: String in WIKI_ENTRY_FILES:
		var path: String = WIKI_ROOT.path_join(file_name)
		if not FileAccess.file_exists(path):
			issues.append("%s is missing" % path)
			continue

		var text: String = _read_text(path)
		if not text.contains(READTHEDOCS_URL):
			issues.append("%s must link to Read the Docs" % path)

	assert_eq(issues, [], "旧 GitHub Wiki 入口文件必须指向 Read the Docs：\n%s" % _join_lines(issues))


func test_legacy_wiki_contains_only_entry_files() -> void:
	var wiki_paths: Array[String] = _collect_markdown_files(WIKI_ROOT)
	var issues: Array[String] = []
	for path: String in wiki_paths:
		if not WIKI_ENTRY_FILES.has(path.get_file()):
			issues.append("%s should be removed; legacy Wiki keeps entry files only" % path)

	assert_eq(issues, [], "旧 GitHub Wiki 只保留 Home、Sidebar 和 Footer，不再保留章节兼容页：\n%s" % _join_lines(issues))


func test_readme_language_switches_and_doc_links_are_present() -> void:
	var english_readme: String = _read_text(README_EN_PATH)
	var chinese_readme: String = _read_text(README_ZH_PATH)
	var addon_readme: String = _read_text(ADDON_README_PATH)

	var issues: Array[String] = []
	if not english_readme.contains("English | [简体中文](README.zh.md)"):
		issues.append("README.md must link to README.zh.md")
	if not chinese_readme.contains("[English](README.md) | 简体中文"):
		issues.append("README.zh.md must link back to README.md")
	if (
		not addon_readme.contains("https://github.com/C76GN/gf-framework/blob/main/README.md")
		or not addon_readme.contains("https://github.com/C76GN/gf-framework/blob/main/README.zh.md")
	):
		issues.append("addons/gf/README.md must point to both repository README languages with distributable HTTPS links")
	if addon_readme.contains("](../"):
		issues.append("addons/gf/README.md must not depend on files outside the distributable addon")

	var required_fragments: Array[String] = [
		READTHEDOCS_URL,
		"addons/gf/kernel",
		"addons/gf/standard",
		"addons/gf/extensions",
		"GF Extensions",
		"tests/gf_core/maintenance",
	]
	for fragment: String in required_fragments:
		if not english_readme.contains(fragment):
			issues.append("README.md is missing `%s`" % fragment)
		if not chinese_readme.contains(fragment):
			issues.append("README.zh.md is missing `%s`" % fragment)

	assert_eq(issues, [], "README 中英文入口、分层说明和正式文档链接必须保持同步：\n%s" % _join_lines(issues))


# --- 私有/辅助方法 ---

func _collect_markdown_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	_collect_markdown_files_recursive(root_path, result)
	result.sort()
	return result


func _collect_directories(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var _root_has_markdown: bool = _collect_directories_recursive(root_path, result)
	result.sort()
	return result


func _collect_markdown_files_recursive(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_169: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var child_path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_markdown_files_recursive(child_path, result)
		elif entry.ends_with(".md"):
			result.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _collect_directories_recursive(root_path: String, result: Array[String]) -> bool:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return false

	var has_markdown: bool = false
	var _list_dir_begin_result_187: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			var child_path: String = root_path.path_join(entry)
			var child_has_markdown: bool = _collect_directories_recursive(child_path, result)
			if child_has_markdown:
				result.append(child_path)
				has_markdown = true
		elif entry.ends_with(".md"):
			has_markdown = true
		entry = dir.get_next()
	dir.list_dir_end()
	return has_markdown


func _write_text(path: String, text: String) -> void:
	var create_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	assert_eq(create_result, OK, "测试应能创建文档夹具目录。")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入文档夹具。")
	if file == null:
		return
	var _store_string_result: bool = file.store_string(text)


func _remove_directory_tree(root_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		var _remove_file_result: Error = DirAccess.remove_absolute(absolute_path.path_join(file_name))
	for directory_name: String in directory.get_directories():
		_remove_directory_tree(root_path.path_join(directory_name))
	var _remove_dir_result: Error = DirAccess.remove_absolute(absolute_path)


func _collect_direct_child_doc_entries(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result

	var _list_dir_begin_result_200: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			var child_index_path: String = child_path.path_join("index.md")
			if FileAccess.file_exists(child_index_path):
				result.append(child_index_path.trim_prefix(DOCS_ROOT + "/"))
		elif entry.ends_with(".md") and entry != "index.md":
			result.append(child_path.trim_prefix(DOCS_ROOT + "/"))
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _collect_markdown_paths_from_text(text: String) -> Array[String]:
	var result: Array[String] = []
	var regex: RegEx = RegEx.new()
	var _compile_result_201: Variant = regex.compile("([A-Za-z0-9_./-]+\\.md)")
	for match_result: RegExMatch in regex.search_all(text):
		var path: String = match_result.get_string(1)
		if not result.has(path):
			result.append(path)
	result.sort()
	return result


func _collect_mkdocs_nav_lines(text: String) -> Array[String]:
	var result: Array[String] = []
	var in_nav_block: bool = false

	for line: String in text.split("\n"):
		if line == "nav:":
			in_nav_block = true
			continue
		if not in_nav_block:
			continue
		if line.strip_edges().is_empty():
			continue
		if not line.begins_with(" "):
			break
		if line.strip_edges().begins_with("- "):
			result.append(line)

	return result


func _extract_mkdocs_nav_label(line: String) -> String:
	var stripped: String = line.strip_edges()
	if not stripped.begins_with("- "):
		return ""

	var item: String = stripped.trim_prefix("- ").strip_edges()
	var colon_index: int = item.find(":")
	if colon_index < 0:
		return ""
	return item.substr(0, colon_index).strip_edges()


func _collect_mkdocs_nav_metrics(text: String) -> Dictionary:
	var item_count: int = 0
	var max_depth: int = 0
	var in_nav_block: bool = false

	for line: String in text.split("\n"):
		if line == "nav:":
			in_nav_block = true
			continue
		if not in_nav_block:
			continue
		if line.strip_edges().is_empty():
			continue
		if not line.begins_with(" "):
			break

		var stripped: String = line.strip_edges()
		if not stripped.begins_with("- "):
			continue

		var indent: int = _count_leading_spaces(line)
		var depth: int = floori(float(maxi(indent - 2, 0)) / 4.0) + 1
		item_count += 1
		max_depth = maxi(max_depth, depth)

	return {
		"item_count": item_count,
		"max_depth": max_depth,
	}


func _collect_reachable_doc_pages(seed_paths: Array[String]) -> Array[String]:
	var reachable_paths: Array[String] = []
	var queued_paths: Array[String] = []
	for path: String in seed_paths:
		if not queued_paths.has(path):
			queued_paths.append(path)

	var cursor: int = 0
	while cursor < queued_paths.size():
		var relative_path: String = queued_paths[cursor]
		cursor += 1
		if reachable_paths.has(relative_path):
			continue

		reachable_paths.append(relative_path)
		if _is_generated_api_reference_detail_page(relative_path):
			continue

		var doc_path: String = DOCS_ROOT.path_join(relative_path)
		if not FileAccess.file_exists(doc_path):
			continue

		for linked_path: String in _collect_markdown_link_targets(relative_path, _read_text(doc_path)):
			if reachable_paths.has(linked_path) or queued_paths.has(linked_path):
				continue
			queued_paths.append(linked_path)

	reachable_paths.sort()
	return reachable_paths


func _collect_markdown_link_targets(source_relative_path: String, text: String) -> Array[String]:
	var result: Array[String] = []
	var regex: RegEx = RegEx.new()
	var _compile_result_248: Variant = regex.compile("(?<!!)\\[[^\\]\\n]+\\]\\(([^)\\n]+)\\)")
	for match_result: RegExMatch in regex.search_all(text):
		var target_path: String = _normalize_markdown_link_target(source_relative_path, match_result.get_string(1))
		if target_path.is_empty() or result.has(target_path):
			continue
		result.append(target_path)
	result.sort()
	return result


func _normalize_markdown_link_target(source_relative_path: String, target: String) -> String:
	var clean_target: String = target.strip_edges()
	if clean_target.begins_with("<") and clean_target.ends_with(">"):
		clean_target = clean_target.substr(1, clean_target.length() - 2)
	if clean_target.is_empty() or clean_target.begins_with("#") or _is_external_link(clean_target):
		return ""

	var fragment_index: int = clean_target.find("#")
	if fragment_index >= 0:
		clean_target = clean_target.substr(0, fragment_index)
	var query_index: int = clean_target.find("?")
	if query_index >= 0:
		clean_target = clean_target.substr(0, query_index)

	if clean_target.is_empty() or not clean_target.ends_with(".md"):
		return ""
	if clean_target.begins_with("/"):
		clean_target = clean_target.trim_prefix("/")

	var base_dir: String = source_relative_path.get_base_dir()
	var normalized_path: String = clean_target
	if not base_dir.is_empty() and base_dir != ".":
		normalized_path = base_dir.path_join(clean_target)
	normalized_path = normalized_path.simplify_path().trim_prefix("./")
	if normalized_path.begins_with("../"):
		return ""
	if not FileAccess.file_exists(DOCS_ROOT.path_join(normalized_path)):
		return ""
	return normalized_path


func _is_external_link(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	var _compile_result_297: Variant = regex.compile("^[A-Za-z][A-Za-z0-9+.-]*:")
	return regex.search(value) != null


func _count_leading_spaces(value: String) -> int:
	var count: int = 0
	while count < value.length() and value.substr(count, 1) == " ":
		count += 1
	return count


func _is_numbered_slug(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	var _compile_result_212: Variant = regex.compile("^\\d\\d-[a-z0-9-]+$")
	return regex.search(value) != null


func _is_generated_api_reference_detail_page(relative_path: String) -> bool:
	if relative_path.begins_with("reference/api/classes/"):
		return true
	return (
		relative_path.begins_with("reference/api/autoloads/")
		and not relative_path.ends_with("/index.md")
	)


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _join_lines(values: Array[String]) -> String:
	if values.is_empty():
		return ""

	var packed: PackedStringArray = PackedStringArray()
	for value: String in values:
		var _append_result_231: Variant = packed.append(value)
	return "\n".join(packed)
