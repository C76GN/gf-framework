@tool

## GFEditorTool: 持续式编辑器交互工具基类。
##
## 用于封装需要激活、停用、接收输入并最终产生命令的编辑器工具。
## 基类只定义生命周期协议，具体绘制和资源修改由子类实现。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorTool
extends RefCounted


# --- 常量 ---

## 编辑器工具上下文脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorToolContextBase = preload("res://addons/gf/kernel/editor/gf_editor_tool_context.gd")

## 编辑器拾取操作脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorPickOperationBase = preload("res://addons/gf/kernel/editor/gf_editor_pick_operation.gd")

## 编辑器工具选项集合脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorToolOptionSchemaBase = preload("res://addons/gf/kernel/editor/gf_editor_tool_option_schema.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 工具稳定标识。
## [br]
## @api public
var tool_id: StringName = &""

## 工具显示名称。
## [br]
## @api public
var label: String = ""

## 工具提示文本。
## [br]
## @api public
var tooltip: String = ""

## 工具排序权重。
## [br]
## @api public
var priority: int = 0

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined editor tool metadata.
var metadata: Dictionary = {}

## 可选工具选项声明。
## [br]
## @api public
var option_schema: GFEditorToolOptionSchemaBase = null


# --- 私有变量 ---

var _active: bool = false
var _context: GFEditorToolContextBase = null
var _option_values: Dictionary = {}
var _pick_operation: GFEditorPickOperationBase = null


# --- 公共方法 ---

## 激活工具。
## [br]
## @api public
## [br]
## @param context: 编辑器工具上下文。
func activate(context: GFEditorToolContextBase) -> void:
	if _active:
		return
	_context = context
	_active = true
	_on_activated(context)


## 停用工具。
## [br]
## @api public
func deactivate() -> void:
	if not _active:
		return
	var previous_context: GFEditorToolContextBase = _context
	_active = false
	if _pick_operation != null:
		_pick_operation.cancel()
		_pick_operation = null
	_on_deactivated(previous_context)
	_context = null


## 工具是否处于激活状态。
## [br]
## @api public
## [br]
## @return 激活时返回 true。
func is_active() -> bool:
	return _active


## 获取当前上下文。
## [br]
## @api public
## [br]
## @return 当前上下文；未激活时返回 null。
func get_context() -> GFEditorToolContextBase:
	return _context


## 设置工具选项声明。
## [br]
## @api public
## [br]
## @param schema: 工具选项声明。
## [br]
## @param reset_values: 是否重置当前选项值。
func set_option_schema(schema: GFEditorToolOptionSchemaBase, reset_values: bool = true) -> void:
	option_schema = schema.duplicate_schema() if schema != null else null
	if reset_values:
		_option_values = option_schema.get_default_values() if option_schema != null else {}


## 设置工具选项值。
## [br]
## @api public
## [br]
## @param option_id: 选项标识。
## [br]
## @param value: 选项值。
## [br]
## @schema value: Variant raw option value.
## [br]
## @return 设置成功返回 true。
func set_tool_option(option_id: StringName, value: Variant) -> bool:
	if option_schema == null or not option_schema.has_option(option_id):
		return false
	var option: GFEditorToolOption = option_schema.get_option(option_id)
	_option_values[option_id] = option.normalize_value(value)
	return true


## 获取工具选项值。
## [br]
## @api public
## [br]
## @param option_id: 选项标识。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @schema default_value: Variant fallback returned when the option is missing.
## [br]
## @return 选项值。
## [br]
## @schema return: Variant option value copy or fallback.
func get_tool_option(option_id: StringName, default_value: Variant = null) -> Variant:
	if _option_values.has(option_id):
		return _duplicate_variant(_option_values[option_id])
	return default_value


## 获取工具选项快照。
## [br]
## @api public
## [br]
## @return 选项值副本。
## [br]
## @schema return: Dictionary keyed by option_id, storing option values.
func get_tool_options() -> Dictionary:
	return _option_values.duplicate(true)


## 清空工具选项值。
## [br]
## @api public
func clear_tool_options() -> void:
	_option_values.clear()


