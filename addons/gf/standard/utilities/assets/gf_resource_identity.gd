## GFResourceIdentity: 资源键、路径和 UID 的规范化身份快照。
##
## 该对象只描述资源身份，不加载资源、不拥有缓存，也不规定项目目录策略。
## 它适合用于资源解析、加载状态、诊断报告和后续缓存键迁移的统一数据边界。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFResourceIdentity
extends RefCounted


# --- 常量 ---

## 普通项目资源路径 scheme。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEME_RES: StringName = &"res"

## Godot UID 资源路径 scheme。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEME_UID: StringName = &"uid"

## 用户数据路径 scheme。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEME_USER: StringName = &"user"

## 没有可识别 scheme。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEME_NONE: StringName = &""


# --- 公共变量 ---

## 稳定资源键；可为空。
## [br]
## @api public
## [br]
## @since 8.0.0
var resource_key: StringName = &""

## 调用方传入的原始路径文本。
## [br]
## @api public
## [br]
## @since 8.0.0
var raw_path: String = ""

## 规范化路径。`uid://` 可解析时会回解为 Godot 当前记录的资源路径。
## [br]
## @api public
## [br]
## @since 8.0.0
var canonical_path: String = ""

## Godot UID 路径；无法取得 UID 时为空。
## [br]
## @api public
## [br]
## @since 8.0.0
var uid_path: String = ""

## ResourceLoader 类型提示；可为空。
## [br]
## @api public
## [br]
## @since 8.0.0
var type_hint: String = ""

## 路径 scheme，例如 `res`、`uid` 或 `user`。
## [br]
## @api public
## [br]
## @since 8.0.0
var scheme: StringName = SCHEME_NONE

## 规范化路径扩展名，不含点号。
## [br]
## @api public
## [br]
## @since 8.0.0
var extension: String = ""

## 推荐缓存键。优先使用 UID，其次使用规范化路径，最后使用资源键。
## [br]
## @api public
## [br]
## @since 8.0.0
var cache_key: String = ""

## 当前工程中是否能确认该资源存在。
## [br]
## @api public
## [br]
## @since 8.0.0
var exists: bool = false

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary with caller-defined identity metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置资源身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_resource_key: 稳定资源键；可为空。
## [br]
## @param p_path: 原始资源路径，支持 `res://`、`uid://` 和 `user://`。
## [br]
## @param p_type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @param options: 可选项，支持 check_exists 和 metadata。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `metadata: Dictionary`.
## [br]
## @return 当前身份对象。
func configure(
	p_resource_key: StringName,
	p_path: String,
	p_type_hint: String = "",
	options: Dictionary = {}
) -> GFResourceIdentity:
	resource_key = p_resource_key
	raw_path = p_path.strip_edges()
	type_hint = p_type_hint.strip_edges()
	canonical_path = _resolve_canonical_path(raw_path)
	uid_path = _resolve_uid_path(raw_path, canonical_path)
	scheme = _get_scheme(canonical_path if not canonical_path.is_empty() else raw_path)
	extension = _get_extension(canonical_path)
	cache_key = _make_cache_key()
	exists = _resource_exists(canonical_path, uid_path, GFVariantData.get_option_bool(options, "check_exists", true))
	metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	return self


## 检查身份是否有路径或资源键。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 有路径或资源键时返回 true。
func has_identity() -> bool:
	return not cache_key.is_empty()


## 导出可序列化字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 资源身份字典。
## [br]
## @schema return: Dictionary with resource_key, raw_path, canonical_path, uid_path, type_hint, scheme, extension, cache_key, exists, and metadata.
func to_dictionary() -> Dictionary:
	return {
		"resource_key": resource_key,
		"raw_path": raw_path,
		"canonical_path": canonical_path,
		"uid_path": uid_path,
		"type_hint": type_hint,
		"scheme": scheme,
		"extension": extension,
		"cache_key": cache_key,
		"exists": exists,
		"metadata": metadata.duplicate(true),
	}


## 创建资源身份副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 身份副本。
func duplicate_identity() -> GFResourceIdentity:
	return from_dictionary(to_dictionary())


