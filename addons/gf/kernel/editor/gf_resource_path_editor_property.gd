@tool

# GFResourcePathEditorProperty: 用 ResourcePicker 编辑 String 形式的资源路径。
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

var _picker: EditorResourcePicker
var _base_type: String = DEFAULT_BASE_TYPE
var _prefer_uid: bool = true
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_picker = _PathResourcePicker.new()
	_picker.base_type = _base_type
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _resource_changed_connected: Error = _picker.resource_changed.connect(_on_resource_changed) as Error
	add_child(_picker)


# --- Godot 回调方法 ---

func _update_property() -> void:
	var edited_object: Object = get_edited_object()
	if edited_object == null:
		return

	var property_name: String = get_edited_property()
	var current_path: String = _to_path_string(edited_object.get(property_name))
	_is_updating = true
	_picker.base_type = _base_type
	_picker.edited_resource = load_resource_from_path(current_path, _base_type)
	_picker.tooltip_text = current_path
	_is_updating = false


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
		_picker.base_type = _base_type


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
	if hint_type != PROPERTY_HINT_FILE:
		return false
	return not get_base_type_for_hint(hint_type, hint_string).is_empty()


## 从 Godot 文件 hint 推导 ResourcePicker 基础类型。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param hint_type: Godot 属性 hint 类型。
## [br]
## @param hint_string: Godot 属性 hint 字符串。
## [br]
## @return 可用于 EditorResourcePicker.base_type 的类型名；无法安全推导时返回空字符串。
static func get_base_type_for_hint(hint_type: int, hint_string: String) -> String:
	if hint_type != PROPERTY_HINT_FILE:
		return ""

	var direct_type: String = hint_string.strip_edges()
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
	if normalized_path.is_empty():
		return null
	if not normalized_path.begins_with(RESOURCE_PREFIX) and not normalized_path.begins_with(UID_PREFIX):
		return null
	if not ResourceLoader.exists(normalized_path, base_type):
		return null

	var resource: Resource = ResourceLoader.load(normalized_path, base_type, ResourceLoader.CACHE_MODE_REUSE)
	return resource


# --- 私有/辅助方法 ---

static func _is_resource_class(type_name: String) -> bool:
	if type_name.is_empty():
		return false
	if type_name == DEFAULT_BASE_TYPE:
		return true
	if not ClassDB.class_exists(type_name):
		return false
	return ClassDB.is_parent_class(type_name, DEFAULT_BASE_TYPE)


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


static func _to_path_string(value: Variant) -> String:
	if value is String:
		var text_value: String = value
		return text_value.strip_edges()
	if value is StringName:
		var name_value: StringName = value
		return String(name_value).strip_edges()
	return ""


static func _get_string_option(options: Dictionary, key: String) -> String:
	var value: Variant = options.get(key, "")
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	return ""


# --- 信号处理函数 ---

func _on_resource_changed(resource: Resource) -> void:
	if _is_updating:
		return

	var property_name: String = get_edited_property()
	var next_path: String = get_stable_resource_path(resource, _prefer_uid)
	_picker.tooltip_text = next_path
	emit_changed(property_name, next_path)


# --- 内部类 ---

class _PathResourcePicker:
	extends EditorResourcePicker

	func _set_create_options(menu_node: Object) -> void:
		if menu_node != null and menu_node.has_method(&"clear"):
			var _clear_result: Variant = menu_node.call(&"clear")
