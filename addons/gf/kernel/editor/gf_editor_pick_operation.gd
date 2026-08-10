@tool

## GFEditorPickOperation: 编辑器工具的分阶段拾取操作协议。
##
## 用于描述 pick、preview、ready、apply 和 cancel 这类持续交互流程。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorPickOperation
extends RefCounted


# --- 枚举 ---

## 拾取操作状态。
## [br]
## @api public
enum State {
	## 尚未开始。
	IDLE,
	## 正在拾取。
	PICKING,
	## 已准备好应用。
	READY,
	## 已应用。
	APPLIED,
	## 已取消。
	CANCELLED,
}


# --- 常量 ---

## 编辑器工具上下文脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorToolContextBase = preload("res://addons/gf/kernel/editor/gf_editor_tool_context.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 操作稳定标识。
## [br]
## @api public
var operation_id: StringName = &""

## 操作显示名称。
## [br]
## @api public
var label: String = ""

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined pick operation metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _state: State = State.IDLE
var _context: GFEditorToolContextBase = null
var _preview: Dictionary = {}
var _result: Dictionary = {}


# --- 公共方法 ---

## 开始拾取操作。
## [br]
## @api public
## [br]
## @param context: 编辑器工具上下文。
## [br]
## @return 成功开始返回 true。
func begin(context: GFEditorToolContextBase) -> bool:
	if context == null or _state == State.PICKING or _state == State.READY:
		return false
	_context = context
	_state = State.PICKING
	_preview.clear()
	_result.clear()
	_on_begin(context)
	return true


## 输入一次拾取数据。
## [br]
## @api public
## [br]
## @param input_data: 调用方传入的通用拾取数据。
## [br]
## @schema input_data: Dictionary containing tool-specific pick input.
## [br]
## @return 操作状态。
func pick(input_data: Dictionary) -> State:
	if _state != State.PICKING and _state != State.READY:
		return _state

	var response: Dictionary = _on_pick(input_data)
	if response.has("preview") and response["preview"] is Dictionary:
		_preview = _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(response["preview"], {})
	if response.has("result") and response["result"] is Dictionary:
		_result = _GF_VARIANT_ACCESS_SCRIPT.to_dictionary(response["result"], {})

	var ready: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(response, "ready", _on_can_apply())
	_state = State.READY if ready else State.PICKING
	return _state


## 检查当前操作是否可应用。
## [br]
## @api public
## [br]
## @return 可应用返回 true。
func can_apply() -> bool:
	return _state == State.READY and _on_can_apply()


## 应用拾取结果。
## [br]
## @api public
## [br]
## @return 应用结果字典。
## [br]
## @schema return: Dictionary result produced by _on_apply().
func apply() -> Dictionary:
	if not can_apply():
		return {
			"ok": false,
			"reason": &"not_ready",
		}
	var result: Dictionary = _on_apply(_context, _result.duplicate(true))
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false):
		_state = State.APPLIED
	return result


## 取消拾取操作。
## [br]
## @api public
func cancel() -> void:
	if _state == State.APPLIED or _state == State.CANCELLED:
		return
	_on_cancel(_context)
	_state = State.CANCELLED


## 获取当前状态。
## [br]
## @api public
## [br]
## @return 当前操作状态。
func get_state() -> State:
	return _state


## 获取预览数据副本。
## [br]
## @api public
## [br]
## @return 预览数据。
## [br]
## @schema return: Dictionary preview data produced by _on_pick().
func get_preview() -> Dictionary:
	return _preview.duplicate(true)


## 获取拾取结果副本。
## [br]
## @api public
## [br]
## @return 拾取结果。
## [br]
## @schema return: Dictionary result data produced by _on_pick().
func get_result() -> Dictionary:
	return _result.duplicate(true)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary containing operation_id, label, state, preview, result, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"operation_id": operation_id,
		"label": label,
		"state": _state,
		"preview": _preview.duplicate(true),
		"result": _result.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


# --- 虚方法（由子类重写） ---

## 拾取流程开始时调用，供子类重写。
## [br]
## @api protected
## [br]
## @param _tool_context: 编辑器工具上下文。
func _on_begin(_tool_context: GFEditorToolContextBase) -> void:
	pass


## 处理一次拾取输入，供子类重写。
## [br]
## @api protected
## [br]
## @param _input_data: 调用方传入的通用拾取数据。
## [br]
## @schema _input_data: Dictionary containing tool-specific pick input.
## [br]
## @return 拾取响应字典，可包含 preview、result 和 ready。
## [br]
## @schema return: Dictionary pick response.
func _on_pick(_input_data: Dictionary) -> Dictionary:
	return {}


## 判断当前拾取结果是否可以应用，供子类重写。
## [br]
## @api protected
## [br]
## @return 可应用返回 true。
func _on_can_apply() -> bool:
	return not _result.is_empty()


## 应用拾取结果，供子类重写。
## [br]
## @api protected
## [br]
## @param _tool_context: 编辑器工具上下文。
## [br]
## @param result: 拾取结果副本。
## [br]
## @schema result: Dictionary pick result data.
## [br]
## @return 应用结果字典。
## [br]
## @schema return: Dictionary apply result.
func _on_apply(_tool_context: GFEditorToolContextBase, result: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"result": result,
	}


## 取消拾取流程时调用，供子类重写。
## [br]
## @api protected
## [br]
## @param _tool_context: 编辑器工具上下文。
func _on_cancel(_tool_context: GFEditorToolContextBase) -> void:
	pass
