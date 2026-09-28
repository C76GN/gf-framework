@tool

# GFResourcePathEditorProperty: 用窗口安全的路径控件编辑 String 形式的资源引用。
extends EditorProperty


# --- 常量 ---

## 默认资源基类名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_BASE_TYPE: String = "Resource"

## Godot 资源 UID 路径前缀。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const UID_PREFIX: String = "uid://"

## Godot 项目资源路径前缀。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const RESOURCE_PREFIX: String = "res://"

## 资源路径状态结果中的空输入值。
## [br]
## @api private
const _STATUS_EMPTY: String = "empty"

## 资源路径通过检查时使用的状态值。
## [br]
## @api private
const _STATUS_OK: String = "ok"

## UID 文本无法解析或 UID 未登记时使用的状态值。
## [br]
## @api private
const _STATUS_INVALID_UID: String = "invalid_uid"

## 目标缺失或资源类型不匹配时使用的状态值。
## [br]
## @api private
const _STATUS_MISSING_OR_TYPE_MISMATCH: String = "missing_or_type_mismatch"

## 不支持的路径 scheme 对应的状态值。
## [br]
## @api private
const _STATUS_UNSUPPORTED_SCHEME: String = "unsupported_scheme"

## 有效路径状态和普通信息提示使用的颜色。
## [br]
## @api private
const _INFO_TEXT_COLOR: Color = Color(0.62, 0.66, 0.72, 1.0)

## 无效路径状态使用的颜色。
## [br]
## @api private
const _WARNING_TEXT_COLOR: Color = Color(1.0, 0.58, 0.30, 1.0)

## 提供 GF 资源路径 hint 常量的脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_HINT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_hint.gd")

## 提供资源路径选择器控件的脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_PICKER_CONTROL_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_picker_control.gd")

## 提供普通属性 Tooltip 的脚本。
## [br]
## @api private
const _GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_property_plain_tooltip.gd")

## 按已知文件扩展名推导的资源基类映射。
## [br]
## @api private
const _RESOURCE_EXTENSIONS: Dictionary = {
	"gd": "Script",
	"gdshader": "Shader",
	"shader": "Shader",
	"scn": "PackedScene",
	"tscn": "PackedScene",
	"glb": "PackedScene",
	"gltf": "PackedScene",
	"ogg": "AudioStream",
	"opus": "AudioStream",
	"mp3": "AudioStream",
	"wav": "AudioStream",
	"bmp": "Texture2D",
	"exr": "Texture2D",
	"hdr": "Texture2D",
	"jpeg": "Texture2D",
	"jpg": "Texture2D",
	"ktx": "Texture2D",
	"ktx2": "Texture2D",
	"png": "Texture2D",
	"svg": "Texture2D",
	"tga": "Texture2D",
	"webp": "Texture2D",
	"res": DEFAULT_BASE_TYPE,
	"tres": DEFAULT_BASE_TYPE,
}


# --- 私有变量 ---

## 资源路径属性编辑器的根容器。
## [br]
## @api private
var _root: VBoxContainer

## 由 GF 选择器脚本创建的单路径编辑控件。
## [br]
## @api private
var _picker: Control

## 显示资源路径状态说明的标签。
## [br]
## @api private
var _status_label: Label

## ResourcePicker 接受的基础资源类型。
## [br]
## @api private
var _base_type: String = DEFAULT_BASE_TYPE

## 选择资源时是否优先使用 uid:// 路径。
## [br]
## @api private
var _prefer_uid: bool = true

## 属性值更新期间的信号抑制标记。
## [br]
## @api private
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

## 构建资源路径选择器和状态标签，订阅路径修改以接入属性编辑。
## [br]
## @api private
func _init() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)

	var picker_value: Variant = _GF_RESOURCE_PATH_PICKER_CONTROL_SCRIPT.new()
	if not picker_value is Control:
		return
	_picker = picker_value
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _path_changed_connected: Error = _picker.connect(&"path_changed", _on_path_changed)
	_root.add_child(_picker)

	_status_label = Label.new()
	_status_label.visible = false
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_status_label)


# --- Godot 回调方法 ---

## 从当前被编辑对象读取属性并同步路径与状态；同步期间设置更新标记，避免回传同一次刷新。
## [br]
## @api private
func _update_property() -> void:
	var edited_object: Object = get_edited_object()
	if edited_object == null:
		return

	var property_name: String = get_edited_property()
	var current_path: String = _to_path_string(edited_object.get(property_name))
	_is_updating = true
	_picker.call(&"set_path", current_path)
	_apply_status(get_resource_path_status(current_path, _base_type))
	_is_updating = false


