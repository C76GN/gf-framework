@tool
extends StandardMaterial3D


# --- 公共变量 ---

static var initialized_count: int = 0


# --- Godot 生命周期方法 ---

func _init() -> void:
	initialized_count += 1
