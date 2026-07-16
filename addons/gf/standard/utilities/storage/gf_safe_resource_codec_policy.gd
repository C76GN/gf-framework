@tool

## GFSafeResourceCodecPolicy: 安全资源图编解码策略。
##
## 定义对象图编解码允许的类、脚本路径、资源路径和大小上限。
## 默认策略不允许实例化对象；调用方必须显式加入 allowlist，避免把存档、
## 网络载荷或工具缓存变成任意对象创建入口。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFSafeResourceCodecPolicy
extends Resource


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 导出变量 ---

## 允许编解码的原生类名或通配模式。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema allowed_classes: PackedStringArray of ClassDB class names or wildcard patterns.
@export var allowed_classes: PackedStringArray = PackedStringArray()

## 允许设置到对象上的脚本路径或通配模式。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema allowed_script_paths: PackedStringArray of res:// script paths or wildcard patterns.
@export var allowed_script_paths: PackedStringArray = PackedStringArray()

## 允许按路径引用或加载的外部资源路径或通配模式。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema allowed_resource_paths: PackedStringArray of res:// resource paths or wildcard patterns.
@export var allowed_resource_paths: PackedStringArray = PackedStringArray()

## 允许递归编解码的最大深度。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var max_depth: int = 32:
	set(value):
		max_depth = maxi(value, 1)

## 允许处理的最大节点、集合项和属性项总数。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var max_items: int = 4096:
	set(value):
		max_items = maxi(value, 1)

## 是否允许把外部 Resource 编码为 resource_path 引用。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var allow_external_resource_paths: bool = true

## 是否允许对象图中的重复引用被编码为 identity reference。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var allow_object_identity_references: bool = true


# --- 公共方法 ---

## 添加允许的类。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param class_id: ClassDB 类名或通配模式。
## [br]
## @return 当前策略。
func allow_class(class_id: String) -> GFSafeResourceCodecPolicy:
	_append_unique(allowed_classes, class_id.strip_edges())
	return self


## 添加允许的脚本路径。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param script_path: res:// 脚本路径或通配模式。
## [br]
## @return 当前策略。
func allow_script_path(script_path: String) -> GFSafeResourceCodecPolicy:
	_append_unique(allowed_script_paths, _normalize_allowlist_path_pattern(script_path))
	return self


## 添加允许的资源路径。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path_pattern: res:// 资源路径或通配模式。
## [br]
## @return 当前策略。
func allow_resource_path(path_pattern: String) -> GFSafeResourceCodecPolicy:
	_append_unique(allowed_resource_paths, _normalize_allowlist_path_pattern(path_pattern))
	return self


## 检查类是否允许。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param class_id: ClassDB 类名。
## [br]
## @return 允许时返回 true。
func allows_class(class_id: String) -> bool:
	var normalized_class: String = class_id.strip_edges()
	if normalized_class.is_empty():
		return false
	if _matches_any_pattern(normalized_class, allowed_classes):
		return true
	for allowed_class: String in allowed_classes:
		if allowed_class.is_empty() or allowed_class.contains("*") or allowed_class.contains("?"):
			continue
		if ClassDB.class_exists(normalized_class) and ClassDB.class_exists(allowed_class):
			if ClassDB.is_parent_class(normalized_class, allowed_class):
				return true
	return false


## 检查脚本路径是否允许。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param script_path: res:// 脚本路径。
## [br]
## @return 允许时返回 true。
func allows_script_path(script_path: String) -> bool:
	return _matches_any_path_pattern(script_path, allowed_script_paths)


## 检查资源路径是否允许。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: res:// 资源路径。
## [br]
## @return 允许时返回 true。
func allows_resource_path(path: String) -> bool:
	return _matches_any_path_pattern(path, allowed_resource_paths)


## 复制策略。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 新策略。
func duplicate_policy() -> GFSafeResourceCodecPolicy:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodecPolicy.new()
	policy.allowed_classes = PackedStringArray(allowed_classes)
	policy.allowed_script_paths = PackedStringArray(allowed_script_paths)
	policy.allowed_resource_paths = PackedStringArray(allowed_resource_paths)
	policy.max_depth = max_depth
	policy.max_items = max_items
	policy.allow_external_resource_paths = allow_external_resource_paths
	policy.allow_object_identity_references = allow_object_identity_references
	return policy


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with allowlists and limits.
func get_debug_snapshot() -> Dictionary:
	return {
		"allowed_classes": PackedStringArray(allowed_classes),
		"allowed_script_paths": PackedStringArray(allowed_script_paths),
		"allowed_resource_paths": PackedStringArray(allowed_resource_paths),
		"max_depth": max_depth,
		"max_items": max_items,
		"allow_external_resource_paths": allow_external_resource_paths,
		"allow_object_identity_references": allow_object_identity_references,
	}


# --- 私有/辅助方法 ---

func _append_unique(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	var _appended: bool = values.append(value)


func _matches_any_pattern(value: String, patterns: PackedStringArray) -> bool:
	if value.is_empty():
		return false
	for pattern: String in patterns:
		if pattern.is_empty():
			continue
		if value == pattern or value.match(pattern):
			return true
	return false


func _matches_any_path_pattern(value: String, patterns: PackedStringArray) -> bool:
	var normalized_value: String = _normalize_candidate_path(value)
	if normalized_value.is_empty():
		return false
	for raw_pattern: String in patterns:
		var pattern: String = _normalize_allowlist_path_pattern(raw_pattern)
		if pattern.is_empty():
			continue
		if normalized_value == pattern or normalized_value.match(pattern):
			return true
	return false


func _normalize_candidate_path(path: String) -> String:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path, "", false)
	if normalized_path.is_empty() or _path_has_parent_segment(normalized_path):
		return ""
	return _GF_PATH_TOOLS.normalize_resource_path(normalized_path)


func _normalize_allowlist_path_pattern(path_pattern: String) -> String:
	var normalized_pattern: String = _GF_PATH_TOOLS.normalize_resource_path(path_pattern, "", false)
	if normalized_pattern.is_empty() or _path_has_parent_segment(normalized_pattern):
		return ""
	return _GF_PATH_TOOLS.normalize_resource_path(normalized_pattern)


func _path_has_parent_segment(path: String) -> bool:
	for segment: String in path.split("/", false):
		if segment == "..":
			return true
	return false