## 通过统一的纯文本提示构造器为当前属性创建提示控件。
## [br]
## @api private
func _make_custom_tooltip(_for_text: String) -> Object:
	return _GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT.make_tooltip(self)


# --- 框架内部方法 ---

## 配置 ResourcePicker 的基础资源类型和路径写入策略。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param base_type: ResourcePicker 接受的资源基类。
## [br]
## @param prefer_uid: 保存资源路径时是否优先写入 uid://。
func setup(base_type: String = DEFAULT_BASE_TYPE, prefer_uid: bool = true) -> void:
	_base_type = base_type if not base_type.strip_edges().is_empty() else DEFAULT_BASE_TYPE
	_prefer_uid = prefer_uid
	if _picker != null:
		_picker.call(&"setup", get_resource_file_filters(_base_type))


## 判断属性是否适合用资源路径编辑器接管。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param type: Godot 属性类型。
## [br]
## @param hint_type: Godot 属性 hint 类型。
## [br]
## @param hint_string: Godot 属性 hint 字符串。
## [br]
## @return 适合接管时返回 true。
static func should_handle_property(type: Variant.Type, hint_type: int, hint_string: String) -> bool:
	if type != TYPE_STRING:
		return false
	if hint_type != PROPERTY_HINT_FILE and hint_type != _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH:
		return false
	return not get_base_type_for_hint(hint_type, hint_string).is_empty()


## 从资源路径 hint 推导 ResourcePicker 基础类型。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param hint_type: Godot 属性 hint 类型或 GFResourcePathHint 常量。
## [br]
## @param hint_string: Godot 属性 hint 字符串。
## [br]
## @return 可用于 EditorResourcePicker.base_type 的类型名；无法安全推导时返回空字符串。
static func get_base_type_for_hint(hint_type: int, hint_string: String) -> String:
	if not _is_resource_path_hint(hint_type):
		return ""

	var direct_type: String = hint_string.strip_edges()
	if direct_type.is_empty() and hint_type != PROPERTY_HINT_FILE:
		return DEFAULT_BASE_TYPE
	if _is_resource_class(direct_type):
		return direct_type

	var base_type: String = ""
	for extension: String in _extract_extensions(hint_string):
		var mapped_type: String = _get_string_option(_RESOURCE_EXTENSIONS, extension)
		if mapped_type.is_empty():
			continue
		if base_type.is_empty():
			base_type = mapped_type
		elif base_type != mapped_type:
			return DEFAULT_BASE_TYPE
	return base_type


## 获取资源类型对应的 EditorFileDialog 过滤器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param base_type: Resource 原生类型或 GDScript 全局资源类型。
## [br]
## @return 可直接赋给 FileDialog.filters 的过滤器列表。
static func get_resource_file_filters(base_type: String) -> PackedStringArray:
	var normalized_base_type: String = _normalize_base_type(base_type)
	var native_base_type: String = _get_native_resource_base_type(normalized_base_type)
	var extensions: PackedStringArray = ResourceLoader.get_recognized_extensions_for_type(
		native_base_type
	)
	var normalized_extensions: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var normalized_extension: String = extension.strip_edges().trim_prefix(".").to_lower()
		if normalized_extension.is_empty() or normalized_extensions.has(normalized_extension):
			continue
		var _append_extension_result: bool = normalized_extensions.append(normalized_extension)
	normalized_extensions.sort()
	if normalized_extensions.is_empty():
		return PackedStringArray()

	var patterns: PackedStringArray = PackedStringArray()
	for extension: String in normalized_extensions:
		var _append_pattern_result: bool = patterns.append("*.%s" % extension)
	return PackedStringArray([
		"%s ; %s" % [", ".join(patterns), normalized_base_type],
	])


## 把资源转换为可保存的稳定路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param resource: 选中的资源。
## [br]
## @param prefer_uid: 是否优先使用 uid://。
## [br]
## @return 稳定资源路径；资源未保存时返回空字符串。
static func get_stable_resource_path(resource: Resource, prefer_uid: bool = true) -> String:
	if resource == null:
		return ""

	var resource_path: String = resource.resource_path.strip_edges()
	if resource_path.is_empty():
		return ""
	if prefer_uid:
		var uid: int = ResourceLoader.get_resource_uid(resource_path)
		if uid != ResourceUID.INVALID_ID:
			return ResourceUID.id_to_text(uid)
	return resource_path


## 解析资源路径对应的 `res://` 路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: `res://` 或 `uid://` 资源路径。
## [br]
## @param base_type: 类型提示。
## [br]
## @return 可加载资源的 `res://` 路径；无法解析或类型不匹配时返回空字符串。
static func get_resolved_resource_path(path: String, base_type: String = DEFAULT_BASE_TYPE) -> String:
	var status: Dictionary = get_resource_path_status(path, base_type)
	return _get_string_option(status, "resolved_path")


