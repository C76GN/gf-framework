@tool

extends Control


# --- 公共变量 ---

var current_context: GFEditorToolContext = null
var context_at_first_enter: GFEditorToolContext = null
var context_at_last_exit: GFEditorToolContext = null
var context_update_count: int = 0
var enter_count: int = 0
var first_context_was_in_tree: bool = false


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	if enter_count == 0:
		context_at_first_enter = current_context
	enter_count += 1


func _exit_tree() -> void:
	context_at_last_exit = current_context


# --- 公共方法 ---

func set_editor_context(editor_context: GFEditorToolContext) -> void:
	if context_update_count == 0:
		first_context_was_in_tree = is_inside_tree()
	current_context = editor_context
	context_update_count += 1
