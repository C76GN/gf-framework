@tool

# GF 编辑器独立工作区窗口。
#
# 承载由 kernel、standard 和扩展贡献的通用编辑器页面，不绑定具体业务语义。
extends Window


# --- 常量 ---

## 默认窗口尺寸。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_WINDOW_SIZE: Vector2i = Vector2i(1180, 760)

## 最小窗口尺寸。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const MIN_WINDOW_SIZE: Vector2i = Vector2i(900, 560)

## 窗口标题。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const WINDOW_TITLE: String = "GF Workspace"

## 工作区 Dock 控件脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorWorkspaceDockBase = preload("res://addons/gf/kernel/editor/gf_editor_workspace_dock.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _workspace: Control = null
var _dock_records: Array[Dictionary] = []


# --- Godot 生命周期方法 ---

func _init() -> void:
	title = WINDOW_TITLE
	size = DEFAULT_WINDOW_SIZE
	min_size = MIN_WINDOW_SIZE
	transient = false
	exclusive = false
	wrap_controls = true
	visible = false
	var _connect_result_57: Variant = close_requested.connect(_on_close_requested)
	_build_ui()


# --- 公共方法 ---

## 设置工作区页面记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param dock_records: 页面记录数组。每条记录至少包含 path，可选 label。
## [br]
## @param editor_context: 可选编辑器上下文；页面可通过 set_editor_context 接收。
## [br]
## @schema dock_records: Array of Dictionary dock page records.
func setup(dock_records: Array[Dictionary], editor_context: GFEditorToolContext = null) -> void:
	_dock_records = _copy_records(dock_records)
	if _workspace != null and _workspace.has_method("setup"):
		_workspace.call("setup", _dock_records, editor_context)


## 更新已创建页面的编辑器上下文；传入 null 撤销页面的编辑环境。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param editor_context: 当前上下文或 null。
func set_editor_context(editor_context: GFEditorToolContext) -> void:
	if _workspace != null and _workspace.has_method("set_editor_context"):
		_workspace.call("set_editor_context", editor_context)


## 显示工作区窗口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func popup_workspace() -> void:
	if size.x <= 0 or size.y <= 0:
		size = DEFAULT_WINDOW_SIZE
	var restore_always_on_top: bool = always_on_top
	if restore_always_on_top:
		always_on_top = false
		_prepare_always_on_top_window()
	popup_centered(size)
	if restore_always_on_top:
		_prepare_always_on_top_window()
		always_on_top = true
	_sync_workspace_window_controls()


## 隐藏工作区窗口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func hide_workspace() -> void:
	hide()


## 获取工作区页面数量。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 页面数量。
func get_page_count() -> int:
	if _workspace != null and _workspace.has_method("get_page_count"):
		return _GF_VARIANT_ACCESS_SCRIPT.to_int(_workspace.call("get_page_count"))
	return 0


## 获取页面标题列表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 页面标题。
func get_page_titles() -> PackedStringArray:
	if _workspace != null and _workspace.has_method("get_page_titles"):
		var titles: Variant = _workspace.call("get_page_titles")
		if titles is PackedStringArray:
			var packed_titles: PackedStringArray = titles
			return packed_titles
	return PackedStringArray()


## 获取内部工作区控件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 工作区控件。
func get_workspace() -> Control:
	return _workspace


## 设置独立工作区窗口是否保持置顶。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param enabled: 为 true 时窗口保持在其他窗口上方。
func set_always_on_top_enabled(enabled: bool) -> void:
	if enabled:
		_prepare_always_on_top_window()
	always_on_top = enabled
	_sync_workspace_window_controls()


## 查询独立工作区窗口是否保持置顶。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 保持置顶时返回 true。
func is_always_on_top_enabled() -> bool:
	return always_on_top


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	if _workspace != null:
		return

	_workspace = GFEditorWorkspaceDockBase.new()
	_workspace.name = "Workspace"
	_workspace.clip_contents = true
	_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_workspace)
	_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_workspace_window_controls()


func _copy_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in source:
		records.append(record.duplicate(true))
	return records


func _sync_workspace_window_controls() -> void:
	if _workspace != null and _workspace.has_method("_sync_window_controls"):
		_workspace.call("_sync_window_controls")


func _prepare_always_on_top_window() -> void:
	transient = false
	exclusive = false


# --- 信号处理函数 ---

func _on_close_requested() -> void:
	hide_workspace()
