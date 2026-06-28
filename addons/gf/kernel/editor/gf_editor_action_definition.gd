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

## 编辑器命令基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorCommandBase = preload("res://addons/gf/kernel/editor/gf_editor_command.gd")


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
## [br]
## @api public
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

	var command_variant: Variant = command_factory.call(context)
	if command_variant is GFEditorCommandBase:
		var command: GFEditorCommandBase = command_variant
		return command
	return null


## 执行动作并可选接入 UndoRedo。
## [br]
## @api public
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

	var command: GFEditorCommandBase = create_command(context)
	if command == null:
		return ERR_CANT_CREATE

	if undo_manager != null:
		return command.add_to_undo_manager(undo_manager)
	return command.execute()


## 动作是否具备可调用命令工厂。
## [br]
## @api public
## [br]
## @param context: 调用方传入的编辑器上下文。
## [br]
## @schema context: Dictionary editor context passed to create_command().
## [br]
## @return 可创建且可执行命令时返回 true。
func is_available(context: Dictionary = {}) -> bool:
	if not enabled:
		return false
	if not command_factory.is_valid():
		return false
	if availability_callback.is_valid():
		return _call_availability_callback(context)
	return true


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

func _call_availability_callback(context: Dictionary) -> bool:
	var result: Variant = availability_callback.call(context)
	if result is bool:
		var bool_result: bool = result
		return bool_result
	return false
