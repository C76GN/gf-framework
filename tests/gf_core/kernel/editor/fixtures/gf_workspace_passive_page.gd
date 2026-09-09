@tool

extends Control


# --- 公共变量 ---

var enter_count: int = 0
var marker: String = "unchanged"


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	enter_count += 1