## 由路径创建资源身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 原始资源路径。
## [br]
## @param p_resource_key: 可选稳定资源键。
## [br]
## @param p_type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @param options: 可选项，支持 check_exists 和 metadata。
## [br]
## @return 新身份对象。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `metadata: Dictionary`.
static func from_path(
	path: String,
	p_resource_key: StringName = &"",
	p_type_hint: String = "",
	options: Dictionary = {}
) -> GFResourceIdentity:
	var identity: GFResourceIdentity = GFResourceIdentity.new()
	var _configured: GFResourceIdentity = identity.configure(p_resource_key, path, p_type_hint, options)
	return identity


## 从字典恢复资源身份快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: to_dictionary() 兼容字典。
## [br]
## @return 身份对象。
## [br]
## @schema data: Dictionary with resource_key, raw_path, canonical_path, uid_path, type_hint, scheme, extension, cache_key, exists, and metadata.
static func from_dictionary(data: Dictionary) -> GFResourceIdentity:
	var identity: GFResourceIdentity = GFResourceIdentity.new()
	identity.resource_key = GFVariantData.get_option_string_name(data, "resource_key")
	identity.raw_path = GFVariantData.get_option_string(data, "raw_path")
	identity.canonical_path = GFVariantData.get_option_string(data, "canonical_path")
	identity.uid_path = GFVariantData.get_option_string(data, "uid_path")
	identity.type_hint = GFVariantData.get_option_string(data, "type_hint")
	identity.scheme = GFVariantData.get_option_string_name(data, "scheme")
	identity.extension = GFVariantData.get_option_string(data, "extension")
	identity.cache_key = GFVariantData.get_option_string(data, "cache_key")
	identity.exists = GFVariantData.get_option_bool(data, "exists", false)
	identity.metadata = GFVariantData.get_option_dictionary(data, "metadata").duplicate(true)
	return identity


# --- 私有/辅助方法 ---

static func _resolve_canonical_path(path: String) -> String:
	var normalized_path: String = GFPathTools.normalize_resource_path(path)
	if normalized_path.begins_with("uid://"):
		var uid_resolved_path: String = _get_resource_path_from_uid(normalized_path)
		if not uid_resolved_path.is_empty():
			return GFPathTools.normalize_resource_path(uid_resolved_path)
	return normalized_path


static func _resolve_uid_path(raw_resource_path: String, canonical_resource_path: String) -> String:
	var normalized_raw_path: String = GFPathTools.normalize_resource_path(raw_resource_path)
	if normalized_raw_path.begins_with("uid://"):
		return normalized_raw_path
	if canonical_resource_path.begins_with("uid://"):
		return canonical_resource_path
	if canonical_resource_path.is_empty():
		return ""
	var uid: int = ResourceLoader.get_resource_uid(canonical_resource_path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid)


static func _get_resource_path_from_uid(uid_text: String) -> String:
	if uid_text.is_empty():
		return ""
	var uid: int = ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
		return ""
	return ResourceUID.get_id_path(uid)


static func _get_scheme(path: String) -> StringName:
	var separator_index: int = path.find("://")
	if separator_index <= 0:
		return SCHEME_NONE
	var scheme_text: String = path.substr(0, separator_index).to_lower()
	return StringName(scheme_text)


static func _get_extension(path: String) -> String:
	if path.is_empty() or path.begins_with("uid://"):
		return ""
	return path.get_extension().to_lower()


func _make_cache_key() -> String:
	if not uid_path.is_empty():
		return uid_path
	if not canonical_path.is_empty():
		return canonical_path
	if resource_key != &"":
		return "key://%s" % String(resource_key)
	return ""


static func _resource_exists(canonical_resource_path: String, identity_uid_path: String, check_exists: bool) -> bool:
	if not check_exists:
		return false
	if not canonical_resource_path.is_empty() and ResourceLoader.exists(canonical_resource_path):
		return true
	if not identity_uid_path.is_empty() and ResourceLoader.exists(identity_uid_path):
		return true
	if not canonical_resource_path.is_empty() and FileAccess.file_exists(canonical_resource_path):
		return true
	return false
