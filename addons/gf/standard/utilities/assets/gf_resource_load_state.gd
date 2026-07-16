## GFResourceLoadState: 资源加载状态与引用快照。
##
## 用于把资源键、路径、加载状态、进度、错误和弱/强引用模式收敛为统一状态对象。
## 它不发起 ResourceLoader 请求，也不规定资源包、下载或缓存策略。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 7.0.0
class_name GFResourceLoadState
extends RefCounted


# --- 常量 ---

## 尚未请求资源。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_UNREQUESTED: StringName = &"unrequested"

## 已请求资源但尚未开始加载。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REQUESTED: StringName = &"requested"

## 资源正在加载。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_LOADING: StringName = &"loading"

## 资源已加载。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_LOADED: StringName = &"loaded"

## 资源加载失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_FAILED: StringName = &"failed"

## 资源引用已释放。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_RELEASED: StringName = &"released"

## 资源状态已过期，需要调用方重新解析或加载。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_STALE: StringName = &"stale"

## 只保存弱引用。
## [br]
## @api public
## [br]
## @since 7.0.0
const REFERENCE_WEAK: StringName = &"weak"

## 保存强引用，由状态对象持有资源。
## [br]
## @api public
## [br]
## @since 7.0.0
const REFERENCE_STRONG: StringName = &"strong"


# --- 公共变量 ---

## 稳定资源键。
## [br]
## @api public
## [br]
## @since 7.0.0
var resource_key: StringName = &""

## 资源路径或解析后的路径。
## [br]
## @api public
## [br]
## @since 7.0.0
var resource_path: String = ""

## 当前加载状态。
## [br]
## @api public
## [br]
## @since 7.0.0
var status: StringName = STATUS_UNREQUESTED:
	set(value):
		status = _normalize_status(value)

## 加载进度，范围 0 到 1。
## [br]
## @api public
## [br]
## @since 7.0.0
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)

## 最近错误文本。
## [br]
## @api public
## [br]
## @since 7.0.0
var error: String = ""

## 资源引用模式。
## [br]
## @api public
## [br]
## @since 7.0.0
var reference_mode: StringName = REFERENCE_WEAK:
	set(value):
		reference_mode = _normalize_reference_mode(value)

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary for caller-defined resource state metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _resource_ref: WeakRef
var _resource_value: Resource


# --- 公共方法 ---

## 配置资源加载状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_resource_key: 稳定资源键。
## [br]
## @param p_resource_path: 资源路径。
## [br]
## @param options: 状态选项，支持 status、progress、error、reference_mode 和 metadata。
## [br]
## @schema options: Dictionary，可包含 status: StringName、progress: float、error: String、reference_mode: StringName、metadata: Dictionary。
## [br]
## @return 当前状态。
func configure(
	p_resource_key: StringName,
	p_resource_path: String = "",
	options: Dictionary = {}
) -> GFResourceLoadState:
	resource_key = p_resource_key
	resource_path = p_resource_path
	status = GFVariantData.get_option_string_name(options, "status", STATUS_UNREQUESTED)
	progress = GFVariantData.get_option_float(options, "progress", 0.0)
	error = GFVariantData.get_option_string(options, "error")
	reference_mode = GFVariantData.get_option_string_name(options, "reference_mode", REFERENCE_WEAK)
	metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	return self


## 设置状态并按需合并 metadata。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_status: 新状态。
## [br]
## @param options: 状态选项，支持 progress、error、metadata 和 clear_error。
## [br]
## @schema options: Dictionary，可包含 progress: float、error: String、metadata: Dictionary、clear_error: bool。
## [br]
## @return 当前状态。
func set_status(p_status: StringName, options: Dictionary = {}) -> GFResourceLoadState:
	status = p_status
	if options.has("progress"):
		progress = GFVariantData.get_option_float(options, "progress", progress)
	if options.has("error"):
		error = GFVariantData.get_option_string(options, "error")
	elif GFVariantData.get_option_bool(options, "clear_error", false):
		error = ""
	_merge_metadata(GFVariantData.get_option_dictionary(options, "metadata"))
	return self


## 设置当前资源引用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param resource: 已加载资源；为空时会清除引用。
## [br]
## @param options: 引用选项，支持 reference_mode 和 metadata。
## [br]
## @schema options: Dictionary，可包含 reference_mode: StringName 和 metadata: Dictionary。
## [br]
## @return 当前状态。
func set_resource(resource: Resource, options: Dictionary = {}) -> GFResourceLoadState:
	if resource == null:
		var _cleared: GFResourceLoadState = clear_resource({ "status": STATUS_RELEASED })
		return self

	reference_mode = GFVariantData.get_option_string_name(options, "reference_mode", reference_mode)
	_resource_ref = weakref(resource)
	_resource_value = resource if reference_mode == REFERENCE_STRONG else null
	progress = 1.0
	status = STATUS_LOADED
	error = ""
	_merge_metadata(GFVariantData.get_option_dictionary(options, "metadata"))
	return self


## 获取当前资源引用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前资源；弱引用已释放时返回 null。
func get_resource() -> Resource:
	if _resource_value != null:
		return _resource_value
	if _resource_ref == null:
		return null

	var value: Variant = _resource_ref.get_ref()
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


## 检查当前状态是否仍能取得资源。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 资源引用仍有效时返回 true。
func has_resource() -> bool:
	return get_resource() != null


## 清除当前资源引用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 清除选项，支持 status 和 metadata。
## [br]
## @schema options: Dictionary，可包含 status: StringName 和 metadata: Dictionary。
## [br]
## @return 当前状态。
func clear_resource(options: Dictionary = {}) -> GFResourceLoadState:
	_resource_ref = null
	_resource_value = null
	status = GFVariantData.get_option_string_name(options, "status", STATUS_RELEASED)
	_merge_metadata(GFVariantData.get_option_dictionary(options, "metadata"))
	return self


