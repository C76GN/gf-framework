@tool

## GFResourcePreviewSourceRegistry: Resource 预览来源注册表。
##
## 负责按优先级从 Resource 预览 provider 中解析源纹理，并在统一预算内生成
## 编辑器缩略图。provider 只需要实现 get_preview_texture(resource)，可选实现
## supports_resource(resource) 与 get_preview_source_id()。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFResourcePreviewSourceRegistry
extends RefCounted


# --- 常量 ---

## 预览生成成功。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_GENERATED: StringName = &"generated"

## Resource 为空。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_NO_RESOURCE: StringName = &"no_resource"

## 没有任何 provider 能为 Resource 提供源纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_NO_SOURCE: StringName = &"no_source"

## provider 返回的纹理无效。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_INVALID_TEXTURE: StringName = &"invalid_texture"

## 源纹理超过预览生成预算。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_SOURCE_TOO_LARGE: StringName = &"source_too_large"

## 请求的目标预览尺寸超过预算。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_TARGET_TOO_LARGE: StringName = &"target_too_large"

## 源纹理无法读取为可缩放 Image。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_DECODE_FAILED: StringName = &"decode_failed"

## 默认最大源纹理边长。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_MAX_SOURCE_DIMENSION: int = 4096

## 默认最大源纹理像素数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_MAX_SOURCE_PIXELS: int = 16_777_216

## 默认最大目标预览边长。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_MAX_TARGET_DIMENSION: int = 1024

## 默认最大目标预览像素数。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_MAX_TARGET_PIXELS: int = 1_048_576

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _SOURCE_METHOD_NAME: StringName = &"get_preview_texture"
const _SUPPORTS_METHOD_NAME: StringName = &"supports_resource"
const _SOURCE_ID_METHOD_NAME: StringName = &"get_preview_source_id"


# --- 私有变量 ---

var _sources: Array[Dictionary] = []
var _next_order: int = 0


# --- 框架内部方法 ---

## 创建带默认 GF 预览来源的注册表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 已注册默认来源的预览来源注册表。
static func make_default() -> GFResourcePreviewSourceRegistry:
	var registry: GFResourcePreviewSourceRegistry = GFResourcePreviewSourceRegistry.new()
	registry.register_default_sources()
	return registry


## 注册默认 GF Resource 预览来源。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func register_default_sources() -> void:
	if has_source_id("gf.method_preview"):
		return
	var _method_registered: bool = register_source(_MethodPreviewSource.new(), {
		"source_id": "gf.method_preview",
		"priority": 100,
	})
	var _property_registered: bool = register_source(_PropertyPreviewSource.new(), {
		"source_id": "gf.property_preview",
		"priority": 10,
	})


## 注册一个 Resource 预览 provider。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param preview_source: 实现 get_preview_texture(resource) 的 provider。
## [br]
## @param options: 注册选项，支持 source_id 和 priority。
## [br]
## @schema options: Dictionary，可包含 source_id:String 与 priority:int。
## [br]
## @return 注册是否成功。
func register_source(preview_source: RefCounted, options: Dictionary = {}) -> bool:
	if preview_source == null or not preview_source.has_method(_SOURCE_METHOD_NAME):
		return false

	var source_id: String = _resolve_source_id(preview_source, options)
	if source_id.is_empty() or has_source_id(source_id):
		return false

	_sources.append({
		"source": preview_source,
		"source_id": source_id,
		"priority": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "priority", 0),
		"order": _next_order,
	})
	_next_order += 1
	_sources.sort_custom(_compare_source_records)
	return true


## 注销指定 Resource 预览 provider。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param preview_source: 已注册的 provider。
## [br]
## @return 是否找到并移除 provider。
func unregister_source(preview_source: RefCounted) -> bool:
	for index: int in range(_sources.size() - 1, -1, -1):
		var record: Dictionary = _sources[index]
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_value(record, "source") == preview_source:
			_sources.remove_at(index)
			return true
	return false


## 清空所有已注册预览来源。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func clear_sources() -> void:
	_sources.clear()


