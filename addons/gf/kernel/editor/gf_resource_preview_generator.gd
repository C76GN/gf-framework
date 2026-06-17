@tool

# GFResourcePreviewGenerator: 为带预览协议或图标字段的 Resource 生成编辑器缩略图。
extends EditorResourcePreviewGenerator


# --- 常量 ---

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


# --- 可重写钩子 / 虚方法 ---

func _handles(type: String) -> bool:
	if type == DEFAULT_BASE_TYPE:
		return true
	if ClassDB.class_exists(type):
		return ClassDB.is_parent_class(type, DEFAULT_BASE_TYPE)
	return true


func _generate(resource: Resource, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	var texture: Texture2D = get_resource_preview_texture(resource)
	if texture == null:
		return null
	return make_preview_texture(texture, size)


# --- 框架内部方法 ---

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
	if resource == null:
		return null

	var method_texture: Texture2D = _get_texture_from_method(resource, PREVIEW_TEXTURE_METHOD)
	if method_texture != null:
		return method_texture

	method_texture = _get_texture_from_method(resource, ICON_TEXTURE_METHOD)
	if method_texture != null:
		return method_texture

	var property_texture: Texture2D = _get_texture_from_property(resource, PREVIEW_TEXTURE_PROPERTY)
	if property_texture != null:
		return property_texture

	return _get_texture_from_property(resource, ICON_TEXTURE_PROPERTY)


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
## @return 等比居中后的 ImageTexture；失败时返回源纹理。
static func make_preview_texture(texture: Texture2D, size: Vector2i) -> Texture2D:
	if texture == null:
		return null

	var source_image: Image = texture.get_image()
	if source_image == null or source_image.get_width() <= 0 or source_image.get_height() <= 0:
		return texture

	var target_size: Vector2i = _normalize_size(size)
	var fitted_size: Vector2i = _fit_size(Vector2i(source_image.get_width(), source_image.get_height()), target_size)
	var image: Image = source_image.duplicate()
	if image.is_compressed():
		var decompress_error: Error = image.decompress()
		if decompress_error != OK:
			return texture
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	image.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)

	var canvas: Image = Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var offset: Vector2i = Vector2i(
		floori(float(target_size.x - fitted_size.x) / 2.0),
		floori(float(target_size.y - fitted_size.y) / 2.0)
	)
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, fitted_size), offset)
	return ImageTexture.create_from_image(canvas)


# --- 私有/辅助方法 ---

static func _get_texture_from_method(resource: Resource, method_name: StringName) -> Texture2D:
	if not resource.has_method(method_name):
		return null

	var value: Variant = resource.call(method_name)
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


static func _get_texture_from_property(resource: Resource, property_name: StringName) -> Texture2D:
	if not _has_property(resource, property_name):
		return null

	var value: Variant = resource.get(property_name)
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


static func _has_property(resource: Resource, property_name: StringName) -> bool:
	for property_info: Dictionary in resource.get_property_list():
		var raw_name: Variant = property_info.get("name", "")
		if _to_string_name(raw_name) == property_name:
			return true
	return false


static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		var name_value: StringName = value
		return name_value
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return &""


static func _normalize_size(size: Vector2i) -> Vector2i:
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))


static func _fit_size(source_size: Vector2i, target_size: Vector2i) -> Vector2i:
	var source_width: int = maxi(source_size.x, 1)
	var source_height: int = maxi(source_size.y, 1)
	var width_scale: float = float(target_size.x) / float(source_width)
	var height_scale: float = float(target_size.y) / float(source_height)
	var scale: float = minf(width_scale, height_scale)
	return Vector2i(
		maxi(1, int(roundf(float(source_width) * scale))),
		maxi(1, int(roundf(float(source_height) * scale)))
	)
