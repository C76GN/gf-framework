## GFPathTools: GF 内部和项目工具可复用的路径规范化辅助。
##
## 只处理字符串层面的路径斜杠、简化、根目录裁剪、相对路径和排除匹配；
## 不访问文件系统、不加载资源，也不解释资源业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFPathTools
extends RefCounted


# --- 公共方法 ---

## 规范化普通路径文本。
## [br]
## @api public
## [br]
## @param path: 输入路径。
## [br]
## @param fallback: 输入为空时返回的兜底路径。
## [br]
## @param simplify: 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。
## [br]
## @return 规范化后的路径。
static func normalize_path(path: String, fallback: String = "", simplify: bool = true) -> String:
	var normalized_path: String = path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return fallback
	if simplify:
		return normalized_path.simplify_path()
	return normalized_path


## 规范化 Godot 资源路径文本。
## [br]
## @api public
## [br]
## @param path: 输入路径，通常是 `res://`、`user://`、`uid://` 或相对路径。
## [br]
## @param fallback: 输入为空时返回的兜底路径。
## [br]
## @param simplify: 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。
## [br]
## @return 规范化后的资源路径文本。
static func normalize_resource_path(path: String, fallback: String = "", simplify: bool = true) -> String:
	return normalize_path(path, fallback, simplify)


## 规范化根目录路径，并移除多余尾随斜杠。
## [br]
## @api public
## [br]
## @param path: 输入根目录。
## [br]
## @param fallback: 输入为空时返回的兜底路径。
## [br]
## @param simplify: 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。
## [br]
## @return 规范化后的根目录路径。
static func normalize_root_path(path: String, fallback: String = "", simplify: bool = true) -> String:
	var normalized_path: String = normalize_resource_path(path, fallback, simplify)
	while normalized_path.ends_with("/") and not normalized_path.ends_with("://"):
		normalized_path = normalized_path.substr(0, normalized_path.length() - 1)
	return normalized_path


## 规范化根目录路径集合，并按首次出现顺序去除空路径和重复项。
## [br]
## @api public
## [br]
## @param paths: 输入根目录路径集合。
## [br]
## @param simplify: 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。
## [br]
## @return 规范化并去重后的根目录路径集合。
static func normalize_root_paths(paths: PackedStringArray, simplify: bool = true) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var normalized_path: String = normalize_root_path(path, "", simplify)
		if normalized_path.is_empty() or result.has(normalized_path):
			continue
		var _appended: bool = result.append(normalized_path)
	return result


## 从 base_path 推导 path 的相对路径。
## [br]
## @api public
## [br]
## @param path: 输入路径。
## [br]
## @param base_path: 基准目录。
## [br]
## @return path 位于 base_path 下时返回相对路径，否则返回规范化后的 path。
static func make_relative_path(path: String, base_path: String) -> String:
	var normalized_path: String = normalize_resource_path(path)
	var normalized_base: String = normalize_root_path(base_path)
	if normalized_path.is_empty() or normalized_base.is_empty():
		return normalized_path
	if normalized_path == normalized_base:
		return ""
	if normalized_path.begins_with(normalized_base + "/"):
		return normalized_path.substr(normalized_base.length() + 1)
	return normalized_path


## 判断 path 是否位于 root_path 内。
## [br]
## @api public
## [br]
## @param path: 输入路径。
## [br]
## @param root_path: 允许的根目录。
## [br]
## @param allow_equal: 为 true 时 path 等于 root_path 也视为命中。
## [br]
## @param empty_root_matches: 为 true 时空 root_path 视为允许所有路径。
## [br]
## @return 位于根目录内时返回 true。
static func is_path_under_root(
	path: String,
	root_path: String,
	allow_equal: bool = true,
	empty_root_matches: bool = false
) -> bool:
	var normalized_path: String = normalize_resource_path(path)
	var normalized_root: String = normalize_root_path(root_path)
	if normalized_root.is_empty():
		return empty_root_matches
	if normalized_path.is_empty():
		return false
	if allow_equal and normalized_path == normalized_root:
		return true
	return normalized_path.begins_with(normalized_root + "/")


## 判断 path 是否被排除路径集合命中。
## [br]
## @api public
## [br]
## @param path: 输入路径。
## [br]
## @param excluded_paths: 排除路径集合；命中目录自身或其子路径都返回 true。
## [br]
## @return 被排除时返回 true。
static func is_path_excluded(path: String, excluded_paths: PackedStringArray) -> bool:
	var normalized_path: String = normalize_root_path(path)
	for excluded_path: String in excluded_paths:
		var normalized_excluded: String = normalize_root_path(excluded_path)
		if normalized_excluded.is_empty():
			continue
		if normalized_path == normalized_excluded or normalized_path.begins_with(normalized_excluded + "/"):
			return true
	return false