## 检查来源 ID 是否已注册。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param source_id: 预览来源 ID。
## [br]
## @return 是否存在该来源 ID。
func has_source_id(source_id: String) -> bool:
	for record: Dictionary in _sources:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "source_id") == source_id:
			return true
	return false


## 返回已注册来源的稳定摘要。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 来源摘要数组。
## [br]
## @schema return: Array of Dictionary records with source_id and priority.
func get_source_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in _sources:
		records.append({
			"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "source_id"),
			"priority": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "priority", 0),
		})
	return records


## 从 Resource 中解析 provider 源纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param resource: 待预览的 Resource。
## [br]
## @return 源纹理解析结果。
## [br]
## @schema return: Dictionary，包含 ok、status、source_id 和 texture。
func resolve_preview_source(resource: Resource) -> Dictionary:
	if resource == null:
		return _make_source_result(false, STATUS_NO_RESOURCE, "", null)

	for record: Dictionary in _sources:
		var preview_source: RefCounted = _get_record_source(record)
		if preview_source == null:
			continue
		if not _source_supports_resource(preview_source, resource):
			continue

		var texture: Texture2D = _get_source_texture(preview_source, resource)
		if texture == null:
			continue
		return _make_source_result(
			true,
			STATUS_GENERATED,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "source_id"),
			texture
		)
	return _make_source_result(false, STATUS_NO_SOURCE, "", null)


## 解析 Resource 的源预览纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param resource: 待预览的 Resource。
## [br]
## @return provider 返回的源纹理；没有来源时返回 null。
func get_resource_preview_texture(resource: Resource) -> Texture2D:
	var result: Dictionary = resolve_preview_source(resource)
	return _get_result_texture(result)


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
## @param options: 预算选项，支持 max_source_dimension、max_source_pixels、max_target_dimension 和 max_target_pixels。
## [br]
## @schema options: Dictionary，可覆盖源纹理和目标预览的尺寸、像素预算。
## [br]
## @return 预览生成结果。
## [br]
## @schema return: Dictionary，包含 ok、status、source_id、texture、source_size、target_size 和 error。
func build_preview_result(resource: Resource, size: Vector2i, options: Dictionary = {}) -> Dictionary:
	var target_size: Vector2i = _normalize_size(size)
	if not _is_size_within_budget(
		target_size,
		_get_budget_int(options, "max_target_dimension", DEFAULT_MAX_TARGET_DIMENSION),
		_get_budget_int(options, "max_target_pixels", DEFAULT_MAX_TARGET_PIXELS)
	):
		return _make_preview_result(false, STATUS_TARGET_TOO_LARGE, "", null, Vector2i.ZERO, target_size, "Target preview size exceeds budget.")

	var source_result: Dictionary = resolve_preview_source(resource)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(source_result, "ok", false):
		return _make_preview_result(
			false,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(source_result, "status", STATUS_NO_SOURCE),
			"",
			null,
			Vector2i.ZERO,
			target_size,
			""
		)

	var source_texture: Texture2D = _get_result_texture(source_result)
	return make_preview_result(
		source_texture,
		target_size,
		options,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_result, "source_id")
	)


