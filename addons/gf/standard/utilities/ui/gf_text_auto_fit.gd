@tool

## GFTextAutoFit: 文本控件自动字体适配节点。
##
## 挂在文本控件旁边或子节点中，在控件尺寸、场景就绪或语言变化时调用 GFTextFitter。
## 它只负责字体尺寸计算和主题覆盖，不接管文本来源、布局策略或项目本地化规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTextAutoFit
extends Node


# --- 导出变量 ---

## 目标 Control 路径。为空时使用父节点。
## [br]
## @api public
@export_node_path("Control") var target_path: NodePath

## 最小字体尺寸。
## [br]
## @api public
@export var min_font_size: int = GFTextFitter.DEFAULT_MIN_FONT_SIZE:
	set(value):
		min_font_size = maxi(value, 1)
		request_refresh()

## 最大字体尺寸。小于等于 0 时使用控件当前主题字体尺寸。
## [br]
## @api public
@export var max_font_size: int = GFTextFitter.DEFAULT_MAX_FONT_SIZE:
	set(value):
		max_font_size = maxi(value, 0)
		request_refresh()

## 是否约束宽度。
## [br]
## @api public
@export var fit_width: bool = true:
	set(value):
		fit_width = value
		request_refresh()

## 是否约束高度。
## [br]
## @api public
@export var fit_height: bool = true:
	set(value):
		fit_height = value
		request_refresh()

## 是否在进入树并解析目标后立即适配。
## [br]
## @api public
@export var fit_on_ready: bool = true

## 是否监听目标控件 resized 信号。
## [br]
## @api public
@export var refresh_on_resize: bool = true

## 是否在收到翻译变更通知时刷新。
## [br]
## @api public
@export var refresh_on_translation_changed: bool = true

## 是否把刷新合并到 deferred 调用，避免同帧多次尺寸变化造成重复计算。
## [br]
## @api public
@export var deferred_refresh: bool = true

## 可选额外配置，会合并到 GFTextFitter.fit_control() 的 options。
## [br]
## @api public
## [br]
## @schema options: Dictionary，字段同 GFTextFitter.fit_control() 的 options；节点会覆盖 min_font_size、max_font_size、fit_width、fit_height 和 apply。
@export var options: Dictionary = {}


# --- 私有变量 ---

## 当前解析并绑定的文本目标控件。
## [br]
## @api private
var _target: Control = null

## 是否已有一次 deferred 刷新排队。
## [br]
## @api private
var _refresh_queued: bool = false


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_bind_target()


func _ready() -> void:
	_bind_target()
	if fit_on_ready:
		request_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and refresh_on_translation_changed:
		request_refresh()


func _exit_tree() -> void:
	_disconnect_target()


# --- 公共方法 ---

## 重新解析并绑定目标控件。
## [br]
## @api public
func rebind_target() -> void:
	_disconnect_target()
	_bind_target()
	request_refresh()


## 请求刷新文本适配。
## [br]
## @api public
func request_refresh() -> void:
	if not is_inside_tree():
		return
	if deferred_refresh:
		if _refresh_queued:
			return
		_refresh_queued = true
		call_deferred("_flush_refresh")
		return

	var _refresh_result_135: Variant = refresh()


## 立即执行一次文本适配。
## [br]
## @api public
## [br]
## @return 计算出的字体尺寸；目标无效时返回 0。
func refresh() -> int:
	_refresh_queued = false
	if _target == null or not is_instance_valid(_target):
		_bind_target()
	if _target == null:
		return 0

	var fit_options: Dictionary = options.duplicate(true)
	fit_options["min_font_size"] = min_font_size
	if max_font_size > 0:
		fit_options["max_font_size"] = max_font_size
	fit_options["fit_width"] = fit_width
	fit_options["fit_height"] = fit_height
	fit_options["apply"] = true
	return GFTextFitter.fit_control(_target, fit_options)


## 获取当前目标控件。
## [br]
## @api public
## [br]
## @return 已绑定的 Control；未绑定时返回 null。
func get_target() -> Control:
	if _target == null or not is_instance_valid(_target):
		_bind_target()
	return _target


# --- 私有/辅助方法 ---

## 解析目标并在目标改变时替换绑定，按配置连接 resized 刷新回调。
## [br]
## @api private
func _bind_target() -> void:
	var resolved: Control = _resolve_target()
	if resolved == _target:
		return

	_disconnect_target()
	_target = resolved
	if _target != null and refresh_on_resize and not _target.resized.is_connected(_on_target_resized):
		var _connect_result_181: Variant = _target.resized.connect(_on_target_resized)


## 断开当前目标的 resized 回调并清空目标引用。
## [br]
## @api private
func _disconnect_target() -> void:
	if _target != null and is_instance_valid(_target):
		if _target.resized.is_connected(_on_target_resized):
			_target.resized.disconnect(_on_target_resized)
	_target = null


## 优先解析 target_path；路径为空时解析父节点。
## [br]
## @api private
func _resolve_target() -> Control:
	if not target_path.is_empty():
		return _get_control(get_node_or_null(target_path))
	return _get_control(get_parent())


## 将 Variant 收窄为 Control；其他类型返回 null。
## [br]
## @api private
func _get_control(value: Variant) -> Control:
	if value is Control:
		var control: Control = value
		return control
	return null


## 执行已排队的刷新，并由 refresh() 清除排队标记。
## [br]
## @api private
func _flush_refresh() -> void:
	var _refresh_result_205: Variant = refresh()


# --- 信号处理函数 ---

## 目标尺寸变化时请求一次配置的文本适配刷新。
## [br]
## @api private
func _on_target_resized() -> void:
	request_refresh()