## 描述资源路径的编辑器状态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: `res://` 或 `uid://` 资源路径。
## [br]
## @param base_type: 类型提示。
## [br]
## @return 路径状态字典。
## [br]
## @schema return: Dictionary with `path: String`, `resolved_path: String`, `valid: bool`, `state: String`, and `message: String`. `state` is one of `empty`, `ok`, `invalid_uid`, `missing_or_type_mismatch`, or `unsupported_scheme`.
static func get_resource_path_status(path: String, base_type: String = DEFAULT_BASE_TYPE) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	var normalized_base_type: String = _normalize_base_type(base_type)
	if normalized_path.is_empty():
		return _make_resource_path_status(normalized_path, "", true, _STATUS_EMPTY, "")

	if normalized_path.begins_with(RESOURCE_PREFIX):
		if not ResourceLoader.exists(normalized_path, normalized_base_type):
			return _make_resource_path_status(
				normalized_path,
				"",
				false,
				_STATUS_MISSING_OR_TYPE_MISMATCH,
				"资源不存在或类型不匹配: %s" % normalized_path
			)
		return _make_resource_path_status(normalized_path, normalized_path, true, _STATUS_OK, "")

	if normalized_path.begins_with(UID_PREFIX):
		var uid: int = ResourceUID.text_to_id(normalized_path)
		if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
			return _make_resource_path_status(
				normalized_path,
				"",
				false,
				_STATUS_INVALID_UID,
				"无法解析 UID 资源路径: %s" % normalized_path
			)

		var resolved_path: String = ResourceUID.get_id_path(uid)
		if resolved_path.is_empty() or not ResourceLoader.exists(normalized_path, normalized_base_type):
			return _make_resource_path_status(
				normalized_path,
				resolved_path,
				false,
				_STATUS_MISSING_OR_TYPE_MISMATCH,
				"资源不存在或类型不匹配: %s" % normalized_path
			)
		return _make_resource_path_status(
			normalized_path,
			resolved_path,
			true,
			_STATUS_OK,
			"%s -> %s" % [normalized_path, resolved_path]
		)

	return _make_resource_path_status(
		normalized_path,
		"",
		false,
		_STATUS_UNSUPPORTED_SCHEME,
		"只支持 res:// 或 uid:// 资源路径: %s" % normalized_path
	)


## 按路径加载 ResourcePicker 当前值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: `res://` 或 `uid://` 资源路径。
## [br]
## @param base_type: 类型提示。
## [br]
## @return 加载出的资源；失败时返回 null。
static func load_resource_from_path(path: String, base_type: String = DEFAULT_BASE_TYPE) -> Resource:
	var normalized_path: String = path.strip_edges()
	var normalized_base_type: String = _normalize_base_type(base_type)
	if normalized_path.is_empty():
		return null
	if not normalized_path.begins_with(RESOURCE_PREFIX) and not normalized_path.begins_with(UID_PREFIX):
		return null
	if not ResourceLoader.exists(normalized_path, normalized_base_type):
		return null

	var resource: Resource = ResourceLoader.load(normalized_path, normalized_base_type, ResourceLoader.CACHE_MODE_REUSE)
	return resource


# --- 私有/辅助方法 ---

## 修剪基础类型首尾空白；结果为空时回退到默认 Resource 类型。
## [br]
## @api private
static func _normalize_base_type(base_type: String) -> String:
	var normalized_base_type: String = base_type.strip_edges()
	return normalized_base_type if not normalized_base_type.is_empty() else DEFAULT_BASE_TYPE


## 判断 hint 是否为 Godot 文件 hint 或 GF 单/多路径资源 hint。
## [br]
## @api private
static func _is_resource_path_hint(hint_type: int) -> bool:
	return (
		hint_type == PROPERTY_HINT_FILE
		or hint_type == _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH
		or hint_type == _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH_ARRAY
	)


## 使用空访问集合检查类型是否为 Resource 子类或继承自该类的 global class。
## [br]
## @api private
static func _is_resource_class(type_name: String) -> bool:
	return _is_resource_class_with_seen(type_name, {})


## 使用空访问集合解析类型对应的原生 Resource 基类名。
## [br]
## @api private
static func _get_native_resource_base_type(type_name: String) -> String:
	return _get_native_resource_base_type_with_seen(type_name, {})