## 标记资源已请求。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_requested(p_metadata: Dictionary = {}) -> GFResourceLoadState:
	return set_status(STATUS_REQUESTED, {
		"progress": 0.0,
		"clear_error": true,
		"metadata": p_metadata,
	})


## 标记资源正在加载。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_progress: 加载进度。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_loading(p_progress: float = 0.0, p_metadata: Dictionary = {}) -> GFResourceLoadState:
	return set_status(STATUS_LOADING, {
		"progress": p_progress,
		"clear_error": true,
		"metadata": p_metadata,
	})


## 标记资源已加载并保存引用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param resource: 已加载资源。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_loaded(resource: Resource, p_metadata: Dictionary = {}) -> GFResourceLoadState:
	return set_resource(resource, { "metadata": p_metadata })


## 标记加载失败。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param error_text: 错误文本。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_failed(error_text: String, p_metadata: Dictionary = {}) -> GFResourceLoadState:
	return set_status(STATUS_FAILED, {
		"progress": progress,
		"error": error_text,
		"metadata": p_metadata,
	})


## 标记资源已释放。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_released(p_metadata: Dictionary = {}) -> GFResourceLoadState:
	return clear_resource({
		"status": STATUS_RELEASED,
		"metadata": p_metadata,
	})


## 标记资源状态已过期。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 过期原因。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary merged into metadata.
## [br]
## @return 当前状态。
func mark_stale(reason: String = "", p_metadata: Dictionary = {}) -> GFResourceLoadState:
	var stale_metadata: Dictionary = p_metadata.duplicate(true)
	if not reason.is_empty():
		stale_metadata["stale_reason"] = reason
	return set_status(STATUS_STALE, {
		"metadata": stale_metadata,
	})


## 检查当前状态是否为成功终态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 成功加载且资源引用有效时返回 true。
func is_success() -> bool:
	return status == STATUS_LOADED and has_resource()


## 检查当前状态是否为终态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return loaded、failed 或 released 时返回 true。
func is_terminal() -> bool:
	return status == STATUS_LOADED or status == STATUS_FAILED or status == STATUS_RELEASED


## 获取当前资源身份快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 可选项，支持 check_exists。
## [br]
## @return 资源身份对象。
## [br]
## @schema options: Dictionary with optional `check_exists: bool`.
func get_resource_identity(options: Dictionary = {}) -> GFResourceIdentity:
	var identity_options: Dictionary = options.duplicate(true)
	if not identity_options.has("metadata"):
		identity_options["metadata"] = metadata.duplicate(true)
	return GFResourceIdentity.from_path(resource_path, resource_key, "", identity_options)


## 导出状态字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 状态字典。
## [br]
## @schema return: Dictionary，包含 resource_key、resource_path、resource_identity、status、progress、error、reference_mode、has_resource、resource_instance_id 和 metadata。
func to_dictionary() -> Dictionary:
	var resource: Resource = get_resource()
	var identity: GFResourceIdentity = get_resource_identity()
	return {
		"resource_key": resource_key,
		"resource_path": resource_path,
		"resource_identity": identity.to_dictionary(),
		"status": status,
		"progress": progress,
		"error": error,
		"reference_mode": reference_mode,
		"has_resource": resource != null,
		"resource_instance_id": resource.get_instance_id() if resource != null else 0,
		"metadata": metadata.duplicate(true),
	}


## 复制状态对象；当前资源引用会以相同引用模式传递。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 状态副本。
func duplicate_state() -> GFResourceLoadState:
	var state: GFResourceLoadState = from_dictionary(to_dictionary())
	var resource: Resource = get_resource()
	if resource != null and state != null:
		var _copied: Variant = state.set_resource(resource, { "reference_mode": reference_mode })
	return state


## 从字典恢复状态对象。资源引用不会从字典中恢复。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param data: to_dictionary() 兼容字典。
## [br]
## @schema data: Dictionary with resource_key, resource_path, status, progress, error, reference_mode and metadata.
## [br]
## @return 状态对象。
static func from_dictionary(data: Dictionary) -> GFResourceLoadState:
	var state: GFResourceLoadState = GFResourceLoadState.new()
	var restored_path: String = GFVariantData.get_option_string(data, "resource_path")
	if restored_path.is_empty():
		var identity_data: Dictionary = GFVariantData.get_option_dictionary(data, "resource_identity")
		restored_path = GFVariantData.get_option_string(
			identity_data,
			"raw_path",
			GFVariantData.get_option_string(identity_data, "canonical_path")
		)
	var _configured: Variant = state.configure(
		GFVariantData.get_option_string_name(data, "resource_key"),
		restored_path,
		{
			"status": GFVariantData.get_option_string_name(data, "status", STATUS_UNREQUESTED),
			"progress": GFVariantData.get_option_float(data, "progress", 0.0),
			"error": GFVariantData.get_option_string(data, "error"),
			"reference_mode": GFVariantData.get_option_string_name(data, "reference_mode", REFERENCE_WEAK),
			"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
		}
	)
	return state


# --- 私有/辅助方法 ---

func _merge_metadata(extra_metadata: Dictionary) -> void:
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(metadata, extra_metadata, true, true)


func _normalize_status(value: StringName) -> StringName:
	match value:
		STATUS_REQUESTED, STATUS_LOADING, STATUS_LOADED, STATUS_FAILED, STATUS_RELEASED, STATUS_STALE:
			return value
		_:
			return STATUS_UNREQUESTED


func _normalize_reference_mode(value: StringName) -> StringName:
	if value == REFERENCE_STRONG:
		return REFERENCE_STRONG
	return REFERENCE_WEAK
