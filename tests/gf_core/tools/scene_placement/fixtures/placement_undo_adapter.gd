@tool

# 普通 GUT 中只适配原生 UndoRedo 的签名，不创建编辑器拥有的对象。
extends RefCounted


# --- 私有变量 ---

var _history: UndoRedo = UndoRedo.new()


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_history):
		_history.free()
		_history = null


# --- 公共方法 ---

func create_action(action_name: String, _merge_mode: int = 0, _custom_context: Object = null) -> void:
	_history.create_action(action_name, UndoRedo.MERGE_DISABLE)


func add_do_method(target: Object, method: StringName) -> void:
	_history.add_do_method(Callable(target, method))


func add_undo_method(target: Object, method: StringName) -> void:
	_history.add_undo_method(Callable(target, method))


func add_do_reference(target: Object) -> void:
	_history.add_do_reference(target)


func add_undo_reference(target: Object) -> void:
	_history.add_undo_reference(target)


func get_object_history_id(_target: Object) -> int:
	return 1


func commit_action(execute: bool = true) -> void:
	_history.commit_action(execute)


func undo() -> bool:
	return _history.undo()


func redo() -> bool:
	return _history.redo()


func clear() -> void:
	_history.clear_history()