## 递归解析 global class 的 base；遇到空名、已访问类型或非 Resource 类时返回默认 Resource。
## [br]
## @api private
static func _get_native_resource_base_type_with_seen(
	type_name: String,
	seen_types: Dictionary
) -> String:
	if type_name.is_empty() or seen_types.has(type_name):
		return DEFAULT_BASE_TYPE
	seen_types[type_name] = true
	if ClassDB.class_exists(type_name):
		return type_name if ClassDB.is_parent_class(type_name, DEFAULT_BASE_TYPE) else DEFAULT_BASE_TYPE

	for global_class_info: Dictionary in ProjectSettings.get_global_class_list():
		if _get_string_option(global_class_info, "class") != type_name:
			continue
		var base_type: String = _get_string_option(global_class_info, "base").strip_edges()
		return _get_native_resource_base_type_with_seen(base_type, seen_types)
	return DEFAULT_BASE_TYPE


## 递归检查 ClassDB 类或 global class 的继承链是否到达 Resource。
## 已访问的 global class 名称再次出现时返回 false。
## [br]
## @api private
static func _is_resource_class_with_seen(type_name: String, seen_types: Dictionary) -> bool:
	if type_name.is_empty():
		return false
	if type_name == DEFAULT_BASE_TYPE:
		return true
	if ClassDB.class_exists(type_name):
		return ClassDB.is_parent_class(type_name, DEFAULT_BASE_TYPE)
	if seen_types.has(type_name):
		return false
	seen_types[type_name] = true

	for global_class_info: Dictionary in ProjectSettings.get_global_class_list():
		if _get_string_option(global_class_info, "class") != type_name:
			continue
		var base_type: String = _get_string_option(global_class_info, "base").strip_edges()
		return _is_resource_class_with_seen(base_type, seen_types)
	return false


## 将分号和逗号分隔的 hint 扩展名拆成小写 token，并去掉可选通配符和点前缀。
## 不在此处去重。
## [br]
## @api private
static func _extract_extensions(hint_string: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized: String = hint_string.replace(";", ",")
	for raw_token: String in normalized.split(",", false):
		var token: String = raw_token.strip_edges()
		if token.contains(" "):
			token = token.get_slice(" ", 0).strip_edges()
		token = token.trim_prefix("*").trim_prefix(".").strip_edges().to_lower()
		if token.is_empty():
			continue
		var _append_result: bool = result.append(token)
	return result


## 将 String 或 StringName 修剪为空白后的文本；其他 Variant 转为空字符串。
## [br]
## @api private
static func _to_path_string(value: Variant) -> String:
	if value is String:
		var text_value: String = value
		return text_value.strip_edges()
	if value is StringName:
		var name_value: StringName = value
		return String(name_value).strip_edges()
	return ""


## 从字典读取 String 或 StringName 字段；其他类型或缺失键返回空字符串，不修剪文本。
## [br]
## @api private
static func _get_string_option(options: Dictionary, key: String) -> String:
	var value: Variant = options.get(key, "")
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	return ""


## 从字典读取 bool 字段；其他类型或缺失键返回 false。
## [br]
## @api private
static func _get_bool_option(options: Dictionary, key: String) -> bool:
	var value: Variant = options.get(key, false)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false


## 组装包含原路径、解析路径、有效标记、状态值和说明文本的状态字典。
## [br]
## @api private
static func _make_resource_path_status(
	path: String,
	resolved_path: String,
	valid: bool,
	state: String,
	message: String
) -> Dictionary:
	return {
		"path": path,
		"resolved_path": resolved_path,
		"valid": valid,
		"state": state,
		"message": message,
	}


## 将状态说明写入选择器和状态标签，并按 valid 值切换可见性与颜色。
## 空说明时选择器 Tooltip 回退为路径文本。
## [br]
## @api private
func _apply_status(status: Dictionary) -> void:
	var path: String = _get_string_option(status, "path")
	var message: String = _get_string_option(status, "message")
	var valid: bool = _get_bool_option(status, "valid")

	_picker.tooltip_text = message if not message.is_empty() else path
	_status_label.text = message
	_status_label.tooltip_text = message
	_status_label.visible = not message.is_empty()
	_status_label.modulate = _INFO_TEXT_COLOR if valid else _WARNING_TEXT_COLOR


# --- 信号处理函数 ---

## 忽略程序性更新；否则修剪新路径，资源可加载时改用稳定路径，再更新控件并发出属性变更。
## [br]
## @api private
func _on_path_changed(path: String) -> void:
	if _is_updating:
		return

	var property_name: String = get_edited_property()
	var next_path: String = path.strip_edges()
	var resource: Resource = load_resource_from_path(next_path, _base_type)
	if resource != null:
		next_path = get_stable_resource_path(resource, _prefer_uid)
	_picker.call(&"set_path", next_path)
	_apply_status(get_resource_path_status(next_path, _base_type))
	emit_changed(property_name, next_path)
