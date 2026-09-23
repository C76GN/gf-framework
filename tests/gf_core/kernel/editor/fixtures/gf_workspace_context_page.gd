@tool

extends Control


# --- 公共变量 ---

static var next_context_callback: Callable = Callable()
static var next_enter_callback: Callable = Callable()
static var next_exit_callback: Callable = Callable()

var current_context: GFEditorToolContext = null
var context_at_first_enter: GFEditorToolContext = null
var context_at_last_exit: GFEditorToolContext = null
var context_update_count: int = 0
var enter_count: int = 0
var first_context_was_in_tree: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "Legacy Context"


func _enter_tree() -> void:
	if enter_count == 0:
		context_at_first_enter = current_context
	enter_count += 1
	var callback: Callable = next_enter_callback
	next_enter_callback = Callable()
	if callback.is_valid():
		var _callback_result: Variant = callback.call(self)


func _exit_tree() -> void:
	context_at_last_exit = current_context
	var callback: Callable = next_exit_callback
	next_exit_callback = Callable()
	if callback.is_valid():
		var _callback_result: Variant = callback.call(self)


# --- 公共方法 ---

func set_editor_context(editor_context: GFEditorToolContext) -> void:
	if context_update_count == 0:
		first_context_was_in_tree = is_inside_tree()
	current_context = editor_context
	context_update_count += 1
	var callback: Callable = next_context_callback
	next_context_callback = Callable()
	if callback.is_valid():
		var _callback_result: Variant = callback.call(self)