## 为源纹理生成预算化预览结果。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param texture: provider 返回的源纹理。
## [br]
## @param size: 目标预览尺寸。
## [br]
## @param options: 预算选项，支持 max_source_dimension、max_source_pixels、max_target_dimension 和 max_target_pixels。
## [br]
## @schema options: Dictionary，可覆盖源纹理和目标预览的尺寸、像素预算。
## [br]
## @param source_id: 预览来源 ID。
## [br]
## @return 预览生成结果。
## [br]
## @schema return: Dictionary，包含 ok、status、source_id、texture、source_size、target_size 和 error。
func make_preview_result(
	texture: Texture2D,
	size: Vector2i,
	options: Dictionary = {},
	source_id: String = ""
) -> Dictionary:
	var target_size: Vector2i = _normalize_size(size)
	if texture == null:
		return _make_preview_result(false, STATUS_INVALID_TEXTURE, source_id, null, Vector2i.ZERO, target_size, "Preview texture is null.")

	var source_size: Vector2i = Vector2i(texture.get_width(), texture.get_height())
	if source_size.x <= 0 or source_size.y <= 0:
		return _make_preview_result(false, STATUS_INVALID_TEXTURE, source_id, null, source_size, target_size, "Preview texture size is invalid.")
	if not _is_size_within_budget(
		source_size,
		_get_budget_int(options, "max_source_dimension", DEFAULT_MAX_SOURCE_DIMENSION),
		_get_budget_int(options, "max_source_pixels", DEFAULT_MAX_SOURCE_PIXELS)
	):
		return _make_preview_result(false, STATUS_SOURCE_TOO_LARGE, source_id, null, source_size, target_size, "Source preview texture exceeds budget.")
	if not _is_size_within_budget(
		target_size,
		_get_budget_int(options, "max_target_dimension", DEFAULT_MAX_TARGET_DIMENSION),
		_get_budget_int(options, "max_target_pixels", DEFAULT_MAX_TARGET_PIXELS)
	):
		return _make_preview_result(false, STATUS_TARGET_TOO_LARGE, source_id, null, source_size, target_size, "Target preview size exceeds budget.")

	var source_image: Image = texture.get_image()
	if source_image == null or source_image.get_width() <= 0 or source_image.get_height() <= 0:
		return _make_preview_result(false, STATUS_DECODE_FAILED, source_id, null, source_size, target_size, "Source preview texture could not be decoded.")

	var fitted_size: Vector2i = _fit_size(Vector2i(source_image.get_width(), source_image.get_height()), target_size)
	var image: Image = source_image.duplicate()
	if image.is_compressed():
		var decompress_error: Error = image.decompress()
		if decompress_error != OK:
			return _make_preview_result(false, STATUS_DECODE_FAILED, source_id, null, source_size, target_size, error_string(decompress_error))
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
	return _make_preview_result(true, STATUS_GENERATED, source_id, ImageTexture.create_from_image(canvas), source_size, target_size, "")


## 为源纹理生成预览纹理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param texture: provider 返回的源纹理。
## [br]
## @param size: 目标预览尺寸。
## [br]
## @param options: 预算选项。
## [br]
## @schema options: Dictionary，可覆盖源纹理和目标预览的尺寸、像素预算。
## [br]
## @return 预览纹理；生成失败时返回 null。
func make_preview_texture(texture: Texture2D, size: Vector2i, options: Dictionary = {}) -> Texture2D:
	var result: Dictionary = make_preview_result(texture, size, options)
	return _get_result_texture(result)


# --- 私有/辅助方法 ---

func _resolve_source_id(preview_source: RefCounted, options: Dictionary) -> String:
	var source_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "source_id").strip_edges()
	if not source_id.is_empty():
		return source_id
	if preview_source.has_method(_SOURCE_ID_METHOD_NAME):
		return _GF_VARIANT_ACCESS_SCRIPT.to_text(preview_source.call(_SOURCE_ID_METHOD_NAME)).strip_edges()
	return "source_%d" % _next_order


func _get_record_source(record: Dictionary) -> RefCounted:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(record, "source")
	if value is RefCounted:
		var preview_source: RefCounted = value
		return preview_source
	return null


func _source_supports_resource(preview_source: RefCounted, resource: Resource) -> bool:
	if not preview_source.has_method(_SUPPORTS_METHOD_NAME):
		return true
	var value: Variant = preview_source.call(_SUPPORTS_METHOD_NAME, resource)
	if value is bool:
		var supported: bool = value
		return supported
	return false


func _get_source_texture(preview_source: RefCounted, resource: Resource) -> Texture2D:
	var value: Variant = preview_source.call(_SOURCE_METHOD_NAME, resource)
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


func _get_result_texture(result: Dictionary) -> Texture2D:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(result, "texture")
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


func _make_source_result(ok: bool, status: StringName, source_id: String, texture: Texture2D) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"source_id": source_id,
		"texture": texture,
	}


func _make_preview_result(
	ok: bool,
	status: StringName,
	source_id: String,
	texture: Texture2D,
	source_size: Vector2i,
	target_size: Vector2i,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"source_id": source_id,
		"texture": texture,
		"source_size": source_size,
		"target_size": target_size,
		"error": error,
	}


func _normalize_size(size: Vector2i) -> Vector2i:
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))


