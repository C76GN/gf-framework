@tool

## GFEditorActionDefinition: 编辑器动作声明。
##
## 把菜单、按钮、快捷键或面板入口与命令工厂解耦。动作只负责描述入口和创建命令，
## 具体执行、撤销和业务含义由调用方或命令实现决定。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorActionDefinition
extends RefCounted


# --- 常量 ---

## 调用探针通过，动作当前可创建并执行命令。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_READY: StringName = &"ready"

## 动作被显式禁用。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_DISABLED: StringName = &"disabled"

## 动作当前未通过可用性回调。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_UNAVAILABLE: StringName = &"unavailable"

## 动作缺少有效命令工厂。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_FACTORY_MISSING: StringName = &"factory_missing"

## 命令工厂没有返回有效 GFEditorCommand。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_COMMAND_INVALID: StringName = &"command_invalid"

## 命令已创建，但命令自身当前不可执行。
## [br]
## @api public
## [br]
## @since 8.0.0
const INVOCATION_STATUS_COMMAND_UNAVAILABLE: StringName = &"command_unavailable"

## 编辑器命令基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorCommandBase = preload("res://addons/gf/kernel/editor/gf_editor_command.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")


# --- 公共变量 ---

## 动作稳定标识。
## [br]
## @api public
var action_id: StringName = &""

## 动作显示名称。
## [br]
## @api public
var label: String = ""

## 动作分组。用于命令面板、工具栏或菜单按领域组织入口。
## [br]
## @api public
## [br]
## @since 6.0.0
var group: StringName = &""

## 动作提示文本。
## [br]
## @api public
var tooltip: String = ""

## 快捷键说明文本，由具体 UI 决定是否展示。
## [br]
## @api public
var shortcut_text: String = ""

## 动作来源标识。通常是贡献该动作的 package、插件或工具 ID。
## [br]
## @api public
## [br]
## @since 6.0.0
var source_id: StringName = &""

## 同组内排序权重，数值越小越靠前。
## [br]
## @api public
## [br]
## @since 6.0.0
var sort_order: int = 0

## 动作是否启用。禁用动作不会创建命令或被调用。
## [br]
## @api public
## [br]
## @since 6.0.0
var enabled: bool = true

## 命令工厂。推荐签名为 `func(context: Dictionary) -> GFEditorCommand`。
## [br]
## @api public
var command_factory: Callable = Callable()

## 可用性回调。推荐签名为 `func(context: Dictionary) -> bool`，必须保持纯查询，不应创建或执行命令。
## [br]
## @api public
## [br]
## @since 6.0.0
var availability_callback: Callable = Callable()

## 动作元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined editor action metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 根据上下文创建命令。
##
## 该方法会遵守 enabled、command_factory 和 availability_callback，但不会执行命令。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to command_factory.
## [br]
## @return 命令对象，工厂无效或返回类型不匹配时为 null。
func create_command(context: Dictionary = {}) -> GFEditorCommandBase:
	if not enabled:
		return null
	if not command_factory.is_valid():
		return null
	if availability_callback.is_valid() and not _call_availability_callback(context):
		return null

	return _create_command_from_factory(context)


## 执行动作并可选接入 UndoRedo。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to create_command().
## [br]
## @param undo_manager: EditorUndoRedoManager 或兼容对象；为空时直接执行命令。
## [br]
## @return Godot 错误码。
func invoke(context: Dictionary = {}, undo_manager: Object = null) -> Error:
	if not enabled:
		return ERR_UNAVAILABLE
	if availability_callback.is_valid() and not _call_availability_callback(context):
		return ERR_UNAVAILABLE
	if not command_factory.is_valid():
		return ERR_CANT_CREATE

	var command: GFEditorCommandBase = _create_command_from_factory(context)
	if command == null:
		return ERR_CANT_CREATE

	if undo_manager != null:
		return command.add_to_undo_manager(undo_manager)
	return command.execute()


## 动作是否应在当前 UI 上下文中展示为可用。
##
## 这是轻量、无命令创建的纯查询，只检查 enabled、command_factory 与
## availability_callback。它不保证 invoke() 一定成功；需要严格执行前诊断时使用
## can_invoke() 或 get_invocation_report()。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to availability_callback.
## [br]
## @return UI 上下文中动作应标记为可用时返回 true。
func is_available(context: Dictionary = {}) -> bool:
	if not enabled:
		return false
	if not command_factory.is_valid():
		return false
	if availability_callback.is_valid():
		return _call_availability_callback(context)
	return true


