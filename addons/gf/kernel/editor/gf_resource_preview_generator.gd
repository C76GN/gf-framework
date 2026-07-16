@tool

# GFResourcePreviewGenerator: 为带预览协议或图标字段的 Resource 生成编辑器缩略图。
extends EditorResourcePreviewGenerator


# --- 常量 ---

const _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_preview_source_registry.gd")

## GF Resource 预览纹理方法名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PREVIEW_TEXTURE_METHOD: StringName = &"get_gf_preview_texture"

## GF Resource 图标纹理方法名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ICON_TEXTURE_METHOD: StringName = &"get_gf_icon_texture"

## GF Resource 预览纹理属性名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PREVIEW_TEXTURE_PROPERTY: StringName = &"preview_texture"

## GF Resource 图标纹理属性名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ICON_TEXTURE_PROPERTY: StringName = &"icon"

## 默认资源基类名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_BASE_TYPE: String = "Resource"


# --- 私有变量 ---

var _registry: _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.make_default()


# --- 可重写钩子 / 虚方法 ---

func _handles(type: String) -> bool:
	if type == DEFAULT_BASE_TYPE:
		return true
	if ClassDB.class_exists(type):
		return ClassDB.is_parent_class(type, DEFAULT_BASE_TYPE)
	return true


func _generate(resource: Resource, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	var result: Dictionary = _registry.build_preview_result(resource, size)
	return _get_result_texture(result)


# --- 框架内部方法 ---

## 注册 Resource 预览 provider。
## [br]
## provider 只需要实现 get_preview_texture(resource)，可选实现
## supports_resource(resource) 与 get_preview_source_id()。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param preview_source: 实现预览纹理解析的 provider。
## [br]
## @param options: 注册选项，支持 source_id 和 priority。
## [br]
## @schema options: Dictionary，可包含 source_id:String 与 priority:int。
## [br]
## @return 注册是否成功。
func register_source(preview_source: RefCounted, options: Dictionary = {}) -> bool:
	return _registry.register_source(preview_source, options)


## 注销 Resource 预览 provider。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param preview_source: 已注册的 provider。
## [br]
## @return 是否找到并移除 provider。
func unregister_source(preview_source: RefCounted) -> bool:
	return _registry.unregister_source(preview_source)


## 返回当前预览来源摘要。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 来源摘要数组。
## [br]
## @schema return: Array of Dictionary records with source_id and priority.
func get_source_records() -> Array[Dictionary]:
	return _registry.get_source_records()


## 为 Resource 生成预算化预览结果。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param resource: 待预览的 Resource。
## [br]
## @param size: Godot 请求的预览尺寸。
## [br]
## @param options: 预算选项。
## [br]
## @schema options: Dictionary，可覆盖源纹理和目标预览的尺寸、像素预算。
## [br]
## @return 预览生成结果。
## [br]
## @schema return: Dictionary，包含 ok、status、source_id、texture、source_size、target_size 和 error。
func build_preview_result(resource: Resource, size: Vector2i, options: Dictionary = {}) -> Dictionary:
	return _registry.build_preview_result(resource, size, options)


## 从资源读取 GF 预览纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param resource: 待读取的资源。
## [br]
## @return 可用于编辑器缩略图的纹理；没有预览时返回 null。
static func get_resource_preview_texture(resource: Resource) -> Texture2D:
	var registry: _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.make_default()
	return registry.get_resource_preview_texture(resource)


## 生成等比适配的编辑器预览纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param texture: 源纹理。
## [br]
## @param size: 目标预览尺寸。
## [br]
## @return 等比居中后的 ImageTexture；失败时返回 null。
static func make_preview_texture(texture: Texture2D, size: Vector2i) -> Texture2D:
	var registry: _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT = _GF_RESOURCE_PREVIEW_SOURCE_REGISTRY_SCRIPT.make_default()
	return registry.make_preview_texture(texture, size)


# --- 私有/辅助方法 ---

static func _get_result_texture(result: Dictionary) -> Texture2D:
	var value: Variant = result.get("texture")
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null