## 工具是否可以处理当前上下文。
## [br]
## @api public
## [br]
## @param context: 编辑器工具上下文。
## [br]
## @return 可处理时返回 true。
func can_handle(context: GFEditorToolContextBase) -> bool:
	return context != null


## 开始分阶段拾取操作。
## [br]
## @api public
## [br]
## @param operation: 拾取操作。
## [br]
## @return 成功开始返回 true。
func begin_pick_operation(operation: GFEditorPickOperationBase) -> bool:
	if not _active or operation == null:
		return false
	if _pick_operation != null:
		_pick_operation.cancel()
		_pick_operation = null
	if not operation.begin(_context):
		return false
	_pick_operation = operation
	return true


## 向当前拾取操作输入数据。
## [br]
## @api public
## [br]
## @param input_data: 通用拾取数据。
## [br]
## @schema input_data: Dictionary pick input forwarded to the active pick operation.
## [br]
## @return 当前拾取状态；没有操作时返回 IDLE。
func pick(input_data: Dictionary) -> int:
	if not _active or _pick_operation == null:
		return GFEditorPickOperationBase.State.IDLE
	return _pick_operation.pick(input_data)


## 应用当前拾取操作。
## [br]
## @api public
## [br]
## @return 应用结果字典。
## [br]
## @schema return: Dictionary apply result from the active pick operation.
func apply_pick_operation() -> Dictionary:
	if not _active:
		return {
			"ok": false,
			"reason": &"tool_inactive",
		}
	if _pick_operation == null:
		return {
			"ok": false,
			"reason": &"missing_operation",
		}
	var result: Dictionary = _pick_operation.apply()
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false):
		_pick_operation = null
	return result


## 取消当前拾取操作。
## [br]
## @api public
func cancel_pick_operation() -> void:
	if _pick_operation == null:
		return
	_pick_operation.cancel()
	_pick_operation = null


## 获取当前拾取操作。
## [br]
## @api public
## [br]
## @return 拾取操作；不存在时返回 null。
func get_pick_operation() -> GFEditorPickOperationBase:
	return _pick_operation


## 向工具转发输入事件。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return true 表示事件已被工具消费。
func gui_input(event: InputEvent) -> bool:
	if not _active:
		return false
	return _handle_gui_input(event)


## 请求工具绘制调试或交互辅助。
## [br]
## @api public
## [br]
## @param viewport: 绘制目标视口。
func draw_tool(viewport: Viewport) -> void:
	if not _active:
		return
	_draw_tool(viewport)


## 获取工具快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing tool_id, label, tooltip, priority, active, options, pick_operation, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"tool_id": String(tool_id),
		"label": label,
		"tooltip": tooltip,
		"priority": priority,
		"active": _active,
		"options": _option_values.duplicate(true),
		"pick_operation": _pick_operation.get_debug_snapshot() if _pick_operation != null else {},
		"metadata": metadata.duplicate(true),
	}


# --- 虚方法（由子类重写） ---

## 工具激活时调用，供子类重写。
## [br]
## @api protected
## [br]
## @param _tool_context: 编辑器工具上下文。
func _on_activated(_tool_context: GFEditorToolContextBase) -> void:
	pass


## 工具停用时调用，供子类重写。
## [br]
## @api protected
## [br]
## @param _tool_context: 编辑器工具上下文。
func _on_deactivated(_tool_context: GFEditorToolContextBase) -> void:
	pass


## 处理 GUI 输入事件，供子类重写。
## [br]
## @api protected
## [br]
## @param _event: 输入事件。
## [br]
## @return 事件被消费时返回 true。
func _handle_gui_input(_event: InputEvent) -> bool:
	return false


## 绘制工具辅助内容，供子类重写。
## [br]
## @api protected
## [br]
## @param _viewport: 绘制目标视口。
func _draw_tool(_viewport: Viewport) -> void:
	pass


# --- 私有/辅助方法 ---

func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	if value is Array:
		var array: Array = value
		return array.duplicate(true)
	return value