## 当前上下文下动作是否可调用。
##
## 与 is_available() 不同，该方法会创建一次临时命令并检查 command.can_execute()，
## 但不会执行命令，也不会写入 UndoRedo。命令工厂必须把创建命令保持为无业务写入副作用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to command_factory.
## [br]
## @return 当前动作可调用时返回 true。
func can_invoke(context: Dictionary = {}) -> bool:
	var report: Dictionary = get_invocation_report(context)
	if report.has("ok") and report["ok"] is bool:
		var ok: bool = report["ok"]
		return ok
	return false


## 获取当前上下文下的动作调用诊断报告。
##
## 该方法会创建一次临时命令并检查 command.can_execute()，但不会执行命令，也不会写入
## UndoRedo。返回报告中的 metadata 会通过 GFReportValueCodec 编码为 JSON-safe 结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to command_factory.
## [br]
## @return 调用诊断报告。
## [br]
## @schema return: JSON-safe Dictionary containing ok, status, action_id, error_code, message, available, enabled, has_command_factory, command_created, command_can_execute, command_name, and metadata.
func get_invocation_report(context: Dictionary = {}) -> Dictionary:
	if not enabled:
		return _make_invocation_report(false, INVOCATION_STATUS_DISABLED, ERR_UNAVAILABLE, "动作已禁用。", false)
	if not command_factory.is_valid():
		return _make_invocation_report(false, INVOCATION_STATUS_FACTORY_MISSING, ERR_CANT_CREATE, "动作缺少有效命令工厂。", false)
	if availability_callback.is_valid() and not _call_availability_callback(context):
		return _make_invocation_report(false, INVOCATION_STATUS_UNAVAILABLE, ERR_UNAVAILABLE, "动作当前不可用。", false)

	var command: GFEditorCommandBase = _create_command_from_factory(context)
	if command == null:
		return _make_invocation_report(false, INVOCATION_STATUS_COMMAND_INVALID, ERR_CANT_CREATE, "命令工厂没有返回有效 GFEditorCommand。", true)
	var command_can_execute: bool = command.can_execute()
	if not command_can_execute:
		return _make_invocation_report(false, INVOCATION_STATUS_COMMAND_UNAVAILABLE, ERR_UNAVAILABLE, "命令当前不可执行。", true, command, false)
	return _make_invocation_report(true, INVOCATION_STATUS_READY, OK, "", true, command, true)


## 获取动作快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing action_id, label, group, tooltip, shortcut_text, source_id, sort_order, enabled, has_command_factory, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"action_id": String(action_id),
		"label": label,
		"group": String(group),
		"tooltip": tooltip,
		"shortcut_text": shortcut_text,
		"source_id": String(source_id),
		"sort_order": sort_order,
		"enabled": enabled,
		"has_command_factory": command_factory.is_valid(),
		"has_availability_callback": availability_callback.is_valid(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _create_command_from_factory(context: Dictionary) -> GFEditorCommandBase:
	var command_variant: Variant = command_factory.call(context)
	if command_variant is GFEditorCommandBase:
		var command: GFEditorCommandBase = command_variant
		return command
	return null


func _make_invocation_report(
	ok: bool,
	status: StringName,
	error_code: Error,
	message: String,
	available: bool,
	command: GFEditorCommandBase = null,
	command_can_execute: bool = false
) -> Dictionary:
	return {
		"ok": ok,
		"status": String(status),
		"action_id": String(action_id),
		"error_code": error_code,
		"message": message,
		"available": available,
		"enabled": enabled,
		"has_command_factory": command_factory.is_valid(),
		"command_created": command != null,
		"command_can_execute": command_can_execute,
		"command_name": command.command_name if command != null else "",
		"metadata": _to_report_dictionary(metadata),
	}


func _to_report_dictionary(value: Dictionary) -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(value, {
		"path_redaction": "basename",
	})


func _call_availability_callback(context: Dictionary) -> bool:
	var result: Variant = availability_callback.call(context)
	if result is bool:
		var bool_result: bool = result
		return bool_result
	return false
