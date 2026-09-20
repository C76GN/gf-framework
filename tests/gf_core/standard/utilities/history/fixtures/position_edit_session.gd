# 项目侧位置编辑示例：预览保存在会话中，确认后才提交一个命令。
extends RefCounted


# --- 私有变量 ---

var _model: PositionModel
var _history: GFCommandHistoryUtility
var _initial_position: Vector2 = Vector2.ZERO
var _preview_position: Vector2 = Vector2.ZERO
var _editing: bool = false


# --- Godot 生命周期方法 ---

func _init(model: PositionModel, history: GFCommandHistoryUtility) -> void:
	_model = model
	_history = history


# --- 公共方法 ---

func begin_edit() -> bool:
	if _editing:
		return false
	_initial_position = _model.position
	_preview_position = _initial_position
	_editing = true
	return true


func update_preview(position: Vector2) -> bool:
	if not _editing:
		return false
	_preview_position = position
	return true


func get_preview_position() -> Vector2:
	return _preview_position if _editing else _model.position


func confirm_edit() -> bool:
	if not _editing:
		return false
	_editing = false
	if _preview_position == _initial_position:
		return false
	var command: MovePositionCommand = MovePositionCommand.new(
		_model, _initial_position, _preview_position
	)
	var result: Variant = await _history.execute_command(command)
	return GFVariantData.to_bool(result, false)


func cancel_edit() -> bool:
	if not _editing:
		return false
	_editing = false
	return true


# --- 内部类 ---

class PositionModel:
	extends RefCounted

	signal position_changed(position: Vector2)

	var position: Vector2 = Vector2.ZERO:
		set(value):
			position = value
			position_changed.emit(value)


class MovePositionCommand:
	extends GFUndoableCommand

	var _model: PositionModel
	var _initial_position: Vector2
	var _final_position: Vector2

	func _init(model: PositionModel, initial_position: Vector2, final_position: Vector2) -> void:
		_model = model
		_initial_position = initial_position
		_final_position = final_position
		action_name = "move_item"

	func execute() -> Variant:
		_model.position = _final_position
		return true

	func undo() -> Variant:
		_model.position = _initial_position
		return true