func _is_size_within_budget(size: Vector2i, max_dimension: int, max_pixels: int) -> bool:
	if max_dimension > 0 and (size.x > max_dimension or size.y > max_dimension):
		return false
	var pixel_count: int = size.x * size.y
	return max_pixels <= 0 or pixel_count <= max_pixels


func _get_budget_int(options: Dictionary, key: String, default_value: int) -> int:
	var value: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, key, default_value)
	return maxi(value, 0)


func _fit_size(source_size: Vector2i, target_size: Vector2i) -> Vector2i:
	var source_width: int = maxi(source_size.x, 1)
	var source_height: int = maxi(source_size.y, 1)
	var width_scale: float = float(target_size.x) / float(source_width)
	var height_scale: float = float(target_size.y) / float(source_height)
	var scale: float = minf(width_scale, height_scale)
	return Vector2i(
		maxi(1, int(roundf(float(source_width) * scale))),
		maxi(1, int(roundf(float(source_height) * scale)))
	)


static func _compare_source_records(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "priority", 0)
	var right_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "priority", 0)
	if left_priority != right_priority:
		return left_priority > right_priority
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 0) < _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 0)


# --- 内部类 ---

class _MethodPreviewSource:
	extends RefCounted

	# --- 常量 ---

	const _PREVIEW_TEXTURE_METHOD: StringName = &"get_gf_preview_texture"
	const _ICON_TEXTURE_METHOD: StringName = &"get_gf_icon_texture"


	# --- 层内方法 ---

	## 从 Resource 的约定预览方法中读取纹理。
	## [br]
	## @api layer_internal
	## [br]
	## @layer kernel/editor
	## [br]
	## @param resource: 待读取预览纹理的 Resource。
	## [br]
	## @return Resource 提供的预览纹理；没有可用纹理时返回 null。
	func get_preview_texture(resource: Resource) -> Texture2D:
		var preview_texture: Texture2D = _get_texture_from_method(resource, _PREVIEW_TEXTURE_METHOD)
		if preview_texture != null:
			return preview_texture
		return _get_texture_from_method(resource, _ICON_TEXTURE_METHOD)


	# --- 私有/辅助方法 ---

	func _get_texture_from_method(resource: Resource, method_name: StringName) -> Texture2D:
		if resource == null or not resource.has_method(method_name):
			return null

		var value: Variant = resource.call(method_name)
		if value is Texture2D:
			var texture: Texture2D = value
			return texture
		return null


class _PropertyPreviewSource:
	extends RefCounted

	# --- 常量 ---

	const _PREVIEW_TEXTURE_PROPERTY: StringName = &"preview_texture"
	const _ICON_TEXTURE_PROPERTY: StringName = &"icon"


	# --- 层内方法 ---

	## 从 Resource 的约定预览属性中读取纹理。
	## [br]
	## @api layer_internal
	## [br]
	## @layer kernel/editor
	## [br]
	## @param resource: 待读取预览纹理的 Resource。
	## [br]
	## @return Resource 持有的预览纹理；没有可用纹理时返回 null。
	func get_preview_texture(resource: Resource) -> Texture2D:
		var preview_texture: Texture2D = _get_texture_from_property(resource, _PREVIEW_TEXTURE_PROPERTY)
		if preview_texture != null:
			return preview_texture
		return _get_texture_from_property(resource, _ICON_TEXTURE_PROPERTY)


	# --- 私有/辅助方法 ---

	func _get_texture_from_property(resource: Resource, property_name: StringName) -> Texture2D:
		if resource == null or not _has_property(resource, property_name):
			return null

		var value: Variant = resource.get(property_name)
		if value is Texture2D:
			var texture: Texture2D = value
			return texture
		return null

	func _has_property(resource: Resource, property_name: StringName) -> bool:
		for property_info: Dictionary in resource.get_property_list():
			var raw_name: Variant = property_info.get("name", "")
			if _to_string_name(raw_name) == property_name:
				return true
		return false

	func _to_string_name(value: Variant) -> StringName:
		if value is StringName:
			var name_value: StringName = value
			return name_value
		if value is String:
			var text_value: String = value
			return StringName(text_value)
		return &""
